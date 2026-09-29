# Test plan (written BEFORE running the harness; kept outside the vault)

Expectations: E2B on CPU (Q4_K_M) should handle short cited answers; BM25 should surface the right chunk for
questions that reuse source vocabulary and may struggle when the wording is paraphrased (Test 2).

| # | Question | Expected source / passage | Expected behavior |
|---|---|---|---|
| 1 | How much memory does the E4B Gemma model need to load at Q4_0? | `running-gemma-locally.md` § Model sizes ("E4B needs roughly 4.5 GB") | Answer "about 4.5 GB", cite the passage |
| 2 | Why did I pick the smallest model for my laptop? (paraphrase: source says "no dedicated GPU ... everything runs on the CPU") | `running-gemma-locally.md` § My laptop | Mentions no discrete GPU/VRAM, CPU only, 16 GB RAM, chose E2B via Ollama |
| 3 | Which graph filter and toggle show only curated notes in Obsidian, and what should note filenames look like? (two sources? no: one source, two facts) — better: How do I keep the Obsidian graph readable and what should notes be named? | `obsidian-vault-practices.md` § Graph view + § Note names | `path:wiki/` filter, Attachments off; 2-6 word subject names |
| 4 | (unsupported) What does the hosted Gemma API cost per million tokens? | none: no source mentions pricing | "INSUFFICIENT EVIDENCE" response, no citations |

Mode checks: chat "what can you help me with?" (no retrieval, no refusal); chat draft + "make that shorter";
search "BM25 keyword search" shows raw passages, no answer; ask a fact that was only stated in chat -> must not be
treated as evidence.
