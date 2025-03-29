# Model Conversion Guide

This guide explains how to convert and optimize LLMs for Apple Neural Engine using the AppleNeuralEngine-Kit.

## Prerequisites

Before you begin, ensure you have the following installed:

- Python 3.8 or newer
- Required Python packages:
  ```bash
  pip install transformers torch coremltools numpy
  ```
- A Mac with Apple Silicon (M1/M2/M3 series)
- Xcode 15 or newer
- AppleNeuralEngine-Kit built from source

## Converting a Hugging Face Model

The simplest way to convert a model is using the `ANEModelConverter` command-line tool:

```bash
swift run ANEModelConverter convert-hf --model-id meta-llama/Llama-3.2-1B --output-dir ./models
```

This performs the following steps automatically:

1. Downloads the model from Hugging Face
2. Converts the model to CoreML format
3. Applies quantization and ANE optimizations
4. Creates the necessary files for the model pipeline

## Manual Conversion Process

For more control over the conversion process, you can follow these steps manually:

### 1. Download a Model from Hugging Face

```bash
python -c "from huggingface_hub import snapshot_download; snapshot_download('meta-llama/Llama-3.2-1B')"
```

### 2. Convert to CoreML Format

```bash
python scripts/convert_hf_to_coreml.py \
  --model_path ./meta-llama/Llama-3.2-1B \
  --output_path ./model_coreml \
  --quantize_weights 4
```

### 3. Split the Model into Chunks

```bash
python scripts/split_coreml_model.py \
  --model_path ./model_coreml \
  --output_path ./model_split \
  --num_chunks 6
```

### 4. Generate KV Cache and Logit Processors

```bash
python scripts/generate_processors.py \
  --model_path ./model_coreml \
  --output_path ./model_split
```

## Quantization Options

The `ANEModelConverter` supports different quantization precisions:

- **4-bit quantization** (default): Best for most applications, provides excellent balance between model size, performance, and quality
  ```bash
  swift run ANEModelConverter convert-hf --quant-bits 4 ...
  ```

- **8-bit quantization**: Higher accuracy but larger model size and potentially slower inference
  ```bash
  swift run ANEModelConverter convert-hf --quant-bits 8 ...
  ```

## Advanced Optimization Techniques

### Activation Awareness

For best results, the quantization process analyzes activation patterns during inference to better preserve the model's behavior:

```bash
python scripts/activation_aware_quantization.py \
  --model_path ./model_coreml \
  --calibration_dataset ./calibration_data \
  --output_path ./model_optimized
```

### Weight Splitting

Weight splitting partitions weight matrices along the hidden dimension, allowing more efficient execution on ANE:

```bash
python scripts/optimize_weight_layout.py \
  --model_path ./model_coreml \
  --output_path ./model_optimized
```

## Using a Converted Model

Once your model is converted, you can use it with AppleNeuralEngine-Kit:

```swift
import ANEKit

let pipeline = try ModelPipeline.from(
    folder: URL(fileURLWithPath: "./model_split"),
    primaryCompute: .cpuAndNeuralEngine
)

let tokenizer = try await AutoTokenizer.from(pretrained: "meta-llama/Llama-3.2-1B")
let generator = TextGenerator(pipeline: pipeline, tokenizer: tokenizer)

try await generator.generate(text: "Once upon a time", maxNewTokens: 100)
```

## Troubleshooting

### Common Issues

- **Out of Memory**: Try increasing the number of chunks when splitting the model
- **ANE Compatibility**: Ensure you're using operations supported by ANE
- **Slow Inference**: Check if all chunks except the first are running on ANE

### Validating a Converted Model

Use the validation tool to ensure your model is functioning correctly:

```bash
swift run ANEModelConverter validate --model-path ./model_split
```

This performs a quick inference to verify the model loads and runs properly.

## For More Information

- Check the [CoreML Tools documentation](https://coremltools.readme.io/docs)
- Review the [LitGPT model conversion scripts](https://github.com/Lightning-AI/lit-gpt)
- See Apple's [guide to ML model deployment](https://developer.apple.com/documentation/coreml)