# Development Guide

This guide provides information for developers who want to contribute to or modify AppleNeuralEngine-Kit.

## Setting Up Development Environment

### Prerequisites

- Xcode 15.0 or newer
- macOS 14 (Sonoma) or newer
- Swift 5.9 or newer
- Python 3.8+ (for model conversion scripts)

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/antmikinka/AppleNeuralEngine-Kit.git
   cd AppleNeuralEngine-Kit
   ```

2. Open the project in Xcode:
   ```bash
   ./generate_xcodeproj.sh
   ```
   Or simply:
   ```bash
   open Package.swift
   ```

3. Install Python dependencies for model conversion:
   ```bash
   pip install -r scripts/requirements.txt
   ```

## Project Structure

```
AppleNeuralEngine-Kit/
├── Sources/
│   ├── Kit/                   # ANEKit core library
│   ├── ANEChat/               # SwiftUI app
│   ├── CommandLine/           # CLI tool
│   └── ModelConverter/        # Model converter
├── scripts/                   # Python conversion scripts
├── docs/                      # Documentation
├── Llama-3.2-1B-Instruct/     # Example model
└── Assets.xcassets/           # App assets
```

## Building and Running

### Building All Components

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Running Specific Components

```bash
# Run the SwiftUI app
swift run ANEChat

# Run the CLI
swift run ANEToolCLI --help

# Run the model converter
swift run ANEModelConverter --help
```

## Development Workflow

### Feature Development

1. Create a new branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes, following the style guidelines

3. Write tests for your changes

4. Run the tests to ensure they pass:
   ```bash
   swift test
   ```

5. Submit a pull request

### Code Style Guidelines

- Follow Swift API Design Guidelines
- Use SwiftLint for linting (configuration included in the repo)
- Document all public APIs with documentation comments
- Use proper error handling with structured errors

### Pull Request Process

1. Ensure all tests pass
2. Update documentation if necessary
3. Request review from at least one maintainer
4. Address any review comments
5. Once approved, your changes will be merged

## Working with CoreML Models

### Model Format

The project works with CoreML models split into chunks for efficient loading and execution on Apple Neural Engine. Each model consists of:

- Multiple `{model_name}_chunk{N}.mlmodelc` files
- `cache-processor.mlmodelc` for KV cache management
- `logit-processor.mlmodelc` for token selection
- Tokenizer files

### Creating New Models

To add support for a new model architecture:

1. Modify the model converter scripts in `scripts/`
2. Ensure the new model's forward pass is compatible with the existing `ModelPipeline`
3. Update the tokenizer handling if necessary
4. Add tests for the new model type

### Debugging Models

- Use `MLModel.load(contentsOf:configuration:)` with a configuration that sets `computeUnits` to `.cpuOnly` for easier debugging
- Add the `.cpuOnly` option to `ModelPipeline.from()` for debugging
- Use Instruments with the "Metal System Trace" template to analyze ANE usage

## Performance Optimization

- Use IOSurface-backed memory for efficient data transfer between CPU, GPU, and ANE
- Batch operations where possible
- Profile with Instruments to identify bottlenecks
- Use the built-in performance metrics to track improvements

## Troubleshooting Common Issues

### Model Loading Failures

- Check that model chunks are correctly named
- Verify that processor models exist in the model directory
- Ensure all model files are properly compiled (.mlmodelc format)

### Compilation Errors

- Make sure you're using the correct Swift version
- Check that all dependencies are up to date
- Verify that the Swift Transformers package is compatible

### Python Script Issues

- Ensure you have the correct Python version (3.8+)
- Check that all dependencies in requirements.txt are installed
- Verify permissions for script execution

## Publishing Updates

1. Update version numbers in:
   - Package.swift
   - README.md
   - Info.plist

2. Create a new release tag:
   ```bash
   git tag v1.0.x
   git push origin v1.0.x
   ```

3. Create a release on GitHub with release notes