// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppleNeuralEngine-Kit",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ANEToolCLI", targets: ["ANEToolCLI"]),
        .library(name: "ANEKit", targets: ["ANEKit"]),
        .executable(name: "ANEChat", targets: ["ANEChat"]),
        .executable(name: "ANEModelConverter", targets: ["ANEModelConverter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.13"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // CLI Target
        .executableTarget(
            name: "ANEToolCLI",
            dependencies: [
                "ANEKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Sources/CommandLine"
        ),
        
        // Library Target for shared code
        .target(
            name: "ANEKit",
            dependencies: [
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Sources/Kit"
        ),
        
        // UI Application Target
        .executableTarget(
            name: "ANEChat",
            dependencies: [
                "ANEKit",
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Sources/ANEChat"
        ),
        
        // Model Converter Target
        .executableTarget(
            name: "ANEModelConverter",
            dependencies: [
                "ANEKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/ModelConverter"
        ),
    ]
)