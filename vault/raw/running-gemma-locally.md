# Running Gemma Locally

*Sample source written for this assignment.*

## Model sizes
Gemma comes in several open-weight sizes. E2B needs roughly 2.9 GB to load at Q4_0 quantization, E4B needs roughly 4.5 GB, and the 26B A4B mixture-of-experts model needs roughly 14.4 GB because all 26B weights must be loaded even though only about 4B are active per token.

## My laptop
My laptop has an AMD Ryzen 5 7520U CPU, 16 GB of RAM, and no dedicated GPU. Because there is no discrete VRAM, everything runs on the CPU, so I picked the smallest model that works: Gemma E2B served through Ollama.

## Quantization
Quantization stores weights in fewer bits, for example 4 bits, to cut memory use. The trade-off is a small loss of answer quality. The model I run uses Q4_K_M quantization.

## Speed expectations
On CPU only, the first request is slow because the model must be loaded into memory, which took over twenty seconds. Later requests reuse the loaded model and answer in a few seconds for short replies.

## Offline use
Weights are downloaded once while online with the command `ollama pull`. After that, the model runs with the internet disconnected, because Ollama serves it from localhost on port 11434.
