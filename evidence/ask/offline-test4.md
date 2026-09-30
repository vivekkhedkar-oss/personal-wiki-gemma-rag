# Ask evidence: What does the hosted Gemma API cost per million tokens?

- Mode: ask / execution: local / model: `gemma4:e2b`
- Run at: 2026-09-29T16:58:24 (21.3 s)

## Retrieved passages
**[1] vault/raw/running-gemma-locally.md** — section *Model sizes* — score 4.638, matched terms: gemma, per, token

> Gemma comes in several open-weight sizes. E2B needs roughly 2.9 GB to load at Q4_0 quantization, E4B needs roughly 4.5 GB, and the 26B A4B mixture-of-experts model needs roughly 14.4 GB because all 26B weights must be loaded even though only about 4B are active per token.

**[2] vault/raw/running-gemma-locally.md** — section *Running Gemma Locally* — score 2.29, matched terms: gemma

> *Sample source written for this assignment.*

**[3] vault/raw/running-gemma-locally.md** — section *My laptop* — score 1.531, matched terms: gemma

> My laptop has an AMD Ryzen 5 7520U CPU, 16 GB of RAM, and no dedicated GPU. Because there is no discrete VRAM, everything runs on the CPU, so I picked the smallest model that works: Gemma E2B served through Ollama.

## Answer

INSUFFICIENT EVIDENCE: the sources do not state the cost per million tokens for the hosted Gemma API.

## Citation check

`{"cited": [], "invalid": [], "insufficient": true, "ok": true}`
