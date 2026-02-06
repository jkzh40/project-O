// MARK: - Mood & Happiness System
// Tracks emotional state, stress, and mental breaks

import Foundation

// MARK: - Thought Types

/// Types of thoughts a unit can have
public enum ThoughtType: String, Sendable, CaseIterable {
    // Positive thoughts
    case ateGoodFood = "ate a fine meal"
    case drankAlcohol = "had a drink"
    case sleptWell = "slept in a bed"
    case madeFriend = "made a friend"
    case talkedWithFriend = "talked with a friend"
    case admiredRoom = "admired own room"
    case didGoodWork = "completed quality work"
    case receivedGift = "received a gift"
    case attendedParty = "attended a party"
    case sawNature = "enjoyed nature"
    case overheardConversation = "overheard an interesting conversation"

    // Negative thoughts
    case wasHungry = "was hungry"
    case wasThirsty = "was thirsty"
    case wasTired = "was tired"
    case sleptOnGround = "slept on the ground"
    case gotRained = "got rained on"
    case sawDeath = "witnessed death"
    case friendDied = "lost a friend"
    case wasAttacked = "was attacked"
    case wasInjured = "was injured"
    case hadToKill = "had to kill"
    case ateRawFood = "ate raw food"
    case lackedShelter = "lacked shelter"
    case workedTooLong = "worked too long"
    case wasLonely = "felt lonely"
    case smelledRot = "smelled something rotting"

    // Seasonal thoughts
    case enjoyedSeason = "enjoyed the season"
    case sufferedSeason = "suffering from the season"

    /// Base happiness modifier for this thought
    public var happinessModifier: Int {
        switch self {
        case .ateGoodFood: return 10
        case .drankAlcohol: return 15
        case .sleptWell: return 20
        case .madeFriend: return 25
        case .talkedWithFriend: return 10
        case .admiredRoom: return 15
        case .didGoodWork: return 20
        case .receivedGift: return 30
        case .attendedParty: return 25
        case .sawNature: return 5
        case .overheardConversation: return 5

        case .wasHungry: return -10
        case .wasThirsty: return -15
        case .wasTired: return -10
        case .sleptOnGround: return -20
        case .gotRained: return -5
        case .sawDeath: return -30
        case .friendDied: return -50
        case .wasAttacked: return -20
        case .wasInjured: return -25
        case .hadToKill: return -15
        case .ateRawFood: return -10
        case .lackedShelter: return -10
        case .workedTooLong: return -15
        case .wasLonely: return -20
        case .smelledRot: return -5
        case .enjoyedSeason: return 10
        case .sufferedSeason: return -10
        }
    }

    /// How long this thought lasts (in ticks)
    public var duration: Int {
        switch self {
        case .sawDeath, .friendDied:
            return 10000  // Long-lasting trauma
        case .madeFriend, .didGoodWork:
            return 5000   // Memorable positive events
        case .wasAttacked, .wasInjured:
            return 3000   // Lasting negative effects
        case .enjoyedSeason, .sufferedSeason:
            return 5000   // Seasonal effects
        case .overheardConversation:
            return 500    // Brief pleasant memory
        default:
            return 1000   // Normal thoughts
        }
    }

    /// Whether this is a positive thought
    public var isPositive: Bool {
        happinessModifier > 0
    }
}

// MARK: - Thought

/// A specific thought a unit has
public struct Thought: Sendable, Identifiable {
    public let id: UInt64
    public let type: ThoughtType
    public let createdAt: UInt64
    public var expiresAt: UInt64

    /// Optional source (e.g., who the friend was)
    public var source: String?

    /// Current happiness effect (may decay)
    public var currentModifier: Int

    public init(
        id: UInt64,
        type: ThoughtType,
        createdAt: UInt64,
        source: String? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.expiresAt = createdAt + UInt64(type.duration)
        self.source = source
        self.currentModifier = type.happinessModifier
    }

    /// Whether the thought has expired
    public func hasExpired(currentTick: UInt64) -> Bool {
        currentTick >= expiresAt
    }

    /// Description of the thought
    public var description: String {
        if let source = source {
            return "\(type.rawValue) (\(source))"
        }
        return type.rawValue
    }
}

// MARK: - Mental Break Types

/// Types of mental breaks that can occur under stress
public enum MentalBreakType: String, Sendable, CaseIterable {
    case minorBreak = "minor break"       // Crying, hiding
    case tantrum = "tantrum"              // Destroying items
    case berserk = "berserk"              // Attacking others
    case catatonic = "catatonic"          // Unresponsive
    case wandering = "wandering"          // Aimless wandering
    case bingeEating = "binge eating"     // Eating all food
    case bingeDrinking = "binge drinking" // Drinking all alcohol

    /// Minimum stress level to trigger this break
    public var stressThreshold: Int {
        switch self {
        case .minorBreak: return 70
        case .tantrum: return 80
        case .wandering: return 75
        case .bingeEating, .bingeDrinking: return 70
        case .catatonic: return 90
        case .berserk: return 95
        }
    }

