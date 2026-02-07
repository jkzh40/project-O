// MARK: - Biome Classifier
// Stage 6: Extended Whittaker diagram mapping temperature + moisture to biome

import Foundation
import OutpostCore

/// Classifies biomes based on temperature, moisture, elevation, and hydrology
struct BiomeClassifier: Sendable {

    /// Classify biomes for all cells in the world map
    static func classify(map: inout WorldMap) {
        let size = map.size
        let seaLevel: Float = 0.3

        for y in 0..<size {
            for x in 0..<size {
                map[x, y].biome = classifyCell(map[x, y], seaLevel: seaLevel)
            }
        }
    }

    /// Classify a single cell
    private static func classifyCell(_ cell: WorldMapCell, seaLevel: Float) -> BiomeType {
        let elev = cell.elevation
        let temp = cell.temperature
        let moisture = cell.moisture

        // Water bodies first
        if cell.isLake {
            return temp < 0.15 ? .frozenLake : .lake
        }

        if cell.isRiver {
            return .river
        }

        // Ocean
        if elev < seaLevel - 0.1 {
            if temp < 0.1 {
                return .frozenOcean
            }
            return elev < seaLevel - 0.2 ? .deepOcean : .ocean
        }

        // Coastal / shallow water
        if elev < seaLevel {
            return temp < 0.1 ? .frozenOcean : .coastalWaters
        }

        // Beach zone (just above sea level)
        if elev < seaLevel + 0.03 {
            if cell.isRiver || moisture > 0.8 {
                return .riverBank
            }
            return .beach
        }

        // High elevation: mountains
        if elev > 0.8 {
            if temp < 0.1 {
                return .snowPeak
            }
            if temp < 0.25 {
                return .mountain
            }
            return .alpineMeadow
        }

        // Moderate-high elevation
        if elev > 0.65 {
            if temp < 0.15 {
                return .snowPeak
            }
            if temp < 0.3 {
                return .mountain
            }
            if moisture > 0.6 {
                return .alpineMeadow
            }
            return .mountain
        }

        // Extended Whittaker classification for remaining land
        return whittakerClassify(temperature: temp, moisture: moisture)
    }

    // MARK: - Whittaker Diagram

    /// Temperature-moisture classification based on extended Whittaker diagram
    private static func whittakerClassify(temperature: Float, moisture: Float) -> BiomeType {
        // Very cold (temp < 0.15)
        if temperature < 0.15 {
            if moisture < 0.2 {
                return .coldDesert
            }
            if moisture < 0.5 {
                return .tundra
            }
            return .iceCap
        }

        // Cold (0.15-0.3)
        if temperature < 0.3 {
            if moisture < 0.25 {
                return .coldDesert
            }
            if moisture < 0.5 {
                return .tundra
            }
            if moisture < 0.7 {
                return .borealForest
            }
            return .borealForest
        }

        // Cool temperate (0.3-0.45)
        if temperature < 0.45 {
            if moisture < 0.2 {
                return .scrubland
            }
            if moisture < 0.4 {
                return .temperateGrassland
            }
            if moisture < 0.65 {
                return .temperateForest
            }
            return .temperateRainforest
        }

        // Warm temperate (0.45-0.6)
        if temperature < 0.6 {
            if moisture < 0.15 {
                return .desert
            }
            if moisture < 0.35 {
                return .scrubland
            }
            if moisture < 0.5 {
                return .temperateGrassland
            }
            if moisture < 0.7 {
                return .temperateForest
            }
            if moisture > 0.85 {
                return .swamp
            }
            return .temperateRainforest
        }

        // Warm (0.6-0.8)
        if temperature < 0.8 {
            if moisture < 0.15 {
                return .hotDesert
            }
            if moisture < 0.3 {
                return .desert
            }
            if moisture < 0.5 {
                return .savanna
            }
            if moisture < 0.7 {
                return .tropicalForest
            }
            if moisture > 0.9 {
                return .mangrove
            }
            return .tropicalRainforest
        }

        // Hot (>0.8)
        if moisture < 0.1 {
            return .hotDesert
        }
        if moisture < 0.25 {
            return .desert
        }
        if moisture < 0.45 {
            return .savanna
        }
        if moisture < 0.65 {
            return .tropicalForest
        }
        if moisture > 0.85 {
            return .mangrove
        }
        return .tropicalRainforest
    }
}
