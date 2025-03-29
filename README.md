# AppleNeuralEngine-Kit

A Swift toolkit for running LLMs on Apple Neural Engine (ANE) with optimized performance, providing both command-line and SwiftUI interfaces.

## Overview

AppleNeuralEngine-Kit enables you to run Large Language Models directly on Apple Silicon using the Neural Engine for maximum efficiency and performance.

![ANE Chat Screenshot](Assets.xcassets/screenshot.png)

## Key Features

- Run LLMs (Llama 2, Llama 3, etc.) on Apple Neural Engine with maximum optimization
- Interactive chat interface with conversation history
- Command-line tool for scripts and automation
- Advanced model conversion with architecture-aware optimizations
- Multi-function model chunks for optimal memory usage
- KV cache optimization for fast token generation
- Real-time text streaming with performance metrics

## Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/antmikinka/AppleNeuralEngine-Kit.git
cd AppleNeuralEngine-Kit

# Build the project
swift build
```

### Chat Interface

```bash
swift run ANEChat
```

### Command Line

```bash
swift run ANEToolCLI --repo-id meta-llama/Llama-3.2-1B --input-text "Tell me about neural networks"
```

### Model Conversion

```bash
# Using the CLI
swift run ANEModelConverter convert-hf --model-id meta-llama/Llama-3.2-1B --output-dir ./models

# Using the Python script directly
python Scripts/convert_model.py --model /path/to/model --output ./converted_model --context 1024 --batch-size 64 --chunks 2 --lut 6
```

## Architecture

The model conversion process follows the architecture-aware approach:

1. **Model Splitting**: Models are split into three components:
   - Embeddings layer
   - Feed Forward Network (FFN)
   - Language Model (LM) Head

2. **Optimized KV Cache**: Dedicated prefill models for fast token generation

3. **Multi-Function Chunks**: Optimizes size by sharing weights between components

4. **Quantization Strategy**: Different precision for different components
   - Embeddings: Unquantized for accuracy
   - FFN/Prefill: 4-6 bit LUT quantization
   - LM Head: 6-bit quantization for prediction quality

## Documentation

- [Usage Guide](docs/USAGE.md) - Detailed usage instructions for all components
- [Architecture](docs/ARCHITECTURE.md) - Overview of system design and components
- [Model Conversion](docs/MODEL_CONVERSION.md) - How to convert and optimize models
- [Development Guide](docs/DEVELOPMENT.md) - Information for contributors and developers
- [ANE Model Architecture](docs/ANE_MODEL_ARCHITECTURE.md) - Detailed explanation of model optimization for ANE
- [iOS Implementation](docs/iOS_IMPLEMENTATION_PLAN.md) - Implementation plan for iOS deployment

## Requirements

- macOS 14 (Sonoma) or newer
- Apple Silicon Mac (M1/M2/M3 series)
- Swift 5.9 or newer
- Python 3.8+ with transformers and coremltools (for model conversion)
- Xcode Command Line Tools (for CoreML compilation)

## Performance

| Model                | Tokens/Sec | 1st Load | Subsequent Loads |
|----------------------|------------|----------|------------------|
| Llama-3.2-1B (M1)    | 7.0        | 113s     | 8.1s             |
| Llama-3.2-1B (M3)    | 13.9       | 30s      | 0.8s             |
| Llama-3.2-3B (M3)    | 5.2        | 201s     | 3.1s             |

## Architecture-Specific Optimization

This project now includes architecture-specific optimizations for:
- Llama models (Llama 2, Llama 3)
- Mistral models
- Qwen models 
- QwQ models
- Phi models
- Gemma models

## Credits

This project builds upon:
- [CoreML LLM CLI](https://github.com/smpanaro/coreml-llm-cli) by Stephen Panaro
- [ANEMLL](https://github.com/Anemll/Anemll) for ANE-optimized conversion techniques
- [LitGPT](https://github.com/Lightning-AI/lit-gpt) for model optimization techniques
- [Apple Silicon 4-bit quantization](https://github.com/apple/coremltools) for efficient model sizing

## License

[MIT License](LICENSE)