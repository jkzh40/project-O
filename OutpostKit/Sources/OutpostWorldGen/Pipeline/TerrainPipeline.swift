// MARK: - Terrain Pipeline
// Composable orchestrator that runs an ordered list of TerrainStage instances

import OutpostCore

/// A composite stage that groups multiple sub-stages into a single logical step.
struct CompositeTerrainStage: TerrainStage {
    let forkLabel: String
    private let message: String
    let stages: [any TerrainStage]

    init(forkLabel: String, message: String, stages: [any TerrainStage]) {
        self.forkLabel = forkLabel
        self.message = message
        self.stages = stages
    }

    func progressMessage(context: WorldGenContext) -> String { message }

    func run(map: inout WorldMap, rng: inout SeededRNG, context: WorldGenContext) {
        for stage in stages {
            var stageRNG = rng.fork(stage.forkLabel)
            stage.run(map: &map, rng: &stageRNG, context: context)
        }
    }
}

/// An ordered sequence of terrain stages executed with deterministic RNG forking.
struct TerrainPipeline: Sendable {
    let stages: [any TerrainStage]

    /// Builds the default 8-stage pipeline, selecting GPU stages when available.
    static func defaultPipeline() -> TerrainPipeline {
        var stages: [any TerrainStage] = []

        stages.append(TectonicSimulator())

        #if canImport(Metal)
        if let accel = MetalTerrainAccelerator() {
            stages.append(MetalHeightmapStage(accelerator: accel))
        } else {
            stages.append(HeightmapGenerator())
        }
        #else
        stages.append(HeightmapGenerator())
        #endif

        stages.append(ErosionSimulator())
        stages.append(GeologyGenerator())

        #if canImport(Metal)
        if let accel = MetalTerrainAccelerator() {
            stages.append(MetalClimateStage(accelerator: accel))
        } else {
            stages.append(ClimateSimulator())
        }
        #else
        stages.append(ClimateSimulator())
        #endif

        stages.append(HydrologySimulator())
        stages.append(BiomeClassifier())
        stages.append(DetailPass())

        return TerrainPipeline(stages: stages)
    }

    /// Builds the CPU-only pipeline (no Metal acceleration).
    static func cpuPipeline() -> TerrainPipeline {
        TerrainPipeline(stages: [
            TectonicSimulator(),
            HeightmapGenerator(),
            ErosionSimulator(),
            GeologyGenerator(),
            ClimateSimulator(),
            HydrologySimulator(),
            BiomeClassifier(),
            DetailPass(),
        ])
    }

    /// Execute all stages in order, forking the RNG for each stage.
    /// - Parameters:
    ///   - context: Shared generation context (params + noise)
    ///   - rng: Root RNG — each stage receives an independent fork
    ///   - progress: Optional callback invoked before each stage
    /// - Returns: The generated world map
    func run(
        context: WorldGenContext,
        rng: SeededRNG,
        progress: ((String) -> Void)? = nil
    ) -> WorldMap {
        var map = WorldMap(size: context.params.mapSize, seed: context.params.seed)
        run(into: &map, context: context, rng: rng, progress: progress)
        return map
    }

    /// Execute all stages into an existing map.
    func run(
        into map: inout WorldMap,
        context: WorldGenContext,
        rng: SeededRNG,
        progress: ((String) -> Void)? = nil
    ) {
        for stage in stages {
            progress?(stage.progressMessage(context: context))
            var stageRNG = rng.fork(stage.forkLabel)
            stage.run(map: &map, rng: &stageRNG, context: context)
        }
        progress?("World map generation complete.")
    }
}
