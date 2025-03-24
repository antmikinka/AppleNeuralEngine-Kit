// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LLMCLI",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "LLMCLI", targets: ["LLMCLI"]),
        .library(name: "LLMKit", targets: ["LLMKit"]),
        .executable(name: "LLMChatUI", targets: ["LLMChatUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/huggingface/swift-transformers", from: "0.1.13"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // CLI Target
        .executableTarget(
            name: "LLMCLI",
            dependencies: [
                "LLMKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Sources",
            exclude: ["Kit", "LLMChatUI"]
        ),
        
        // Library Target for shared code
        .target(
            name: "LLMKit",
            dependencies: [
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Sources/Kit"
        ),
        
        // UI Application Target
        .executableTarget(
            name: "LLMChatUI",
            dependencies: [
                "LLMKit",
                .product(name: "Transformers", package: "swift-transformers"),
            ],
            path: "Sources/LLMChatUI"
        ),
    ]
)