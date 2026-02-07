// MARK: - Autonomous Work Types
// Resource needs and work targets for automatic job generation

import Foundation

// MARK: - Resource Need Priority

/// Priority levels for different resource needs
public enum ResourceNeed: Int, Comparable, Sendable {
    case critical = 0   // Immediate survival needs
    case high = 1       // Important for colony function
    case normal = 2     // Standard maintenance
    case low = 3        // Nice to have

    public static func < (lhs: ResourceNeed, rhs: ResourceNeed) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Work Target

/// A potential work target found in the world
public struct WorkTarget: Sendable {
    public let position: Position          // Where the worker should stand
    public let targetPosition: Position?   // The actual resource position (for trees, ore, etc.)
    public let type: WorkTargetType
    public let priority: ResourceNeed

    public init(position: Position, type: WorkTargetType, priority: ResourceNeed = .normal, targetPosition: Position? = nil) {
        self.position = position
        self.targetPosition = targetPosition
        self.type = type
        self.priority = priority
    }
}

/// Types of work targets
public enum WorkTargetType: Sendable {
    case tree           // Chop for logs
    case stone          // Mine for stone blocks
    case ore            // Mine for metal ore
    case shrub          // Gather plants
    case water          // Fishing spot
    case huntable(UInt64)  // Animal to hunt (unit ID)
    case workshop(WorkshopType)  // Crafting at workshop
}

// MARK: - Colony Needs Assessment

/// Assessment of current colony resource needs
public struct ColonyNeeds: Sendable {
    public var foodNeed: ResourceNeed = .normal
    public var drinkNeed: ResourceNeed = .normal
    public var woodNeed: ResourceNeed = .normal
    public var stoneNeed: ResourceNeed = .normal
    public var oreNeed: ResourceNeed = .normal
    public var plantNeed: ResourceNeed = .normal

    /// Food/drink per orc thresholds
    public static let criticalFoodPerOrc = 1
    public static let lowFoodPerOrc = 3
    public static let adequateFoodPerOrc = 5

    public static let criticalDrinkPerOrc = 1
    public static let lowDrinkPerOrc = 3
    public static let adequateDrinkPerOrc = 5

    /// Material thresholds (absolute)
    public static let criticalWood = 5
    public static let lowWood = 15
    public static let adequateWood = 30

    public static let criticalStone = 5
    public static let lowStone = 20
    public static let adequateStone = 50

    public static let criticalOre = 0
    public static let lowOre = 10
    public static let adequateOre = 25

    public init(
        foodNeed: ResourceNeed = .normal,
        drinkNeed: ResourceNeed = .normal,
        woodNeed: ResourceNeed = .normal,
        stoneNeed: ResourceNeed = .normal,
        oreNeed: ResourceNeed = .normal,
        plantNeed: ResourceNeed = .normal
    ) {
        self.foodNeed = foodNeed
        self.drinkNeed = drinkNeed
        self.woodNeed = woodNeed
        self.stoneNeed = stoneNeed
        self.oreNeed = oreNeed
        self.plantNeed = plantNeed
    }
}

// MARK: - Statistics

/// Statistics for autonomous work generation
public struct AutonomousWorkStats: Sendable {
    public var chopJobsCreated: Int = 0
    public var mineJobsCreated: Int = 0
    public var gatherJobsCreated: Int = 0
    public var huntJobsCreated: Int = 0
    public var fishJobsCreated: Int = 0
    public var cookJobsCreated: Int = 0
    public var craftJobsCreated: Int = 0

    public var totalJobsCreated: Int {
        chopJobsCreated + mineJobsCreated + gatherJobsCreated +
        huntJobsCreated + fishJobsCreated + cookJobsCreated + craftJobsCreated
    }

    public init(
        chopJobsCreated: Int = 0,
        mineJobsCreated: Int = 0,
        gatherJobsCreated: Int = 0,
        huntJobsCreated: Int = 0,
        fishJobsCreated: Int = 0,
        cookJobsCreated: Int = 0,
        craftJobsCreated: Int = 0
    ) {
        self.chopJobsCreated = chopJobsCreated
        self.mineJobsCreated = mineJobsCreated
        self.gatherJobsCreated = gatherJobsCreated
        self.huntJobsCreated = huntJobsCreated
        self.fishJobsCreated = fishJobsCreated
        self.cookJobsCreated = cookJobsCreated
        self.craftJobsCreated = craftJobsCreated
    }
}
