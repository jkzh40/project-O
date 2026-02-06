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
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "OutpostWorldGen"
        ),
        .target(
            name: "OutpostCore",
            dependencies: ["OutpostWorldGen", "Yams"],
            resources: [
                .copy("Resources/outpost.yaml"),
                .copy("Resources/creatures.yaml"),
                .copy("Resources/items.yaml")
            ]
        ),
        .testTarget(
            name: "OutpostCoreTests",
            dependencies: ["OutpostCore"]
        ),
    ]
)
