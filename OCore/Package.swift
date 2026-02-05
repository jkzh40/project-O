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
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OCore",
            targets: ["OCore"]
        ),
        .executable(
            name: "DwarfSim",
            targets: ["DwarfSim"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OCore",
            dependencies: ["Yams"],
            resources: [
                .copy("Resources/dwarfsim.yaml"),
                .copy("Resources/creatures.yaml"),
                .copy("Resources/items.yaml")
            ]
        ),
        .executableTarget(
            name: "DwarfSim",
            dependencies: ["OCore"]
        ),
        .testTarget(
            name: "OCoreTests",
            dependencies: ["OCore"]
        ),
    ]
)
