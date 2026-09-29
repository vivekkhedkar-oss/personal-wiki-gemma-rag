"""Ingestion: raw source -> local Gemma -> readable wiki page (+ links, index, retrieval index).
Re-ingesting is idempotent: catalog.json maps source_id -> page path, so pages are updated in place."""
import hashlib
import json
import re
import time

from . import RAW, WIKI, VAULT, INDEX_DATA, ROOT, DEFAULT_MODEL
from . import llm, retrieval

CATEGORIES = ["Concepts", "Tools", "Practices"]
CATALOG = INDEX_DATA / "catalog.json"

PROMPT = """You are building a personal wiki page from ONE source document. Use only facts in the document.
Return JSON with keys:
  "title": a short subject name of 2-6 words in Title Case, not a sentence (e.g. "Retrieval Augmented Generation"),
  "category": one of {cats},
  "summary": 2 sentences summarizing the document,
  "key_points": list of 4 to 6 short bullet strings, each a fact stated in the document.

DOCUMENT ({name}):
{text}"""


def sanitize_title(t, fallback):
    t = re.sub(r"[^A-Za-z0-9 \-]", "", (t or "")).strip()
    if not 2 <= len(t.split()) <= 6:
        t = re.sub(r"[^A-Za-z0-9 \-]", "", fallback).strip()
    return t


def load_catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8")) if CATALOG.exists() else {}


def shared_terms(a, b, n=4):
    ta, tb = set(retrieval.tokenize(a)), set(retrieval.tokenize(b))
    common = sorted(ta & tb, key=lambda t: -min(a.lower().count(t), b.lower().count(t)))
    return [t for t in common if len(t) > 3][:n]


def ingest(model=DEFAULT_MODEL, force=False, log=print):
    INDEX_DATA.mkdir(exist_ok=True)
    catalog, t0, texts = load_catalog(), time.time(), {}
    for src in sorted(RAW.glob("*")):
        if src.suffix.lower() not in (".md", ".txt", ".pdf"):
            continue
        rel = src.relative_to(ROOT).as_posix()
        sid = hashlib.sha1(rel.encode()).hexdigest()[:10]
        text = retrieval.read_source(src)
        texts[sid] = text
        sha = hashlib.sha256(src.read_bytes()).hexdigest()
        entry = catalog.get(sid)
        if entry and entry["sha256"] == sha and not force and (ROOT / entry["page"]).exists():
            log(f"  unchanged  {rel} -> {entry['page']} (kept, no model call)")
            continue
        log(f"  ingesting  {rel} with {model} ...")
        raw_json, secs = llm.chat(
            [{"role": "user", "content": PROMPT.format(cats=CATEGORIES, name=src.name, text=text[:6000])}],
            model=model, temperature=0.1, num_ctx=4096, json_mode=True)
        try:
            data = json.loads(raw_json)
        except json.JSONDecodeError:
            data = {}
        first_h = (re.search(r"^#\s+(.*)", text, re.M) or [None, src.stem])[1]
        if entry:                                   # re-ingest: keep the existing readable name/location
            title, page = entry["title"], ROOT / entry["page"]
            cat = page.parent.name
        else:
            title = sanitize_title(data.get("title"), first_h)
            cat = data.get("category") if data.get("category") in CATEGORIES else "Concepts"
            page = WIKI / cat / f"{title}.md"
            if page.exists():                       # same title from a different source: add a meaningful qualifier
                page = WIKI / cat / f"{title} - {src.stem.split('-')[0].title()}.md"
                title = page.stem
        page.parent.mkdir(parents=True, exist_ok=True)
        points = [str(p).strip() for p in data.get("key_points", []) if str(p).strip()]
        sections = [c[0] for c in retrieval.chunk_text(text)]
        body = ["---", f"title: {title}", f"source: {rel}", f"source_id: {sid}", f"source_sha256: {sha}",
                f"original_filename: {src.name}", f"category: {cat}", "status: generated-needs-review", "---", "",
                f"# {title}", "", str(data.get("summary", "")).strip(), "", "## Key points", ""]
        body += [f"- {p}" for p in points] + ["", "## Source", "",
                 f"- Original: [{src.name}](../../raw/{src.name})",
                 f"- Sections: {', '.join(dict.fromkeys(sections))}", "", "## Related", "", "%% related:auto %%", ""]
        page.write_text("\n".join(body), encoding="utf-8")
        catalog[sid] = {"source": rel, "page": page.relative_to(ROOT).as_posix(), "title": title,
                        "sha256": sha, "seconds": round(secs, 1)}
        log(f"    -> {catalog[sid]['page']} ({secs:.1f} s)")
    CATALOG.write_text(json.dumps(catalog, indent=2), encoding="utf-8")
    link_related(catalog, texts)
    write_index(catalog)
    n = len(retrieval.build_index())
    log(f"  retrieval index rebuilt: {n} passages. total {time.time() - t0:.1f} s")
    return catalog


def link_related(catalog, texts):
    """Add [[links]] between pages whose sources share vocabulary, with the reason stated."""
    for sid, e in catalog.items():
        others = [(o, shared_terms(texts.get(sid, ""), texts.get(oid, ""))) for oid, o in catalog.items() if oid != sid]
        others = [(o, t) for o, t in others if len(t) >= 2]
        p = ROOT / e["page"]
        content = p.read_text(encoding="utf-8")
        if "%% related:curated %%" in content:   # hand-reviewed links are never overwritten
            continue
        lines = [f"- [[{o['title']}]] — shares topics with this note: {', '.join(t)}." for o, t in others]
        block = "\n".join(lines) if lines else "- (no related notes yet)"
        content = re.sub(r"(## Related\n\n).*?(\n*$)", lambda m: m.group(1) + "%% related:auto %%\n" + block + "\n",
                         content, flags=re.S)
        p.write_text(content, encoding="utf-8")


def write_index(catalog):
    lines = ["# Index", "", "Landing page for this personal wiki. Notes are generated from originals in `raw/` "
             "and reviewed by hand.", ""]
    for cat in CATEGORIES:
        entries = [e for e in catalog.values() if (ROOT / e["page"]).parent.name == cat]
        if not entries:
            continue
        lines += [f"## {cat}", ""]
        for e in sorted(entries, key=lambda e: e["title"]):
            txt = (ROOT / e["page"]).read_text(encoding="utf-8")
            m = re.search(r"^# .*\n\n(.+)", txt, re.M)
            first = re.split(r"(?<=[.!?])\s", m.group(1).strip())[0] if m else ""
            lines.append(f"- [[{e['title']}]] — {first}")
        lines.append("")
    lines += ["## Source catalog", "", "| Note | Original | Source ID |", "|---|---|---|"]
    for sid, e in sorted(catalog.items(), key=lambda kv: kv[1]["title"]):
        lines.append(f"| [[{e['title']}]] | `{e['source'].replace('vault/', '')}` | {sid} |")
    (VAULT / "index.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
