"""Retrieval tool: chunk the ORIGINAL sources in vault/raw and search them with BM25.
No model is involved, so `wiki search` works even when Gemma is not running."""
import json
import math
import re
from collections import Counter

from . import RAW, INDEX_DATA, ROOT

STOP = set("""a an and are as at be by can do does for from has have how i in is it its me my of on or
that the their this to was were what when where which who whom why will with you your about into than then
there these those they we should would could not no yes if so also more most some any each other""".split())
CHUNK_CHARS = 800


def stem(w):
    for suf in ("ing", "ed", "es", "s"):
        if w.endswith(suf) and len(w) - len(suf) >= 3:
            return w[: -len(suf)]
    return w


def tokenize(text):
    return [stem(w) for w in re.findall(r"[a-z0-9]+", text.lower()) if w not in STOP]


def read_source(path):
    if path.suffix.lower() == ".pdf":
        from pypdf import PdfReader  # local parsing only
        return "\n\n".join((p.extract_text() or "") for p in PdfReader(str(path)).pages)
    return path.read_text(encoding="utf-8")


def chunk_text(text):
    """Split at headings, then pack paragraphs up to ~CHUNK_CHARS. Returns [(section, text)]."""
    sections, current, buf = [], "Introduction", []
    for line in text.splitlines():
        m = re.match(r"^#{1,6}\s+(.*)", line)
        if m:
            sections.append((current, "\n".join(buf)))
            current, buf = m.group(1).strip(), []
        else:
            buf.append(line)
    sections.append((current, "\n".join(buf)))
    out = []
    for sec, body in sections:
        pack = ""
        for para in [p.strip() for p in re.split(r"\n\s*\n", body) if p.strip()]:
            if pack and len(pack) + len(para) > CHUNK_CHARS:
                out.append((sec, pack))
                pack = ""
            pack = (pack + "\n\n" + para).strip()
        if pack:
            out.append((sec, pack))
    return out


def build_index():
    chunks = []
    for path in sorted(RAW.glob("*")):
        if path.suffix.lower() not in (".md", ".txt", ".pdf"):
            continue
        rel = path.relative_to(ROOT).as_posix()
        for i, (sec, body) in enumerate(chunk_text(read_source(path))):
            chunks.append({"id": f"{path.stem}#{i}", "source": rel, "section": sec, "text": body})
    INDEX_DATA.mkdir(exist_ok=True)
    (INDEX_DATA / "chunks.json").write_text(json.dumps(chunks, indent=1), encoding="utf-8")
    return chunks


def load_index():
    p = INDEX_DATA / "chunks.json"
    if not p.exists():
        return build_index()
    return json.loads(p.read_text(encoding="utf-8"))


def search(query, k=4):
    """BM25 over chunks. Each hit has score, matched query terms and query-term coverage."""
    chunks = load_index()
    docs = [tokenize(c["section"] + " " + c["text"]) for c in chunks]
    q = sorted(set(tokenize(query)))
    if not q or not docs:
        return []
    N, avg = len(docs), sum(map(len, docs)) / len(docs)
    df = Counter(t for d in docs for t in set(d))
    hits = []
    for c, d in zip(chunks, docs):
        tf, score, matched = Counter(d), 0.0, []
        for t in q:
            if tf[t]:
                idf = math.log(1 + (N - df[t] + 0.5) / (df[t] + 0.5))
                score += idf * tf[t] * 2.2 / (tf[t] + 1.2 * (0.25 + 0.75 * len(d) / avg))
                matched.append(t)
        if matched:
            hits.append({**c, "score": round(score, 3), "matched": matched,
                         "coverage": round(len(matched) / len(q), 2)})
    return sorted(hits, key=lambda h: -h["score"])[:k]


def is_relevant(hits, min_coverage=0.5, min_matches=2):
    """Cheap signal used to decide whether chat should consult notes."""
    return bool(hits) and hits[0]["coverage"] >= min_coverage and len(hits[0]["matched"]) >= min_matches
