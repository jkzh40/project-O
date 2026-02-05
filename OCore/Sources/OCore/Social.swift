// MARK: - Social System
// Handles relationships, conversations, and social interactions

import Foundation

// MARK: - Relationship Types

/// Types of relationships between units
public enum RelationshipType: String, Sendable, CaseIterable {
    case stranger = "stranger"
    case acquaintance = "acquaintance"
    case friend = "friend"
    case closeFriend = "close friend"
    case lover = "lover"
    case spouse = "spouse"
    case rival = "rival"
    case enemy = "enemy"
    case parent = "parent"
    case child = "child"
    case sibling = "sibling"

    /// Whether this is a positive relationship
    public var isPositive: Bool {
        switch self {
        case .friend, .closeFriend, .lover, .spouse, .parent, .child, .sibling:
            return true
        case .acquaintance:
            return true  // Neutral-positive
        case .stranger:
            return false  // Neutral
        case .rival, .enemy:
            return false
        }
    }

    /// Minimum strength required for this relationship
    public var minimumStrength: Int {
        switch self {
        case .stranger: return Int.min
        case .acquaintance: return 10
        case .friend: return 40
        case .closeFriend: return 70
        case .lover: return 80
        case .spouse: return 90
        case .rival: return -40
        case .enemy: return -70
        case .parent, .child, .sibling: return 0  // Family is inherent
        }
    }
}

// MARK: - Relationship

/// A relationship between two units
public struct Relationship: Sendable {
    /// The other unit in this relationship
    public let targetId: UInt64

    /// Current relationship type
    public var type: RelationshipType

    /// Strength of the relationship (-100 to 100)
    public var strength: Int

    /// When the relationship was formed
    public let formedAt: UInt64

    /// Last interaction tick
    public var lastInteraction: UInt64

    /// Number of interactions
    public var interactionCount: Int

    public init(targetId: UInt64, type: RelationshipType = .stranger, formedAt: UInt64) {
        self.targetId = targetId
        self.type = type
        self.strength = type == .stranger ? 0 : 10
        self.formedAt = formedAt
        self.lastInteraction = formedAt
        self.interactionCount = 0
    }

    /// Update relationship type based on strength
    public mutating func updateType() {
        // Don't change family relationships
        if type == .parent || type == .child || type == .sibling {
            return
        }

        // Don't demote spouse/lover easily
        if type == .spouse && strength > 50 { return }

        // Update based on strength
        if strength >= 90 && type == .lover {
            type = .spouse
        } else if strength >= 80 && (type == .closeFriend || type == .spouse) {
            // Can become lover if both suitable
            type = .lover
        } else if strength >= 70 {
            type = .closeFriend
        } else if strength >= 40 {
            type = .friend
        } else if strength >= 10 {
            type = .acquaintance
        } else if strength <= -70 {
            type = .enemy
        } else if strength <= -40 {
            type = .rival
        } else {
            type = .stranger
        }
    }
}

// MARK: - Conversation Topics

/// Topics that can be discussed in conversations
public enum ConversationTopic: String, Sendable, CaseIterable {
    case weather = "the weather"
    case work = "work"
    case food = "food and drink"
    case hobby = "hobbies"
    case family = "family"
    case stories = "stories"
    case gossip = "gossip"
    case philosophy = "philosophy"
    case art = "art"
    case nature = "nature"
    case memories = "memories"
    case complaint = "complaints"
    case joke = "jokes"
    case praise = "praise"

    /// Base relationship modifier from this topic
    public var baseModifier: Int {
        switch self {
        case .weather, .work, .food, .hobby, .nature:
            return 2  // Neutral topics
        case .family, .stories, .memories:
            return 3  // Bonding topics
        case .gossip, .complaint:
            return 1  // Risky topics (can backfire)
        case .philosophy, .art:
            return 2  // Interest-dependent
        case .joke:
            return 4  // High risk, high reward
        case .praise:
            return 5  // Always positive
        }
    }
}

// MARK: - Conversation Result

/// Result of a conversation
public struct ConversationResult: Sendable {
    public let participant1: UInt64
    public let participant2: UInt64
    public let topic: ConversationTopic
    public let success: Bool
    public let relationshipChange: Int
    public let description: String

    public init(
        participant1: UInt64,
        participant2: UInt64,
        topic: ConversationTopic,
        success: Bool,
        relationshipChange: Int,
        description: String
    ) {
        self.participant1 = participant1
        self.participant2 = participant2
        self.topic = topic
        self.success = success
        self.relationshipChange = relationshipChange
        self.description = description
    }
}

// MARK: - Social Manager

/// Manages social interactions and relationships
@MainActor
public final class SocialManager: Sendable {
    /// Relationships by unit ID -> target ID -> Relationship
    public private(set) var relationships: [UInt64: [UInt64: Relationship]] = [:]

