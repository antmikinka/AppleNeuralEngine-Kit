# AppleNeuralEngine-Kit

A Swift toolkit for running LLMs on Apple Neural Engine (ANE) using CoreML, with both command-line and SwiftUI interfaces.

## Features

- Fast inference of CoreML-compatible LLMs (Llama 2, Llama 3, etc.) using Apple Neural Engine
- Both CLI and SwiftUI interfaces for model interaction
- Optimized memory usage with IOSurface-backed CVPixelBuffers
- Tensor reshaping for faster matrix operations
- Model chunking for efficient loading and memory management
- Asynchronous KV cache updates for improved performance
- Real-time text streaming in the UI

## Requirements

- macOS 14 (Sonoma) or newer
- Swift 5.9 or newer

## Components

### CLI Tool

Download and run CoreML-compatible LLMs from the command line:

```shell
$ swift run LLMCLI --repo-id smpanaro/Llama-2-7b-coreml
```

### SwiftUI App

Interact with CoreML LLMs using a chat interface:

```shell
$ swift run LLMChatUI
```

### LLMKit Library

Core functionality available as a Swift library for integration in other projects.

## Installation

1. Clone this repository
2. Run `swift build` to build the project
3. Use the CLI with `swift run LLMCLI` or the UI with `swift run LLMChatUI`

## Performance

| Variant | 1st Load Time | 2nd+ Load Time | Tokens/Sec   | ANE Power |
|---------|---------------|----------------|--------------|-----------|
| M1 Max  | 113s          | 8.1s           | 7.02 ± 0.11  | 4.2W      |
| M3 Max  | -             | 0.8s           | 13.92 ± 0.5  | 8W        |

## Credits

This project is based on [CoreML LLM CLI](https://github.com/smpanaro/coreml-llm-cli) by Stephen Panaro, extended with a UI interface and library structure.

## License

[MIT License](LICENSE)