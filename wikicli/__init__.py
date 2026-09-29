"""Personal wiki CLI + harness (local Gemma via Ollama, BM25 retrieval)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VAULT = ROOT / "vault"
RAW = VAULT / "raw"
WIKI = VAULT / "wiki"
INDEX_DATA = ROOT / "index_data"      # machine files: chunks, catalog (kept outside the vault)
INSTRUCTIONS = ROOT / "instructions"
EVIDENCE = ROOT / "evidence"
MEMORY = ROOT / "memory"              # explicitly saved chat drafts (never used as evidence)
DEFAULT_MODEL = "gemma4:e2b"