    /// Duration of the mental break (ticks)
    public var duration: Int {
        switch self {
        case .minorBreak: return 200
        case .tantrum: return 500
        case .berserk: return 300
        case .catatonic: return 1000
        case .wandering: return 400
        case .bingeEating, .bingeDrinking: return 300
        }
    }

    /// Severity rating (higher = worse)
    public var severity: Int {
        switch self {
        case .minorBreak: return 1
        case .wandering: return 2
        case .bingeEating, .bingeDrinking: return 2
        case .tantrum: return 3
        case .catatonic: return 4
        case .berserk: return 5
        }
    }
}

// MARK: - Mental Break

/// An active mental break
public struct MentalBreak: Sendable {
    public let type: MentalBreakType
    public let startedAt: UInt64
    public var endsAt: UInt64

    public init(type: MentalBreakType, startedAt: UInt64) {
        self.type = type
        self.startedAt = startedAt
        self.endsAt = startedAt + UInt64(type.duration)
    }

    public func hasEnded(currentTick: UInt64) -> Bool {
        currentTick >= endsAt
    }
}

// MARK: - Mood State

/// Overall mood categories
public enum MoodState: String, Sendable {
    case ecstatic = "ecstatic"      // 90-100
    case happy = "happy"            // 70-89
    case content = "content"        // 50-69
    case unhappy = "unhappy"        // 30-49
    case miserable = "miserable"    // 10-29
    case breakdown = "breakdown"    // 0-9

    /// Get mood state from happiness level
    public static func from(happiness: Int) -> MoodState {
        switch happiness {
        case 90...100: return .ecstatic
        case 70..<90: return .happy
        case 50..<70: return .content
        case 30..<50: return .unhappy
        case 10..<30: return .miserable
        default: return .breakdown
        }
    }

    /// Color for display
    public var displayColor: String {
        switch self {
        case .ecstatic: return "bright_green"
        case .happy: return "green"
        case .content: return "white"
        case .unhappy: return "yellow"
        case .miserable: return "red"
        case .breakdown: return "bright_red"
        }
    }
}

// MARK: - Mood Tracker

/// Tracks a unit's emotional state
public struct MoodTracker: Sendable {
    /// Base happiness (affected by personality)
    public var baseHappiness: Int

    /// Current happiness level (0-100)
    public var happiness: Int

    /// Current stress level (0-100)
    public var stress: Int

    /// Active thoughts
    public var thoughts: [Thought]

    /// Current mental break (if any)
    public var mentalBreak: MentalBreak?

    /// ID counter for thoughts
    private var nextThoughtId: UInt64 = 1

    /// Maximum thoughts to track
    public let maxThoughts: Int = 20

    public init(baseHappiness: Int = 50) {
        self.baseHappiness = baseHappiness
        self.happiness = baseHappiness
        self.stress = 0
        self.thoughts = []
        self.mentalBreak = nil
    }

    /// Current mood state
    public var moodState: MoodState {
        MoodState.from(happiness: happiness)
    }

    /// Whether unit is having a mental break
    public var isHavingBreak: Bool {
        mentalBreak != nil
    }

    // MARK: - Thought Management

    /// Add a new thought
    public mutating func addThought(_ type: ThoughtType, currentTick: UInt64, source: String? = nil) {
        // Check if we already have this thought type recently
        if thoughts.contains(where: { $0.type == type && !$0.hasExpired(currentTick: currentTick) }) {
            return  // Don't add duplicate thoughts
        }

        let thought = Thought(
            id: nextThoughtId,
            type: type,
            createdAt: currentTick,
            source: source
        )
        nextThoughtId += 1

        thoughts.append(thought)

        // Trim if too many
        if thoughts.count > maxThoughts {
            // Remove oldest expired or lowest impact
            if let expiredIndex = thoughts.firstIndex(where: { $0.hasExpired(currentTick: currentTick) }) {
                thoughts.remove(at: expiredIndex)
            } else {
                thoughts.removeFirst()
            }
        }
    }

    /// Update mood based on current thoughts
    public mutating func updateMood(currentTick: UInt64, stressVulnerability: Int) {
        // Remove expired thoughts
        thoughts.removeAll { $0.hasExpired(currentTick: currentTick) }

        // Calculate happiness from thoughts
        var thoughtModifier = 0
        for thought in thoughts {
            // Thoughts decay over time
            let age = currentTick - thought.createdAt
            let duration = thought.expiresAt - thought.createdAt
            let decayFactor = 1.0 - (Double(age) / Double(duration) * 0.5)  // Decay to 50%
            thoughtModifier += Int(Double(thought.currentModifier) * decayFactor)
        }

        // Calculate new happiness
        let targetHappiness = max(0, min(100, baseHappiness + thoughtModifier))
        // Smooth transition (move 10% toward target)
        happiness = happiness + (targetHappiness - happiness) / 10
        happiness = max(0, min(100, happiness))

        // Calculate stress
        updateStress(stressVulnerability: stressVulnerability)

        // Check for mental break
        checkMentalBreak(currentTick: currentTick)
    }

