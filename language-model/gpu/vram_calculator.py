import os
import json
import urllib.request
import argparse

# Calculate GPU VRAM requirements for LLM models
# 
# Version 1.5

GGUF_MAPPING = {
    "Q8_0": 8.5,
    "Q6_K": 6.59,
    "Q5_K_M": 5.69,
    "Q5_K_S": 5.54,
    "Q5_0": 5.54,
    "Q4_K_M": 4.85,
    "Q4_K_S": 4.58,
    "Q4_0": 4.55,
    "IQ4_NL": 4.5,
    "Q3_K_L": 4.27,
    "IQ4_XS": 4.25,
    "Q3_K_M": 3.91,
    "IQ3_M": 3.7,
    "IQ3_S": 3.5,
    "Q3_K_S": 3.5,
    "Q2_K": 3.35,
    "IQ3_XS": 3.3,
    "IQ3_XXS": 3.06,
    "IQ2_M": 2.7,
    "IQ2_S": 2.5,
    "IQ2_XS": 2.31,
    "IQ2_XXS": 2.06,
    "IQ1_S": 1.56,
}

EXL2_OPTIONS = [round(i, 2) for i in reversed([x * 0.05 + 2 for x in range(81)])]

def bits_to_gb(bits):
    return bits / (2 ** 30)


def calculate_vram_raw(num_params=None, bpw=5.0, lm_head_bpw=6.0, kv_cache_bpw=8.0, context=None, fp8=True,
                       num_gpus=1, max_position_embeddings=None, num_hidden_layers=None, hidden_size=None,
                       num_key_value_heads=None, num_attention_heads=None, intermediate_size=None, vocab_size=None,
                       gqa=True):
    cuda_size = 500 * 2 ** 20 * num_gpus
    params_size = num_params * 1e9 * (bpw / 8)
    kv_cache_size = (context * 2 * num_hidden_layers * hidden_size) * (kv_cache_bpw / 8)

    if gqa:
        kv_cache_size *= num_key_value_heads / num_attention_heads

    bytes_per_param = (bpw / 8)
    lm_head_bytes_per_param = (lm_head_bpw / 8)
    head_dim = hidden_size / num_attention_heads

    attention_input = bytes_per_param * context * hidden_size
    q = bytes_per_param * context * head_dim * num_attention_heads
    k = bytes_per_param * context * head_dim * num_key_value_heads
    v = bytes_per_param * context * head_dim * num_key_value_heads

    softmax_output = lm_head_bytes_per_param * num_attention_heads * context
    softmax_dropout_mask = num_attention_heads * context
    dropout_output = lm_head_bytes_per_param * num_attention_heads * context
    out_proj_input = lm_head_bytes_per_param * context * num_attention_heads * head_dim
    attention_dropout = context * hidden_size

    attention_block = (
        attention_input + q + k + softmax_output + v + out_proj_input + softmax_dropout_mask + dropout_output + attention_dropout
    )

    mlp_input = bytes_per_param * context * hidden_size
    activation_input = bytes_per_param * context * intermediate_size
    down_proj_input = bytes_per_param * context * intermediate_size
    dropout_mask = context * hidden_size
    mlp_block = mlp_input + activation_input + down_proj_input + dropout_mask

    layer_norms = bytes_per_param * context * hidden_size * 2
    activations_size = attention_block + mlp_block + layer_norms
    output_size = lm_head_bytes_per_param * context * vocab_size

    vram_bits = cuda_size + params_size + activations_size + output_size + kv_cache_size
    return round(bits_to_gb(vram_bits), 2)


def download_file(url, filepath, headers=None):
    if headers is None:
        headers = {}

    # Create the cache directory if it doesn't exist
    os.makedirs(os.path.dirname(filepath), exist_ok=True)

    # Check if file already exists
    if os.path.exists(filepath):
        return

    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response, open(filepath, 'wb') as out_file:
        while chunk := response.read(1024):
            out_file.write(chunk)


def download_model_configs(model_id, access=None):
    url = f"https://huggingface.co/{model_id}"
    readme_url = f"{url}/raw/main/README.md"
    config_url = f"{url}/raw/main/config.json"
    index_url = f"{url}/raw/main/model.safetensors.index.json"

    cache_dir = os.path.join("cache", model_id)
    readme_path = os.path.join(cache_dir, "README.md")
    config_path = os.path.join(cache_dir, "config.json")
    index_path = os.path.join(cache_dir, "model.safetensors.index.json")

    headers = {}
    if access:
        headers["Authorization"] = f"Bearer {access}"

    download_file(readme_url, readme_path, headers=headers)
    download_file(config_url, config_path, headers=headers)
    download_file(index_url, index_path, headers=headers)


def get_model_config(model_id, access=None):
    download_model_configs(model_id, access=access)
    cache_dir = os.path.join("cache", model_id)
    config_path = os.path.join(cache_dir, "config.json")
    index_path = os.path.join(cache_dir, "model.safetensors.index.json")
    config = json.load(open(config_path))
    index = json.load(open(index_path))
    num_params = index["metadata"]["total_size"] / 2 / 1e9
    config["num_params"] = num_params
    return config


