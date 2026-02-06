// MARK: - Core Data Structures

import Foundation

// MARK: - Position

/// A 3D coordinate in the game world
public struct Position: Hashable, Sendable, CustomStringConvertible {
    public var x: Int
    public var y: Int
    public var z: Int

    public init(x: Int, y: Int, z: Int = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// Manhattan distance to another position (including z-level)
    public func distance(to other: Position) -> Int {
        abs(x - other.x) + abs(y - other.y) + abs(z - other.z)
    }

    /// Euclidean distance to another position
    public func euclideanDistance(to other: Position) -> Double {
        let dx = Double(x - other.x)
        let dy = Double(y - other.y)
        let dz = Double(z - other.z)
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    /// Whether this position is adjacent to another (including diagonals)
    public func isAdjacent(to other: Position) -> Bool {
        guard z == other.z else { return false }
        let dx = abs(x - other.x)
        let dy = abs(y - other.y)
        return dx <= 1 && dy <= 1 && (dx + dy) > 0
    }

    /// Returns neighbors in cardinal + diagonal directions on same z-level
    public func neighbors() -> [Position] {
        Direction.allCases.map { direction in
            Position(x: x + direction.offset.x, y: y + direction.offset.y, z: z)
        }
    }

    /// Returns position moved in a direction
    public func moved(in direction: Direction) -> Position {
        Position(x: x + direction.offset.x, y: y + direction.offset.y, z: z)
    }

    public var description: String {
        "(\(x), \(y), \(z))"
    }
}

// MARK: - Attribute Value

/// Represents an attribute with base, current, and max values
public struct AttributeValue: Sendable {
    public var base: Int
    public var current: Int
    public var max: Int
    public var modifier: Int

    public init(base: Int, max: Int? = nil) {
        self.base = base
        self.current = base
        self.max = max ?? base
        self.modifier = 0
    }

    /// Effective value including modifiers
    public var effective: Int {
        current + modifier
    }

    /// Attribute level description (DF-style)
    public var levelDescription: String {
        switch effective {
        case ..<200: return "Very Low"
        case 200..<450: return "Low"
        case 450..<650: return "Below Average"
        case 650..<1100: return "Average"
        case 1100..<1350: return "Above Average"
        case 1350..<1550: return "High"
        case 1550..<2000: return "Very High"
        case 2000..<3000: return "Superior"
        default: return "Extreme"
        }
    }
}

// MARK: - Skill Entry

/// Represents a unit's proficiency in a skill
public struct SkillEntry: Sendable {
    public var skillType: SkillType
    public var rating: Int  // 0-20
    public var experience: Int
    public var rustCounter: Int
    public var naturalLevel: Int  // Cannot degrade below this

    public init(skillType: SkillType, rating: Int = 0) {
        self.skillType = skillType
        self.rating = rating
        self.experience = 0
        self.rustCounter = 0
        self.naturalLevel = 0
    }

    /// XP required to reach next level
    public var xpForNextLevel: Int {
        400 + 100 * (rating + 1)
    }

    /// Adds experience and handles level up
    public mutating func addExperience(_ amount: Int) {
        experience += amount
        rustCounter = 0

        while experience >= xpForNextLevel && rating < 20 {
            experience -= xpForNextLevel
            rating += 1
        }
    }

    /// Skill level name (DF-style)
    public var levelName: String {
        switch rating {
        case 0: return "Not"
        case 1: return "Dabbling"
        case 2: return "Novice"
        case 3: return "Adequate"
        case 4: return "Competent"
        case 5: return "Skilled"
        case 6: return "Proficient"
        case 7: return "Talented"
        case 8: return "Adept"
        case 9: return "Expert"
        case 10: return "Professional"
        case 11: return "Accomplished"
        case 12: return "Great"
        case 13: return "Master"
        case 14: return "High Master"
        case 15: return "Grand Master"
        default: return "Legendary"
        }
    }
}

// MARK: - Need Instance

/// Represents a specific need and its current satisfaction level
public struct NeedInstance: Sendable {
    public var needType: NeedType
    public var counter: Int  // Increases over time, higher = more urgent
    public var strength: Int  // How strongly this need affects the unit (from personality)

    public init(needType: NeedType, strength: Int = 50) {
        self.needType = needType
        self.counter = 0
        self.strength = strength
    }

    /// Whether this need is at a critical level
    public var isCritical: Bool {
        switch needType {
        case .thirst: return counter >= NeedThresholds.thirstCritical
        case .hunger: return counter >= NeedThresholds.hungerCritical
        case .drowsiness: return counter >= NeedThresholds.drowsyCritical
        default: return false
        }
    }

    /// Whether the unit should consider satisfying this need when idle
    public var shouldConsider: Bool {
        switch needType {
        case .thirst: return counter >= NeedThresholds.thirstConsider
        case .hunger: return counter >= NeedThresholds.hungerConsider
        case .drowsiness: return counter >= NeedThresholds.drowsyConsider
        default: return false
        }
    }
}

// MARK: - Need Thresholds (Constants from DF)

public enum NeedThresholds {
    // Thirst
    public static let thirstConsider = 20_000
    public static let thirstDecide = 22_000
    public static let thirstIndicator = 25_000
    public static let thirstCritical = 35_000
    public static let thirstDehydrated = 50_000
    public static let thirstDeath = 75_000

    // Hunger
    public static let hungerConsider = 40_000
    public static let hungerDecide = 45_000
    public static let hungerIndicator = 50_000
    public static let hungerCritical = 65_000
    public static let hungerStarving = 75_000
    public static let hungerDeath = 100_000

    // Drowsiness
    public static let drowsyConsider = 50_000
    public static let drowsyDecide = 54_000
    public static let drowsyIndicator = 57_600
    public static let drowsyCritical = 150_000
    public static let drowsyInsane = 200_000

    // Satisfaction amounts
    public static let drinkSatisfaction = 50_000
    public static let eatSatisfaction = 50_000
    public static let sleepRecoveryPerTick = 19
}

// MARK: - Personality

/// A unit's personality traits
public struct Personality: Sendable {
    /// Facet values (0-100 for each)
    public var facets: [PersonalityFacet: Int]

    public init() {
        facets = [:]
        // Initialize with random values
        for facet in PersonalityFacet.allCases {
            facets[facet] = Int.random(in: 25...75)
        }
    }

    public init(facets: [PersonalityFacet: Int]) {
        self.facets = facets
    }

    public func value(for facet: PersonalityFacet) -> Int {
        facets[facet] ?? 50
    }

    public mutating func setValue(_ value: Int, for facet: PersonalityFacet) {
        facets[facet] = max(0, min(100, value))
    }
}

// MARK: - Speed Constants

public enum SpeedConstants {
    public static let defaultSpeed = 900
    public static let movementBaseTicks = 8
}

// MARK: - Time Constants

public enum TimeConstants {
    // 1 tick = 72 in-game seconds
    public static let ticksPerHour = 50
    public static let ticksPerDay = 1_200
    public static let ticksPerMonth = 33_600
    public static let ticksPerSeason = 100_800
    public static let ticksPerYear = 403_200
}

// MARK: - World Calendar

/// A calendar representation derived from a simulation tick.
/// Provides year, season, month, day, hour, minute and time-of-day.
public struct WorldCalendar: Sendable {
    public let year: Int
    public let season: Season
    public let month: Int      // 1-12
    public let day: Int        // 1-28
    public let hour: Int       // 0-23
    public let minute: Int     // 0-59

    /// Seasonal daylight hours: (dawnStart, dawnEnd, duskStart, duskEnd)
    public var seasonalDaylightHours: (dawnStart: Int, dawnEnd: Int, duskStart: Int, duskEnd: Int) {
        switch season {
        case .spring: return (5, 7, 18, 20)
        case .summer: return (4, 6, 20, 22)
        case .autumn: return (6, 8, 17, 19)
        case .winter: return (7, 9, 16, 18)
        }
    }

    /// Time of day computed from hour and seasonal daylight variation
    public var timeOfDay: TimeOfDay {
        let dl = seasonalDaylightHours
        if hour >= dl.dawnStart && hour < dl.dawnEnd { return .dawn }
        if hour >= dl.dawnEnd && hour < 12 { return .morning }
        if hour >= 12 && hour < dl.duskStart { return .afternoon }
        if hour >= dl.duskStart && hour < dl.duskEnd { return .dusk }
        if hour >= dl.duskEnd && hour < dl.duskEnd + 2 { return .evening }
        return .night
    }

    /// Whether it is currently nighttime
    public var isNight: Bool {
        let dl = seasonalDaylightHours
        return hour < dl.dawnStart || hour >= dl.duskEnd
    }

    /// Whether it is currently daytime (dawn through dusk)
    public var isDaytime: Bool {
        !isNight
    }

    /// Fractional progress through the current day (0.0 - 1.0)
    public var dayProgress: Double {
        Double(hour * 60 + minute) / (24.0 * 60.0)
    }

    /// Human-readable date string e.g. "Spring 5, Year 1"
    public var dateString: String {
        "\(season) \(day), Year \(year)"
    }

    /// Human-readable time string e.g. "14:30"
    public var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Initialize from a simulation tick
    public init(tick: UInt64) {
        let t = Int(tick)

        // Year (1-indexed)
        self.year = t / TimeConstants.ticksPerYear + 1
        let tickInYear = t % TimeConstants.ticksPerYear

        // Season (0-3)
        let seasonIndex = tickInYear / TimeConstants.ticksPerSeason
        self.season = Season(rawValue: min(seasonIndex, 3)) ?? .spring

        // Month (1-12): 3 months per season
        let tickInSeason = tickInYear % TimeConstants.ticksPerSeason
        let monthInSeason = tickInSeason / TimeConstants.ticksPerMonth
        self.month = seasonIndex * 3 + min(monthInSeason, 2) + 1

        // Day (1-28): each month is ticksPerMonth ticks
        let tickInMonth = tickInSeason % TimeConstants.ticksPerMonth
        self.day = tickInMonth / TimeConstants.ticksPerDay + 1

        // Hour (0-23) and minute (0-59)
        let tickInDay = tickInMonth % TimeConstants.ticksPerDay
        self.hour = tickInDay / TimeConstants.ticksPerHour
        let tickInHour = tickInDay % TimeConstants.ticksPerHour
        // Each tick = 72 seconds; 50 ticks per hour → minute = tickInHour * 60 / 50
        self.minute = tickInHour * 60 / TimeConstants.ticksPerHour
    }
}
