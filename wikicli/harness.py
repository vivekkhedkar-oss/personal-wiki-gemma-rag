"""The harness: mode selection, instructions, conversation context, retrieval decisions,
prompt assembly, local model calls, citation checks and saved evidence."""
import json
import re
import time
from datetime import datetime

from . import INSTRUCTIONS, EVIDENCE, MEMORY, DEFAULT_MODEL
from . import llm, retrieval

CAPABILITY_RE = re.compile(
    r"\b(what (can|could|do) (you|we)|who are you|what are you|help me with|what can we do|your capabilities)\b", re.I)
GREETING_RE = re.compile(r"^\s*(hi|hello|hey|thanks|thank you|ok|okay|cool|nice)\b[\s!.?]*$", re.I)
NOTES_RE = re.compile(r"\b(my notes|the wiki|my wiki|my sources|according to|in my notes|what did i write)\b", re.I)


def _read(name):
    return (INSTRUCTIONS / name).read_text(encoding="utf-8").strip()


def format_sources(hits):
    return "\n\n".join(f"[{i}] (source: {h['source']}, section: {h['section']})\n{h['text']}"
                       for i, h in enumerate(hits, 1))


def check_citations(answer, n_passages):
    """Verify every [n] in the answer points at a passage that was actually retrieved."""
    cited = sorted({int(x) for x in re.findall(r"\[(\d+)\]", answer)})
    invalid = [c for c in cited if not 1 <= c <= n_passages]
    insufficient = answer.upper().startswith("INSUFFICIENT EVIDENCE")
    ok = insufficient and not cited or (bool(cited) and not invalid and not insufficient)
    return {"cited": cited, "invalid": invalid, "insufficient": insufficient, "ok": ok}


# ---------------------------------------------------------------- ask
def ask(question, model=DEFAULT_MODEL, k=3, save=True, label=None):
    """Standalone RAG: no chat history, no persona. question -> retrieve -> prompt -> Gemma -> citation check."""
    hits = retrieval.search(question, k=k)
    if hits:
        user = f"SOURCES:\n{format_sources(hits)}\n\nQUESTION: {question}"
        answer, secs = llm.chat(
            [{"role": "system", "content": _read("wiki-instructions.md")}, {"role": "user", "content": user}],
            model=model, temperature=0.0)
    else:
        answer, secs = "INSUFFICIENT EVIDENCE: no passage in the sources matches this question.", 0.0
    check = check_citations(answer, len(hits))
    card = {"mode": "ask", "execution": "local", "model": model, "time": datetime.now().isoformat(timespec="seconds"),
            "question": question, "retrieved": [{k_: v for k_, v in h.items()} for h in hits],
            "answer": answer, "citation_check": check, "seconds": round(secs, 1)}
    if save:
        save_card(card, label)
    return card


def save_card(card, label=None):
    EVIDENCE.joinpath("ask").mkdir(parents=True, exist_ok=True)
    slug = label or re.sub(r"[^a-z0-9]+", "-", card["question"].lower()).strip("-")[:50]
    (EVIDENCE / "ask" / f"{slug}.json").write_text(json.dumps(card, indent=2), encoding="utf-8")
    lines = [f"# Ask evidence: {card['question']}", "",
             f"- Mode: ask / execution: {card['execution']} / model: `{card['model']}`",
             f"- Run at: {card['time']} ({card['seconds']} s)", "", "## Retrieved passages"]
    for i, h in enumerate(card["retrieved"], 1):
        lines += [f"**[{i}] {h['source']}** — section *{h['section']}* — score {h['score']}, "
                  f"matched terms: {', '.join(h['matched'])}", "", "> " + h["text"].replace("\n", "\n> "), ""]
    lines += ["## Answer", "", card["answer"], "", "## Citation check", "", f"`{json.dumps(card['citation_check'])}`", ""]
    (EVIDENCE / "ask" / f"{slug}.md").write_text("\n".join(lines), encoding="utf-8")


# ---------------------------------------------------------------- chat
class Chat:
    """Personal assistant. Keeps recent history; retrieves notes only when the message needs them."""

    def __init__(self, model=DEFAULT_MODEL, max_turns=6):
        self.model, self.max_turns, self.history, self.last_reply = model, max_turns, [], ""
        self.system = _read("persona.md")

    def should_retrieve(self, msg):
        if CAPABILITY_RE.search(msg) or GREETING_RE.match(msg):
            return None
        hits = retrieval.search(msg, k=3)
        if NOTES_RE.search(msg) and hits:
            return hits
        return hits if retrieval.is_relevant(hits) else None

    def send(self, msg):
        hits = self.should_retrieve(msg)
        if hits:
            content = (f"NOTES (from the user's wiki; cite with [n] any claim you take from them):\n"
                       f"{format_sources(hits)}\n\nUSER MESSAGE: {msg}")
        else:
            content = msg
        messages = [{"role": "system", "content": self.system}] + self.history[-self.max_turns * 2:] \
            + [{"role": "user", "content": content}]
        reply, secs = llm.chat(messages, model=self.model, temperature=0.7)
        # history stores the plain user message (not the pasted notes) to keep context small
        self.history += [{"role": "user", "content": msg}, {"role": "assistant", "content": reply}]
        self.last_reply = reply
        return reply, hits, secs

    def save_last(self):
        if not self.last_reply:
            return None
        MEMORY.mkdir(exist_ok=True)
        p = MEMORY / f"draft-{datetime.now():%Y%m%d-%H%M%S}.md"
        p.write_text("<!-- Generated by chat. NOT original evidence; not indexed for ask/search. -->\n\n"
                     + self.last_reply + "\n", encoding="utf-8")
        return p
