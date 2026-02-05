import SpriteKit
import OCore

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
    let tileSize: CGFloat = 16.0

    /// Cached textures
    private var terrainTextures: [TerrainType: SKTexture] = [:]
    private var unitTextures: [CreatureType: SKTexture] = [:]
    private var itemTextures: [ItemType: SKTexture] = [:]
    private var selectionTexture: SKTexture?

    private init() {
        loadTerrainTextures()
        loadUnitTextures()
        loadItemTextures()
        loadSelectionTexture()
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
        ]

        for (terrain, assetName) in terrainAssetNames {
            terrainTextures[terrain] = SKTexture(imageNamed: assetName)
            terrainTextures[terrain]?.filteringMode = .nearest // Pixel-perfect rendering
        }
    }

    private func loadUnitTextures() {
        let creatureAssetNames: [CreatureType: String] = [
            .dwarf: "Creatures/creature_dwarf",
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

    // MARK: - Texture Access

    func texture(for terrain: TerrainType) -> SKTexture {
        terrainTextures[terrain] ?? terrainTextures[.grass]!
    }

    func texture(for creature: CreatureType) -> SKTexture {
        unitTextures[creature] ?? unitTextures[.dwarf]!
    }

    func texture(for item: ItemType) -> SKTexture {
        itemTextures[item] ?? itemTextures[.food]!
    }

    func selectionRingTexture() -> SKTexture {
        selectionTexture!
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
