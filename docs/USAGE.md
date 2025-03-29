# AppleNeuralEngine-Kit Usage Guide

This guide provides detailed usage instructions for all components of AppleNeuralEngine-Kit.

## Table of Contents

- [SwiftUI App (ANEChat)](#swiftui-app-anechat)
- [Command Line Tool (ANEToolCLI)](#command-line-tool-anetoolcli)
- [Model Converter (ANEModelConverter)](#model-converter-anemodelconverter)
- [Library Usage (ANEKit)](#library-usage-anekit)

## SwiftUI App (ANEChat)

### Starting the App

```bash
swift run ANEChat
```

### Chat Interface

- Type messages in the text field at the bottom
- Conversations are saved automatically
- Use the sidebar to switch between conversations
- Performance metrics are displayed after each generation

### Model Conversion Interface

The app now includes a dedicated model conversion tab:

1. Click the "Convert Model" tab in the main window
2. Configure your conversion options:
   - **Model Path**: Select the HuggingFace model directory
   - **Output Path**: Choose where to save the converted model
   - **Architecture**: Auto-detect or specify model architecture
   - **Context Length**: Set maximum context window size
   - **Batch Size**: Configure prefill batch size
   - **Chunks**: Set number of model chunks (or auto)
   - **Quantization**: Choose 4-bit (faster) or 6-bit (higher quality)
3. Click "Convert Model" to start the conversion with real-time progress tracking

### Loading a Model

1. Click the settings gear icon in the top right
2. Choose either:
   - **Local Model**: Select a folder containing CoreML model chunks
   - **Remote Model**: Enter a HuggingFace repo ID to download

### Keyboard Shortcuts

- **⌘N**: Create a new chat
- **⌘,**: Open settings
- **⌘T**: Switch tabs (Chat/Convert)
- **⌘W**: Close current window
- **⌘S**: Save conversation
- **⌘⏎**: Send message

## Command Line Tool (ANEToolCLI)

### Basic Usage

```bash
swift run ANEToolCLI --input-text "Tell me about neural networks" --max-new-tokens 200
```

### Loading Models

From HuggingFace:
```bash
swift run ANEToolCLI --repo-id meta-llama/Llama-3.2-1B
```

From local directory:
```bash
swift run ANEToolCLI --local-model-directory /path/to/model
```

### Advanced Options

```bash
# Specify tokenizer
swift run ANEToolCLI --tokenizer-name meta-llama/Llama-3.2-1B

# Specify model prefix for disambiguation
swift run ANEToolCLI --local-model-prefix "Llama-3.2-1B"

# Verbose logging
swift run ANEToolCLI --verbose
```

### Output Formatting

The tool prints:
- Model loading information
- Token generation statistics
- Generated text
- Performance metrics

## Model Converter (ANEModelConverter)

### Converting HuggingFace Models

```bash
swift run ANEModelConverter convert-hf --model-id meta-llama/Llama-3.2-1B --output-dir ./models
```

Options:
- `--quant-bits 4` - Use 4-bit quantization (faster, smaller)
- `--quant-bits 6` - Use 6-bit quantization (balanced)
- `--quant-bits 8` - Use 8-bit quantization (higher quality)
- `--context-length 2048` - Set maximum context length
- `--num-chunks 4` - Set number of model chunks 
- `--verbose` - Show detailed conversion logs with progress tracking

### Using the Enhanced Python Converter Directly

For detailed progress tracking and architecture-specific optimizations:

```bash
python scripts/convert_hf_to_coreml.py \
    --model_path meta-llama/Llama-3.2-1B \
    --output_path ./converted_model \
    --max_seq_len 1024 \
    --batch_size 64 \
    --quantize_weights 6 \
    --verbose
```

This enhanced converter provides:
- Real-time progress percentage updates
- ETA (estimated time remaining)
- Architecture-specific optimizations
- Auto-detection of optimal chunk count

### Optimizing Existing CoreML Models

```bash
swift run ANEModelConverter optimize --input-model /path/to/model.mlpackage --output-model /path/to/output
```

### Splitting a Model into Chunks

```bash
swift run ANEModelConverter split --input-model /path/to/model.mlpackage --output-dir /path/to/output --num-chunks 6
```

### Installing Required Python Dependencies

```bash
cd scripts
pip install -r requirements.txt
```

## Library Usage (ANEKit)

### Adding to Your Project

In Package.swift:
```swift
dependencies: [
    .package(url: "https://github.com/antmikinka/AppleNeuralEngine-Kit", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "ANEKit", package: "AppleNeuralEngine-Kit")
        ]
    )
]
```

### Basic Usage

```swift
import ANEKit
import Tokenizers

// Load the model
let pipeline = try ModelPipeline.from(
    folder: modelDirectory,
    modelPrefix: "Llama-3.2-1B",
    cacheProcessorModelName: "cache-processor.mlmodelc",
    logitProcessorModelName: "logit-processor.mlmodelc"
)

// Load tokenizer
let tokenizer = try await AutoTokenizer.from(pretrained: "meta-llama/Llama-3.2-1B")

// Create text generator
let generator = TextGenerator(pipeline: pipeline, tokenizer: tokenizer)

// Generate text
try await generator.generate(text: "Neural networks are", maxNewTokens: 50)
```

### Streaming Generation

```swift
try await generator.generateWithCallback(
    text: "Neural networks are",
    maxNewTokens: 100,
    onToken: { token, fullText, prediction in
        print("Generated: \(token)")
        print("Full text: \(fullText)")
        
        // Access timing information
        if let latency = prediction.latency?.converted(to: .milliseconds).value {
            print("Token generation latency: \(latency) ms")
        }
    }
)
```

### Custom Configuration

```swift
// Configure the model pipeline
let pipeline = try ModelPipeline.from(
    folder: modelDirectory,
    modelPrefix: "Llama-3.2-1B",
    cacheProcessorModelName: "cache-processor.mlmodelc",
    logitProcessorModelName: "logit-processor.mlmodelc",
    primaryCompute: .cpuAndNeuralEngine,
    chunkLimit: nil // Set a value to limit the number of chunks for testing
)
```