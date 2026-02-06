// MARK: - Memory System
// Persistent episodic, semantic, and emotional memory for units

import Foundation

// MARK: - Memory Event Types

/// Types of events that can be recorded as memories
public enum MemoryEventType: String, Sendable, CaseIterable {
    // Social
    case conversationWith = "had a conversation"
    case argumentWith = "had an argument"
    case madeNewFriend = "made a new friend"
    case lostFriend = "lost a friend"
    case marriedTo = "got married"
    case heardGossipAbout = "heard gossip"

    // Combat
    case attackedBy = "was attacked"
    case killedEnemy = "killed an enemy"
    case witnessedDeath = "witnessed a death"
    case wasInjured = "was injured"
    case nearDeath = "nearly died"

    // Needs/Environment
    case starvedNearly = "nearly starved"
    case sleptOutside = "slept outside"
    case foundFood = "found food"
    case foundWater = "found water"

    // Work/Achievement
    case completedTask = "completed a task"
    case learnedSkill = "learned a skill"
    case builtStructure = "built a structure"

    // Seasonal/Environmental
    case survivedWinter = "survived winter"
    case enjoyedSpring = "enjoyed spring"

    /// Base salience for this event type (1-10)
    public var baseSalience: Int {
        switch self {
        case .conversationWith: return 3
        case .argumentWith: return 5
        case .madeNewFriend: return 7
        case .lostFriend: return 8
        case .marriedTo: return 10
        case .heardGossipAbout: return 4

        case .attackedBy: return 8
        case .killedEnemy: return 9
        case .witnessedDeath: return 9
        case .wasInjured: return 7
        case .nearDeath: return 10

        case .starvedNearly: return 6
        case .sleptOutside: return 3
        case .foundFood: return 2
        case .foundWater: return 2

        case .completedTask: return 4
        case .learnedSkill: return 5
        case .builtStructure: return 6

        case .survivedWinter: return 7
        case .enjoyedSpring: return 4
        }
    }

    /// Emotional valence for this event type (-5 to +5)
    public var emotionalValence: Int {
        switch self {
        case .conversationWith: return 2
        case .argumentWith: return -3
        case .madeNewFriend: return 4
        case .lostFriend: return -4
        case .marriedTo: return 5
        case .heardGossipAbout: return 1

        case .attackedBy: return -4
        case .killedEnemy: return -1
        case .witnessedDeath: return -5
        case .wasInjured: return -3
        case .nearDeath: return -5

        case .starvedNearly: return -3
        case .sleptOutside: return -2
        case .foundFood: return 2
        case .foundWater: return 2

        case .completedTask: return 3
        case .learnedSkill: return 3
        case .builtStructure: return 4

        case .survivedWinter: return 2
        case .enjoyedSpring: return 3
        }
    }
}

// MARK: - Episodic Memory

/// A specific event memory
public struct EpisodicMemory: Sendable, Identifiable {
    public let id: UInt64
    public let eventType: MemoryEventType
    public let tick: UInt64
    public let involvedEntityIds: [UInt64]
    public let involvedNames: [String]
    public let location: Position
    public var salience: Int
    public var recallCount: Int
    public let emotionalValence: Int
    public var detail: String

    public init(
        id: UInt64,
        eventType: MemoryEventType,
        tick: UInt64,
        involvedEntityIds: [UInt64] = [],
        involvedNames: [String] = [],
        location: Position,
        salience: Int? = nil,
        emotionalValence: Int? = nil,
        detail: String = ""
    ) {
        self.id = id
        self.eventType = eventType
        self.tick = tick
        self.involvedEntityIds = involvedEntityIds
        self.involvedNames = involvedNames
        self.location = location
        self.salience = salience ?? eventType.baseSalience
        self.recallCount = 0
        self.emotionalValence = emotionalValence ?? eventType.emotionalValence
        self.detail = detail.isEmpty ? eventType.rawValue : detail
    }
}

// MARK: - Semantic Memory

/// Categories for semantic (belief) memories
public enum SemanticCategory: String, Sendable, CaseIterable {
    case dangerAssessment = "danger"
    case socialKnowledge = "social"
    case locationKnowledge = "location"
    case skillKnowledge = "skill"
}

/// A distilled belief formed from repeated experiences
public struct SemanticMemory: Sendable, Identifiable {
    public let id: UInt64
    public let belief: String
    public let category: SemanticCategory
    public var confidence: Int
    public let formedAt: UInt64
    public var lastReinforced: UInt64
    public var evidenceCount: Int

