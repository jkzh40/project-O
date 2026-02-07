import SpriteKit
import OutpostRuntime

#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
#elseif os(macOS)
import AppKit
typealias PlatformColor = NSColor
#endif

/// Manages textures for rendering using pixel art assets
@MainActor
final class TextureManager {
    static let shared = TextureManager()

    /// Tile size in points
    let tileSize: CGFloat = 32.0

    /// Cached textures
    private var terrainTextures: [TerrainType: SKTexture] = [:]
    private var unitTextures: [CreatureType: SKTexture] = [:]
    private var itemTextures: [ItemType: SKTexture] = [:]
    private var selectionTexture: SKTexture?
    private var waterFrames: [SKTexture] = []
    private var healthBarBgTex: SKTexture?
    private var healthBarFillTex: SKTexture?

    /// Seasonal terrain textures
    private var seasonalTerrainTextures: [TerrainType: [Season: SKTexture]] = [:]
    private var seasonalWaterFrames: [Season: [SKTexture]] = [:]

    /// Animation frame textures
    private var unitWalkFrames: [CreatureType: [SKTexture]] = [:]
    private var unitAttackFrames: [CreatureType: [SKTexture]] = [:]
    private var unitIdleFrames: [CreatureType: [SKTexture]] = [:]
    private var unitDeathFrames: [CreatureType: [SKTexture]] = [:]
    private var shadowTex: SKTexture?
    private var terrainVariantTextures: [TerrainType: [SKTexture]] = [:]

    private init() {
        loadTerrainTextures()
        loadUnitTextures()
        loadItemTextures()
        loadSelectionTexture()
        loadWaterAnimationFrames()
        loadHealthBarTextures()
        loadSeasonalTerrainTextures()
        loadSeasonalWaterFrames()
        loadUnitAnimationFrames()
        loadShadowTexture()
        loadTerrainVariants()
    }

    // MARK: - Texture Loading

    private func loadTerrainTextures() {
        let terrainAssetNames: [TerrainType: String] = [
            .emptyAir: "Terrain/terrain_empty_air",
            .grass: "Terrain/terrain_grass",
            .dirt: "Terrain/terrain_dirt",
            .stone: "Terrain/terrain_stone",
            .water: "Terrain/terrain_water",
            .tree: "Terrain/terrain_tree",
            .shrub: "Terrain/terrain_shrub",
            .wall: "Terrain/terrain_wall",
            .ore: "Terrain/terrain_ore",
            .woodenFloor: "Terrain/terrain_wooden_floor",
            .stoneFloor: "Terrain/terrain_stone_floor",
            .constructedWall: "Terrain/terrain_constructed_wall",
            .stairsUp: "Terrain/terrain_stairs_up",
            .stairsDown: "Terrain/terrain_stairs_down",
            .stairsUpDown: "Terrain/terrain_stairs_updown",
            .rampUp: "Terrain/terrain_ramp_up",
            .rampDown: "Terrain/terrain_ramp_down",
            // New terrain types — use placeholder fallbacks to existing textures
            .sand: "Terrain/terrain_sand",
            .snow: "Terrain/terrain_snow",
            .ice: "Terrain/terrain_ice",
            .marsh: "Terrain/terrain_marsh",
            .deepWater: "Terrain/terrain_deep_water",
            .clay: "Terrain/terrain_clay",
            .gravel: "Terrain/terrain_gravel",
            .mud: "Terrain/terrain_mud",
            .coniferTree: "Terrain/terrain_conifer_tree",
            .palmTree: "Terrain/terrain_palm_tree",
            .deadTree: "Terrain/terrain_dead_tree",
            .tallGrass: "Terrain/terrain_tall_grass",
            .cactus: "Terrain/terrain_cactus",
            .moss: "Terrain/terrain_moss",
            .reeds: "Terrain/terrain_reeds",
            .sandstone: "Terrain/terrain_sandstone",
            .limestone: "Terrain/terrain_limestone",
            .granite: "Terrain/terrain_granite",
            .obsidian: "Terrain/terrain_obsidian",
            .topsoil: "Terrain/terrain_topsoil",
            .frozenGround: "Terrain/terrain_frozen_ground",
            .lava: "Terrain/terrain_lava",
        ]

        for (terrain, assetName) in terrainAssetNames {
            terrainTextures[terrain] = SKTexture(imageNamed: assetName)
            terrainTextures[terrain]?.filteringMode = .nearest // Pixel-perfect rendering
        }

        // Generate placeholder textures for new terrain types that don't have assets yet
        generatePlaceholderTextures()
    }

