// MARK: - Biome

import Foundation

/// Biome classification based on temperature and moisture (extended Whittaker diagram)
public enum BiomeType: String, CaseIterable, Sendable {
    // Aquatic
    case ocean
    case deepOcean
    case coastalWaters
    case frozenOcean
    case lake
    case frozenLake
    case river

    // Cold
    case tundra
    case iceCap
    case alpineMeadow
    case borealForest       // Taiga

    // Temperate
    case temperateGrassland
    case temperateForest
    case temperateRainforest
    case swamp
    case marsh

    // Warm
    case savanna
    case tropicalForest
    case tropicalRainforest
    case mangrove

    // Dry
    case desert
    case hotDesert
    case coldDesert
    case scrubland

    // Elevation-based
    case mountain
    case snowPeak
    case volcanicWaste

    // Transitional
    case beach
    case riverBank
}
