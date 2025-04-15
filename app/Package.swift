// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Sorta",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "Sorta", targets: ["Sorta"]),
    ],
    dependencies: [
        .package(url: "https://github.com/eastriverlee/LLM.swift", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "Sorta",
            dependencies: [
                .product(name: "LLM", package: "LLM.swift"),
            ]
        ),
    ]
)