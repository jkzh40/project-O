// MARK: - Terrain

import Foundation

/// Types of terrain tiles
public enum TerrainType: String, CaseIterable, Sendable {
    // Natural terrain
    case emptyAir
    case grass
    case dirt
    case stone
    case water
    case tree
    case shrub
    case wall
    case ore             // Minable ore

    // Expanded natural terrain
    case sand
    case snow
    case ice
    case marsh
    case deepWater
    case clay
    case gravel
    case mud
    case coniferTree
    case palmTree
    case deadTree
    case tallGrass
    case cactus
    case moss
    case reeds

    // Rock types
    case sandstone
    case limestone
    case granite
    case obsidian
    case topsoil
    case frozenGround
    case lava

    // Constructed terrain
    case woodenFloor
    case stoneFloor
    case constructedWall

    // Z-Level navigation
    case stairsUp        // Stairs going up only
    case stairsDown      // Stairs going down only
    case stairsUpDown    // Stairs going both ways
    case rampUp          // Ramp going up
    case rampDown        // Ramp coming from above (open space with ramp below)

    /// Whether units can walk through this terrain
    public var isPassable: Bool {
        switch self {
        case .emptyAir, .grass, .dirt, .stone, .woodenFloor, .stoneFloor,
             .stairsUp, .stairsDown, .stairsUpDown, .rampUp, .rampDown, .ore,
             .sand, .snow, .gravel, .mud, .tallGrass, .moss, .topsoil,
             .frozenGround, .clay, .sandstone, .limestone, .granite:
            return true
        case .water, .tree, .shrub, .wall, .constructedWall,
             .deepWater, .ice, .coniferTree, .palmTree, .deadTree,
             .cactus, .reeds, .marsh, .obsidian, .lava:
            return false
        }
    }

    /// Whether this terrain allows movement up to the next z-level
    public var allowsMovementUp: Bool {
        switch self {
        case .stairsUp, .stairsUpDown, .rampUp:
            return true
        default:
            return false
        }
    }

    /// Whether this terrain allows movement down to the previous z-level
    public var allowsMovementDown: Bool {
        switch self {
        case .stairsDown, .stairsUpDown, .rampDown:
            return true
        default:
            return false
        }
    }

    /// Whether this is a solid tile that can be mined
    public var isMinable: Bool {
        switch self {
        case .wall, .stone, .ore, .sandstone, .limestone, .granite, .obsidian:
            return true
        default:
            return false
        }
    }

    /// Whether this is a tree that can be chopped
    public var isHarvestableTree: Bool {
        switch self {
        case .tree, .coniferTree, .palmTree, .deadTree:
            return true
        default:
            return false
        }
    }

    /// Whether this is a body of water
    public var isWaterBody: Bool {
        switch self {
        case .water, .deepWater:
            return true
        default:
            return false
        }
    }

    /// Whether this is a vegetation tile
    public var isVegetation: Bool {
        switch self {
        case .tree, .shrub, .coniferTree, .palmTree, .deadTree,
             .tallGrass, .cactus, .reeds, .moss:
            return true
        default:
            return false
        }
    }

    /// Movement cost multiplier (1.0 = normal)
    public var movementCost: Double {
        switch self {
        case .grass, .dirt, .woodenFloor, .stoneFloor, .stairsUp, .stairsDown, .stairsUpDown,
             .topsoil, .moss:
            return 1.0
        case .stone, .ore, .sandstone, .limestone, .granite:
            return 1.2
        case .rampUp, .rampDown:
            return 1.5
        case .sand, .gravel:
            return 1.3
        case .snow, .frozenGround:
            return 1.4
        case .mud, .clay:
            return 1.6
        case .tallGrass:
            return 1.1
        case .water:
            return 5.0
        default:
            return Double.infinity
        }
    }

    /// Character representation for terminal display
    public var displayChar: Character {
        switch self {
        case .emptyAir: return " "
        case .grass: return "."
        case .dirt: return ","
        case .stone: return "_"
        case .ore: return "$"
        case .water: return "~"
        case .deepWater: return "≈"
        case .tree: return "T"
        case .coniferTree: return "♠"
        case .palmTree: return "♣"
        case .deadTree: return "†"
        case .shrub: return "*"
        case .tallGrass: return ";"
        case .cactus: return "¡"
        case .reeds: return "|"
        case .moss: return "·"
        case .wall: return "#"
        case .sand: return "∘"
        case .snow: return "○"
        case .ice: return "◇"
        case .marsh: return "≋"
        case .clay: return "▪"
        case .gravel: return "░"
        case .mud: return "▓"
        case .sandstone: return "▤"
        case .limestone: return "▥"
        case .granite: return "▦"
        case .obsidian: return "■"
        case .topsoil: return "▫"
        case .frozenGround: return "◻"
        case .lava: return "▣"
        case .woodenFloor: return "="
        case .stoneFloor: return "+"
        case .constructedWall: return "H"
        case .stairsUp: return "<"
        case .stairsDown: return ">"
        case .stairsUpDown: return "X"
        case .rampUp: return "^"
        case .rampDown: return "v"
        }
    }
}
