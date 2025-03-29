# Contributing to AppleNeuralEngine-Kit

Thank you for your interest in contributing to AppleNeuralEngine-Kit! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project. We aim to foster an inclusive and welcoming community.

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check if the issue already exists in the [GitHub Issues](https://github.com/YOUR_USERNAME/AppleNeuralEngine-Kit/issues)
2. If not, create a new issue with a descriptive title and detailed information:
   - For bugs: steps to reproduce, expected behavior, actual behavior, and environment details
   - For features: clear description of the proposed functionality and its benefits

### Pull Requests

1. Fork the repository
2. Create a new branch for your feature or bug fix
3. Make your changes, following the coding style guidelines
4. Add tests for your changes
5. Update documentation as needed
6. Submit a pull request with a clear description of the changes

## Development Setup

1. Clone the repository
   ```bash
   git clone https://github.com/YOUR_USERNAME/AppleNeuralEngine-Kit.git
   cd AppleNeuralEngine-Kit
   ```

2. Build the project
   ```bash
   swift build
   ```

3. Run tests
   ```bash
   swift test
   ```

## Project Structure

- `Sources/`: Swift source code
  - `ANEKit/`: Core library code
  - `ANEChat/`: SwiftUI app interface
  - `CommandLine/`: CLI tools
  - `ModelConverter/`: Model conversion tools
- `scripts/`: Python scripts for model conversion
- `docs/`: Documentation

## Coding Guidelines

### Swift

- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use descriptive variable and function names
- Add comments for complex logic
- Include documentation comments for public API

### Python

- Follow [PEP 8](https://www.python.org/dev/peps/pep-0008/) guidelines
- Use type hints for function parameters and return values
- Add docstrings for all functions and classes

## Documentation

Please update documentation when adding or modifying features:

- Update README.md for major changes
- Update or create documentation files in the `/docs` directory
- Include code examples where appropriate

## Testing

- Add tests for new features
- Ensure all tests pass before submitting a pull request
- For model conversion, test with at least one small model

## License

By contributing, you agree that your contributions will be licensed under the project's [MIT License](../LICENSE).

## Questions?

If you have questions about contributing, feel free to open an issue for discussion.