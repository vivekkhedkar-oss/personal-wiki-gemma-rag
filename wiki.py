#!/usr/bin/env python
"""wiki: personal wiki CLI. Modes: chat (assistant), ask (grounded answer), search (raw passages), ingest."""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # embedded Pythons ignore the script dir

from wikicli import DEFAULT_MODEL
from wikicli import harness, ingest as ingest_mod, retrieval
from wikicli.llm import LLMUnavailable

sys.stdout.reconfigure(encoding="utf-8")

EPILOG = """examples:
  python wiki.py ingest                      read vault/raw, generate wiki pages, rebuild index
  python wiki.py search "workshop location"  show original passages (no model needed)
  python wiki.py ask "Where is the workshop?"  standalone cited answer from local Gemma
  python wiki.py chat                        assistant with conversation memory (/help inside)
configuration: --model (default gemma4:e2b via local Ollama), --mode local (default; only local is implemented).
inputs: original sources (.md/.txt/.pdf) in vault/raw/. Ollama must be running for ingest/ask/chat."""


def banner(mode, model):
    print(f"[mode: {mode} | execution: local | model: {model}]")


def cmd_ingest(a):
    banner("ingest", a.model)
    if not list(ingest_mod.RAW.glob("*")):
        sys.exit("error: vault/raw/ is empty. Add source files first.")
    ingest_mod.ingest(model=a.model, force=a.force)


def cmd_search(a):
    print("[mode: search | execution: local | no model used]")
    hits = retrieval.search(a.query, k=a.k)
    if not hits:
        print("No matching passages.")
    for i, h in enumerate(hits, 1):
        print(f"\n[{i}] {h['source']}  (section: {h['section']}; score {h['score']}; matched: {', '.join(h['matched'])})")
        print("    " + h["text"].replace("\n", "\n    "))


def cmd_ask(a):
    banner("ask", a.model)
    card = harness.ask(a.question, model=a.model, label=a.label)
    print("\nRetrieved:", ", ".join(f"[{i}] {h['source']} § {h['section']}" for i, h in enumerate(card["retrieved"], 1)) or "none")
    print("\nAnswer:\n" + card["answer"])
    cc = card["citation_check"]
    print(f"\nCitations: cited={cc['cited']} invalid={cc['invalid']} ok={cc['ok']}  ({card['seconds']} s)")
    if not cc["ok"]:
        print("warning: answer failed the citation check (uncited or bad citation).")


CHAT_HELP = "Commands: /help  /save (save last reply as a draft in memory/)  /quit. Otherwise just talk."


def cmd_chat(a):
    banner("chat", a.model)
    print("Wiki Buddy here. " + CHAT_HELP)
    chat = harness.Chat(model=a.model)
    while True:
        try:
            msg = input("\nyou> ").lstrip("﻿").strip()
        except EOFError:
            break
        if not msg:
            continue
        if not sys.stdin.isatty():      # piped input is not echoed by the terminal
            print(msg)
        if msg == "/quit":
            break
        if msg == "/help":
            print(CHAT_HELP); continue
        if msg == "/save":
            p = chat.save_last(); print(f"saved draft: {p}" if p else "nothing to save yet."); continue
        reply, hits, secs = chat.send(msg)
        print(f"\nbuddy> {reply}")
        print(f"  [notes consulted: {', '.join(sorted({h['source'] for h in hits})) if hits else 'none'} | {secs:.1f} s]")


def main():
    p = argparse.ArgumentParser(prog="wiki", description=__doc__, epilog=EPILOG,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--model", default=DEFAULT_MODEL, help="local Ollama model tag")
    p.add_argument("--mode", default="local", choices=["local"], help="execution setting (local only)")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("ingest", help="raw sources -> wiki pages + index"); s.add_argument("--force", action="store_true"); s.set_defaults(f=cmd_ingest)
    s = sub.add_parser("search", help="show original passages, no generated answer"); s.add_argument("query"); s.add_argument("-k", type=int, default=4); s.set_defaults(f=cmd_search)
    s = sub.add_parser("ask", help="standalone grounded answer with citations"); s.add_argument("question"); s.add_argument("--label"); s.set_defaults(f=cmd_ask)
    s = sub.add_parser("chat", help="personal assistant"); s.set_defaults(f=cmd_chat)
    a = p.parse_args()
    try:
        a.f(a)
    except LLMUnavailable as e:
        sys.exit(f"error: {e}")
    except FileNotFoundError as e:
        sys.exit(f"error: missing file: {e}")


if __name__ == "__main__":
    main()
