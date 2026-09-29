# Offline demonstration for Assignment 4.
# 1. Waits until the internet is disconnected (checks a web URL and a ping).
# 2. Restarts Ollama, then runs help, ingestion, the four ask tests, search and chat checks,
#    each as a fresh CLI process, saving every output under evidence/offline/.
# 3. Writes evidence/offline/SUMMARY.md and a screenshot, then asks you to reconnect.
# -Rehearsal runs online into evidence/rehearsal-online/ to test the script (NOT offline evidence).
param([switch]$Rehearsal)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = New-Object Text.UTF8Encoding $false   # no BOM on text piped into python's stdin
$env:PYTHONIOENCODING = "utf-8"
$outDir = if ($Rehearsal) { "evidence\rehearsal-online" } else { "evidence\offline" }
$labelPrefix = if ($Rehearsal) { "rehearsal" } else { "offline" }
New-Item -ItemType Directory -Force $outDir | Out-Null
$python = (Get-Command python -ErrorAction Stop).Source
$ollama = (Get-Command ollama -ErrorAction Stop).Source

function Test-Online {
    $web = $false
    try { Invoke-WebRequest "http://www.msftconnecttest.com/connecttest.txt" -UseBasicParsing -TimeoutSec 4 | Out-Null; $web = $true } catch {}
    $ping = Test-Connection 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Web = $web; Ping = [bool]$ping; Online = ($web -or $ping) }
}

function Banner($text) { Write-Host ""; Write-Host ("=" * 70) -ForegroundColor Cyan; Write-Host "  $text" -ForegroundColor Cyan; Write-Host ("=" * 70) -ForegroundColor Cyan }

