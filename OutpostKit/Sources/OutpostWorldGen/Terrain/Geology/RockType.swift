// MARK: - Rock Type
// Geological rock classification for subsurface strata

import OutpostCore

/// Geological rock types used in underground strata generation
enum RockType: String, CaseIterable, Sendable {
    // Sedimentary
    case sandstone
    case limestone
    case shale
    case conglomerate
    case chalk
    case mudstone
    case siltstone
    case travertine

    // Igneous extrusive
    case basalt
    case andesite
    case rhyolite
    case tuff
    case pumice

    // Igneous intrusive
    case granite
    case diorite
    case gabbro
    case pegmatite

    // Metamorphic
    case slate
    case schist
    case marble
    case quartzite
    case gneiss
    case serpentinite
    case soapstone
    case phyllite
    case migmatite

    // Volcanic glass
    case obsidian

    // Fantasy — deep crust
    case deepslate

    // Fantasy — magical
    case glowstone
    case shadowrock
    case crystalrock
    case bloodstone
    case voidrock
    case moonstone
    case sunrock
    case dragonrock
    case runestone
    case aetherstone
    case livingrock

    /// Maps to the corresponding TerrainType for tile rendering
    var terrainType: TerrainType {
        switch self {
        case .sandstone: return .sandstone
        case .limestone: return .limestone
        case .shale: return .shale
        case .conglomerate: return .sandstone
        case .chalk: return .chalk
        case .mudstone: return .mudstone
        case .siltstone: return .siltstone
        case .travertine: return .travertine
        case .basalt: return .basalt
        case .andesite: return .basalt
        case .rhyolite: return .rhyolite
        case .tuff: return .tuff
        case .pumice: return .pumice
        case .granite: return .granite
        case .diorite: return .diorite
        case .gabbro: return .gabbro
        case .pegmatite: return .pegmatite
        case .slate: return .slate
        case .schist: return .schist
        case .marble: return .marble
        case .quartzite: return .quartzite
        case .gneiss: return .granite
        case .serpentinite: return .serpentinite
        case .soapstone: return .soapstone
        case .phyllite: return .phyllite
        case .migmatite: return .migmatite
        case .obsidian: return .obsidian
        case .deepslate: return .deepslate
        case .glowstone: return .glowstone
        case .shadowrock: return .shadowrock
        case .crystalrock: return .crystalrock
        case .bloodstone: return .bloodstone
        case .voidrock: return .voidrock
        case .moonstone: return .moonstone
        case .sunrock: return .sunrock
        case .dragonrock: return .dragonrock
        case .runestone: return .runestone
        case .aetherstone: return .aetherstone
        case .livingrock: return .livingrock
        }
    }

    /// Rock hardness (0-1), affects mining speed
    var hardness: Float {
        switch self {
        case .chalk: return 0.15
        case .mudstone: return 0.18
        case .shale: return 0.2
        case .siltstone: return 0.22
        case .pumice: return 0.25
        case .travertine: return 0.28
        case .sandstone, .limestone, .conglomerate: return 0.3
        case .soapstone: return 0.3
        case .serpentinite: return 0.4
        case .slate: return 0.4
        case .phyllite: return 0.42
        case .tuff: return 0.45
        case .aetherstone: return 0.45
        case .moonstone: return 0.48
        case .glowstone: return 0.5
        case .schist: return 0.5
        case .sunrock: return 0.52
        case .crystalrock: return 0.55
        case .marble: return 0.55
        case .livingrock: return 0.58
        case .rhyolite: return 0.6
        case .andesite: return 0.6
        case .runestone: return 0.6
        case .basalt: return 0.65
        case .shadowrock: return 0.65
        case .diorite: return 0.7
        case .pegmatite: return 0.7
        case .bloodstone: return 0.7
        case .gneiss: return 0.75
        case .migmatite: return 0.78
        case .granite: return 0.8
        case .gabbro: return 0.8
        case .quartzite: return 0.85
        case .voidrock: return 0.85
        case .dragonrock: return 0.88
        case .obsidian: return 0.9
        case .deepslate: return 0.92
        }
    }

    /// Ore types that can appear within this rock
    var compatibleOres: [OreType] {
        switch self {
        // Sedimentary: coal, iron, tin + new sedimentary ores
        case .sandstone, .conglomerate:
            return [.coal, .iron, .tin, .lead, .zinc]
        case .limestone:
            return [.coal, .iron, .tin, .lead, .zinc]
        case .shale:
            return [.coal, .iron, .tin, .lead, .bauxite]
        case .chalk:
            return [.coal, .saltpeter, .lead]
        case .mudstone:
            return [.coal, .iron, .bauxite]
        case .siltstone:
            return [.coal, .lead, .zinc]
        case .travertine:
            return [.saltpeter, .zinc]

        // Igneous extrusive: iron, copper + new volcanic ores
        case .basalt, .andesite:
            return [.iron, .copper, .zinc, .nickel]
        case .rhyolite:
            return [.iron, .copper, .sulfur]
        case .tuff:
            return [.sulfur, .mercury]
        case .pumice:
            return [.sulfur]

        // Igneous intrusive: tin, copper, gold, silver, gemstone + new deep ores
        case .granite, .diorite:
            return [.tin, .copper, .gold, .silver, .gemstone]
        case .gabbro:
            return [.tin, .copper, .gold, .silver, .gemstone, .chromium]
        case .pegmatite:
            return [.platinum, .bismuth, .gemstone, .tin]

        // Metamorphic: gold, silver, gemstone + new metamorphic ores
        case .slate, .schist, .quartzite, .gneiss:
            return [.gold, .silver, .gemstone]
        case .marble:
            return [.gold, .silver, .gemstone]
        case .serpentinite:
            return [.chromium, .nickel, .cobalt]
        case .soapstone:
            return [.tungsten, .mithril]
        case .phyllite:
            return [.gold, .tungsten]
        case .migmatite:
            return [.platinum, .mithril]

        // Volcanic glass
        case .obsidian:
            return [.gemstone, .mercury]

        // Fantasy — deep crust
        case .deepslate:
            return [.adamantine, .starmetal]

        // Fantasy — magical rocks
        case .glowstone:
            return [.moonsilver, .etherealite]
        case .shadowrock:
            return [.darksteel, .voidstone]
        case .crystalrock:
            return [.etherealite, .moonsilver]
        case .bloodstone:
            return [.bloodiron]
        case .voidrock:
            return [.voidstone, .adamantine]
        case .moonstone:
            return [.moonsilver, .mithril]
        case .sunrock:
            return [.sunstone, .orichalcum]
        case .dragonrock:
            return [.dragonite, .sunstone]
        case .runestone:
            return [.runegold, .mithril]
        case .aetherstone:
            return [.etherealite, .starmetal]
        case .livingrock:
            return [.mithril, .orichalcum]
        }
    }
}
