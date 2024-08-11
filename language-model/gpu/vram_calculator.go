package main

// Calculate GPU VRAM requirements for LLM models
//
// Date created: 2024-08-11
// Version 1.8
// License: MIT
// Copyright: Cedric Chee

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

const (
	baseDir = "cache"
)

var (
	GGUF_MAPPING = map[string]float64{
		"Q8_0":    8.5,
		"Q6_K":    6.59,
		"Q5_K_M":  5.69,
		"Q5_K_S":  5.54,
		"Q5_0":    5.54,
		"Q4_K_M":  4.85,
		"Q4_K_S":  4.58,
		"Q4_0":    4.55,
		"IQ4_NL":  4.5,
		"Q3_K_L":  4.27,
		"IQ4_XS":  4.25,
		"Q3_K_M":  3.91,
		"IQ3_M":   3.7,
		"IQ3_S":   3.5,
		"Q3_K_S":  3.5,
		"Q2_K":    3.35,
		"IQ3_XS":  3.3,
		"IQ3_XXS": 3.06,
		"IQ2_M":   2.7,
		"IQ2_S":   2.5,
		"IQ2_XS":  2.31,
		"IQ2_XXS": 2.06,
		"IQ1_S":   1.56,
	}

	EXL2_OPTIONS = []float64{}
)

// bpwValue defines custom type that can hold either a float or a string value.
// The type is for the flag `-bpw“.
type bpwValue struct {
	value interface{}
}

// Set method attempts to parse the input string as a float, and if that fails,
// it stores the string value instead.
func (b *bpwValue) Set(s string) error {
	if f, err := strconv.ParseFloat(s, 64); err == nil {
		b.value = f
		return nil
	}
	b.value = s
	return nil
}

// String method returns a string representation of the value.
func (b *bpwValue) String() string {
	return fmt.Sprintf("%v", b.value)
}

func init() {
	i := 6.0
	for i > 1.0 {
		EXL2_OPTIONS = append(EXL2_OPTIONS, i)
		i -= 0.05
	}
}

func bitsToGb(bits float64) float64 {
	// return bits / (2 * 1024 * 1024 * 1024) // wrong
	return bits / math.Pow(2, 30)
}

func calculateVramRaw(
	numParams float64,
	bpw float64,
	lmHeadBpw float64,
	kvCacheBpw float64,
	context float64,
	fp8 bool,
	numGpus int,
	maxPositionEmbeddings float64,
	numHiddenLayers float64,
	hiddenSize float64,
	numKeyValueHeads float64,
	numAttentionHeads float64,
	intermediateSize float64,
	vocabSize float64,
	gqa bool,
) float64 {
	// cudaSize := 500 * 2 * 1024 * 1024 * float64(numGpus)
	// cudaSize := float64(500 * 1 << 20 * numGpus)
	cudaSize := float64(500) * math.Pow(2, 20) * float64(numGpus)
	paramsSize := numParams * 1e9 * (bpw / 8)
	kvCacheSize := (context * 2 * numHiddenLayers * hiddenSize) * (kvCacheBpw / 8)

	if gqa {
		kvCacheSize *= numKeyValueHeads / numAttentionHeads
	}

	bytesPerParam := bpw / 8
	lmHeadBytesPerParam := lmHeadBpw / 8

	headDim := hiddenSize / numAttentionHeads
	attentionInput := bytesPerParam * context * hiddenSize

	q := bytesPerParam * context * headDim * numAttentionHeads
	k := bytesPerParam * context * headDim * numKeyValueHeads
	v := bytesPerParam * context * headDim * numKeyValueHeads

	softmaxOutput := lmHeadBytesPerParam * numAttentionHeads * context
	softmaxDropoutMask := numAttentionHeads * context
	dropoutOutput := lmHeadBytesPerParam * numAttentionHeads * context

	outProjInput := lmHeadBytesPerParam * context * numAttentionHeads * headDim
	attentionDropout := context * hiddenSize

	attentionBlock := (attentionInput +
		q +
		k +
		softmaxOutput +
		v +
		outProjInput +
		softmaxDropoutMask +
		dropoutOutput +
		attentionDropout)

	mlpInput := bytesPerParam * context * hiddenSize
	activationInput := bytesPerParam * context * intermediateSize
	downProjInput := bytesPerParam * context * intermediateSize
	dropoutMask := context * hiddenSize
	mlpBlock := mlpInput + activationInput + downProjInput + dropoutMask

	layerNorms := bytesPerParam * context * hiddenSize * 2
	activationsSize := attentionBlock + mlpBlock + layerNorms

	outputSize := lmHeadBytesPerParam * context * vocabSize

	vramBits := cudaSize + paramsSize + activationsSize + outputSize + kvCacheSize

	return round(bitsToGb(vramBits), 2)
}

