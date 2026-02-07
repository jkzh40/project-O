// MARK: - Detail Pass
// Stage 7: Vegetation density, ore placement, soil depth

import Foundation
import OutpostCore

/// Adds final detail: vegetation, ore deposits, soil depth based on biome and geology
struct DetailPass: Sendable {

    /// Run detail pass over the world map
    /// - Parameters:
    ///   - map: World map with biome classification
    ///   - noise: Noise generator for variation
    ///   - rng: Seeded RNG
    static func apply(map: inout WorldMap, noise: SimplexNoise, rng: inout SeededRNG) {
        let size = map.size
        let invSize = 1.0 / Double(size)

        for y in 0..<size {
            for x in 0..<size {
                let nx = Double(x) * invSize
                let ny = Double(y) * invSize

                // Vegetation density
                map[x, y].vegetationDensity = computeVegetation(
                    biome: map[x, y].biome,
                    moisture: map[x, y].moisture,
                    noiseVal: Float(noise.noise2D(x: nx * 8.0, y: ny * 8.0))
                )

                // Soil depth
                map[x, y].soilDepth = computeSoilDepth(
                    biome: map[x, y].biome,
                    elevation: map[x, y].elevation,
                    sediment: map[x, y].sediment,
                    noiseVal: Float(noise.noise2D(x: nx * 6.0 + 300, y: ny * 6.0 + 300))
                )

                // Ore deposits
                placeOre(
                    cell: &map[x, y],
                    x: x, y: y,
                    noise: noise,
                    invSize: invSize,
                    rng: &rng
                )
            }
        }
    }

    // MARK: - Vegetation

    private static func computeVegetation(biome: BiomeType, moisture: Float, noiseVal: Float) -> Float {
        let baseVegetation: Float
        switch biome {
        case .tropicalRainforest, .temperateRainforest:
            baseVegetation = 0.9
        case .tropicalForest, .temperateForest, .borealForest:
            baseVegetation = 0.7
        case .mangrove, .swamp:
            baseVegetation = 0.65
        case .savanna, .temperateGrassland:
            baseVegetation = 0.4
        case .marsh:
            baseVegetation = 0.5
        case .scrubland:
            baseVegetation = 0.25
        case .tundra, .alpineMeadow:
            baseVegetation = 0.15
        case .desert, .hotDesert, .coldDesert:
            baseVegetation = 0.05
        case .beach, .riverBank:
            baseVegetation = 0.2
        case .mountain:
            baseVegetation = 0.1
        default:
            baseVegetation = 0.0
        }

        let variation = noiseVal * 0.2
        return max(0, min(1, baseVegetation + variation + moisture * 0.1))
    }

    // MARK: - Soil Depth

    private static func computeSoilDepth(
        biome: BiomeType,
        elevation: Float,
        sediment: Float,
        noiseVal: Float
    ) -> Float {
        var depth: Float

        switch biome {
        case .temperateGrassland, .savanna:
            depth = 0.7
        case .temperateForest, .tropicalForest, .borealForest:
            depth = 0.6
        case .tropicalRainforest, .temperateRainforest:
            depth = 0.8
        case .swamp, .marsh, .mangrove:
            depth = 0.5
        case .desert, .hotDesert, .coldDesert:
            depth = 0.1
        case .tundra:
            depth = 0.2
        case .mountain, .snowPeak, .alpineMeadow:
            depth = 0.1
        case .beach:
            depth = 0.3
        default:
            depth = 0.3
        }

        // Sediment increases soil depth
        depth += sediment * 0.3

        // Elevation reduces soil (erosion on steep slopes)
        if elevation > 0.6 {
            depth *= max(0.2, 1.0 - (elevation - 0.6) * 2.0)
        }

        // Noise variation
        depth += noiseVal * 0.15

        return max(0, min(1, depth))
    }

    // MARK: - Ore Placement

    private static func placeOre(
        cell: inout WorldMapCell,
        x: Int, y: Int,
        noise: SimplexNoise,
        invSize: Double,
        rng: inout SeededRNG
    ) {
        let nx = Double(x) * invSize
        let ny = Double(y) * invSize

        // Only place ore in appropriate terrain (not ocean, not surface)
        guard cell.elevation > 0.35 else { return }

        // Use noise to create ore veins
        let oreNoise = noise.noise2D(x: nx * 12.0 + 500, y: ny * 12.0 + 500)

        // Only place in noise peaks (sparse placement)
        guard oreNoise > 0.5 else { return }

        let richness = Float((oreNoise - 0.5) * 2.0) // 0-1 range from threshold

        // If geological column exists, pick ore from mid-depth rock compatibility
        if let column = cell.geologicalColumn {
            let midRock = column.rockType(atZLevel: 1, totalDepth: 3)
            let compatible = midRock.compatibleOres
            guard !compatible.isEmpty else { return }

            let oreType = compatible[rng.nextInt(in: 0...(compatible.count - 1))]
            cell.oreType = oreType
            cell.oreRichness = richness

            // If ore is gemstone, pick a specific gemstone type from rock compatibility
            if oreType == .gemstone {
                let gems = midRock.compatibleGemstones
                if !gems.isEmpty {
                    cell.gemstoneType = gems[rng.nextInt(in: 0...(gems.count - 1))]
                }
            }
            return
        }

        // Legacy fallback: ore type depends on elevation and boundary type
        let oreType: OreType
        if cell.elevation > 0.7 {
            if rng.nextBool(probability: 0.3) {
                oreType = .gold
            } else if rng.nextBool(probability: 0.4) {
                oreType = .silver
            } else {
                oreType = .gemstone
            }
        } else if cell.boundaryStress > 0.3 {
            if rng.nextBool(probability: 0.5) {
                oreType = .iron
            } else {
                oreType = .copper
            }
        } else if cell.elevation > 0.5 {
            if rng.nextBool(probability: 0.4) {
                oreType = .iron
            } else if rng.nextBool(probability: 0.3) {
                oreType = .tin
            } else {
                oreType = .coal
            }
        } else {
            if rng.nextBool(probability: 0.5) {
                oreType = .coal
            } else {
                oreType = .tin
            }
        }

        cell.oreType = oreType
        cell.oreRichness = richness
    }
}

// MARK: - TerrainStage Conformance

extension DetailPass: TerrainStage {
    var forkLabel: String { "detail" }

    func progressMessage(context: WorldGenContext) -> String {
        "Adding vegetation and ore deposits..."
    }

    func run(map: inout WorldMap, rng: inout SeededRNG, context: WorldGenContext) {
        Self.apply(map: &map, noise: context.noise, rng: &rng)
    }
}
