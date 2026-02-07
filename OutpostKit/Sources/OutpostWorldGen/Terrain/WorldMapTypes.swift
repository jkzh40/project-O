// MARK: - World Map Types
// Generation-only types that remain in OutpostWorldGen

import Foundation
import OutpostCore

// MARK: - WorldSeed RNG Extension

extension WorldSeed {
    /// Creates an RNG from this seed (internal to OutpostWorldGen)
    func makeRNG() -> SeededRNG {
        SeededRNG(seed: value)
    }
}

// MARK: - World Gen Parameters

/// Configuration for world generation
public struct WorldGenParameters: Sendable {
    public let seed: WorldSeed
    public let mapSize: Int              // World map dimensions (square)
    public let plateCount: Int           // Number of tectonic plates
    public let erosionDroplets: Int      // Number of erosion droplets
    public let embarkSize: Int           // Size of embark region to extract

    public init(
        seed: WorldSeed = WorldSeed(),
        mapSize: Int = 257,
        plateCount: Int = 12,
        erosionDroplets: Int = 500_000,
        embarkSize: Int = 50
    ) {
        self.seed = seed
        self.mapSize = mapSize
        self.plateCount = plateCount
        self.erosionDroplets = erosionDroplets
        self.embarkSize = embarkSize
    }
}
