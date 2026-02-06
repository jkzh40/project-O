// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OutpostSim",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: "../OutpostKit"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "OutpostSim",
            dependencies: [
                .product(name: "OutpostCore", package: "OutpostKit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
