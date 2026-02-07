// MARK: - Metal GPU Terrain Stages
// TerrainStage wrappers for GPU-accelerated heightmap and climate generation

#if canImport(Metal)

import OutpostCore

/// GPU-accelerated heightmap generation stage.
/// Uses `MetalTerrainAccelerator.generateHeightmap()` for the heavy lifting.
/// Shares the same `forkLabel` as `HeightmapGenerator` for deterministic RNG parity.
struct MetalHeightmapStage: TerrainStage {
    let accelerator: MetalTerrainAccelerator
    var forkLabel: String { "heightmap" }

    func progressMessage(context: WorldGenContext) -> String {
        "Generating heightmap (GPU)..."
    }

    func run(map: inout WorldMap, rng: inout SeededRNG, context: WorldGenContext) {
        accelerator.generateHeightmap(map: &map, noise: context.noise)
    }
}

/// GPU-accelerated climate stage.
/// Runs temperature and wind on the GPU, then moisture advection on the CPU.
/// Shares the same `forkLabel` as `ClimateSimulator` for deterministic RNG parity.
struct MetalClimateStage: TerrainStage {
    let accelerator: MetalTerrainAccelerator
    var forkLabel: String { "climate" }

    func progressMessage(context: WorldGenContext) -> String {
        "Simulating climate (GPU)..."
    }

    func run(map: inout WorldMap, rng: inout SeededRNG, context: WorldGenContext) {
        accelerator.generateTemperatureAndWind(map: &map, noise: context.noise)
        ClimateSimulator.applyMoistureAdvection(map: &map, noise: context.noise, rng: &rng)
    }
}

#endif