func downloadFile(url string, filename string, headers map[string]string) error {
	// Disable the following line for fixing error "stat cache/{model_id}/config.json: no such file or directory"
	// baseDir := filepath.Join(filepath.Dir(os.Args[0]), baseDir)
	filePath := filepath.Join(baseDir, filename)

	if _, err := os.Stat(filePath); err == nil {
		return nil
	}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}

	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("status code: %d", resp.StatusCode)
	}

	os.MkdirAll(filepath.Dir(filePath), 0755)

	f, err := os.Create(filePath)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = io.Copy(f, resp.Body)
	if err != nil {
		return err
	}

	// Check if the file was saved correctly
	if _, err := os.Stat(filePath); err != nil {
		return err
	}

	return nil
}

func downloadModelConfigs(modelId string, access string) error {
	baseUrl := fmt.Sprintf("https://huggingface.co/%s/raw/main/", modelId)

	readmeUrl := baseUrl + "README.md"
	configUrl := baseUrl + "config.json"
	indexUrl := baseUrl + "model.safetensors.index.json"

	readmePath := filepath.Join(modelId, "README.md")
	configPath := filepath.Join(modelId, "config.json")
	indexPath := filepath.Join(modelId, "model.safetensors.index.json")

	headers := map[string]string{}
	if access != "" {
		headers["Authorization"] = fmt.Sprintf("Bearer %s", access)
	}

	if err := downloadFile(readmeUrl, readmePath, headers); err != nil {
		return err
	}
	if err := downloadFile(configUrl, configPath, headers); err != nil {
		return err
	}
	if err := downloadFile(indexUrl, indexPath, headers); err != nil {
		return err
	}

	return nil
}

func getModelConfig(modelId string, access string) (map[string]interface{}, error) {
	if err := downloadModelConfigs(modelId, access); err != nil {
		return nil, err
	}

	modelDir := filepath.Join(baseDir, modelId)
	configPath := filepath.Join(modelDir, "config.json")
	indexPath := filepath.Join(modelDir, "model.safetensors.index.json")

	// Check if the config file exists
	if _, err := os.Stat(configPath); err != nil {
		return nil, err
	}

	// Check if the index file exists
	if _, err := os.Stat(indexPath); err != nil {
		return nil, err
	}

	var config map[string]interface{}
	{
		f, err := os.Open(configPath)
		if err != nil {
			return nil, err
		}
		defer f.Close()

		if err := json.NewDecoder(f).Decode(&config); err != nil {
			return nil, err
		}
	}

	var index map[string]interface{}
	{
		f, err := os.Open(indexPath)
		if err != nil {
			return nil, err
		}
		defer f.Close()

		if err := json.NewDecoder(f).Decode(&index); err != nil {
			return nil, err
		}
	}

	numParams := index["metadata"].(map[string]interface{})["total_size"].(float64) / 2 / 1e9
	config["num_params"] = numParams
	return config, nil
}

func parseBpw(bpw string) float64 {
	f, err := strconv.ParseFloat(bpw, 64)
	if err != nil {
		return GGUF_MAPPING[strings.ToUpper(bpw)]
	}
	return f
}

func getBpwValues(bpw string, fp8 bool) map[string]float64 {
	bpwValue := parseBpw(bpw)

	lmHeadBpw := 6.0
	if bpwValue > 6.0 {
		lmHeadBpw = 8.0
	}

	kvCacheBpw := 16.0
	if fp8 {
		kvCacheBpw = 8.0
	}

	return map[string]float64{
		"bpw":          bpwValue,
		"lm_head_bpw":  lmHeadBpw,
		"kv_cache_bpw": kvCacheBpw,
	}
}

