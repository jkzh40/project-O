// MARK: - Simulation Types
// Data types used by the Simulation class

import Foundation

// MARK: - Simulation Statistics

/// Statistics tracked during simulation
public struct SimulationStats: Sendable {
    public var totalDeaths: Int = 0
    public var totalKills: Int = 0
    public var totalCombatDamage: Int = 0
    public var totalJobsCompleted: Int = 0
    public var totalConversations: Int = 0
    public var totalMarriages: Int = 0
    public var hostileSpawns: Int = 0
    public var haulJobsGenerated: Int = 0
    public var mealsEaten: Int = 0
    public var drinksDrank: Int = 0
    public var migrants: Int = 0
    public var births: Int = 0

    // Autonomous work stats
    public var treesChopped: Int = 0
    public var tilesMinedSIM: Int = 0
    public var plantsGathered: Int = 0
    public var fishCaught: Int = 0
    public var animalsHunted: Int = 0
    public var mealsCookedSIM: Int = 0
    public var drinksBrewedSIM: Int = 0

    public init(
        totalDeaths: Int = 0,
        totalKills: Int = 0,
        totalCombatDamage: Int = 0,
        totalJobsCompleted: Int = 0,
        totalConversations: Int = 0,
        totalMarriages: Int = 0,
        hostileSpawns: Int = 0,
        haulJobsGenerated: Int = 0,
        mealsEaten: Int = 0,
        drinksDrank: Int = 0,
        migrants: Int = 0,
        births: Int = 0,
        treesChopped: Int = 0,
        tilesMinedSIM: Int = 0,
        plantsGathered: Int = 0,
        fishCaught: Int = 0,
        animalsHunted: Int = 0,
        mealsCookedSIM: Int = 0,
        drinksBrewedSIM: Int = 0
    ) {
        self.totalDeaths = totalDeaths
        self.totalKills = totalKills
        self.totalCombatDamage = totalCombatDamage
        self.totalJobsCompleted = totalJobsCompleted
        self.totalConversations = totalConversations
        self.totalMarriages = totalMarriages
        self.hostileSpawns = hostileSpawns
        self.haulJobsGenerated = haulJobsGenerated
        self.mealsEaten = mealsEaten
        self.drinksDrank = drinksDrank
        self.migrants = migrants
        self.births = births
        self.treesChopped = treesChopped
        self.tilesMinedSIM = tilesMinedSIM
        self.plantsGathered = plantsGathered
        self.fishCaught = fishCaught
        self.animalsHunted = animalsHunted
        self.mealsCookedSIM = mealsCookedSIM
        self.drinksBrewedSIM = drinksBrewedSIM
    }
}

// MARK: - Simulation Events

/// Events that can occur during simulation for logging/display
public enum SimulationEvent: Sendable, CustomStringConvertible {
    case unitSpawned(unitId: UInt64, name: String)
    case unitDied(unitId: UInt64, cause: String)
    case unitAction(unitId: UInt64, unitName: String, action: String)
    case unitSeeking(unitId: UInt64, unitName: String, target: String)
    case combat(attackerName: String, defenderName: String, damage: Int, damageType: String, weapon: String, critical: Bool, killed: Bool)
    case social(unit1Name: String, unit2Name: String, message: String)
    case milestone(tick: UInt64, message: String)
    case seasonChanged(season: Season, year: Int)

    public var description: String {
        switch self {
        case .unitSpawned(_, let name):
            return "\(name) arrived"
        case .unitDied(_, let cause):
            return cause
        case .unitAction(_, let unitName, let action):
            return "\(unitName) \(action)"
        case .unitSeeking(_, let unitName, let target):
            return "\(unitName) seeking \(target)"
        case .combat(let attackerName, let defenderName, let damage, let damageType, let weapon, let critical, let killed):
            var msg = "\(attackerName)"
            if critical {
                msg += " CRIT"
            }
            msg += " hit \(defenderName) for \(damage) \(damageType)"
            if !weapon.isEmpty {
                msg += " (\(weapon))"
            }
            if killed {
                msg += " [KILLED]"
            }
            return msg
        case .social(let unit1Name, let unit2Name, let message):
            return "\(unit1Name) & \(unit2Name): \(message)"
        case .milestone(_, let message):
            return message
        case .seasonChanged(let season, let year):
            return "\(season) of Year \(year) has begun"
        }
    }

    /// Whether this is an important event (for highlighting)
    public var isImportant: Bool {
        switch self {
        case .unitDied, .milestone, .seasonChanged:
            return true
        case .combat(_, _, _, _, _, _, let killed) where killed:
            return true
        case .combat(_, _, _, _, _, let critical, _) where critical:
            return true
        case .social(_, _, let message) where message.contains("married"):
            return true
        default:
            return false
        }
    }
}

// MARK: - Active Conversation

/// Represents a multi-turn conversation currently being displayed with speech bubbles
public struct ActiveConversation: Sendable {
    public let participantIds: [UInt64]
    public let participantNames: [UInt64: String]
    public private(set) var eavesdropperIds: Set<UInt64>
    public let topic: String
    public let isSuccess: Bool
    public let startTick: UInt64
    public let exchanges: [ConversationExchange]
    public let ticksPerExchange: UInt64

    public init(
        participantIds: [UInt64],
        participantNames: [UInt64: String],
        eavesdropperIds: Set<UInt64> = [],
        topic: String,
        isSuccess: Bool,
        startTick: UInt64,
        exchanges: [ConversationExchange],
        ticksPerExchange: UInt64 = 10
    ) {
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.eavesdropperIds = eavesdropperIds
        self.topic = topic
        self.isSuccess = isSuccess
        self.startTick = startTick
        self.exchanges = exchanges
        self.ticksPerExchange = ticksPerExchange
    }

    /// Total duration of the conversation in ticks
    public var totalDuration: UInt64 {
        UInt64(exchanges.count) * ticksPerExchange
    }

    /// Which exchange index is active at the given tick
    public func currentExchangeIndex(at tick: UInt64) -> Int {
        let elapsed = tick - startTick
        return min(Int(elapsed / ticksPerExchange), exchanges.count - 1)
    }

    /// The current exchange at the given tick, or nil if conversation is complete
    public func currentExchange(at tick: UInt64) -> ConversationExchange? {
        guard !isComplete(at: tick) else { return nil }
        let idx = currentExchangeIndex(at: tick)
        guard idx >= 0 && idx < exchanges.count else { return nil }
        return exchanges[idx]
    }

    /// Whether the conversation has finished all exchanges
    public func isComplete(at tick: UInt64) -> Bool {
        tick - startTick >= totalDuration
    }

    /// Current dialogue line for a given participant at the given tick
    public func lineForParticipant(_ unitId: UInt64, at tick: UInt64) -> String {
        guard !isComplete(at: tick) else { return "" }
        let idx = currentExchangeIndex(at: tick)
        for i in stride(from: idx, through: 0, by: -1) {
            if exchanges[i].speakerId == unitId {
                return exchanges[i].line
            }
        }
        return ""
    }

    /// Whether a given participant is the active speaker at the given tick
    public func isSpeaking(_ unitId: UInt64, at tick: UInt64) -> Bool {
        guard let exchange = currentExchange(at: tick) else { return false }
        return exchange.speakerId == unitId
    }

    /// Promote an eavesdropper to participant (they get relationship/mood benefits)
    public mutating func promoteEavesdropper(_ unitId: UInt64) {
        eavesdropperIds.remove(unitId)
    }
}
