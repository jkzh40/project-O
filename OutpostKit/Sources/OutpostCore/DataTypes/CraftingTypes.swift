// MARK: - Crafting System Types
// Recipes, material processing, and item creation

import Foundation

// MARK: - Recipe

/// A crafting recipe
public struct Recipe: Sendable, Identifiable {
    public let id: String
    public let name: String

    /// Items required as input
    public let inputs: [ItemType: Int]

    /// Items produced as output
    public let outputs: [ItemType: Int]

    /// Workshop type required
    public let workshopType: WorkshopType

    /// Skill used for crafting
    public let skill: SkillType

    /// Base work ticks required
    public let workTicks: Int

    /// Minimum skill level required (0 = any)
    public let minimumSkillLevel: Int

    public init(
        id: String,
        name: String,
        inputs: [ItemType: Int],
        outputs: [ItemType: Int],
        workshopType: WorkshopType,
        skill: SkillType,
        workTicks: Int = 100,
        minimumSkillLevel: Int = 0
    ) {
        self.id = id
        self.name = name
        self.inputs = inputs
        self.outputs = outputs
        self.workshopType = workshopType
        self.skill = skill
        self.workTicks = workTicks
        self.minimumSkillLevel = minimumSkillLevel
    }
}

// MARK: - Standard Recipes

/// Collection of standard crafting recipes
public enum StandardRecipes {
    /// All available recipes
    public static let all: [Recipe] = [
        // Carpenter's Workshop
        Recipe(
            id: "bed_wooden",
            name: "Wooden Bed",
            inputs: [.log: 2],
            outputs: [.bed: 1],
            workshopType: .carpenterWorkshop,
            skill: .carpentry,
            workTicks: 150
        ),
        Recipe(
            id: "table_wooden",
            name: "Wooden Table",
            inputs: [.log: 1],
            outputs: [.table: 1],
            workshopType: .carpenterWorkshop,
            skill: .carpentry,
            workTicks: 100
        ),
        Recipe(
            id: "chair_wooden",
            name: "Wooden Chair",
            inputs: [.log: 1],
            outputs: [.chair: 1],
            workshopType: .carpenterWorkshop,
            skill: .carpentry,
            workTicks: 80
        ),
        Recipe(
            id: "door_wooden",
            name: "Wooden Door",
            inputs: [.log: 1],
            outputs: [.door: 1],
            workshopType: .carpenterWorkshop,
            skill: .carpentry,
            workTicks: 100
        ),
        Recipe(
            id: "barrel_wooden",
            name: "Wooden Barrel",
            inputs: [.log: 1],
            outputs: [.barrel: 1],
            workshopType: .carpenterWorkshop,
            skill: .carpentry,
            workTicks: 80
        ),
        Recipe(
            id: "bin_wooden",
            name: "Wooden Bin",
            inputs: [.log: 1],
            outputs: [.bin: 1],
            workshopType: .carpenterWorkshop,
            skill: .carpentry,
            workTicks: 80
        ),

        // Mason's Workshop
        Recipe(
            id: "table_stone",
            name: "Stone Table",
            inputs: [.stone: 2],
            outputs: [.table: 1],
            workshopType: .masonWorkshop,
            skill: .masonry,
            workTicks: 120
        ),
        Recipe(
            id: "chair_stone",
            name: "Stone Chair",
            inputs: [.stone: 1],
            outputs: [.chair: 1],
            workshopType: .masonWorkshop,
            skill: .masonry,
            workTicks: 100
        ),
        Recipe(
            id: "door_stone",
            name: "Stone Door",
            inputs: [.stone: 2],
            outputs: [.door: 1],
            workshopType: .masonWorkshop,
            skill: .masonry,
            workTicks: 120
        ),

        // Kitchen
        Recipe(
            id: "meal_simple",
            name: "Simple Meal",
            inputs: [.rawMeat: 1, .plant: 1],
            outputs: [.food: 2],
            workshopType: .kitchen,
            skill: .cooking,
            workTicks: 60
        ),
        Recipe(
            id: "meal_fine",
            name: "Fine Meal",
            inputs: [.rawMeat: 2, .plant: 2],
            outputs: [.food: 4],
            workshopType: .kitchen,
            skill: .cooking,
            workTicks: 100,
            minimumSkillLevel: 3
        ),
        Recipe(
            id: "roast",
            name: "Roast Meat",
            inputs: [.rawMeat: 1],
            outputs: [.food: 1],
            workshopType: .kitchen,
            skill: .cooking,
            workTicks: 40
        ),

        // Brewery
        Recipe(
            id: "brew_basic",
            name: "Orcish Ale",
            inputs: [.plant: 2],
            outputs: [.drink: 3],
            workshopType: .brewery,
            skill: .brewing,
            workTicks: 80
        ),
        Recipe(
            id: "brew_fine",
            name: "Fine Ale",
            inputs: [.plant: 3],
            outputs: [.drink: 5],
            workshopType: .brewery,
            skill: .brewing,
            workTicks: 120,
            minimumSkillLevel: 3
        ),

        // Craftsorc's Workshop
        Recipe(
            id: "craft_stone",
            name: "Stone Crafts",
            inputs: [.stone: 1],
            outputs: [.stone: 1],  // Would be a craft item
            workshopType: .craftsorcWorkshop,
            skill: .carpentry,
            workTicks: 60
        ),

        // Forge (tools)
        Recipe(
            id: "pickaxe",
            name: "Pickaxe",
            inputs: [.ore: 2, .log: 1],
            outputs: [.pickaxe: 1],
            workshopType: .forge,
            skill: .mining,  // Would be smithing
            workTicks: 150,
            minimumSkillLevel: 2
        ),
        Recipe(
            id: "axe",
            name: "Axe",
            inputs: [.ore: 2, .log: 1],
            outputs: [.axe: 1],
            workshopType: .forge,
            skill: .mining,
            workTicks: 150,
            minimumSkillLevel: 2
        ),
    ]

    /// Get recipes for a workshop type
    public static func recipes(for workshopType: WorkshopType) -> [Recipe] {
        all.filter { $0.workshopType == workshopType }
    }

    /// Get recipe by ID
    public static func recipe(withId id: String) -> Recipe? {
        all.first { $0.id == id }
    }

    /// Get recipes that produce a specific item
    public static func recipes(producing itemType: ItemType) -> [Recipe] {
        all.filter { $0.outputs[itemType] != nil }
    }
}

// MARK: - Craft Result

/// Result of a crafting attempt
public struct CraftResult: Sendable {
    public let recipeId: String
    public let success: Bool
    public let quality: ItemQuality
    public let itemsProduced: [ItemType: Int]
    public let skillGained: Int
    public let crafterId: UInt64

    public init(
        recipeId: String,
        success: Bool,
        quality: ItemQuality,
        itemsProduced: [ItemType: Int],
        skillGained: Int,
        crafterId: UInt64
    ) {
        self.recipeId = recipeId
        self.success = success
        self.quality = quality
        self.itemsProduced = itemsProduced
        self.skillGained = skillGained
        self.crafterId = crafterId
    }
}
