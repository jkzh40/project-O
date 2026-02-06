// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "OCore",
            targets: ["OCore"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "OCore",
            dependencies: ["Yams"],
            resources: [
                .copy("Resources/outpost.yaml"),
                .copy("Resources/creatures.yaml"),
                .copy("Resources/items.yaml")
            ]
        ),
        .testTarget(
            name: "OCoreTests",
            dependencies: ["OCore"]
        ),
    ]
)