func calculateVram(modelId string, bpw string, context float64, fp8 bool, access string) (float64, error) {
	config, err := getModelConfig(modelId, access)
	if err != nil {
		return 0, err
	}

	bpwValues := getBpwValues(bpw, fp8)

	if context == 0 {
		context = config["max_position_embeddings"].(float64)
	}

	return calculateVramRaw(
		config["num_params"].(float64),
		bpwValues["bpw"],
		bpwValues["lm_head_bpw"],
		bpwValues["kv_cache_bpw"],
		context,
		fp8,
		1,
		config["max_position_embeddings"].(float64),
		config["num_hidden_layers"].(float64),
		config["hidden_size"].(float64),
		config["num_key_value_heads"].(float64),
		config["num_attention_heads"].(float64),
		config["intermediate_size"].(float64),
		config["vocab_size"].(float64),
		true,
	), nil
}

func calculateContext(modelId string, memory float64, bpw string, fp8 bool, access string) (float64, error) {
	config, err := getModelConfig(modelId, access)
	if err != nil {
		return 0, err
	}

	minContext := 2048.0
	maxContext := config["max_position_embeddings"].(float64)

	low, high := minContext, maxContext
	for low < high {
		mid := (low + high + 1) / 2
		vram, err := calculateVram(modelId, bpw, mid, fp8, access)
		if err != nil {
			return 0, err
		}
		if vram > memory {
			high = mid - 1
		} else {
			low = mid
		}
	}

	context := low
	for {
		vram, err := calculateVram(modelId, bpw, context, fp8, access)
		if err != nil {
			return 0, err
		}
		if vram >= memory || context >= maxContext {
			break
		}
		context += 100
	}

	return context - 100, nil
}

func calculateBpw(modelId string, memory float64, context float64, fp8 bool, type_ string, access string) (string, error) {
	if type_ == "exl2" {
		for _, bpw := range EXL2_OPTIONS {
			vram, err := calculateVram(modelId, fmt.Sprintf("%f", bpw), context, fp8, access)
			if err != nil {
				return "", err
			}
			if vram < memory {
				return fmt.Sprintf("%f", bpw), nil
			}
		}
	} else if type_ == "gguf" {
		// Be careful: The iteration order of Go maps won’t necessarily be the
		// same every time you run the program.

		// for name := range GGUF_MAPPING {
		// 	vram, err := calculateVram(modelId, name, context, fp8, access)
		// 	if err != nil {
		// 		return "", err
		// 	}
		// 	if vram < memory {
		// 		return name, nil
		// 	}
		// }

		// Ordering map keys
		keys := make([]string, 0, len(GGUF_MAPPING))
		for key := range GGUF_MAPPING {
			keys = append(keys, key)
		}
		sort.SliceStable(keys, func(i, j int) bool {
			return GGUF_MAPPING[keys[i]] > GGUF_MAPPING[keys[j]]
		})

		for _, k := range keys {
			name := k

			bpw := fmt.Sprintf("%f", GGUF_MAPPING[name])
			vram, err := calculateVram(modelId, bpw, context, fp8, access)
			if err != nil {
				return "", err
			}
			if vram < memory {
				return name, nil
			}
		}
	}
	return "", nil
}

func round(val float64, precision int) float64 {
	p := math.Pow10(precision)
	return math.Round(val*p) / p
}