    /// Generate solid-color placeholder textures for new terrain types
    private func generatePlaceholderTextures() {
        let placeholders: [TerrainType: PlatformColor] = [
            .sand: PlatformColor(red: 0.93, green: 0.87, blue: 0.65, alpha: 1),
            .snow: PlatformColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1),
            .ice: PlatformColor(red: 0.75, green: 0.88, blue: 0.97, alpha: 1),
            .marsh: PlatformColor(red: 0.35, green: 0.45, blue: 0.3, alpha: 1),
            .deepWater: PlatformColor(red: 0.1, green: 0.15, blue: 0.4, alpha: 1),
            .clay: PlatformColor(red: 0.65, green: 0.45, blue: 0.3, alpha: 1),
            .gravel: PlatformColor(red: 0.6, green: 0.58, blue: 0.55, alpha: 1),
            .mud: PlatformColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1),
            .coniferTree: PlatformColor(red: 0.1, green: 0.35, blue: 0.15, alpha: 1),
            .palmTree: PlatformColor(red: 0.2, green: 0.5, blue: 0.15, alpha: 1),
            .deadTree: PlatformColor(red: 0.4, green: 0.35, blue: 0.25, alpha: 1),
            .tallGrass: PlatformColor(red: 0.4, green: 0.6, blue: 0.25, alpha: 1),
            .cactus: PlatformColor(red: 0.3, green: 0.55, blue: 0.2, alpha: 1),
            .moss: PlatformColor(red: 0.3, green: 0.5, blue: 0.2, alpha: 1),
            .reeds: PlatformColor(red: 0.45, green: 0.55, blue: 0.3, alpha: 1),
            .sandstone: PlatformColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 1),
            .limestone: PlatformColor(red: 0.85, green: 0.83, blue: 0.75, alpha: 1),
            .granite: PlatformColor(red: 0.55, green: 0.52, blue: 0.5, alpha: 1),
            .obsidian: PlatformColor(red: 0.15, green: 0.1, blue: 0.2, alpha: 1),
            .topsoil: PlatformColor(red: 0.45, green: 0.35, blue: 0.2, alpha: 1),
            .frozenGround: PlatformColor(red: 0.7, green: 0.72, blue: 0.8, alpha: 1),
            .lava: PlatformColor(red: 0.9, green: 0.3, blue: 0.05, alpha: 1),
        ]

        let size = CGSize(width: 32, height: 32)
        for (terrain, color) in placeholders {
            // Only create placeholder if no real asset was loaded (check if texture has actual content)
            // SKTexture(imageNamed:) returns a default texture if asset not found, so we always
            // set the placeholder - the real asset will be used if it exists in the catalog
            if terrainTextures[terrain] == nil {
                let tex = createSolidTexture(color: color, size: size)
                terrainTextures[terrain] = tex
            }
        }
    }

    /// Create a solid color texture
    private func createSolidTexture(color: PlatformColor, size: CGSize) -> SKTexture {
        #if os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        let tex = SKTexture(image: image)
        #else
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        let tex = SKTexture(image: image)
        #endif
        tex.filteringMode = .nearest
        return tex
    }

    private func loadUnitTextures() {
        let creatureAssetNames: [CreatureType: String] = [
            .orc: "Creatures/creature_orc",
            .goblin: "Creatures/creature_goblin",
            .wolf: "Creatures/creature_wolf",
            .bear: "Creatures/creature_bear",
            .giant: "Creatures/creature_giant",
            .undead: "Creatures/creature_undead",
        ]

        for (creature, assetName) in creatureAssetNames {
            unitTextures[creature] = SKTexture(imageNamed: assetName)
            unitTextures[creature]?.filteringMode = .nearest
        }
    }

    private func loadItemTextures() {
        let itemAssetNames: [ItemType: String] = [
            .food: "Items/item_food",
            .drink: "Items/item_drink",
            .rawMeat: "Items/item_raw_meat",
            .plant: "Items/item_plant",
            .bed: "Items/item_bed",
            .table: "Items/item_table",
            .chair: "Items/item_chair",
            .door: "Items/item_door",
            .barrel: "Items/item_barrel",
            .bin: "Items/item_bin",
            .pickaxe: "Items/item_pickaxe",
            .axe: "Items/item_axe",
            .log: "Items/item_log",
            .stone: "Items/item_stone",
            .ore: "Items/item_ore",
        ]

        for (item, assetName) in itemAssetNames {
            itemTextures[item] = SKTexture(imageNamed: assetName)
            itemTextures[item]?.filteringMode = .nearest
        }
    }

    private func loadSelectionTexture() {
        selectionTexture = SKTexture(imageNamed: "UI/ui_selection")
        selectionTexture?.filteringMode = .nearest
    }

    private func loadWaterAnimationFrames() {
        for i in 0...2 {
            let tex = SKTexture(imageNamed: "Terrain/terrain_water_\(i)")
            tex.filteringMode = .nearest
            waterFrames.append(tex)
        }
    }

    private func loadHealthBarTextures() {
        healthBarBgTex = SKTexture(imageNamed: "UI/ui_healthbar_bg")
        healthBarBgTex?.filteringMode = .nearest
        healthBarFillTex = SKTexture(imageNamed: "UI/ui_healthbar_fill")
        healthBarFillTex?.filteringMode = .nearest
    }

    private func loadSeasonalTerrainTextures() {
        // Terrain types that have seasonal variants: grass, tree, shrub, dirt
        // Summer uses the default (base) textures; spring/autumn/winter have their own.
        let seasonalAssets: [(TerrainType, Season, String)] = [
            (.grass, .spring, "Terrain/terrain_grass_spring"),
            (.grass, .autumn, "Terrain/terrain_grass_autumn"),
            (.grass, .winter, "Terrain/terrain_grass_winter"),
            (.tree, .spring, "Terrain/terrain_tree_spring"),
            (.tree, .autumn, "Terrain/terrain_tree_autumn"),
            (.tree, .winter, "Terrain/terrain_tree_winter"),
            (.shrub, .spring, "Terrain/terrain_shrub_spring"),
            (.shrub, .autumn, "Terrain/terrain_shrub_autumn"),
            (.shrub, .winter, "Terrain/terrain_shrub_winter"),
            (.dirt, .winter, "Terrain/terrain_dirt_winter"),
        ]

        for (terrain, season, assetName) in seasonalAssets {
            let tex = SKTexture(imageNamed: assetName)
            tex.filteringMode = .nearest
            if seasonalTerrainTextures[terrain] == nil {
                seasonalTerrainTextures[terrain] = [:]
            }
            seasonalTerrainTextures[terrain]![season] = tex
        }
    }

    private func loadSeasonalWaterFrames() {
        for season in [Season.autumn, .winter] {
            let seasonName: String
            switch season {
            case .autumn: seasonName = "autumn"
            case .winter: seasonName = "winter"
            default: continue
            }
            var frames: [SKTexture] = []
            for i in 0...2 {
                let tex = SKTexture(imageNamed: "Terrain/terrain_water_\(seasonName)_\(i)")
                tex.filteringMode = .nearest
                frames.append(tex)
            }
            seasonalWaterFrames[season] = frames
        }
    }

    private func loadUnitAnimationFrames() {
        let creatureMap: [CreatureType: String] = [
            .orc: "orc", .goblin: "goblin", .wolf: "wolf",
            .bear: "bear", .giant: "giant", .undead: "undead",
        ]
        for (creature, name) in creatureMap {
            // Walk (0-3)
            var walk: [SKTexture] = []
            for f in 0...3 {
                let tex = SKTexture(imageNamed: "Creatures/creature_\(name)_walk_\(f)")
                tex.filteringMode = .nearest
                walk.append(tex)
            }
            unitWalkFrames[creature] = walk

            // Attack (0-2)
            var attack: [SKTexture] = []
            for f in 0...2 {
                let tex = SKTexture(imageNamed: "Creatures/creature_\(name)_attack_\(f)")
                tex.filteringMode = .nearest
                attack.append(tex)
            }
            unitAttackFrames[creature] = attack

            // Idle (0-1)
            var idle: [SKTexture] = []
            for f in 0...1 {
                let tex = SKTexture(imageNamed: "Creatures/creature_\(name)_idle_\(f)")
                tex.filteringMode = .nearest
                idle.append(tex)
            }
            unitIdleFrames[creature] = idle

            // Death (0-2)
            var death: [SKTexture] = []
            for f in 0...2 {
                let tex = SKTexture(imageNamed: "Creatures/creature_\(name)_death_\(f)")
                tex.filteringMode = .nearest
                death.append(tex)
            }
            unitDeathFrames[creature] = death
        }
    }

    private func loadShadowTexture() {
        shadowTex = SKTexture(imageNamed: "UI/ui_unit_shadow")
        shadowTex?.filteringMode = .nearest
    }

    private func loadTerrainVariants() {
        // Grass variants: base (index 0) + v1, v2
        let grassBase = terrainTextures[.grass]!
        let gv1 = SKTexture(imageNamed: "Terrain/terrain_grass_v1"); gv1.filteringMode = .nearest
        let gv2 = SKTexture(imageNamed: "Terrain/terrain_grass_v2"); gv2.filteringMode = .nearest
        terrainVariantTextures[.grass] = [grassBase, gv1, gv2]

        // Dirt variants: base (index 0) + v1, v2
        let dirtBase = terrainTextures[.dirt]!
        let dv1 = SKTexture(imageNamed: "Terrain/terrain_dirt_v1"); dv1.filteringMode = .nearest
        let dv2 = SKTexture(imageNamed: "Terrain/terrain_dirt_v2"); dv2.filteringMode = .nearest
        terrainVariantTextures[.dirt] = [dirtBase, dv1, dv2]
    }

    // MARK: - Texture Access

    func texture(for terrain: TerrainType) -> SKTexture {
        terrainTextures[terrain] ?? terrainTextures[.grass]!
    }

    func texture(for terrain: TerrainType, season: Season) -> SKTexture {
        // Summer uses the default base texture
        if season == .summer {
            return texture(for: terrain)
        }
        // Check for a seasonal variant
        if let seasonVariants = seasonalTerrainTextures[terrain],
           let tex = seasonVariants[season] {
            return tex
        }
        // Fallback to default
        return texture(for: terrain)
    }

    func texture(for creature: CreatureType) -> SKTexture {
        unitTextures[creature] ?? unitTextures[.orc]!
    }

    func texture(for item: ItemType) -> SKTexture {
        itemTextures[item] ?? itemTextures[.food]!
    }

    func selectionRingTexture() -> SKTexture {
        selectionTexture!
    }

    func waterAnimationTextures() -> [SKTexture] {
        waterFrames
    }

    func waterAnimationTextures(for season: Season) -> [SKTexture] {
        if let frames = seasonalWaterFrames[season], !frames.isEmpty {
            return frames
        }
        return waterFrames
    }

    func healthBarBgTexture() -> SKTexture {
        healthBarBgTex ?? SKTexture()
    }

    func healthBarFillTexture() -> SKTexture {
        healthBarFillTex ?? SKTexture()
    }

    // MARK: - Animation Frame Access

    func walkTextures(for creature: CreatureType) -> [SKTexture] {
        unitWalkFrames[creature] ?? []
    }

    func attackTextures(for creature: CreatureType) -> [SKTexture] {
        unitAttackFrames[creature] ?? []
    }

    func idleTextures(for creature: CreatureType) -> [SKTexture] {
        unitIdleFrames[creature] ?? []
    }

    func deathTextures(for creature: CreatureType) -> [SKTexture] {
        unitDeathFrames[creature] ?? []
    }

    func unitShadowTexture() -> SKTexture {
        shadowTex ?? SKTexture()
    }

    func terrainTexture(for terrain: TerrainType, season: Season, variant: Int) -> SKTexture {
        // Try variant first (only for grass and dirt)
        if variant > 0, let variants = terrainVariantTextures[terrain], variant < variants.count {
            // For non-summer seasons, we still use the seasonal texture (variants are summer-only visual variety)
            if season != .summer {
                return texture(for: terrain, season: season)
            }
            return variants[variant]
        }
        return texture(for: terrain, season: season)
    }

    // MARK: - State Colors

    func stateColor(for state: UnitState) -> PlatformColor {
        switch state {
        case .idle:
            return .clear
        case .moving:
            return PlatformColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.3)
        case .working:
            return PlatformColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 0.3)
        case .eating:
            return PlatformColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 0.3)
        case .drinking:
            return PlatformColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 0.3)
        case .sleeping:
            return PlatformColor(red: 0.4, green: 0.3, blue: 0.6, alpha: 0.3)
        case .socializing:
            return PlatformColor(red: 0.8, green: 0.4, blue: 0.8, alpha: 0.3)
        case .fighting:
            return PlatformColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.4)
        case .fleeing:
            return PlatformColor(red: 0.9, green: 0.9, blue: 0.2, alpha: 0.3)
        case .unconscious:
            return PlatformColor(red: 0.5, green: 0.3, blue: 0.3, alpha: 0.4)
        case .dead:
            return PlatformColor(red: 0.3, green: 0.1, blue: 0.1, alpha: 0.5)
        }
    }
}
