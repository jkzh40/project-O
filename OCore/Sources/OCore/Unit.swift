// MARK: - Unit Model for Orc Outpost Simulation

import Foundation

/// A unit in the simulation (orc, creature, etc.)
public struct Unit: Sendable, Identifiable {
    // MARK: - Identity

    public let id: UInt64
    public var name: UnitName

    // MARK: - Position & Movement

    public var position: Position
    public var facing: Direction
    public var currentPath: [Position]?

    // MARK: - State

    public var state: UnitState
    public var actionCounter: Int

    // MARK: - Needs (counters that increment each tick)

    public var hunger: Int
    public var thirst: Int
    public var drowsiness: Int

    // MARK: - Personality

    public var personality: Personality

    // MARK: - Skills

    public var skills: [SkillType: SkillEntry]

    // MARK: - Physical Attributes

    public var physicalAttributes: [PhysicalAttribute: AttributeValue]

    // MARK: - Mental Attributes

    public var mentalAttributes: [MentalAttribute: AttributeValue]

    // MARK: - Health & Combat

    public var health: Health

    // MARK: - Mood & Happiness

    public var mood: MoodTracker

    // MARK: - Labor Preferences

    public var laborPreferences: LaborPreferences

    // MARK: - Creature Type

    public var creatureType: CreatureType

    // MARK: - Initialization

    /// Creates a unit with default values and random personality
    public init(
        id: UInt64 = UInt64.random(in: 0...UInt64.max),
        name: UnitName = NameGenerator.generate(),
        position: Position = Position(x: 0, y: 0, z: 0),
        facing: Direction = .south
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.facing = facing
        self.currentPath = nil

        self.state = .idle
        self.actionCounter = 0

        // Initialize needs at 0
        self.hunger = 0
        self.thirst = 0
        self.drowsiness = 0

        // Random personality
        self.personality = Personality()

        // Empty skills dictionary
        self.skills = [:]

        // Initialize physical attributes with typical orc values (1000-1250 range)
        self.physicalAttributes = [:]
        for attribute in PhysicalAttribute.allCases {
            let baseValue = Int.random(in: 1000...1250)
            self.physicalAttributes[attribute] = AttributeValue(base: baseValue)
        }

        // Initialize mental attributes with typical orc values (1000-1250 range)
        self.mentalAttributes = [:]
        for attribute in MentalAttribute.allCases {
            let baseValue = Int.random(in: 1000...1250)
            self.mentalAttributes[attribute] = AttributeValue(base: baseValue)
        }

        // Initialize health based on toughness
        let toughness = self.physicalAttributes[.toughness]?.base ?? 1000
        let maxHP = 50 + (toughness / 20)  // 100 HP at 1000 toughness
        self.health = Health(maxHP: maxHP)

        // Initialize mood based on cheerfulness
        let cheerfulness = self.personality.value(for: .cheerfulness)
        self.mood = MoodTracker(baseHappiness: 40 + cheerfulness / 2)

        // Default labor preferences (all enabled)
        self.laborPreferences = LaborPreferences()

        // Default creature type
        self.creatureType = .orc
    }

    // MARK: - Factory Method

    /// Creates a new unit with a random name and default attributes
    public static func create(at position: Position = Position(x: 0, y: 0, z: 0)) -> Unit {
        Unit(
            id: UInt64.random(in: 0...UInt64.max),
            name: NameGenerator.generate(),
            position: position
        )
    }

    // MARK: - Tick Update

    /// Updates the unit for a single tick - increments needs, decrements action counter
    public mutating func tickUpdate() {
        // Increment need counters (DF style - +1 per tick)
        hunger += 1
        thirst += 1
        drowsiness += 1

        // Decrement action counter
        if actionCounter > 0 {
            actionCounter -= 1
        }
    }

    /// Returns true if the unit can take an action this tick
    public var canAct: Bool {
        actionCounter <= 0
    }

    // MARK: - Speed System

    /// Calculates the action delay based on DF speed system
    /// Speed value determines delay: hundreds digit = full turns to skip,
    /// tens/ones = probability of extra turn
    public func calculateActionDelay() -> Int {
        let baseSpeed = SpeedConstants.defaultSpeed

        // Apply agility modifier (higher agility = faster)
        var effectiveSpeed = baseSpeed
        if let agility = physicalAttributes[.agility] {
            // Agility affects speed: higher agility reduces effective speed
            // Scale: average (1000) = no change, 2000 = 10% faster, 500 = 10% slower
            let agilityModifier = Double(agility.effective - 1000) / 10000.0
            effectiveSpeed = Int(Double(effectiveSpeed) * (1.0 - agilityModifier))
        }

        // Clamp effective speed to reasonable bounds
        effectiveSpeed = max(100, min(2000, effectiveSpeed))

        // Convert to delay using DF formula
        let fullTurns = effectiveSpeed / 100
        let remainder = effectiveSpeed % 100

        // Probabilistic extra delay
        var delay = fullTurns
        if Int.random(in: 1...100) <= remainder {
            delay += 1
        }

        return max(1, delay)
    }

    // MARK: - Need Checks

    /// Returns the most urgent critical need that should interrupt current activity, or nil
    public func checkCriticalNeeds() -> NeedType? {
        // Check in priority order: thirst > hunger > drowsiness
        if thirst >= NeedThresholds.thirstCritical {
            return .thirst
        }
        if hunger >= NeedThresholds.hungerCritical {
            return .hunger
        }
        if drowsiness >= NeedThresholds.drowsyCritical {
            return .drowsiness
        }
        return nil
    }

