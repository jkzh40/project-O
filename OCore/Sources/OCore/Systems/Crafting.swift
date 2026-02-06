// MARK: - Crafting System
// Handles recipes, material processing, and item creation

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

// MARK: - Crafting Manager

/// Manages crafting operations
@MainActor
public final class CraftingManager: Sendable {
    /// Recent craft results for logging
    public private(set) var recentCrafts: [CraftResult] = []

    /// Maximum craft history
    public var maxCraftHistory: Int = 50

    public init() {}

    /// Calculate quality based on skill level
    public func calculateQuality(skillLevel: Int) -> ItemQuality {
        // Base chances modified by skill
        let roll = Int.random(in: 1...100)

        // Skill thresholds for quality
        // Higher skill = better chance at higher quality
        let masterworkThreshold = max(1, 5 - skillLevel / 4)   // 1-5% at high skill
        let exceptionalThreshold = masterworkThreshold + max(2, 10 - skillLevel / 3)
        let superiorThreshold = exceptionalThreshold + max(5, 15 - skillLevel / 2)
        let finelyCraftedThreshold = superiorThreshold + max(10, 20 - skillLevel)
        let wellCraftedThreshold = finelyCraftedThreshold + max(15, 25 - skillLevel)

        if roll <= masterworkThreshold && skillLevel >= 15 {
            return .masterwork
        } else if roll <= exceptionalThreshold && skillLevel >= 10 {
            return .exceptional
        } else if roll <= superiorThreshold && skillLevel >= 7 {
            return .superior
        } else if roll <= finelyCraftedThreshold && skillLevel >= 4 {
            return .finelyCrafted
        } else if roll <= wellCraftedThreshold && skillLevel >= 2 {
            return .wellCrafted
        } else {
            return .standard
        }
    }

    /// Calculate skill experience gained
    public func calculateSkillGain(recipe: Recipe, quality: ItemQuality) -> Int {
        var baseXP = recipe.workTicks / 10

        // Quality bonus
        switch quality {
        case .standard: break
        case .wellCrafted: baseXP += 5
        case .finelyCrafted: baseXP += 10
        case .superior: baseXP += 20
        case .exceptional: baseXP += 35
        case .masterwork: baseXP += 50
        case .artifact: baseXP += 100
        }

        return baseXP
    }

    /// Attempt to craft a recipe
    public func craft(
        recipe: Recipe,
        crafterId: UInt64,
        crafterSkillLevel: Int
    ) -> CraftResult {
        // Check skill requirement
        let success = crafterSkillLevel >= recipe.minimumSkillLevel

        let quality: ItemQuality
        let itemsProduced: [ItemType: Int]
        let skillGained: Int

        if success {
            quality = calculateQuality(skillLevel: crafterSkillLevel)
            itemsProduced = recipe.outputs
            skillGained = calculateSkillGain(recipe: recipe, quality: quality)
        } else {
            // Failed craft - still gain some skill
            quality = .standard
            itemsProduced = [:]
            skillGained = recipe.workTicks / 20  // Half XP for failure
        }

        let result = CraftResult(
            recipeId: recipe.id,
            success: success,
            quality: quality,
            itemsProduced: itemsProduced,
            skillGained: skillGained,
            crafterId: crafterId
        )

        // Store in history
        recentCrafts.append(result)
        if recentCrafts.count > maxCraftHistory {
            recentCrafts.removeFirst()
        }

        return result
    }

    /// Check if recipe can be crafted with available items
    public func canCraft(recipe: Recipe, availableItems: [ItemType: Int]) -> Bool {
        for (requiredType, requiredCount) in recipe.inputs {
            let available = availableItems[requiredType] ?? 0
            if available < requiredCount {
                return false
            }
        }
        return true
    }

    /// Get craftable recipes given available items and workshop
    public func getCraftableRecipes(
        workshopType: WorkshopType,
        availableItems: [ItemType: Int],
        crafterSkillLevel: Int
    ) -> [Recipe] {
        StandardRecipes.recipes(for: workshopType).filter { recipe in
            // Check skill requirement
            guard crafterSkillLevel >= recipe.minimumSkillLevel else { return false }

            // Check materials
            return canCraft(recipe: recipe, availableItems: availableItems)
        }
    }
}