func main() {
	flag.Usage = func() {
		w := flag.CommandLine.Output()
		fmt.Fprintf(w, "GPU VRAM, context length, and BPW calculator for LLMs.\n\n")
		fmt.Fprintf(w, "Usage: %s [options]\n\nOptions:\n", os.Args[0])
		flag.PrintDefaults()
		fmt.Fprintf(w, "\nMode-specific options:\n")
		fmt.Fprintf(w, "Mode A: Set -bpw and -context to get the amount of VRAM required\n")
		fmt.Fprintf(w, "Mode B: Set -memory and -bpw to get the amount of context you can fit in your VRAM\n")
		fmt.Fprintf(w, "Mode C: Set -memory and -context to get the best BPW you can fit in your VRAM\n\n")
		fmt.Fprintf(w, "Note:\n")
		fmt.Fprintf(w, "You can use numbers like 4.55 OR GGUF Quant IDs like Q4_0 for the -bpw value.\n")
		fmt.Fprintf(w, "For mode C, specifying -type gguf will return GGUF Quant IDs, while specifying -type exl2 will return floating point numbers.\n\n")
		fmt.Fprintf(w, "Examples:\n")
		fmt.Fprintf(w, "1) How much memory do I need to run a LLama 3.1 405B model quantized to Q4_0?\n")
		fmt.Fprintf(w, "./vram_calculator -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode A -bpw Q4_0 -access $HF_API_TOKEN\n\n")
		fmt.Fprintf(w, "2) How much context can I get out of this model?\n")
		fmt.Fprintf(w, "./vram_calculator -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode B -ram 289 -bpw 4.55 -access $HF_API_TOKEN\n\n")
		fmt.Fprintf(w, "3) What is the best quant I can run of this model?\n")
		fmt.Fprintf(w, "./vram_calculator -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode C -ram 289 -type gguf -access $HF_API_TOKEN\n\n")
	}

	modelId := flag.String("model_id", "", "Model ID from Hugging Face Hub")
	access := flag.String("access", "", "Access token for Hugging Face API (optional)")
	fp8 := flag.Bool("fp8", false, "Use FP8 KV cache (default false)")
	mode := flag.String("mode", "A", "Select mode")

	// The flag `-bpw` should accept either a float or a string value.
	bpw := &bpwValue{value: 5.0}
	// Define the `-bpw`` flag with the custom `bpwValue` type.
	flag.Var(bpw, "bpw", "Bits per weight (can be float or GGUF ID)")

	context := flag.Float64("context", 0, "Context length (default use model setting)")
	ram := flag.Float64("ram", 48, "Available VRAM in GB")
	type_ := flag.String("type", "exl2", "Type of quantization [exl2, gguf] for BPW calculation")

	flag.Parse()

	*mode = strings.ToLower(*mode)

	// Extract the float or string value from the `bpw` flag.
	bpwFloat, bpwStr := 0.0, ""
	switch v := bpw.value.(type) {
	case float64:
		bpwFloat = v
	case string:
		bpwStr = v
	default:
		log.Fatal("Invalid value for -bpw flag")
	}

	if *mode == "a" {
		// Mode A - calculate VRAM required

		vram, err := calculateVram(*modelId, bpwStr, *context, *fp8, *access)
		if bpwStr == "" {
			vram, err = calculateVram(*modelId, fmt.Sprintf("%f", bpwFloat), *context, *fp8, *access)
		}
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(vram)
	} else if *mode == "b" {
		// Mode B - calculate context you can fit in your VRAM

		context, err := calculateContext(*modelId, *ram, fmt.Sprintf("%f", bpwFloat), *fp8, *access)
		if bpwStr != "" {
			context, err = calculateContext(*modelId, *ram, bpwStr, *fp8, *access)
		}
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(int(context))
	} else if *mode == "c" {
		// Mode C - calculate the best BPW you can fit in your VRAM

		bpw, err := calculateBpw(*modelId, *ram, *context, *fp8, *type_, *access)
		if err != nil {
			log.Fatal(err)
		}
		fmt.Println(bpw)
	}
}

/*
Examples:

1) How much memory do I need to run a LLama 3.1 405B model quantized to Q4_0?
$ go run vram_calculator.go -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode A -bpw Q4_0 -access $HF_API_TOKEN
288.41


2) How much context can I get out of this model?
$ go run vram_calculator.go -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode B -ram 289 -bpw 4.55 -access $HF_API_TOKEN
130972


3) What is the best quant I can run of this model?
$ go run vram_calculator.go -model_id meta-llama/Meta-Llama-3.1-405B-Instruct-FP8 -mode C -ram 289 -type gguf -access $HF_API_TOKEN
Q4_0
*/
