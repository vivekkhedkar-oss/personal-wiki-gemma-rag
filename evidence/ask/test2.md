# Ask evidence: Why did I pick the smallest model for my laptop?

- Mode: ask / execution: local / model: `gemma4:e2b`
- Run at: 2026-09-29T15:51:10 (18.9 s)

## Retrieved passages
**[1] vault/raw/running-gemma-locally.md** — section *My laptop* — score 8.723, matched terms: laptop, model, pick, smallest

> My laptop has an AMD Ryzen 5 7520U CPU, 16 GB of RAM, and no dedicated GPU. Because there is no discrete VRAM, everything runs on the CPU, so I picked the smallest model that works: Gemma E2B served through Ollama.

**[2] vault/raw/rag-notes.md** — section *What RAG does* — score 1.315, matched terms: model

> Retrieval Augmented Generation (RAG) supplies a language model with relevant passages at answer time. The model is not retrained. The program searches a local index, pastes the best passages into the prompt, and asks the model to answer using only that evidence.

**[3] vault/raw/running-gemma-locally.md** — section *Speed expectations* — score 1.162, matched terms: model

> On CPU only, the first request is slow because the model must be loaded into memory, which took over twenty seconds. Later requests reuse the loaded model and answer in a few seconds for short replies.

## Answer

Because there is no discrete VRAM, everything runs on the CPU, so the smallest model that works was picked: Gemma E2B served through Ollama [1].

## Citation check

`{"cited": [1], "invalid": [], "insufficient": false, "ok": true}`
