// MARK: - Crafting Manager

import Foundation
import OutpostCore

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
        let masterworkThreshold = max(1, 5 - skillLevel / 4)
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
