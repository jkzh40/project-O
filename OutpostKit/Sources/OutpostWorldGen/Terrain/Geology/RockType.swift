// MARK: - Rock Type
// Geological rock classification for subsurface strata

/// Geological rock types used in underground strata generation
enum RockType: String, CaseIterable, Sendable {
    // Sedimentary
    case sandstone
    case limestone
    case shale
    case conglomerate

    // Igneous extrusive
    case basalt
    case andesite

    // Igneous intrusive
    case granite
    case diorite
    case gabbro

    // Metamorphic
    case slate
    case schist
    case marble
    case quartzite
    case gneiss

    // Volcanic glass
    case obsidian

    /// Maps to the corresponding TerrainType for tile rendering
    var terrainType: TerrainType {
        switch self {
        case .sandstone: return .sandstone
        case .limestone: return .limestone
        case .shale: return .shale
        case .conglomerate: return .sandstone
        case .basalt: return .basalt
        case .andesite: return .basalt
        case .granite: return .granite
        case .diorite: return .diorite
        case .gabbro: return .gabbro
        case .slate: return .slate
        case .schist: return .schist
        case .marble: return .marble
        case .quartzite: return .quartzite
        case .gneiss: return .granite
        case .obsidian: return .obsidian
        }
    }

    /// Rock hardness (0-1), affects mining speed
    var hardness: Float {
        switch self {
        case .shale: return 0.2
        case .sandstone, .limestone, .conglomerate: return 0.3
        case .slate: return 0.4
        case .schist: return 0.5
        case .marble: return 0.55
        case .andesite: return 0.6
        case .basalt: return 0.65
        case .diorite: return 0.7
        case .gneiss: return 0.75
        case .granite: return 0.8
        case .gabbro: return 0.8
        case .quartzite: return 0.85
        case .obsidian: return 0.9
        }
    }

    /// Ore types that can appear within this rock
    var compatibleOres: [OreType] {
        switch self {
        // Sedimentary: coal, iron, tin
        case .sandstone, .limestone, .shale, .conglomerate:
            return [.coal, .iron, .tin]
        // Igneous extrusive: iron, copper
        case .basalt, .andesite:
            return [.iron, .copper]
        // Igneous intrusive: tin, copper, gold, silver, gemstone
        case .granite, .diorite, .gabbro:
            return [.tin, .copper, .gold, .silver, .gemstone]
        // Metamorphic: gold, silver, gemstone
        case .slate, .schist, .marble, .quartzite, .gneiss:
            return [.gold, .silver, .gemstone]
        // Obsidian: gemstone only
        case .obsidian:
            return [.gemstone]
        }
    }
}
