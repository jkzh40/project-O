// MARK: - Gemstone Type
// Specific gemstone varieties replacing the catch-all .gemstone OreType

/// Types of gemstones that can be found in ore deposits
public enum GemstoneType: String, CaseIterable, Sendable {
    case diamond
    case ruby
    case emerald
    case sapphire
    case amethyst
    case topaz
    case opal
    case garnet
    case jade
    case onyx
    case turquoise
    case lapis

    /// Rarity factor (0-1, lower = rarer)
    public var rarity: Float {
        switch self {
        case .diamond: return 0.05
        case .ruby: return 0.08
        case .emerald: return 0.08
        case .sapphire: return 0.10
        case .opal: return 0.12
        case .topaz: return 0.15
        case .jade: return 0.15
        case .lapis: return 0.15
        case .turquoise: return 0.18
        case .amethyst: return 0.20
        case .onyx: return 0.20
        case .garnet: return 0.25
        }
    }

    /// Base trade value
    public var value: Int {
        switch self {
        case .diamond: return 500
        case .ruby: return 350
        case .emerald: return 350
        case .sapphire: return 300
        case .opal: return 250
        case .topaz: return 200
        case .jade: return 200
        case .lapis: return 200
        case .turquoise: return 175
        case .amethyst: return 150
        case .onyx: return 150
        case .garnet: return 100
        }
    }
}

// MARK: - RockType Gemstone Compatibility

extension RockType {
    /// Gemstone types that can appear within this rock
    public var compatibleGemstones: [GemstoneType] {
        switch self {
        // Sedimentary: common gems
        case .sandstone, .limestone, .shale, .conglomerate,
             .chalk, .mudstone, .siltstone, .travertine:
            return [.amethyst, .garnet, .onyx]

        // Igneous extrusive
        case .basalt, .andesite, .rhyolite, .tuff, .pumice:
            return [.opal, .garnet, .topaz]

        // Igneous intrusive — gemstone-rich
        case .granite, .diorite, .gabbro:
            return [.diamond, .emerald, .topaz, .ruby, .sapphire]

        // Pegmatite — extra gemstone-rich
        case .pegmatite:
            return [.diamond, .emerald, .topaz, .opal]

        // Metamorphic
        case .slate, .schist, .marble, .quartzite, .gneiss,
             .serpentinite, .soapstone, .phyllite, .migmatite:
            return [.ruby, .emerald, .sapphire, .jade, .lapis]

        // Volcanic glass
        case .obsidian:
            return [.onyx, .opal]

        // Fantasy rocks — magical gems
        case .deepslate, .voidrock, .dragonrock:
            return [.diamond, .ruby, .sapphire]
        case .glowstone, .crystalrock, .aetherstone:
            return [.opal, .topaz, .amethyst]
        case .shadowrock:
            return [.onyx, .lapis]
        case .bloodstone:
            return [.ruby, .garnet]
        case .moonstone:
            return [.sapphire, .opal, .diamond]
        case .sunrock:
            return [.topaz, .ruby, .garnet]
        case .runestone:
            return [.lapis, .amethyst, .sapphire]
        case .livingrock:
            return [.emerald, .jade, .turquoise]
        }
    }
}
