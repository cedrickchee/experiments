# Usage

Estimate GPU VRAM requirements, context length, and quantization bits per weight (BPW) for any LLM models.

## Examples

### In Go

1. How much memory do I need to run a LLama 3.1 405B model quantized to Q4_0?

```sh
$ go run vram_calculator.go -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode A -bpw Q4_0 -access $HF_API_TOKEN
288.41
```

2. How much context can I get out of this model?

```sh
$ go run vram_calculator.go -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode B -ram 289 -bpw 4.55 -access $HF_API_TOKEN
130972
```

3. What is the best quant I can run of this model?

```sh
$ go run vram_calculator.go -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode C -ram 289 -type gguf -access $HF_API_TOKEN
Q4_0
```

### In Python

1. How much memory do I need to run a LLama 3.1 405B model quantized to Q4_0?

```sh
$ python3 vram_calculator.py --mode A --bpw Q4_0 --access hf_xxxxxxxx meta-llama/Meta-Llama-3.1-405B-Instruct-FP8
288.41
```

2. How much context can I get out of this model?

```sh
$ python3 vram_calculator.py --mode B --ram 289 --bpw 4.55 meta-llama/Meta-Llama-3.1-405B-Instruct-FP8
131072
```

3. What is the best quant I can run of this model?

```sh
$ python3 vram_calculator.py --mode C --ram 289 --type gguf meta-llama/Meta-Llama-3.1-405B-Instruct-FP8
Q4_0
```
