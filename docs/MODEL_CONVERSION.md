# Model Conversion Guide

This guide explains how to convert LLM models for optimal use with the Apple Neural Engine (ANE).

## Overview

Converting models for ANE requires special optimization techniques to achieve maximum performance. Our conversion process splits the model into distinct components and applies architecture-specific optimizations.

## Conversion Process

The conversion pipeline involves several key steps, with detailed progress tracking for each stage:

1. **Model Configuration Analysis**: 
   - Load and analyze the model's configuration
   - Auto-detect architecture type
   - Estimate parameter count and recommend chunk size

2. **Model Loading**: 
   - Load model weights with memory optimization
   - Apply architecture-specific preprocessing

3. **Model Splitting**: Split into three components:
   - Embeddings layer (token embeddings)
   - Feed Forward Network (transformer layers)
   - LM Head (token prediction)

4. **KV Cache Optimization**: 
   - Create prefill models for efficient processing of long contexts
   - Optimize attention mechanisms based on architecture

5. **Multi-Function Chunks**: 
   - Merge FFN and prefill models to optimize weight sharing
   - Reduce total model size by approximately 50%

6. **LUT Quantization**: 
   - Apply Look-Up Table quantization with architecture-specific settings
   - Use different precision for different model components

7. **Compilation**: 
   - Convert to MLModelC format for efficient on-device execution
   - Optimize for Apple Neural Engine

## Using the Conversion Tool

### Option 1: Using the Visual Interface

The macOS app includes a built-in model conversion interface:

1. Launch the app: `swift run ANEChat`
2. Click on the "Convert Model" tab
3. Fill in the conversion options:
   - Model Path: Select HuggingFace model directory
   - Output Path: Choose where to save the converted model
   - Architecture: Auto-detect or specify model type
   - Context Length, Batch Size, Chunks, etc.
4. Click "Convert Model" to start the process with real-time progress tracking

### Option 2: Using the Swift CLI

```bash
swift run ANEModelConverter convert-hf \
    --model-id meta-llama/Llama-3.2-1B \
    --output-dir ./models \
    --context-length 1024 \
    --num-chunks 2 \
    --lut-bits 6
```

### Option 3: Using the Python Script

For direct access to the conversion process with detailed progress reporting:

```bash
python scripts/convert_hf_to_coreml.py \
    --model_path meta-llama/Llama-3.2-1B \
    --output_path ./converted_model \
    --max_seq_len 1024 \
    --batch_size 64 \
    --quantize_weights 6 \
    --verbose
```

You'll see detailed progress indicators showing:
- Overall completion percentage
- Current conversion step
- Estimated time remaining
- Architecture-specific optimizations being applied

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

## Monitoring Conversion Progress

With the enhanced progress tracking, you can now monitor each step of the conversion process:

1. **Configuration Analysis**:
   - Displays model details (parameters, architecture)
   - Shows recommended chunk count based on architecture analysis

2. **Weight Loading**:
   - Progress indicators for loading large model files
   - Memory usage optimization notification

3. **Optimization Phase**:
   - Shows which architecture-specific optimizations are being applied
   - Details on any compatibility adjustments being made

4. **Conversion and Quantization**:
   - Progress metrics for CoreML conversion
   - Notifications for each major conversion step
   - ETA based on processing speed

## Troubleshooting

If conversion fails:

1. Check the detailed error messages for specific step failures
2. Verify input model format and completeness
3. Try increasing chunk count for large models
4. Use `--skip-check` if dependency checks are failing incorrectly
5. Use `--verbose` to get more detailed progress and debugging information
6. Check for available memory (conversion requires significant RAM)
7. For large models, ensure your system meets the minimum requirements

## Credits

The conversion approach is based on techniques from:
- ANEMLL's architecture-aware model splitting
- Apple's CoreML quantization tools
- LitGPT optimization methods