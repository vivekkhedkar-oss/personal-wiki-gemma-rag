---
title: Running Gemma Locally
source: vault/raw/running-gemma-locally.md
source_id: 34c5e2649c
source_sha256: 257f695740f522c70ff87dc74f33e4ac26fb756ec454c2f3dd38ddf1206fbb76
original_filename: running-gemma-locally.md
category: Tools
status: reviewed
---

# Running Gemma Locally

Gemma models come in various open-weight sizes with different memory requirements. Running these models locally on a laptop often involves using the CPU and quantization to manage memory usage.

## Key points

- Gemma sizes include E2B (approx. 2.9 GB at Q4_0), E4B (approx. 4.5 GB), and 26B A4B (approx. 14.4 GB).
- The user's laptop has an AMD Ryzen 5 7520U CPU and 16 GB of RAM with no dedicated GPU.
- Quantization reduces memory use by storing weights in fewer bits, which results in a small loss of answer quality.
- Requests are slow initially because the model must load into memory, but subsequent requests are fast.
- Weights can be downloaded once using `ollama pull` for offline use.

## Source

- Original: [running-gemma-locally.md](../../raw/running-gemma-locally.md)
- Sections: Running Gemma Locally, Model sizes, My laptop, Quantization, Speed expectations, Offline use

## Related

%% related:curated %%
- [[Retrieval Augmented Generation]] — the workflow this model is used for: answering from retrieved passages.
- [[Obsidian Vault Practices]] — how to browse the wiki pages this model helps generate.