    /// Recent conversations for logging
    public private(set) var recentConversations: [ConversationResult] = []

    /// Maximum conversation history
    public var maxConversationHistory: Int = 30

    public init() {}

    // MARK: - Relationship Management

    /// Get or create a relationship between two units
    public func getRelationship(from unitId: UInt64, to targetId: UInt64, currentTick: UInt64) -> Relationship {
        if relationships[unitId] == nil {
            relationships[unitId] = [:]
        }

        if let existing = relationships[unitId]?[targetId] {
            return existing
        }

        // Create new stranger relationship
        let newRelation = Relationship(targetId: targetId, formedAt: currentTick)
        relationships[unitId]?[targetId] = newRelation
        return newRelation
    }

    /// Update a relationship
    public func updateRelationship(from unitId: UInt64, to targetId: UInt64, _ update: (inout Relationship) -> Void) {
        guard var relations = relationships[unitId], var relation = relations[targetId] else {
            return
        }

        update(&relation)
        relation.updateType()

        relations[targetId] = relation
        relationships[unitId] = relations
    }

    /// Add strength to a relationship
    public func modifyRelationship(
        from unitId: UInt64,
        to targetId: UInt64,
        amount: Int,
        currentTick: UInt64
    ) {
        // Ensure relationships exist
        _ = getRelationship(from: unitId, to: targetId, currentTick: currentTick)
        _ = getRelationship(from: targetId, to: unitId, currentTick: currentTick)

        // Update both directions (slightly less for target)
        updateRelationship(from: unitId, to: targetId) { relation in
            relation.strength = max(-100, min(100, relation.strength + amount))
            relation.lastInteraction = currentTick
            relation.interactionCount += 1
        }

        updateRelationship(from: targetId, to: unitId) { relation in
            let reciprocalAmount = amount > 0 ? amount * 3 / 4 : amount  // Less positive reciprocation
            relation.strength = max(-100, min(100, relation.strength + reciprocalAmount))
            relation.lastInteraction = currentTick
            relation.interactionCount += 1
        }
    }

    /// Set family relationship (symmetric)
    public func setFamilyRelationship(
        parent: UInt64,
        child: UInt64,
        currentTick: UInt64
    ) {
        // Ensure relationships exist
        if relationships[parent] == nil {
            relationships[parent] = [:]
        }
        if relationships[child] == nil {
            relationships[child] = [:]
        }

        // Parent -> Child
        var parentRelation = Relationship(targetId: child, type: .child, formedAt: currentTick)
        parentRelation.strength = 80
        relationships[parent]?[child] = parentRelation

        // Child -> Parent
        var childRelation = Relationship(targetId: parent, type: .parent, formedAt: currentTick)
        childRelation.strength = 70
        relationships[child]?[parent] = childRelation
    }

    /// Set sibling relationship (symmetric)
    public func setSiblingRelationship(
        sibling1: UInt64,
        sibling2: UInt64,
        currentTick: UInt64
    ) {
        if relationships[sibling1] == nil {
            relationships[sibling1] = [:]
        }
        if relationships[sibling2] == nil {
            relationships[sibling2] = [:]
        }

        var relation1 = Relationship(targetId: sibling2, type: .sibling, formedAt: currentTick)
        relation1.strength = 50
        relationships[sibling1]?[sibling2] = relation1

        var relation2 = Relationship(targetId: sibling1, type: .sibling, formedAt: currentTick)
        relation2.strength = 50
        relationships[sibling2]?[sibling1] = relation2
    }

    // MARK: - Conversations

    /// Have two units converse
    public func haveConversation(
        participant1: UInt64,
        participant2: UInt64,
        personality1: Personality,
        personality2: Personality,
        currentTick: UInt64
    ) -> ConversationResult {
        // Select a topic based on personalities
        let topic = selectTopic(personality1: personality1, personality2: personality2)

        // Calculate success chance
        let baseChance = 60

        // Gregariousness helps conversations
        let socialBonus = (personality1.value(for: .gregariousness) + personality2.value(for: .gregariousness)) / 4

        // Existing relationship helps
        let relation = getRelationship(from: participant1, to: participant2, currentTick: currentTick)
        let relationBonus = relation.strength / 5

        let successChance = baseChance + socialBonus + relationBonus
        let success = Int.random(in: 1...100) <= successChance

        // Calculate relationship change
        var change = topic.baseModifier
        if success {
            change += Int.random(in: 1...3)
        } else {
            change = -Int.random(in: 1...2)
        }

        // Apply relationship change
        modifyRelationship(from: participant1, to: participant2, amount: change, currentTick: currentTick)

        // Create result
        let description: String
        if success {
            description = "Had a pleasant conversation about \(topic.rawValue)"
        } else {
            description = "Had an awkward conversation about \(topic.rawValue)"
        }

        let result = ConversationResult(
            participant1: participant1,
            participant2: participant2,
            topic: topic,
            success: success,
            relationshipChange: change,
            description: description
        )

        // Store in history
        recentConversations.append(result)
        if recentConversations.count > maxConversationHistory {
            recentConversations.removeFirst()
        }

        return result
    }

