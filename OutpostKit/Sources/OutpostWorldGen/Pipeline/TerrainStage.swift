// MARK: - Terrain Stage Protocol
// Composable pipeline stage for terrain generation

import OutpostCore

/// Immutable context shared across all terrain stages
struct WorldGenContext: Sendable {
    let params: WorldGenParameters
    let noise: SimplexNoise
}

/// A single composable step in the terrain generation pipeline.
///
/// Each stage receives a forked RNG (independent from the root), so reordering
/// stages does not break determinism. The `forkLabel` is hashed via FNV-1a in
/// `SeededRNG.fork(_:)` to produce the child seed.
protocol TerrainStage: Sendable {
    /// Stable identifier used to fork a deterministic child RNG.
    /// Must never change between versions for a given stage.
    var forkLabel: String { get }

    /// Human-readable progress message for this stage.
    func progressMessage(context: WorldGenContext) -> String

    /// Execute the stage, mutating the world map in place.
    /// - Parameters:
    ///   - map: The world map to modify
    ///   - rng: A forked RNG specific to this stage
    ///   - context: Shared generation parameters and noise
    func run(map: inout WorldMap, rng: inout SeededRNG, context: WorldGenContext)
}