def parse_bpw(bpw):
    try:
        return float(bpw)
    except ValueError:
        bpw = bpw.upper()
        return GGUF_MAPPING.get(bpw, 5.0)  # Default to 5.0 if not found

def get_bpw_values(bpw, fp8):
    bpw = parse_bpw(bpw)
    lm_head_bpw = 8.0 if bpw > 6.0 else 6.0
    kv_cache_bpw = 8 if fp8 else 16
    return {
        "bpw": bpw,
        "lm_head_bpw": lm_head_bpw,
        "kv_cache_bpw": kv_cache_bpw,
    }

def calculate_vram(model_id, bpw=5.0, context=None, fp8=True, access=None):
    config = get_model_config(model_id, access=access)
    bpw_values = get_bpw_values(bpw, fp8)
    context = context or config["max_position_embeddings"]
    return calculate_vram_raw(
        num_params=config["num_params"],
        bpw=bpw_values["bpw"],
        lm_head_bpw=bpw_values["lm_head_bpw"],
        kv_cache_bpw=bpw_values["kv_cache_bpw"],
        context=context,
        num_hidden_layers=config["num_hidden_layers"],
        hidden_size=config["hidden_size"],
        num_key_value_heads=config["num_key_value_heads"],
        num_attention_heads=config["num_attention_heads"],
        intermediate_size=config["intermediate_size"],
        vocab_size=config["vocab_size"],
    )


def calculate_context(model_id, memory=48, bpw=5.0, fp8=True, access=None):
    config = get_model_config(model_id, access=access)
    min_context = 2048
    max_context = config["max_position_embeddings"]

    low, high = min_context, max_context
    while low < high:
        mid = (low + high + 1) // 2
        if calculate_vram(model_id, bpw, mid, fp8, access=access) > memory:
            high = mid - 1
        else:
            low = mid

    context = low
    while calculate_vram(model_id, bpw, context, fp8, access=access) < memory and context <= max_context:
        context += 100

    return context - 100


def calculate_bpw(model_id, memory=48, context=None, fp8=True, type="exl2", access=None):
    if type == "exl2":
        for bpw in EXL2_OPTIONS:
            if calculate_vram(model_id, bpw, context, fp8, access=access) < memory:
                return bpw
    elif type == "gguf":
        for name, bpw in GGUF_MAPPING.items():
            if calculate_vram(model_id, bpw, context, fp8, access=access) < memory:
                return name
    return None


def main(model_id, mode="A", bpw=5.0, context=None, memory=48, type="exl2", fp8=True, access=None):
    if mode == "A":
        vram = calculate_vram(model_id, bpw, context, fp8, access=access)
        print(vram)
    elif mode == "B":
        context = calculate_context(model_id, memory, bpw, fp8, access=access)
        print(context)
    elif mode == "C":
        bpw = calculate_bpw(model_id, memory, context, fp8, type=type, access=access)
        print(bpw)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="VRAM, context length, and BPW calculator for LLMs.")
    parser.add_argument("model_id", type=str, help="Model ID from Hugging Face Hub")
    parser.add_argument("-m", "--mode", choices=["A", "B", "C"], default="A", help="Mode: A (calculate VRAM required), B (calculate context you can fit in your VRAM), C (calculate the best BPW you can fit in your VRAM)")
    parser.add_argument("-b", "--bpw", type=str, default="5.0", help="Bits per weight (can be float or GGUF ID, default: 5.0)")
    parser.add_argument("-c", "--context", type=int, default=None, help="Context length (default: use model setting)")
    parser.add_argument("-r", "--ram", type=int, default=48, help="Available VRAM in GB (default: 48)")
    parser.add_argument("-t", "--type", type=str, default="exl2", choices=["exl2", "gguf"],
                        help="Type of quantization [exl2, gguf] for BPW calculation (default: exl2)")
    parser.add_argument("-f", "--fp8", action=argparse.BooleanOptionalAction, help="Use FP8 KV cache (default: false)")
    parser.add_argument("-a", "--access", type=str, default=None, help="Access token for Hugging Face API (optional)")

    args = parser.parse_args()
    main(
        model_id=args.model_id,
        mode=args.mode,
        bpw=args.bpw,
        context=args.context,
        memory=args.ram,
        type=args.type,
        fp8=args.fp8,
        access=args.access
    )


"""
Examples:

1) How much memory do I need to run a LLama 3.1 405B model quantized to Q4_0?
$ python3 vram_calculator.py --mode A --bpw Q4_0 --access hf_xxxxxxxx meta-llama/Meta-Llama-3.1-405B-Instruct-FP8
288.41


2) How much context can I get out of this model?
$ python3 vram_calculator.py --mode B --ram 289 --bpw 4.55 meta-llama/Meta-Llama-3.1-405B-Instruct-FP8
131072


3) What is the best quant I can run of this model?
$ python3 vram_calculator.py --mode C --ram 289 --type gguf meta-llama/Meta-Llama-3.1-405B-Instruct-FP8
Q4_0
"""