$results = @()
function Run-Step($name, $file, [string[]]$cliArgs, [string[]]$stdin = $null) {
    Banner "$name   >  python wiki.py $($cliArgs -join ' ')"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    if ($stdin) { $out = $stdin | & $python wiki.py @cliArgs 2>&1 | ForEach-Object { "$_" } }
    else { $out = & $python wiki.py @cliArgs 2>&1 | ForEach-Object { "$_" } }
    $code = $LASTEXITCODE; $sw.Stop()
    $header = @("# command: python wiki.py $($cliArgs -join ' ')", "# started: $(Get-Date -Format s)  exit code: $code  wall time: $([math]::Round($sw.Elapsed.TotalSeconds,1)) s", "")
    ($header + $out) | Out-File -Encoding utf8 (Join-Path $outDir $file)
    $out | ForEach-Object { Write-Host $_ }
    Write-Host "  -> saved $outDir\$file  (exit $code, $([math]::Round($sw.Elapsed.TotalSeconds,1)) s)" -ForegroundColor DarkGray
    $script:results += [pscustomobject]@{ Step = $name; File = $file; Exit = $code; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}

# ---------------------------------------------------------------- 1. wait for offline
Banner "Personal Wiki - offline demonstration"
if (-not $Rehearsal) {
    $net = Test-Online
    if ($net.Online) {
        Write-Host ""
        Write-Host "  You are ONLINE. Turn off Wi-Fi now:" -ForegroundColor Yellow
        Write-Host "  click the Wi-Fi icon at the bottom-right of the taskbar, then click the Wi-Fi tile so it turns grey." -ForegroundColor Yellow
        Write-Host "  (Also unplug any Ethernet cable.) This window will continue by itself." -ForegroundColor Yellow
        while ((Test-Online).Online) { Start-Sleep 3; Write-Host "." -NoNewline }
        Write-Host ""
    }
}
Start-Transcript -Path (Join-Path $outDir "transcript.txt") -Force | Out-Null
$net = Test-Online
$adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status | Format-Table -AutoSize | Out-String
$netReport = @"
checked at: $(Get-Date -Format s)
HTTP GET http://www.msftconnecttest.com/connecttest.txt succeeded: $($net.Web)
ping 8.8.8.8 succeeded: $($net.Ping)
=> online: $($net.Online)

$adapters
"@
$netReport | Out-File -Encoding utf8 (Join-Path $outDir "network-check.txt")
Write-Host $netReport
if (-not $Rehearsal -and $net.Online) { Write-Host "Still online - stopping." -ForegroundColor Red; Stop-Transcript; exit 1 }

# ---------------------------------------------------------------- 2. device + restart Ollama
$cs = Get-CimInstance Win32_ComputerSystem; $os = Get-CimInstance Win32_OperatingSystem
$device = @"
OS: $($os.Caption) $($os.Version)
CPU: $((Get-CimInstance Win32_Processor).Name.Trim())
RAM total: $([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB, free before model load: $([math]::Round($os.FreePhysicalMemory/1MB,1)) GB
Python: $(& $python --version 2>&1)
Ollama: $(& $ollama --version 2>&1)
"@
Banner "Restarting Ollama (local model server on 127.0.0.1:11434)"
Get-Process "ollama app", "ollama" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 2
Start-Process $ollama -ArgumentList "serve" -WindowStyle Hidden
$up = $false
for ($i = 0; $i -lt 30 -and -not $up; $i++) { Start-Sleep 1; try { Invoke-RestMethod "http://127.0.0.1:11434/api/version" -TimeoutSec 2 | Out-Null; $up = $true } catch {} }
Write-Host "Ollama running locally: $up"
$device += "`nOllama restarted for this run: $up`n" + ((& $ollama show gemma4:e2b 2>&1 | Select-Object -First 8) -join "`n")
Write-Host $device

# ---------------------------------------------------------------- 3. the CLI runs (each a fresh process)
Run-Step "Help" "01-help.txt" @("--help")
# Real ingestion with the model, run on a scratch copy so the reviewed wiki pages are not overwritten.
$copy = Join-Path $env:TEMP "personal-wiki-ingest-demo"
Remove-Item -Recurse -Force $copy -ErrorAction SilentlyContinue
New-Item -ItemType Directory $copy | Out-Null
Copy-Item -Recurse wiki.py, wikicli, instructions, vault, index_data $copy
Banner "Ingest with local Gemma (scratch copy at $copy)"
Push-Location $copy
$sw = [Diagnostics.Stopwatch]::StartNew()
$ing = & $python wiki.py ingest --force 2>&1 | ForEach-Object { "$_" }
$sw.Stop(); $ingCode = $LASTEXITCODE
Pop-Location
$ing | ForEach-Object { Write-Host $_ }
(@("# command (in scratch copy): python wiki.py ingest --force", "# exit code: $ingCode  wall time: $([math]::Round($sw.Elapsed.TotalSeconds,1)) s", "") + $ing) | Out-File -Encoding utf8 (Join-Path $outDir "02-ingest-model.txt")
New-Item -ItemType Directory -Force (Join-Path $outDir "ingest-generated-pages") | Out-Null
Get-ChildItem (Join-Path $copy "vault\wiki") -Recurse -File | Copy-Item -Destination (Join-Path $outDir "ingest-generated-pages")
$results += [pscustomobject]@{ Step = "Ingest with model (scratch copy)"; File = "02-ingest-model.txt"; Exit = $ingCode; Seconds = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
Run-Step "Re-ingest real vault (expect no duplicates)" "03-reingest.txt" @("ingest")
$pageCount = (Get-ChildItem vault\wiki -Recurse -File).Count

Run-Step "Ask test 1 (direct)" "04-ask-test1.txt" @("ask", "How much memory does the E4B Gemma model need to load at Q4_0?", "--label", "$labelPrefix-test1")
Run-Step "Ask test 2 (paraphrase)" "05-ask-test2.txt" @("ask", "Why did I pick the smallest model for my laptop?", "--label", "$labelPrefix-test2")
Run-Step "Ask test 3 (two facts)" "06-ask-test3.txt" @("ask", "How do I keep the Obsidian graph readable and what should notes be named?", "--label", "$labelPrefix-test3")
Run-Step "Ask test 4 (unsupported)" "07-ask-test4.txt" @("ask", "What does the hosted Gemma API cost per million tokens?", "--label", "$labelPrefix-test4")
Run-Step "Search check" "08-search.txt" @("search", "Obsidian graph filter")
Run-Step "Chat check" "09-chat.txt" @("chat") @(
    "what can we do?",
    "what can you help me with?",
    "Give me a 3-step plan for studying for a networks exam.",
    "make that shorter",
    "For this chat, my cat is named Pixel.",
    "/quit")
Run-Step "Ask vs chat (fact stated only in chat)" "10-ask-vs-chat.txt" @("ask", "What is the name of my cat?", "--label", "$labelPrefix-ask-vs-chat")

$ps = (& $ollama ps 2>&1) -join "`n"
$osAfter = Get-CimInstance Win32_OperatingSystem
$netAfter = Test-Online

# ---------------------------------------------------------------- 4. summary
$rows = ($results | ForEach-Object { "| $($_.Step) | [$($_.File)]($($_.File)) | $($_.Exit) | $($_.Seconds) |" }) -join "`n"
$summary = @"
# $(if ($Rehearsal) { 'ONLINE REHEARSAL (not offline evidence)' } else { 'Offline demonstration' }) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')

Model: ``gemma4:e2b`` (Q4_K_M) via local Ollama at 127.0.0.1:11434. Execution: local. Every step below is a fresh CLI process.

## Network state
- Before the run: web check = $($net.Web), ping = $($net.Ping) (online = $($net.Online)). Details: [network-check.txt](network-check.txt)
- After the run: web check = $($netAfter.Web), ping = $($netAfter.Ping) (online = $($netAfter.Online))

## Device
``````
$device
``````

## Steps
| Step | Output | Exit code | Wall time (s) |
|---|---|---|---|
$rows

Wiki pages in vault/wiki after re-ingest: $pageCount (expected 3, no duplicates).
Ingestion output pages from the scratch-copy run: [ingest-generated-pages/](ingest-generated-pages/)
Ask evidence cards: ``evidence/ask/$labelPrefix-test1.md`` ... ``$labelPrefix-test4.md``, ``$labelPrefix-ask-vs-chat.md``

## Memory after the run
``````
$ps
``````
Free RAM after run: $([math]::Round($osAfter.FreePhysicalMemory/1MB,1)) GB

Full console transcript: [transcript.txt](transcript.txt). Screenshot: [offline-terminal.png](offline-terminal.png)
"@
$summary | Out-File -Encoding utf8 (Join-Path $outDir "SUMMARY.md")
Banner "DONE. Summary written to $outDir\SUMMARY.md"
$results | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Network during run - online: $($net.Online) before, $($netAfter.Online) after." -ForegroundColor Green
Stop-Transcript | Out-Null
Start-Sleep 1
& (Join-Path $PSScriptRoot "capture-screen.ps1") -Out (Join-Path $outDir "offline-terminal.png") | Out-Null
Write-Host ""
Write-Host "  All done. You can turn Wi-Fi back ON now, then tell Claude 'offline run finished'." -ForegroundColor Yellow
Write-Host "  Press Enter to close this window." -ForegroundColor Yellow
if (-not $Rehearsal) { Read-Host | Out-Null }
