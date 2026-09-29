"""Thin client for the local Ollama server (localhost only; no cloud calls)."""
import json
import time
import urllib.request
import urllib.error

from . import DEFAULT_MODEL

HOST = "http://127.0.0.1:11434"


class LLMUnavailable(RuntimeError):
    pass


def chat(messages, model=DEFAULT_MODEL, temperature=0.2, num_ctx=4096, json_mode=False):
    """Send chat messages to local Gemma. Returns (text, seconds)."""
    body = {
        "model": model,
        "messages": messages,
        "stream": False,
        "think": False,
        "options": {"temperature": temperature, "num_ctx": num_ctx},
    }
    if json_mode:
        body["format"] = "json"
    req = urllib.request.Request(
        HOST + "/api/chat", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"}
    )
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        raise LLMUnavailable(f"Ollama error {e.code}: {e.read().decode()[:200]} "
                             f"(is '{model}' installed? try: ollama pull {model})")
    except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
        raise LLMUnavailable(f"Cannot reach local Ollama at {HOST} ({e}). Start it with: ollama serve")
    return data["message"]["content"].strip(), time.time() - t0