    /// Select a conversation topic based on personalities
    private func selectTopic(personality1: Personality, personality2: Personality) -> ConversationTopic {
        // Weight topics by personality
        var weights: [ConversationTopic: Int] = [:]

        for topic in ConversationTopic.allCases {
            var weight = 10  // Base weight

            switch topic {
            case .philosophy, .art:
                weight += personality1.value(for: .curiosity) / 10
            case .joke:
                weight += personality1.value(for: .cheerfulness) / 10
            case .complaint, .gossip:
                weight -= personality1.value(for: .cheerfulness) / 10
                weight += personality1.value(for: .anxiety) / 15
            case .family, .memories:
                weight += (100 - personality1.value(for: .anxiety)) / 15
            case .work:
                weight += personality1.value(for: .perseverance) / 10
            case .nature:
                weight += personality1.value(for: .curiosity) / 15
            case .praise:
                weight += personality1.value(for: .altruism) / 10
            default:
                break
            }

            weights[topic] = max(1, weight)
        }

        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        var roll = Int.random(in: 0..<totalWeight)

        for (topic, weight) in weights {
            roll -= weight
            if roll < 0 {
                return topic
            }
        }

        return .weather  // Fallback
    }

    // MARK: - Queries

    /// Get all friends of a unit
    public func getFriends(of unitId: UInt64) -> [UInt64] {
        guard let relations = relationships[unitId] else { return [] }
        return relations.values
            .filter { $0.type == .friend || $0.type == .closeFriend }
            .map { $0.targetId }
    }

    /// Get spouse of a unit (if any)
    public func getSpouse(of unitId: UInt64) -> UInt64? {
        guard let relations = relationships[unitId] else { return nil }
        return relations.values.first { $0.type == .spouse }?.targetId
    }

    /// Get family members of a unit
    public func getFamily(of unitId: UInt64) -> [UInt64] {
        guard let relations = relationships[unitId] else { return [] }
        return relations.values
            .filter { $0.type == .parent || $0.type == .child || $0.type == .sibling || $0.type == .spouse }
            .map { $0.targetId }
    }

    /// Get enemies of a unit
    public func getEnemies(of unitId: UInt64) -> [UInt64] {
        guard let relations = relationships[unitId] else { return [] }
        return relations.values
            .filter { $0.type == .enemy || $0.type == .rival }
            .map { $0.targetId }
    }

    /// Check if two units can become lovers
    public func canBecomLovers(unit1: UInt64, unit2: UInt64) -> Bool {
        // Check neither is already married
        if getSpouse(of: unit1) != nil || getSpouse(of: unit2) != nil {
            return false
        }

        // Check relationship strength
        guard let relation = relationships[unit1]?[unit2] else { return false }
        return relation.strength >= 70
    }

    // MARK: - Marriage

    /// Marry two units
    public func marry(unit1: UInt64, unit2: UInt64, currentTick: UInt64) -> Bool {
        guard canBecomLovers(unit1: unit1, unit2: unit2) else { return false }

        // Set spouse relationship both ways
        updateRelationship(from: unit1, to: unit2) { relation in
            relation.type = .spouse
            relation.strength = max(90, relation.strength)
        }

        updateRelationship(from: unit2, to: unit1) { relation in
            relation.type = .spouse
            relation.strength = max(90, relation.strength)
        }

        return true
    }

    /// Relationship decay over time (call periodically)
    public func decayRelationships(currentTick: UInt64, decayRate: Int = 1) {
        for (unitId, var relations) in relationships {
            for (targetId, var relation) in relations {
                // Don't decay family or spouse
                if relation.type == .parent || relation.type == .child ||
                   relation.type == .sibling || relation.type == .spouse {
                    continue
                }

                // Decay based on time since last interaction
                let ticksSinceLast = Int(currentTick - relation.lastInteraction)
                if ticksSinceLast > 1000 {
                    relation.strength = max(-100, min(100, relation.strength - decayRate))
                    relation.updateType()
                    relations[targetId] = relation
                }
            }
            relationships[unitId] = relations
        }
    }

    /// Clear relationships for a unit (when they die)
    public func clearRelationships(for unitId: UInt64) {
        relationships.removeValue(forKey: unitId)

        // Also remove this unit from others' relationships
        for (otherId, var relations) in relationships {
            relations.removeValue(forKey: unitId)
            relationships[otherId] = relations
        }
    }
}
