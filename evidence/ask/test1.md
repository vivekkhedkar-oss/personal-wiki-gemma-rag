# Ask evidence: How much memory does the E4B Gemma model need to load at Q4_0?

- Mode: ask / execution: local / model: `gemma4:e2b`
- Run at: 2026-09-29T15:50:51 (20.5 s)

## Retrieved passages
**[1] vault/raw/running-gemma-locally.md** — section *Model sizes* — score 11.593, matched terms: 0, e4b, gemma, load, model, need, q4

> Gemma comes in several open-weight sizes. E2B needs roughly 2.9 GB to load at Q4_0 quantization, E4B needs roughly 4.5 GB, and the 26B A4B mixture-of-experts model needs roughly 14.4 GB because all 26B weights must be loaded even though only about 4B are active per token.

**[2] vault/raw/running-gemma-locally.md** — section *Speed expectations* — score 5.659, matched terms: load, memory, model

> On CPU only, the first request is slow because the model must be loaded into memory, which took over twenty seconds. Later requests reuse the loaded model and answer in a few seconds for short replies.

**[3] vault/raw/running-gemma-locally.md** — section *Quantization* — score 4.663, matched terms: memory, model, q4

> Quantization stores weights in fewer bits, for example 4 bits, to cut memory use. The trade-off is a small loss of answer quality. The model I run uses Q4_K_M quantization.

## Answer

E4B needs roughly 4.5 GB to load at Q4_0 quantization [1].

## Citation check

`{"cited": [1], "invalid": [], "insufficient": false, "ok": true}`
