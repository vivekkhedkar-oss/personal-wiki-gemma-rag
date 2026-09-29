# Retrieval Augmented Generation Notes

*Sample source written for this assignment.*

## What RAG does
Retrieval Augmented Generation (RAG) supplies a language model with relevant passages at answer time. The model is not retrained. The program searches a local index, pastes the best passages into the prompt, and asks the model to answer using only that evidence.

## Chunking
Documents are split into passages of about 800 characters, cut at heading and paragraph boundaries. Each passage keeps its source path and section heading so a citation can point back to the original file.

## Retrieval methods
Keyword search with BM25 needs no extra model and works offline. Embedding search finds paraphrases better but needs a local embedding model. In my setup I chose BM25 first because it is easy to debug: when a wrong passage appears, the matching words explain why.

## Citations and missing evidence
Every claim in an answer should carry a citation such as [1] that maps to a retrieved passage. If no passage supports the question, the assistant must say the evidence is insufficient instead of guessing. A fluent answer with no supporting passage counts as a failure.
