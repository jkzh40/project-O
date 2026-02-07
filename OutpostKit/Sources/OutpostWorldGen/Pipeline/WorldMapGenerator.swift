// MARK: - World Map Generator
// Orchestrator: runs all 7 stages of the terrain generation pipeline

import Foundation
import OutpostCore

/// Progress callback for world map generation
typealias WorldMapProgressCallback = (String) -> Void

/// Orchestrates the 7-stage world map generation pipeline
struct WorldMapGenerator: Sendable {

    /// Generate a complete world map from parameters
    /// - Parameters:
    ///   - params: World generation parameters
    ///   - pipeline: Optional custom pipeline (defaults to `TerrainPipeline.defaultPipeline()`)
    ///   - progress: Optional progress callback
    /// - Returns: Complete world map with all data
    static func generate(
        params: WorldGenParameters,
        pipeline: TerrainPipeline? = nil,
        progress: WorldMapProgressCallback? = nil
    ) -> WorldMap {
        let rng = params.seed.makeRNG()
        let context = WorldGenContext(
            params: params,
            noise: SimplexNoise(seed: params.seed.value)
        )
        let activePipeline = pipeline ?? .defaultPipeline()
        return activePipeline.run(context: context, rng: rng, progress: progress)
    }

    /// Find a good embark location: temperate, near water, not too mountainous
    /// - Parameters:
    ///   - map: Generated world map
    ///   - size: Embark region size
    ///   - rng: Seeded RNG
    /// - Returns: Embark region
    static func findEmbarkSite(
        map: WorldMap,
        size embarkSize: Int,
        rng: inout SeededRNG
    ) -> EmbarkRegion {
        let mapSize = map.size
        let searchMargin = embarkSize + 10

        var bestScore: Float = -Float.infinity
        var bestX = mapSize / 2
        var bestY = mapSize / 2

        // Sample random positions and score them
        let attempts = 100
        for _ in 0..<attempts {
            let x = rng.nextInt(in: searchMargin...(mapSize - searchMargin))
            let y = rng.nextInt(in: searchMargin...(mapSize - searchMargin))

            let score = scoreEmbarkSite(map: map, centerX: x, centerY: y, size: embarkSize)
            if score > bestScore {
                bestScore = score
                bestX = x
                bestY = y
            }
        }

        return EmbarkRegion.centered(x: bestX, y: bestY, size: embarkSize, mapSize: mapSize)
    }

    /// Score a potential embark site
    private static func scoreEmbarkSite(map: WorldMap, centerX: Int, centerY: Int, size: Int) -> Float {
        let half = size / 2
        var score: Float = 0
        var cellCount: Float = 0

        for dy in -half...half {
            for dx in -half...half {
                let x = centerX + dx
                let y = centerY + dy
                guard map.isValid(x: x, y: y) else { continue }

                let cell = map[x, y]
                cellCount += 1

                // Prefer temperate biomes
                switch cell.biome {
                case .temperateGrassland: score += 3
                case .temperateForest: score += 4
                case .temperateRainforest: score += 2
                case .savanna: score += 2
                case .borealForest: score += 1
                default: break
                }

                // Prefer moderate elevation
                if cell.elevation > 0.3 && cell.elevation < 0.6 {
                    score += 2
                }

                // Bonus for nearby water
                if cell.isRiver { score += 3 }
                if cell.isLake { score += 2 }
                if cell.moisture > 0.4 { score += 1 }

                // Penalty for ocean
                if cell.elevation < 0.3 { score -= 5 }

                // Penalty for extreme elevation
                if cell.elevation > 0.75 { score -= 3 }

                // Bonus for ore nearby
                if cell.oreType != nil { score += 1 }

                // Bonus for vegetation (resources)
                score += cell.vegetationDensity
            }
        }

        return cellCount > 0 ? score / cellCount : -Float.infinity
    }
}