    public init(
        id: UInt64,
        belief: String,
        category: SemanticCategory,
        confidence: Int = 30,
        formedAt: UInt64,
        evidenceCount: Int = 1
    ) {
        self.id = id
        self.belief = belief
        self.category = category
        self.confidence = confidence
        self.formedAt = formedAt
        self.lastReinforced = formedAt
        self.evidenceCount = evidenceCount
    }
}

// MARK: - Emotional Association

/// An emotional link between this unit and another entity
public struct EmotionalAssociation: Sendable {
    public let entityId: UInt64
    public let entityName: String
    public var feeling: Int // -100 to +100
    public var lastUpdated: UInt64

    public init(entityId: UInt64, entityName: String, feeling: Int = 0, lastUpdated: UInt64) {
        self.entityId = entityId
        self.entityName = entityName
        self.feeling = max(-100, min(100, feeling))
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Memory Store

/// Per-unit memory storage
public struct MemoryStore: Sendable {
    public var episodic: [EpisodicMemory] = []
    public var semantic: [SemanticMemory] = []
    public var emotionalAssociations: [UInt64: EmotionalAssociation] = [:]
    public var shortTermBuffer: [EpisodicMemory] = []
    public var consolidationCount: Int = 0
    private var nextMemoryId: UInt64 = 1

    // Capacity limits
    private let maxEpisodic = 100
    private let maxSemantic = 30
    private let maxEmotional = 50
    private let maxShortTerm = 10

    public init() {}

    // MARK: - Recording

    /// Record a new event into the short-term buffer
    public mutating func recordEvent(
        type: MemoryEventType,
        tick: UInt64,
        entities: [UInt64] = [],
        names: [String] = [],
        location: Position,
        detail: String = ""
    ) {
        let memory = EpisodicMemory(
            id: nextMemoryId,
            eventType: type,
            tick: tick,
            involvedEntityIds: entities,
            involvedNames: names,
            location: location,
            detail: detail
        )
        nextMemoryId += 1

        shortTermBuffer.append(memory)

        // Overflow: drop lowest salience
        if shortTermBuffer.count > maxShortTerm {
            if let minIdx = shortTermBuffer.indices.min(by: { shortTermBuffer[$0].salience < shortTermBuffer[$1].salience }) {
                shortTermBuffer.remove(at: minIdx)
            }
        }
    }

    // MARK: - Consolidation (called during sleep)

    /// Consolidate short-term buffer into long-term memory
    public mutating func consolidate(personality: Personality, currentTick: UInt64) {
        consolidationCount += 1
        print("[MEMORY] Consolidation #\(consolidationCount) at tick \(currentTick): \(shortTermBuffer.count) buffer → episodic")
        // 1. Move buffer → episodic
        episodic.append(contentsOf: shortTermBuffer)
        shortTermBuffer.removeAll()

        // 2. Pattern detection: form semantic memories from repeated patterns
        formSemanticMemories(currentTick: currentTick)

        // 3. Update emotional associations from recent episodic memories
        updateEmotionalAssociations(currentTick: currentTick)

        // 4. Decay old episodic salience
        for i in episodic.indices {
            let age = currentTick - episodic[i].tick
            if age > 5000 {
                episodic[i].salience -= 1
            }
        }

        // Prune memories with salience <= 0
        episodic.removeAll { $0.salience <= 0 }

        // 5. Capacity enforcement
        if episodic.count > maxEpisodic {
            episodic.sort { $0.salience > $1.salience }
            episodic = Array(episodic.prefix(maxEpisodic))
        }

        if semantic.count > maxSemantic {
            semantic.sort { $0.confidence > $1.confidence }
            semantic = Array(semantic.prefix(maxSemantic))
        }

        if emotionalAssociations.count > maxEmotional {
            // Drop oldest
            let sorted = emotionalAssociations.sorted { $0.value.lastUpdated > $1.value.lastUpdated }
            emotionalAssociations = Dictionary(uniqueKeysWithValues: sorted.prefix(maxEmotional).map { ($0.key, $0.value) })
        }
    }

    /// Detect patterns in episodic memories and form semantic beliefs
    private mutating func formSemanticMemories(currentTick: UInt64) {
        // Group recent episodic memories by (eventType, entity)
        var patterns: [String: (count: Int, eventType: MemoryEventType, entityName: String)] = [:]

        for memory in episodic {
            for (i, entityId) in memory.involvedEntityIds.enumerated() {
                let key = "\(memory.eventType.rawValue)_\(entityId)"
                let name = i < memory.involvedNames.count ? memory.involvedNames[i] : "unknown"
                if var existing = patterns[key] {
                    existing.count += 1
                    patterns[key] = existing
                } else {
                    patterns[key] = (count: 1, eventType: memory.eventType, entityName: name)
                }
            }

            // Also track event types without specific entities
            let typeKey = "type_\(memory.eventType.rawValue)"
            if var existing = patterns[typeKey] {
                existing.count += 1
                patterns[typeKey] = existing
            } else {
                patterns[typeKey] = (count: 1, eventType: memory.eventType, entityName: "")
            }
        }

        // Form beliefs from patterns with 3+ occurrences
        for (_, pattern) in patterns where pattern.count >= 3 {
            let belief: String
            let category: SemanticCategory

            switch pattern.eventType {
            case .attackedBy:
                if !pattern.entityName.isEmpty {
                    belief = "\(pattern.entityName) is dangerous"
                } else {
                    belief = "the world is dangerous"
                }
                category = .dangerAssessment
            case .conversationWith, .madeNewFriend:
                if !pattern.entityName.isEmpty {
                    belief = "\(pattern.entityName) is a good companion"
                } else {
                    belief = "socializing is rewarding"
                }
                category = .socialKnowledge
            case .argumentWith:
                if !pattern.entityName.isEmpty {
                    belief = "\(pattern.entityName) is difficult"
                } else {
                    belief = "arguments happen often"
                }
                category = .socialKnowledge
            case .completedTask, .builtStructure:
                belief = "hard work pays off"
                category = .skillKnowledge
            case .witnessedDeath:
                belief = "death is common here"
                category = .dangerAssessment
            case .killedEnemy:
                belief = "I can handle myself in a fight"
                category = .skillKnowledge
            case .starvedNearly:
                belief = "food can be scarce"
                category = .locationKnowledge
            case .sleptOutside:
                belief = "need better shelter"
                category = .locationKnowledge
            case .survivedWinter:
                belief = "winters are harsh"
                category = .dangerAssessment
            default:
                continue
            }

            // Check if we already have this belief
            if let idx = semantic.firstIndex(where: { $0.belief == belief }) {
                semantic[idx].confidence = min(100, semantic[idx].confidence + 10)
                semantic[idx].lastReinforced = currentTick
                semantic[idx].evidenceCount += 1
            } else {
                let mem = SemanticMemory(
                    id: nextMemoryId,
                    belief: belief,
                    category: category,
                    confidence: 30 + pattern.count * 10,
                    formedAt: currentTick,
                    evidenceCount: pattern.count
                )
                nextMemoryId += 1
                semantic.append(mem)
            }
        }
    }

    /// Update emotional associations based on recent episodic memories
    private mutating func updateEmotionalAssociations(currentTick: UInt64) {
        // Sum emotional valences from episodic memories per entity
        var deltas: [UInt64: (delta: Int, name: String)] = [:]

        for memory in episodic {
            for (i, entityId) in memory.involvedEntityIds.enumerated() {
                let name = i < memory.involvedNames.count ? memory.involvedNames[i] : "unknown"
                if var existing = deltas[entityId] {
                    existing.delta += memory.emotionalValence
                    deltas[entityId] = existing
                } else {
                    deltas[entityId] = (delta: memory.emotionalValence, name: name)
                }
            }
        }

        for (entityId, info) in deltas {
            if var assoc = emotionalAssociations[entityId] {
                assoc.feeling = max(-100, min(100, assoc.feeling + info.delta))
                assoc.lastUpdated = currentTick
                emotionalAssociations[entityId] = assoc
            } else {
                emotionalAssociations[entityId] = EmotionalAssociation(
                    entityId: entityId,
                    entityName: info.name,
                    feeling: max(-100, min(100, info.delta * 5)),
                    lastUpdated: currentTick
                )
            }
        }
    }

    // MARK: - Recall

    /// Recall memories about a specific entity
    public mutating func recall(about entityId: UInt64) -> [EpisodicMemory] {
        var results: [EpisodicMemory] = []
        for i in episodic.indices {
            if episodic[i].involvedEntityIds.contains(entityId) {
                episodic[i].recallCount += 1
                results.append(episodic[i])
            }
        }
        return results.sorted { $0.salience > $1.salience }
    }

    /// Recall memories by event type
    public func recall(type: MemoryEventType) -> [EpisodicMemory] {
        episodic.filter { $0.eventType == type }
            .sorted { $0.salience > $1.salience }
    }

    /// Recall most recent episodic memories (includes short-term buffer)
    public func recallRecent(limit: Int = 5) -> [EpisodicMemory] {
        let all = episodic + shortTermBuffer
        return Array(all.sorted { $0.tick > $1.tick }.prefix(limit))
    }

    /// Get feeling about a specific entity
    public func getFeeling(about entityId: UInt64) -> Int? {
        emotionalAssociations[entityId]?.feeling
    }

    /// Update feeling about an entity
    public mutating func updateFeeling(about entityId: UInt64, name: String, delta: Int, tick: UInt64) {
        if var assoc = emotionalAssociations[entityId] {
            assoc.feeling = max(-100, min(100, assoc.feeling + delta))
            assoc.lastUpdated = tick
            emotionalAssociations[entityId] = assoc
        } else {
            emotionalAssociations[entityId] = EmotionalAssociation(
                entityId: entityId,
                entityName: name,
                feeling: max(-100, min(100, delta)),
                lastUpdated: tick
            )
        }
    }

    /// Find a matching semantic belief
    public func getBelief(category: SemanticCategory, matching keyword: String) -> SemanticMemory? {
        semantic.first { $0.category == category && $0.belief.contains(keyword) }
    }

    // MARK: - Periodic Thinking

    /// Periodic rumination: pick a random salient memory, may generate a mood thought
    public mutating func think(personality: Personality, currentTick: UInt64) -> ThoughtType? {
        // Need some memories to think about (long-term or buffer)
        let allMemories = episodic + shortTermBuffer
        guard !allMemories.isEmpty else { return nil }

        // Weighted random pick by salience
        let totalSalience = allMemories.reduce(0) { $0 + max(1, $1.salience) }
        var roll = Int.random(in: 0..<totalSalience)

        var picked: EpisodicMemory?
        for memory in allMemories {
            roll -= max(1, memory.salience)
            if roll < 0 {
                picked = memory
                break
            }
        }
        // Increment recall count if it's in long-term episodic
        if let picked = picked, let idx = episodic.firstIndex(where: { $0.id == picked.id }) {
            episodic[idx].recallCount += 1
        }

        guard let memory = picked else { return nil }

        let anxiety = personality.value(for: .anxiety)
        let cheerfulness = personality.value(for: .cheerfulness)

        // Negative memory rumination
        if memory.emotionalValence < -2 && anxiety > 60 {
            switch memory.eventType {
            case .attackedBy, .wasInjured, .nearDeath:
                return .wasAttacked
            case .witnessedDeath:
                return .sawDeath
            case .lostFriend:
                return .friendDied
            case .argumentWith:
                return .wasLonely
            case .starvedNearly:
                return .wasHungry
            case .sleptOutside:
                return .sleptOnGround
            default:
                return nil
            }
        }

        // Positive memory reminiscence
        if memory.emotionalValence > 2 && cheerfulness > 60 {
            switch memory.eventType {
            case .conversationWith, .madeNewFriend:
                return .talkedWithFriend
            case .marriedTo:
                return .madeFriend
            case .completedTask, .builtStructure:
                return .didGoodWork
            case .enjoyedSpring:
                return .sawNature
            default:
                return nil
            }
        }

        return nil
    }

    // MARK: - Summary for Display

    /// Get the highest-salience memory description (includes buffer)
    public var topMemoryDescription: String? {
        let all = episodic + shortTermBuffer
        guard let top = all.max(by: { $0.salience < $1.salience }) else { return nil }
        let names = top.involvedNames.joined(separator: ", ")
        if names.isEmpty {
            return top.detail
        }
        return "\(top.detail) (\(names))"
    }

    /// Total episodic memory count (buffer + long-term)
    public var totalEpisodicCount: Int {
        shortTermBuffer.count + episodic.count
    }

    /// Get top positive emotional associations
    public func topPositiveAssociations(limit: Int = 3) -> [EmotionalAssociation] {
        Array(emotionalAssociations.values
            .filter { $0.feeling > 0 }
            .sorted { $0.feeling > $1.feeling }
            .prefix(limit))
    }

    /// Get top negative emotional associations
    public func topNegativeAssociations(limit: Int = 3) -> [EmotionalAssociation] {
        Array(emotionalAssociations.values
            .filter { $0.feeling < 0 }
            .sorted { $0.feeling < $1.feeling }
            .prefix(limit))
    }

    /// Get top beliefs by confidence
    public func topBeliefs(limit: Int = 3) -> [SemanticMemory] {
        Array(semantic.sorted { $0.confidence > $1.confidence }.prefix(limit))
    }
}
