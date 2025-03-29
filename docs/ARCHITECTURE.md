# AppleNeuralEngine-Kit Architecture

This document describes the architecture of the AppleNeuralEngine-Kit, explaining how the components work together to run LLMs on Apple Neural Engine.

## Overview

AppleNeuralEngine-Kit consists of four main components:

1. **ANEKit** - Core library for working with CoreML models on Apple Neural Engine
2. **ANEChat** - SwiftUI app for interactive chat with LLMs
3. **ANEToolCLI** - Command-line interface for running models
4. **ANEModelConverter** - Tool for converting models to Apple Neural Engine optimized formats

## Component Architecture

### ANEKit

![ANEKit Architecture](../Assets.xcassets/anekit-arch.png)

The core library consists of:

- **ModelPipeline**: Manages the forward pass for an LLM split across many MLModels
  - Handles loading/unloading chunks
  - Coordinates inference across models
  - Routes operations to appropriate compute units (CPU/ANE)

- **KVCacheProcessor**: Handles key-value cache updates
  - Efficiently updates attention caches
  - Manages IOSurface-backed memory for fast transfers

- **LogitProcessor**: Manages logit processing
  - Handles token selection
  - Applies sampling strategies (temperature, top-k, top-p)

- **TextGenerator**: High-level API for text generation
  - Manages tokenization and generation loop
  - Provides streaming interface with callbacks

### ANEChat

The SwiftUI app is structured around:

- **ChatViewModel**: Manages state and business logic
  - Handles model loading
  - Manages conversations
  - Controls generation process

- **Navigation System**: Three-column design
  - Conversation list
  - Chat interface
  - Settings panel

- **Persistence Layer**: UserDefaults-based
  - Saves conversations
  - Preserves settings

### ANEToolCLI

Command-line tool with:

- **ArgumentParser Integration**: Structured CLI interface
  - Model selection options
  - Generation parameters
  - Output formatting

- **HuggingFace Integration**: Remote model support
  - Downloads models from HuggingFace
  - Handles tokenizer downloads

### ANEModelConverter

Model conversion tool with:

- **Swift CLI Frontend**: User-friendly interface
  - Multiple conversion options
  - Progress reporting

- **Python Backend**: Technical conversion layer
  - HuggingFace → CoreML conversion
  - Model splitting and optimization
  - ANE-specific adaptations

## Data Flow During Inference

1. Input text is tokenized using the model's tokenizer
2. Tokens are processed by the ModelPipeline:
   - First chunk processes the input (runs on CPU)
   - Subsequent chunks process the hidden states (run on ANE)
   - KV cache is updated for each token
3. Logits from the final layer are processed by the LogitProcessor
4. Next token is selected and the process repeats
5. Generated tokens are decoded back to text

## Memory Management

The system employs several techniques for efficient memory use:

1. **IOSurface-Backed Storage**: Fast memory sharing between CPU/GPU/ANE
2. **Progressive Loading**: Loads model chunks as needed
3. **Chunked Architecture**: Splits model to fit in available memory
4. **Tensor Pooling**: Reuses tensor allocations when possible

## Concurrency Model

- Leverages Swift concurrency with async/await
- Uses actors for thread-safe state management
- Employs Task system for cancellable operations
- Provides progress updates via callbacks

## Extension Points

The architecture allows for:

1. **Custom Tokenizers**: Support for different tokenization schemes
2. **Alternative Models**: Any CoreML-compatible model
3. **Custom Sampling**: Pluggable logit processors
4. **Different UI Frontends**: Using ANEKit as a foundation