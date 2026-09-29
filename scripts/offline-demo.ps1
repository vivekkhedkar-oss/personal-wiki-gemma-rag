# Offline demonstration for Assignment 4.
# 1. Waits until the internet is disconnected (checks a web URL and a ping).
# 2. Restarts Ollama, then runs help, ingestion, the four ask tests, search and chat checks,
#    each as a fresh CLI process, streaming output live and saving it under evidence/offline/.
#    The network is re-checked after every step; if it comes back, the run stops (no online results).
# 3. Writes evidence/offline/SUMMARY.md and a screenshot, then tells you to reconnect.
# -Rehearsal runs online into evidence/rehearsal-online/ to test the script (NOT offline evidence).
param([switch]$Rehearsal)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = New-Object Text.UTF8Encoding $false   # no BOM on text piped into python's stdin
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUNBUFFERED = "1"                              # print each line as soon as python writes it
$outDir = if ($Rehearsal) { "evidence\rehearsal-online" } else { "evidence\offline" }
$labelPrefix = if ($Rehearsal) { "rehearsal" } else { "offline" }
Remove-Item -Recurse -Force $outDir -ErrorAction SilentlyContinue           # fresh run, no stale files
Get-ChildItem evidence\ask -Filter "$labelPrefix-*" -ErrorAction SilentlyContinue | Remove-Item -Force
New-Item -ItemType Directory -Force $outDir | Out-Null
$python = (Get-Command python -ErrorAction Stop).Source
$ollama = (Get-Command ollama -ErrorAction Stop).Source
$totalSteps = 10

function Test-Online {
    $web = $false
    try { Invoke-WebRequest "http://www.msftconnecttest.com/connecttest.txt" -UseBasicParsing -TimeoutSec 4 | Out-Null; $web = $true } catch {}
    $ping = Test-Connection 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
    return [pscustomobject]@{ Web = $web; Ping = [bool]$ping; Online = ($web -or $ping) }
}

function Banner($text, $color = "Cyan") { Write-Host ""; Write-Host ("=" * 74) -ForegroundColor $color; Write-Host "  $text" -ForegroundColor $color; Write-Host ("=" * 74) -ForegroundColor $color }

function Stop-IfOnline($after) {
    if ($Rehearsal) { return }
    if ((Test-Online).Online) {
        $msg = "INTERNET CAME BACK ON after '$after'. The run was stopped so no online results are saved as offline evidence."
        $msg | Out-File -Encoding utf8 (Join-Path $outDir "RUN-ABORTED.txt")
        Banner $msg "Red"
        Write-Host "  Keep Wi-Fi OFF for the whole run. Close this window and double-click RUN-OFFLINE-DEMO.bat again." -ForegroundColor Yellow
        Stop-Transcript | Out-Null
        Read-Host "Press Enter to close"; exit 1
    }
}

$results = @()
$stepNo = 0
function Invoke-Wiki([string[]]$cliArgs, [string[]]$stdin) {
    # Stream each output line to the screen as it arrives and also return it for saving.
    if ($stdin) { $stdin | & $python -u wiki.py @cliArgs 2>&1 | ForEach-Object { $l = "$_"; Write-Host $l; $l } }
    else { & $python -u wiki.py @cliArgs 2>&1 | ForEach-Object { $l = "$_"; Write-Host $l; $l } }
}
function Run-Step($name, $file, $expect, [string[]]$cliArgs, [string[]]$stdin = $null, $workDir = $null) {
    $script:stepNo++
    Banner "Step $($script:stepNo) of $totalSteps - $name  (expected: $expect)"
    Write-Host "  > python wiki.py $($cliArgs -join ' ')" -ForegroundColor DarkCyan
    Write-Host "  working... (the model may be silent for 20-60 s at a time; this is normal)" -ForegroundColor DarkGray
    if ($workDir) { Push-Location $workDir }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = Invoke-Wiki $cliArgs $stdin
    $code = $LASTEXITCODE; $sw.Stop()
    if ($workDir) { Pop-Location }
    $secs = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $where = if ($workDir) { " (run in scratch copy $workDir)" } else { "" }
    $header = @("# command: python wiki.py $($cliArgs -join ' ')$where", "# finished: $(Get-Date -Format s)  exit code: $code  wall time: $secs s", "")
    ($header + $out) | Out-File -Encoding utf8 (Join-Path $outDir $file)
    Write-Host "  -> saved $outDir\$file  (exit code $code, $secs s)" -ForegroundColor Green
    $script:results += [pscustomobject]@{ Step = $name; File = $file; Exit = $code; Seconds = $secs }
    Stop-IfOnline $name
}

