// MARK: - Core Enumerations for Orc Outpost Simulation

import Foundation

// MARK: - Unit States

/// Primary states a unit can be in
public enum UnitState: String, CaseIterable, Sendable {
    case idle
    case moving
    case working
    case eating
    case drinking
    case sleeping
    case socializing
    case fighting
    case fleeing
    case unconscious
    case dead
}

// MARK: - Needs

/// Types of needs that drive unit behavior
public enum NeedType: String, CaseIterable, Sendable {
    case hunger
    case thirst
    case drowsiness
    case social
    case occupation
    case creativity
    case martial
}

// MARK: - Direction

/// Cardinal and intercardinal directions for movement and facing
public enum Direction: Int, CaseIterable, Sendable {
    case north = 0
    case northeast = 1
    case east = 2
    case southeast = 3
    case south = 4
    case southwest = 5
    case west = 6
    case northwest = 7

    /// Direction offset as (dx, dy)
    public var offset: (x: Int, y: Int) {
        switch self {
        case .north: return (0, -1)
        case .northeast: return (1, -1)
        case .east: return (1, 0)
        case .southeast: return (1, 1)
        case .south: return (0, 1)
        case .southwest: return (-1, 1)
        case .west: return (-1, 0)
        case .northwest: return (-1, -1)
        }
    }

    /// Returns the opposite direction
    public var opposite: Direction {
        Direction(rawValue: (rawValue + 4) % 8)!
    }
}

// MARK: - Items

/// Types of items that can exist in the world
public enum ItemType: String, CaseIterable, Sendable {
    // Food & Drink
    case food
    case drink
    case rawMeat
    case plant

    // Furniture
    case bed
    case table
    case chair
    case door
    case barrel
    case bin

    // Tools
    case pickaxe
    case axe

    // Materials
    case log
    case stone
    case ore
}

// MARK: - Jobs

/// Types of jobs units can perform
public enum JobType: String, CaseIterable, Sendable {
    // Mining & Digging
    case mine           // Mine out rock/ore
    case dig            // Dig soil

    // Woodworking
    case chopTree       // Cut down trees

    // Construction
    case construct      // Build structures
    case buildWorkshop  // Build a workshop

    // Crafting
    case craft          // Create items at workshop

    // Hauling & Storage
    case haul           // Move items
    case store          // Place items in stockpile

    // Food Production
    case cook           // Prepare food
    case brew           // Make drinks

    // Farming
    case plant          // Plant seeds
    case harvest        // Gather crops

    // Hunting & Fishing
    case hunt           // Hunt animals
    case fish           // Catch fish
}

// MARK: - Personality Facets

/// Personality traits that influence behavior (0-100 scale)
public enum PersonalityFacet: String, CaseIterable, Sendable {
    case gregariousness      // Desire for social interaction
    case anxiety             // Prone to worry
    case cheerfulness        // Tendency toward happiness
    case bravery             // Courage in face of danger
    case activityLevel       // Energy and initiative
    case perseverance        // Persistence in tasks
    case curiosity           // Interest in exploration
    case altruism            // Willingness to help others
    case stressVulnerability // How easily stressed
    case orderliness         // Preference for organization
}

// MARK: - Skills

/// Skills that units can develop
public enum SkillType: String, CaseIterable, Sendable {
    // Labor
    case mining
    case woodcutting
    case carpentry
    case masonry
    case cooking
    case brewing
    case farming

    // Combat
    case meleeCombat
    case dodging
    case wrestling

    // Social
    case persuasion
    case leadership

    // General
    case swimming
    case climbing
    case observation
}

// MARK: - Physical Attributes

/// Physical attributes affecting body capabilities
public enum PhysicalAttribute: String, CaseIterable, Sendable {
    case strength
    case agility
    case toughness
    case endurance
    case recuperation
    case diseaseResistance
}

// MARK: - Mental Attributes

/// Mental attributes affecting mind capabilities
public enum MentalAttribute: String, CaseIterable, Sendable {
    case analyticalAbility
    case focus
    case willpower
    case creativity
    case intuition
    case patience
    case memory
    case spatialSense
    case empathy
    case socialAwareness
}

// MARK: - Item Quality

/// Quality levels for crafted items
public enum ItemQuality: Int, CaseIterable, Sendable, Comparable {
    case standard = 0
    case wellCrafted = 1
    case finelyCrafted = 2
    case superior = 3
    case exceptional = 4
    case masterwork = 5
    case artifact = 6

    /// Value multiplier for this quality level
    public var multiplier: Double {
        switch self {
        case .standard: return 1.0
        case .wellCrafted: return 1.2
        case .finelyCrafted: return 1.4
        case .superior: return 1.6
        case .exceptional: return 1.8
        case .masterwork: return 2.0
        case .artifact: return 120.0
        }
    }

    public static func < (lhs: ItemQuality, rhs: ItemQuality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Job Priority

/// Priority levels for job assignment
public enum JobPriority: Int, CaseIterable, Sendable, Comparable {
    case highest = 1
    case high = 2
    case aboveNormal = 3
    case normal = 4
    case belowNormal = 5
    case low = 6
    case lowest = 7

    public static func < (lhs: JobPriority, rhs: JobPriority) -> Bool {
        // Lower raw value = higher priority
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Idle Activities

/// Activities units can do when idle
public enum IdleActivity: String, CaseIterable, Sendable {
    case wander
    case socialize
    case rest
    case selfTrain
    case appreciateArt
    case contemplateNature
    case reminisce
}

// MARK: - Season

/// Seasons of the in-game year (4 seasons, 3 months each)
public enum Season: Int, CaseIterable, Sendable, CustomStringConvertible {
    case spring = 0
    case summer = 1
    case autumn = 2
    case winter = 3

    public var description: String {
        switch self {
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn"
        case .winter: return "Winter"
        }
    }

    /// The next season in the cycle
    public var next: Season {
        Season(rawValue: (rawValue + 1) % 4)!
    }
}

// MARK: - Time of Day

/// Periods within a day, derived from hour and seasonal daylight
public enum TimeOfDay: String, Sendable {
    case dawn = "dawn"
    case morning = "morning"
    case afternoon = "afternoon"
    case dusk = "dusk"
    case evening = "evening"
    case night = "night"
}
