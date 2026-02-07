// MARK: - Geology Generator
// Facade: generates geological strata columns for all world map cells

import OutpostCore

/// Generates geological columns for the world map using tectonic context
struct GeologyGenerator: Sendable {

    /// Generate geological strata for all applicable cells
    /// - Parameters:
    ///   - map: The world map (modified in place)
    ///   - noise: Noise generator for thickness perturbation
    ///   - rng: Seeded RNG
    static func generate(map: inout WorldMap, noise: SimplexNoise, rng: inout SeededRNG) {
        let size = map.size
        let plates = map.plates

        for y in 0..<size {
            for x in 0..<size {
                // Skip deep ocean cells (no meaningful underground)
                guard map[x, y].elevation >= 0.25 else { continue }

                let context = StrataGenerator.classifyContext(
                    cell: map[x, y],
                    plates: plates
                )

                var cellRNG = rng.fork("geo_\(x)_\(y)")
                let column = StrataGenerator.generateColumn(
                    context: context,
                    cell: map[x, y],
                    noise: noise,
                    x: x,
                    y: y,
                    rng: &cellRNG
                )

                map[x, y].geologicalColumn = column
            }
        }
    }
}

// MARK: - TerrainStage Conformance

extension GeologyGenerator: TerrainStage {
    var forkLabel: String { "geology" }

    func progressMessage(context: WorldGenContext) -> String {
        "Generating geological strata..."
    }

    func run(map: inout WorldMap, rng: inout SeededRNG, context: WorldGenContext) {
        Self.generate(map: &map, noise: context.noise, rng: &rng)
    }
}