    /// Update stress level
    private mutating func updateStress(stressVulnerability: Int) {
        // Stress increases when happiness is low
        let unhappinessContribution = max(0, 50 - happiness) / 2

        // Vulnerability affects how fast stress accumulates
        let vulnerabilityMod = Double(stressVulnerability) / 50.0

        let stressChange = Int(Double(unhappinessContribution) * vulnerabilityMod) - 5  // -5 base recovery

        stress = max(0, min(100, stress + stressChange / 10))
    }

    /// Check if a mental break should occur
    private mutating func checkMentalBreak(currentTick: UInt64) {
        // If already having a break, check if it's over
        if let currentBreak = mentalBreak {
            if currentBreak.hasEnded(currentTick: currentTick) {
                mentalBreak = nil
                stress = max(0, stress - 20)  // Recover some stress after break
            }
            return
        }

        // Check if stress is high enough for a break
        guard stress >= 70 else { return }

        // Random chance scaled by stress
        let breakChance = (stress - 60) / 2  // 5-20% chance
        guard Int.random(in: 1...100) <= breakChance else { return }

        // Determine break type based on stress level
        let possibleBreaks = MentalBreakType.allCases.filter { $0.stressThreshold <= stress }
        guard let breakType = possibleBreaks.randomElement() else { return }

        mentalBreak = MentalBreak(type: breakType, startedAt: currentTick)
    }

    // MARK: - Queries

    /// Get most impactful recent thoughts
    public func getMostImpactfulThoughts(limit: Int = 5) -> [Thought] {
        thoughts
            .sorted { abs($0.currentModifier) > abs($1.currentModifier) }
            .prefix(limit)
            .map { $0 }
    }

    /// Get recent positive thoughts
    public func getPositiveThoughts() -> [Thought] {
        thoughts.filter { $0.type.isPositive }
    }

    /// Get recent negative thoughts
    public func getNegativeThoughts() -> [Thought] {
        thoughts.filter { !$0.type.isPositive }
    }
}

// MARK: - Mood Manager

/// Manages mood for all units
@MainActor
public final class MoodManager: Sendable {
    /// Mood trackers by unit ID
    public private(set) var moods: [UInt64: MoodTracker] = [:]

    /// Recent mental breaks for logging
    public private(set) var recentBreaks: [(unitId: UInt64, break_: MentalBreak)] = []

    public init() {}

    /// Initialize mood for a unit
    public func initializeMood(
        unitId: UInt64,
        cheerfulness: Int,
        stressVulnerability: Int
    ) {
        // Base happiness influenced by cheerfulness
        let baseHappiness = 40 + (cheerfulness / 2)  // 40-90 range
        moods[unitId] = MoodTracker(baseHappiness: baseHappiness)
    }

    /// Add thought to a unit
    public func addThought(
        unitId: UInt64,
        type: ThoughtType,
        currentTick: UInt64,
        source: String? = nil
    ) {
        guard var mood = moods[unitId] else { return }
        mood.addThought(type, currentTick: currentTick, source: source)
        moods[unitId] = mood
    }

    /// Update all moods
    public func updateAll(currentTick: UInt64, stressVulnerabilities: [UInt64: Int]) {
        for (unitId, var mood) in moods {
            let vulnerability = stressVulnerabilities[unitId] ?? 50
            let hadBreak = mood.isHavingBreak

            mood.updateMood(currentTick: currentTick, stressVulnerability: vulnerability)

            // Track new mental breaks
            if mood.isHavingBreak && !hadBreak, let newBreak = mood.mentalBreak {
                recentBreaks.append((unitId: unitId, break_: newBreak))
                if recentBreaks.count > 20 {
                    recentBreaks.removeFirst()
                }
            }

            moods[unitId] = mood
        }
    }

    /// Get mood state for a unit
    public func getMoodState(unitId: UInt64) -> MoodState? {
        moods[unitId]?.moodState
    }

    /// Get happiness for a unit
    public func getHappiness(unitId: UInt64) -> Int? {
        moods[unitId]?.happiness
    }

    /// Get stress for a unit
    public func getStress(unitId: UInt64) -> Int? {
        moods[unitId]?.stress
    }

    /// Check if unit is having a mental break
    public func isHavingBreak(unitId: UInt64) -> Bool {
        moods[unitId]?.isHavingBreak ?? false
    }

    /// Get current mental break type
    public func getMentalBreak(unitId: UInt64) -> MentalBreakType? {
        moods[unitId]?.mentalBreak?.type
    }

    /// Remove mood tracking for a unit (e.g., when they die)
    public func removeMood(unitId: UInt64) {
        moods.removeValue(forKey: unitId)
    }
}
