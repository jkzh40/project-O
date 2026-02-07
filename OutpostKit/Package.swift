// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OutpostKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "OutpostCore",
            targets: ["OutpostCore"]
        ),
        .library(
            name: "OutpostWorldGen",
            targets: ["OutpostWorldGen"]
        ),
        .library(
            name: "OutpostRuntime",
            targets: ["OutpostRuntime"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "OutpostCore",
            dependencies: ["Yams"],
            resources: [
                .copy("Resources/outpost.yaml"),
                .copy("Resources/creatures.yaml"),
                .copy("Resources/items.yaml")
            ]
        ),
        .target(
            name: "OutpostWorldGen",
            dependencies: ["OutpostCore"]
        ),
        .target(
            name: "OutpostRuntime",
            dependencies: ["OutpostCore", "OutpostWorldGen"]
        ),
        .testTarget(
            name: "OutpostCoreTests",
            dependencies: ["OutpostRuntime"]
        ),
    ]
)
