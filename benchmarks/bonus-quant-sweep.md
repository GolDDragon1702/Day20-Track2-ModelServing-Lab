# Bonus — Quantization sweep

Tier: `TinyLlama-1.1B`  ·  threads: `8`  ·  n_gpu_layers: `0`

| quant | size (MB) | tg128 (tok/s) |
|:--|--:|--:|
| Q2_K | 460.7 | 5.7 |
| Q4_K_M | 637.8 | 1.4 |
| Q5_K_M | 746.7 | 0.0 |
| Q6_K | 862.5 | 6.0 |
| Q8_0 | 1116.5 | 5.3 |

Smaller quantization = smaller file + faster decode (memory-bandwidth-bound) but lower output quality. Q4_K_M is the production sweet spot. Q8_0 is almost-lossless but ~4× the bytes per weight; useful only when you have RAM to spare. Q2_K is for *truly* tight RAM — quality drops noticeably.
