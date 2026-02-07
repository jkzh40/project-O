// MARK: - Social System Types
// Relationships, conversations, and social interactions

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

    /// Recent conversation topics (capped at 5, oldest dropped first)
    public var conversationHistory: [ConversationTopic] = []

    public init(targetId: UInt64, type: RelationshipType = .stranger, formedAt: UInt64) {
        self.targetId = targetId
        self.type = type
        self.strength = type == .stranger ? 0 : 10
        self.formedAt = formedAt
        self.lastInteraction = formedAt
        self.interactionCount = 0
    }

    /// Record a conversation topic, keeping the last 5
    public mutating func recordConversation(topic: ConversationTopic) {
        conversationHistory.append(topic)
        if conversationHistory.count > 5 {
            conversationHistory.removeFirst()
        }
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

// MARK: - Multi-Turn Conversation

/// A participant in a conversation (used to build group conversations)
public struct ConversationParticipant: Sendable {
    public let unitId: UInt64
    public let name: String
    public let personality: Personality

    public init(unitId: UInt64, name: String, personality: Personality) {
        self.unitId = unitId
        self.name = name
        self.personality = personality
    }
}

/// A single exchange (turn) in a conversation
public struct ConversationExchange: Sendable {
    public let speakerId: UInt64
    public let line: String
    public let turnIndex: Int

    public init(speakerId: UInt64, line: String, turnIndex: Int) {
        self.speakerId = speakerId
        self.line = line
        self.turnIndex = turnIndex
    }
}

/// A planned multi-turn conversation
public struct ConversationPlan: Sendable {
    public let participantIds: [UInt64]
    public let exchanges: [ConversationExchange]
    public let topic: ConversationTopic
    public let overallSuccess: Bool
    public let relationshipChange: Int

    public init(
        participantIds: [UInt64],
        exchanges: [ConversationExchange],
        topic: ConversationTopic,
        overallSuccess: Bool,
        relationshipChange: Int
    ) {
        self.participantIds = participantIds
        self.exchanges = exchanges
        self.topic = topic
        self.overallSuccess = overallSuccess
        self.relationshipChange = relationshipChange
    }
}
