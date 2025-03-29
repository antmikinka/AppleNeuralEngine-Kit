# ANE Model Architecture

This document explains the detailed architecture of models optimized for the Apple Neural Engine (ANE).

## Core Principles

The Apple Neural Engine (ANE) is a specialized processor for neural network inference, part of Apple Silicon. To maximize its performance, models must be structured in specific ways:

1. **Size Constraints**: 
   - iOS models are limited to 1GB per file
   - macOS models are limited to ~2GB per file

2. **Tensor Operations Optimization**:
   - ANE favors certain tensor operations
   - Memory bandwidth is a limiting factor

3. **Stateful Operations**:
   - Efficient KV cache management is crucial
   - Stateful API support introduced in iOS 18/macOS 15

## Model Components

An ANE-optimized LLM consists of three main components:

### 1. Embeddings Layer

The embeddings layer is responsible for converting token IDs to embeddings:

```
Token IDs (int32) → Embeddings (float16 vectors)
```

**Characteristics**:
- Usually small in size (compared to FFN)
- Not quantized (for maximum accuracy)
- Single embedding per token (no chunking needed)

### 2. Feed Forward Network (FFN)

The FFN contains the transformer layers that process embeddings:

```
Embeddings → Transformer Layers → Hidden States
```

**Characteristics**:
- Largest part of the model (80%+ of parameters)
- Split into multiple chunks for large models
- Quantized using LUT (Look-Up Table) techniques
- May have specialized attention mechanisms per architecture

### 3. Language Model (LM) Head

The LM Head predicts the next token:

```
Hidden States → LM Head → Logits (vocabulary scores)
```

**Characteristics**:
- Similar size to embeddings layer
- Usually quantized with 6-bit precision
- Single component (no chunking)

## KV Cache Optimization

KV cache is a critical optimization for generative models:

1. **Prefill Mode**:
   - Processes initial prompt in batch
   - Generates KV cache for all tokens at once
   - Uses specialized "prefill" model variant

2. **Generation Mode**:
   - Processes one token at a time
   - Uses cached KV values from previous tokens
   - Only needs to compute for the new token

This architecture uses multi-function models that share weights between prefill and generation modes, reducing model size by approximately 50%.

## Multi-Function Chunks

Multi-function chunks combine different roles in one model file:

```
┌───────────────────────────┐
│ Multi-Function Chunk      │
├───────────────────────────┤
│ ├─ FFN Function           │
│ │  (token generation)     │
│ │                         │
│ ├─ Prefill Function       │
│ │  (KV cache generation)  │
└───────────────────────────┘
```

**Benefits**:
- Shared weights between functions
- Reduced total model size
- Efficient memory usage
- Faster switching between modes

## Quantization Strategy

Different model components use different quantization approaches:

| Component   | Quantization        | Rationale                        |
|-------------|---------------------|----------------------------------|
| Embeddings  | None (float16)      | Maximizes embedding accuracy     |
| FFN         | 4-6 bit LUT         | Balances size and accuracy       |
| LM Head     | 6-bit LUT           | Ensures prediction quality       |

## Architecture-Specific Adaptations

### Llama Models

```
┌─────────────────────────────────────┐
│ Llama Attention                     │
├─────────────────────────────────────┤
│ Multi-Head Attention                │
│ ├─ RoPE (Rotary Position Embedding) │
│ ├─ QKV Projection                   │
│ ├─ Attention Score Computation      │
│ └─ Output Projection                │
└─────────────────────────────────────┘
```

- Split points: After attention output and FFN blocks
- Special handling for RoPE embeddings
- KV cache optimized for Llama's attention pattern

### Qwen Models

```
┌─────────────────────────────────────┐
│ Qwen Attention                      │
├─────────────────────────────────────┤
│ Grouped-Query Attention             │
│ ├─ Modified RoPE                    │
│ ├─ Group-Query Projection           │
│ ├─ Sliding Window Attention         │
│ └─ Output Projection                │
└─────────────────────────────────────┘
```

- Special handling for grouped-query attention
- Custom KV cache design for grouped queries
- Split points optimized for Qwen architecture

### Mistral Models

```
┌─────────────────────────────────────┐
│ Mistral Attention                   │
├─────────────────────────────────────┤
│ Sliding Window Attention            │
│ ├─ Fixed Window Size                │
│ ├─ Efficient KV Cache               │
│ ├─ Optimized for Local Context      │
│ └─ Output Projection                │
└─────────────────────────────────────┘
```

- Optimized sliding window attention
- Specialized KV cache for window attention
- Split points after window attention blocks

## File Structure

A converted model has the following structure:

```
converted_model/
├── embeddings.mlmodelc/          # Embeddings model
├── lm_head_lut6.mlmodelc/        # LM head with 6-bit quantization
├── combined_lut6_chunk_01of02.mlmodelc/  # Multi-function chunk 1
├── combined_lut6_chunk_02of02.mlmodelc/  # Multi-function chunk 2
├── tokenizer.json               # HuggingFace tokenizer
├── meta.yaml                    # Configuration metadata
└── meta.json                    # JSON version of metadata
```

## Performance Considerations

Performance is affected by several factors:

1. **Chunk Count**:
   - More chunks = smaller files, more loading operations
   - Fewer chunks = larger files, potentially exceeding size limits

2. **Quantization Level**:
   - Lower bits (4-bit) = faster, less accurate
   - Higher bits (6-bit) = slower, more accurate

3. **Context Length**:
   - Longer contexts require more memory and KV cache
   - Scaling context length impacts memory usage quadratically

4. **Batch Size**:
   - Higher batch size for prefill = more efficient prompt processing
   - Limited by available memory

## Conclusion

The ANE model architecture represents a careful balance between model size, performance, and accuracy. By splitting the model into specialized components, applying targeted quantization, and optimizing KV cache operations, we achieve significant performance improvements for on-device inference.

This architecture is inspired by techniques from:
- ANEMLL's implementation by [@Anemll](https://github.com/Anemll/Anemll)
- Apple's CoreML model optimization approaches
- Research on efficient inference for large language models