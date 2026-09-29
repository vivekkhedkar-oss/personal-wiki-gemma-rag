---
title: Retrieval Augmented Generation
source: vault/raw/rag-notes.md
source_id: 0dbd301dc1
source_sha256: 4a8266e45f1c145d96575c1692e82ce0f6a2b44017c81ab118e142065ba27027
original_filename: rag-notes.md
category: Concepts
status: reviewed
---

# Retrieval Augmented Generation

Retrieval Augmented Generation (RAG) provides a language model with relevant passages at the time of answering, without retraining the model. The process involves searching a local index, inserting the best passages into the prompt, and asking the model to answer based only on that evidence.

## Key points

- RAG supplies a language model with relevant passages at answer time.
- The model is not retrained during the RAG process.
- The program searches a local index and pastes the best passages into the prompt.
- Documents are split into passages of about 800 characters at heading and paragraph boundaries, keeping source path and section heading.
- BM25 keyword search works offline with no extra model; embedding search handles paraphrases better but needs a local embedding model.
- Every claim in an answer should carry a citation such as [1] that maps to a retrieved passage.
- If no passage supports a question, the assistant must state that the evidence is insufficient.

## Source

- Original: [rag-notes.md](../../raw/rag-notes.md)
- Sections: Retrieval Augmented Generation Notes, What RAG does, Chunking, Retrieval methods, Citations and missing evidence

## Related

%% related:curated %%
- [[Running Gemma Locally]] — supplies the local model that answers from the retrieved passages; RAG works offline because Gemma is served from localhost.
- [[Obsidian Vault Practices]] — describes how the notes and source references that retrieval relies on should be organized in the vault.