# ---------------------------------------------------------------- 1. wait for offline
Banner "Personal Wiki - offline demonstration (about 8 minutes)"
Write-Host "  IMPORTANT: keep Wi-Fi OFF until this window shows a green 'ALL DONE' banner." -ForegroundColor Yellow
if (-not $Rehearsal) {
    if ((Test-Online).Online) {
        Write-Host ""
        Write-Host "  You are ONLINE. Turn off Wi-Fi now:" -ForegroundColor Yellow
        Write-Host "  click the Wi-Fi icon at the bottom-right of the taskbar, then click the Wi-Fi tile so it turns grey." -ForegroundColor Yellow
        Write-Host "  (Also unplug any Ethernet cable.) This window will continue by itself." -ForegroundColor Yellow
        Write-Host "  waiting for the internet to disconnect" -NoNewline
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
if (-not $Rehearsal -and $net.Online) { Write-Host "Still online - stopping." -ForegroundColor Red; Stop-Transcript; Read-Host "Press Enter to close"; exit 1 }
Write-Host "  OFFLINE confirmed. Starting. Do not reconnect yet." -ForegroundColor Green

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
Run-Step "Help" "01-help.txt" "1 s" @("--help")

# Real ingestion with the model, on a scratch copy so the reviewed wiki pages are not overwritten.
$copy = Join-Path $env:TEMP "personal-wiki-ingest-demo"
Remove-Item -Recurse -Force $copy -ErrorAction SilentlyContinue
New-Item -ItemType Directory $copy | Out-Null
Copy-Item -Recurse wiki.py, wikicli, instructions, vault, index_data $copy
Run-Step "Ingest 3 sources with local Gemma" "02-ingest-model.txt" "about 2.5 min" @("ingest", "--force") -workDir $copy
New-Item -ItemType Directory -Force (Join-Path $outDir "ingest-generated-pages") | Out-Null
Get-ChildItem (Join-Path $copy "vault\wiki") -Recurse -File | Copy-Item -Destination (Join-Path $outDir "ingest-generated-pages")

Run-Step "Re-ingest real vault (expect no duplicates)" "03-reingest.txt" "1 s" @("ingest")
$pageCount = (Get-ChildItem vault\wiki -Recurse -File).Count

Run-Step "Ask test 1 (direct)" "04-ask-test1.txt" "about 25 s" @("ask", "How much memory does the E4B Gemma model need to load at Q4_0?", "--label", "$labelPrefix-test1")
Run-Step "Ask test 2 (paraphrase)" "05-ask-test2.txt" "about 25 s" @("ask", "Why did I pick the smallest model for my laptop?", "--label", "$labelPrefix-test2")
Run-Step "Ask test 3 (two facts)" "06-ask-test3.txt" "about 30 s" @("ask", "How do I keep the Obsidian graph readable and what should notes be named?", "--label", "$labelPrefix-test3")
Run-Step "Ask test 4 (unsupported)" "07-ask-test4.txt" "about 25 s" @("ask", "What does the hosted Gemma API cost per million tokens?", "--label", "$labelPrefix-test4")
Run-Step "Search check (no model)" "08-search.txt" "1 s" @("search", "Obsidian graph filter")
Run-Step "Chat check" "09-chat.txt" "about 1.5 min" @("chat") @(
    "what can we do?",
    "what can you help me with?",
    "Give me a 3-step plan for studying for a networks exam.",
    "make that shorter",
    "For this chat, my cat is named Pixel.",
    "/quit")
Run-Step "Ask vs chat (fact stated only in chat)" "10-ask-vs-chat.txt" "about 15 s" @("ask", "What is the name of my cat?", "--label", "$labelPrefix-ask-vs-chat")

$ps = (& $ollama ps 2>&1) -join "`n"
$osAfter = Get-CimInstance Win32_OperatingSystem
$netAfter = Test-Online

# ---------------------------------------------------------------- 4. summary
$rows = ($results | ForEach-Object { "| $($_.Step) | [$($_.File)]($($_.File)) | $($_.Exit) | $($_.Seconds) |" }) -join "`n"
$summary = @"
# $(if ($Rehearsal) { 'ONLINE REHEARSAL (not offline evidence)' } else { 'Offline demonstration' }) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')

Model: ``gemma4:e2b`` (Q4_K_M) via local Ollama at 127.0.0.1:11434. Execution: local. Every step below is a fresh CLI process.
The network was re-checked after every step$(if ($Rehearsal) { ' (skipped in rehearsal)' } else { ' and was offline each time' }).

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
Pages generated by the model during this run (scratch copy): [ingest-generated-pages/](ingest-generated-pages/)
Ask evidence cards: ``evidence/ask/$labelPrefix-test1.md`` ... ``$labelPrefix-test4.md``, ``$labelPrefix-ask-vs-chat.md``

## Memory after the run
``````
$ps
``````
Free RAM after run: $([math]::Round($osAfter.FreePhysicalMemory/1MB,1)) GB

Full console transcript: [transcript.txt](transcript.txt). Screenshot: [offline-terminal.png](offline-terminal.png)
"@
$summary | Out-File -Encoding utf8 (Join-Path $outDir "SUMMARY.md")
$results | Format-Table -AutoSize | Out-String | Write-Host
Write-Host "Network - online before: $($net.Online), online after: $($netAfter.Online)" -ForegroundColor Green
Banner "ALL DONE. Summary: $outDir\SUMMARY.md" "Green"
Stop-Transcript | Out-Null
Start-Sleep 1
& (Join-Path $PSScriptRoot "capture-screen.ps1") -Out (Join-Path $outDir "offline-terminal.png") | Out-Null
Write-Host ""
Write-Host "  You can turn Wi-Fi back ON now, then tell Claude 'offline run finished'." -ForegroundColor Yellow
if (-not $Rehearsal) { Read-Host "  Press Enter to close this window" | Out-Null }
