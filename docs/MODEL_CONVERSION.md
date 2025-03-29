# Model Conversion Guide

This guide explains how to convert LLM models for optimal use with the Apple Neural Engine (ANE).

## Overview

Converting models for ANE requires special optimization techniques to achieve maximum performance. Our conversion process splits the model into distinct components and applies architecture-specific optimizations.

## Conversion Process

The conversion pipeline involves several key steps:

1. **Model Splitting**: Split into three components:
   - Embeddings layer (token embeddings)
   - Feed Forward Network (transformer layers)
   - LM Head (token prediction)

2. **KV Cache Optimization**: Create prefill models for efficient processing of long contexts

3. **Multi-Function Chunks**: Merge FFN and prefill models to optimize weight sharing

4. **LUT Quantization**: Apply Look-Up Table quantization with architecture-specific settings

5. **Compilation**: Convert to MLModelC format for efficient on-device execution

## Using the Conversion Tool

### Option 1: Using the Swift CLI

```bash
swift run ANEModelConverter convert-hf \
    --model-id meta-llama/Llama-3.2-1B \
    --output-dir ./models \
    --context-length 1024 \
    --num-chunks 2 \
    --lut-bits 6
```

### Option 2: Using the Python Script

```bash
python Scripts/convert_model.py \
    --model /path/to/model \
    --output ./converted_model \
    --context 1024 \
    --batch-size 64 \
    --chunks 2 \
    --lut 6
```

## Conversion Parameters

| Parameter | Description | Recommended Value |
|-----------|-------------|------------------|
| `--context` | Maximum context length | 1024-4096 |
| `--batch-size` | Batch size for prefill mode | 64-128 |
| `--chunks` | Number of model chunks | 1-2 (1B), 4-8 (7B+) |
| `--lut` | LUT quantization bits | 6 (balanced), 4 (speed) |
| `--architecture` | Model architecture | Auto-detected if not specified |

## Architecture-Specific Optimizations

Different model architectures benefit from specific optimizations:

### Llama Models
- Optimized attention mechanism for Llama-style MHA
- Split points after attention blocks and FFN projections
- Recommended quantization: 6-bit LUT

### Qwen Models
- Specialized handling for Qwen's grouped-query attention
- Split points after attention outputs
- Optimized embedding handling with shared weights
- Recommended quantization: 6-bit LUT

### QwQ Models
- Custom quantization handling for already quantized models
- Specialized KV cache for optimized memory usage
- Recommended setting: preserve existing quantization

### Mistral Models
- Optimized for Mistral's sliding window attention
- Special handling for Mistral's KV cache pattern
- Recommended chunks: 4 for 7B model

## Chunk Size Recommendations

Choose chunk counts based on model size:

| Model Size | Recommended Chunks | iOS | macOS |
|------------|-------------------|-----|-------|
| 1B         | 1-2               | ✓   | ✓     |
| 3B         | 2-4               | ✓   | ✓     |
| 7B         | 4-8               | ✓   | ✓     |
| 13B        | 8-16              | ⚠️   | ✓     |
| 70B+       | 32+               | ❌   | ⚠️    |

Note: iOS has a 1GB file size limit per model, while macOS can handle ~2GB.

## Verification and Testing

After conversion, verify your model:

```bash
# Test in chat interface
swift run ANEChat

# Simple CLI test
swift run ANEToolCLI --model-path ./converted_model --prompt "Hello, world!"
```

## Troubleshooting

If conversion fails:

1. Check error messages for specific step failures
2. Verify input model format and completeness
3. Try increasing chunk count for large models
4. Use `--skip-check` if dependency checks are failing incorrectly
5. Use `--restart N` to resume from a specific step (1-8)

## Credits

The conversion approach is based on techniques from:
- ANEMLL's architecture-aware model splitting
- Apple's CoreML quantization tools
- LitGPT optimization methods