    /// Returns a need to consider satisfying when idle, using DF's decision thresholds
    /// Uses probabilistic check for soft thresholds (1/120 chance per tick)
    public func checkNeedConsideration() -> NeedType? {
        // Hard decision thresholds - always decide to satisfy
        if thirst >= NeedThresholds.thirstDecide {
            return .thirst
        }
        if hunger >= NeedThresholds.hungerDecide {
            return .hunger
        }
        if drowsiness >= NeedThresholds.drowsyDecide {
            return .drowsiness
        }

        // Soft consideration thresholds - 1/120 chance per tick
        let considerationChance = 120
        if Int.random(in: 1...considerationChance) == 1 {
            if thirst >= NeedThresholds.thirstConsider {
                return .thirst
            }
            if hunger >= NeedThresholds.hungerConsider {
                return .hunger
            }
            if drowsiness >= NeedThresholds.drowsyConsider {
                return .drowsiness
            }
        }

        return nil
    }

    /// Returns true if the unit should be considered dead from need deprivation
    public func checkNeedDeath() -> NeedType? {
        if thirst >= NeedThresholds.thirstDeath {
            return .thirst
        }
        if hunger >= NeedThresholds.hungerDeath {
            return .hunger
        }
        if drowsiness >= NeedThresholds.drowsyInsane {
            return .drowsiness
        }
        return nil
    }

    // MARK: - Need Satisfaction

    /// Satisfies the specified need by reducing its counter
    public mutating func satisfyNeed(_ need: NeedType) {
        switch need {
        case .thirst:
            thirst = max(0, thirst - NeedThresholds.drinkSatisfaction)
        case .hunger:
            hunger = max(0, hunger - NeedThresholds.eatSatisfaction)
        case .drowsiness:
            // Sleep recovery happens per tick, this is for immediate satisfaction
            drowsiness = max(0, drowsiness - NeedThresholds.sleepRecoveryPerTick)
        default:
            // Other need types not implemented yet
            break
        }
    }

    /// Processes sleep recovery (called each tick while sleeping)
    public mutating func processSleepRecovery() {
        drowsiness = max(0, drowsiness - NeedThresholds.sleepRecoveryPerTick)
    }

    /// Returns true if drowsiness has been fully recovered
    public var isFullyRested: Bool {
        drowsiness <= 0
    }

    // MARK: - Pathfinding & Movement

    /// Sets the movement path for the unit
    public mutating func setPath(_ path: [Position]) {
        currentPath = path
        if !path.isEmpty {
            state = .moving
        }
    }

    /// Clears the current path
    public mutating func clearPath() {
        currentPath = nil
    }

    /// Advances the unit along its current path
    /// Returns true if the unit has arrived at the destination
    @discardableResult
    public mutating func advanceOnPath() -> Bool {
        guard var path = currentPath, !path.isEmpty else {
            state = .idle
            return true
        }

        // Move to the next position in the path
        let nextPosition = path.removeFirst()

        // Update facing direction based on movement
        if let newFacing = directionTo(nextPosition) {
            facing = newFacing
        }

        position = nextPosition
        currentPath = path

        // Check if arrived at destination
        if path.isEmpty {
            currentPath = nil
            return true
        }

        return false
    }

    /// Returns the direction from current position to target position
    private func directionTo(_ target: Position) -> Direction? {
        let dx = target.x - position.x
        let dy = target.y - position.y

        // Determine direction based on offset
        switch (dx, dy) {
        case (0, -1): return .north
        case (1, -1): return .northeast
        case (1, 0): return .east
        case (1, 1): return .southeast
        case (0, 1): return .south
        case (-1, 1): return .southwest
        case (-1, 0): return .west
        case (-1, -1): return .northwest
        default: return nil
        }
    }

    /// Returns true if the unit has a path and is not at the destination
    public var isPathfinding: Bool {
        guard let path = currentPath else { return false }
        return !path.isEmpty
    }

    // MARK: - Skills

    /// Gets the skill entry for a specific skill type, creating it if needed
    public mutating func getOrCreateSkill(_ skillType: SkillType) -> SkillEntry {
        if let existing = skills[skillType] {
            return existing
        }
        let newEntry = SkillEntry(skillType: skillType)
        skills[skillType] = newEntry
        return newEntry
    }

    /// Gets the skill level for a specific skill (0 if not learned)
    public func skillLevel(for skillType: SkillType) -> Int {
        skills[skillType]?.rating ?? 0
    }

    /// Adds experience to a skill
    public mutating func addSkillExperience(_ skillType: SkillType, amount: Int) {
        if skills[skillType] == nil {
            skills[skillType] = SkillEntry(skillType: skillType)
        }
        skills[skillType]?.addExperience(amount)
    }

    // MARK: - State Management

    /// Transitions the unit to a new state
    public mutating func transition(to newState: UnitState) {
        state = newState
    }

    /// Returns true if the unit is in a state that can be interrupted
    public var canBeInterrupted: Bool {
        switch state {
        case .idle, .moving, .working, .socializing:
            return true
        case .eating, .drinking, .sleeping, .fighting, .fleeing, .unconscious, .dead:
            return false
        }
    }

    /// Returns true if the unit is alive
    public var isAlive: Bool {
        state != .dead
    }
}

// MARK: - CustomStringConvertible

extension Unit: CustomStringConvertible {
    public var description: String {
        "\(name.description) at \(position) [\(state.rawValue)]"
    }
}

// MARK: - Equatable & Hashable

extension Unit: Equatable {
    public static func == (lhs: Unit, rhs: Unit) -> Bool {
        lhs.id == rhs.id
    }
}

extension Unit: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
