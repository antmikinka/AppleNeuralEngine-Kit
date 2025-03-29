# AppleNeuralEngine-Kit

A Swift toolkit for running LLMs on Apple Neural Engine (ANE) with optimized performance, providing both command-line and SwiftUI interfaces.

## Overview

AppleNeuralEngine-Kit enables you to run Large Language Models directly on Apple Silicon using the Neural Engine for maximum efficiency and performance.

![ANE Chat Screenshot](Assets.xcassets/screenshot.png)

## Key Features

- Run LLMs (Llama 2, Llama 3, etc.) on Apple Neural Engine with maximum optimization
- Interactive chat interface with conversation history
- Command-line tool for scripts and automation
- Model conversion tools for optimizing HuggingFace models
- Efficient memory management with chunked model loading
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
swift run ANEModelConverter convert-hf --model-id meta-llama/Llama-3.2-1B --output-dir ./models
```

## Documentation

- [Usage Guide](docs/USAGE.md) - Detailed usage instructions for all components
- [Architecture](docs/ARCHITECTURE.md) - Overview of system design and components
- [Model Conversion](docs/MODEL_CONVERSION.md) - How to convert and optimize models
- [Development Guide](docs/DEVELOPMENT.md) - Information for contributors and developers

## Requirements

- macOS 14 (Sonoma) or newer
- Apple Silicon Mac (M1/M2/M3 series)
- Swift 5.9 or newer
- Python 3.8+ with transformers and coremltools (for model conversion)

## Performance

| Model                | Tokens/Sec | 1st Load | Subsequent Loads |
|----------------------|------------|----------|------------------|
| Llama-3.2-1B (M1)    | 7.0        | 113s     | 8.1s             |
| Llama-3.2-1B (M3)    | 13.9       | 30s      | 0.8s             |
| Llama-3.2-3B (M3)    | 5.2        | 201s     | 3.1s             |

## Credits

This project builds upon:
- [CoreML LLM CLI](https://github.com/smpanaro/coreml-llm-cli) by Stephen Panaro
- [LitGPT](https://github.com/Lightning-AI/lit-gpt) for model optimization techniques
- [Apple Silicon 4-bit quantization](https://github.com/apple/coremltools) for efficient model sizing

## License

[MIT License](LICENSE)