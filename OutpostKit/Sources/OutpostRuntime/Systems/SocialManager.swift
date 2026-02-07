// MARK: - Social Manager

import Foundation
import OutpostCore

// MARK: - Dialogue Banks

/// Short dialogue lines organized by topic and role
enum DialogueBank {
    enum Role { case opener, response, closer, failOpener, failResponse }

    static func lines(for topic: ConversationTopic, role: Role) -> [String] {
        switch (topic, role) {
        case (.weather, .opener):    return ["Nice day", "Windy today", "Looks like rain"]
        case (.weather, .response):  return ["Aye", "Sure is", "Could be worse"]
        case (.weather, .closer):    return ["Stay dry", "Enjoy it"]
        case (.weather, .failOpener):  return ["Awful weather", "Ugh, this air"]
        case (.weather, .failResponse): return ["Hmph", "Whatever"]

        case (.work, .opener):    return ["Busy day...", "Much to do", "The mines need work"]
        case (.work, .response):  return ["Tell me about it", "Could be worse", "Aye, always"]
        case (.work, .closer):    return ["Back to it", "Good luck"]
        case (.work, .failOpener):  return ["Too much work", "I'm exhausted"]
        case (.work, .failResponse): return ["Not now", "Leave me be"]

        case (.food, .opener):    return ["Hungry?", "Smells good", "Had a fine meal"]
        case (.food, .response):  return ["Starving!", "Mmm indeed", "Could eat"]
        case (.food, .closer):    return ["Eat well", "Save me some"]
        case (.food, .failOpener):  return ["Tastes awful", "Nothing to eat"]
        case (.food, .failResponse): return ["Gross", "Don't remind me"]

        case (.hobby, .opener):    return ["Been crafting?", "Try anything new?"]
        case (.hobby, .response):  return ["A little", "Not lately", "Always!"]
        case (.hobby, .closer):    return ["Show me sometime", "Nice"]
        case (.hobby, .failOpener):  return ["So bored", "Nothing to do"]
        case (.hobby, .failResponse): return ["Yep", "Meh"]

        case (.family, .opener):    return ["How's family?", "Miss the old days"]
        case (.family, .response):  return ["They're well", "Same here", "Growing fast"]
        case (.family, .closer):    return ["Give them my best", "Good to hear"]
        case (.family, .failOpener):  return ["Family troubles", "Don't ask"]
        case (.family, .failResponse): return ["Sorry to hear", "Oh..."]

        case (.stories, .opener):    return ["Heard a tale", "Listen to this...", "Remember when..."]
        case (.stories, .response):  return ["Go on!", "Tell me more", "Ha!"]
        case (.stories, .closer):    return ["Good story", "I'll remember that"]
        case (.stories, .failOpener):  return ["Boring tale...", "Forget it"]
        case (.stories, .failResponse): return ["Hmm", "Heard it before"]

        case (.gossip, .opener):    return ["Did you hear?", "Guess what...", "Don't tell anyone"]
        case (.gossip, .response):  return ["No way!", "Really?!", "Who?!"]
        case (.gossip, .closer):    return ["Keep it quiet", "Interesting..."]
        case (.gossip, .failOpener):  return ["Heard a rumor", "They said..."]
        case (.gossip, .failResponse): return ["Don't care", "That's mean"]

        case (.philosophy, .opener):    return ["Ever wonder...", "What if...", "Think about it"]
        case (.philosophy, .response):  return ["Hmm, perhaps", "Deep thought", "Interesting"]
        case (.philosophy, .closer):    return ["Food for thought", "Makes you think"]
        case (.philosophy, .failOpener):  return ["Life is strange", "Nothing matters"]
        case (.philosophy, .failResponse): return ["Too deep", "My head hurts"]

        case (.art, .opener):    return ["See that carving?", "Beautiful work"]
        case (.art, .response):  return ["Lovely indeed", "Fine craft", "I see it"]
        case (.art, .closer):    return ["Inspiring", "Well made"]
        case (.art, .failOpener):  return ["Ugly piece", "Who made that"]
        case (.art, .failResponse): return ["Hmph", "Not my taste"]

        case (.nature, .opener):    return ["Hear the birds?", "Fine forest", "Look at that"]
        case (.nature, .response):  return ["Beautiful", "Peaceful", "I see"]
        case (.nature, .closer):    return ["Good spot", "Nature provides"]
        case (.nature, .failOpener):  return ["Wild beasts...", "Dangerous out"]
        case (.nature, .failResponse): return ["Stay safe", "Scary"]

        case (.memories, .opener):    return ["Remember when...", "Long time ago...", "Old times"]
        case (.memories, .response):  return ["Those were the days", "I remember", "Ha, yes!"]
        case (.memories, .closer):    return ["Good times", "We've come far"]
        case (.memories, .failOpener):  return ["Bad memories", "Rather forget"]
        case (.memories, .failResponse): return ["Sorry", "Let it go"]

        case (.complaint, .opener):    return ["Can you believe...", "So annoying", "Ugh"]
        case (.complaint, .response):  return ["I know, right?", "Terrible", "Yeah..."]
        case (.complaint, .closer):    return ["Had to vent", "Thanks for listening"]
        case (.complaint, .failOpener):  return ["Everything's wrong", "I hate this"]
        case (.complaint, .failResponse): return ["Stop whining", "Enough"]

        case (.joke, .opener):    return ["Ha, listen...", "Heard this one?", "Why did the..."]
        case (.joke, .response):  return ["Hah!", "Good one!", "Ha ha ha!"]
        case (.joke, .closer):    return ["Classic!", "Tell another"]
        case (.joke, .failOpener):  return ["Wanna hear one?", "So, uh..."]
        case (.joke, .failResponse): return ["Ugh...", "Not funny", "Really?"]

        case (.praise, .opener):    return ["Nice work!", "Well done", "You're great"]
        case (.praise, .response):  return ["Thanks!", "Means a lot", "You too!"]
        case (.praise, .closer):    return ["Keep it up", "Proud of you"]
        case (.praise, .failOpener):  return ["You tried", "Not bad I guess"]
        case (.praise, .failResponse): return ["Sure...", "Thanks I guess"]
        }
    }

    static func callbackLine(for topic: ConversationTopic) -> String {
        switch topic {
        case .joke:    return "Like that joke before"
        case .gossip:  return "More gossip, huh?"
        case .work:    return "Work talk again"
        case .stories: return "Another tale?"
        case .food:    return "Food talk again"
        default:       return "Like last time"
        }
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

    /// Have two units converse — delegates to group conversation
    public func haveConversation(
        participant1: UInt64,
        participant2: UInt64,
        personality1: Personality,
        personality2: Personality,
        currentTick: UInt64
    ) -> ConversationPlan {
        let participants = [
            ConversationParticipant(unitId: participant1, name: "", personality: personality1),
            ConversationParticipant(unitId: participant2, name: "", personality: personality2),
        ]
        return haveGroupConversation(participants: participants, currentTick: currentTick)
    }

    /// Have a group of units converse (2-5 participants) — returns a multi-turn plan
    public func haveGroupConversation(
        participants: [ConversationParticipant],
        currentTick: UInt64,
        initiatorMemories: MemoryStore? = nil
    ) -> ConversationPlan {
        guard participants.count >= 2 else {
            return ConversationPlan(participantIds: [], exchanges: [], topic: .weather, overallSuccess: false, relationshipChange: 0)
        }

        let initiator = participants[0]
        let second = participants[1]

        // Get conversation history from initiator <-> second relationship
        let relation = getRelationship(from: initiator.unitId, to: second.unitId, currentTick: currentTick)
        let history = relation.conversationHistory

        // Select topic based on initiator + second's personalities/history and memories
        let topic = selectTopic(
            personality1: initiator.personality,
            personality2: second.personality,
            history: history,
            initiatorMemories: initiatorMemories,
            partnerId: second.unitId
        )

        // Success chance uses average gregariousness of all participants
        let baseChance = 60
        let avgGregariousness = participants.reduce(0) { $0 + $1.personality.value(for: .gregariousness) } / participants.count
        let socialBonus = avgGregariousness / 2
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

        // Turn count = base (2-4 by relationship) + (participantCount - 2) for groups
        let baseTurnCount: Int
        switch relation.type {
        case .closeFriend, .lover, .spouse, .parent, .child, .sibling:
            baseTurnCount = Int.random(in: 3...4)
        case .friend:
            baseTurnCount = Int.random(in: 2...3)
        default:
            baseTurnCount = 2
        }
        let turnCount = baseTurnCount + (participants.count - 2)

        // Check if this topic was discussed before
        let isCallback = history.contains(topic)

        // Generate exchanges with round-robin speakers
        let exchanges = generateGroupExchanges(
            participants: participants,
            topic: topic,
            turnCount: turnCount,
            success: success,
            isCallback: isCallback
        )

        // Apply relationship changes between ALL pairs
        let participantIds = participants.map { $0.unitId }
        for i in 0..<participants.count {
            for j in (i + 1)..<participants.count {
                let a = participants[i].unitId
                let b = participants[j].unitId
                // Initiator pair (i==0) gets full effect, non-initiator pairs get 2/3
                let pairChange = (i == 0) ? change : (change * 2 / 3)
                modifyRelationship(from: a, to: b, amount: pairChange, currentTick: currentTick)

                // Record topic in conversation history for both directions
                updateRelationship(from: a, to: b) { rel in
                    rel.recordConversation(topic: topic)
                }
                updateRelationship(from: b, to: a) { rel in
                    rel.recordConversation(topic: topic)
                }
            }
        }

        // Create legacy result for logging (uses initiator + second)
        let description: String
        if success {
            description = "Had a pleasant conversation about \(topic.rawValue)"
        } else {
            description = "Had an awkward conversation about \(topic.rawValue)"
        }

        let result = ConversationResult(
            participant1: initiator.unitId,
            participant2: second.unitId,
            topic: topic,
            success: success,
            relationshipChange: change,
            description: description
        )

        recentConversations.append(result)
        if recentConversations.count > maxConversationHistory {
            recentConversations.removeFirst()
        }

        return ConversationPlan(
            participantIds: participantIds,
            exchanges: exchanges,
            topic: topic,
            overallSuccess: success,
            relationshipChange: change
        )
    }

    /// Generate dialogue exchanges with round-robin speaker selection
    private func generateGroupExchanges(
        participants: [ConversationParticipant],
        topic: ConversationTopic,
        turnCount: Int,
        success: Bool,
        isCallback: Bool
    ) -> [ConversationExchange] {
        var exchanges: [ConversationExchange] = []

        for i in 0..<turnCount {
            let speakerId = participants[i % participants.count].unitId
            let line: String

            if i == 0 {
                // First turn: opener (with possible callback)
                if isCallback && Bool.random() {
                    line = DialogueBank.callbackLine(for: topic)
                } else if success {
                    line = DialogueBank.lines(for: topic, role: .opener).randomElement() ?? "..."
                } else {
                    line = DialogueBank.lines(for: topic, role: .failOpener).randomElement() ?? "..."
                }
            } else if i == turnCount - 1 {
                // Last turn: closer
                if success {
                    line = DialogueBank.lines(for: topic, role: .closer).randomElement() ?? "..."
                } else {
                    line = DialogueBank.lines(for: topic, role: .failResponse).randomElement() ?? "..."
                }
            } else {
                // Middle turn: response
                if success {
                    line = DialogueBank.lines(for: topic, role: .response).randomElement() ?? "..."
                } else {
                    line = DialogueBank.lines(for: topic, role: .failResponse).randomElement() ?? "..."
                }
            }

            exchanges.append(ConversationExchange(speakerId: speakerId, line: line, turnIndex: i))
        }

        return exchanges
    }

    /// Select a conversation topic based on personalities, history, and memories
    private func selectTopic(
        personality1: Personality,
        personality2: Personality,
        history: [ConversationTopic] = [],
        initiatorMemories: MemoryStore? = nil,
        partnerId: UInt64? = nil
    ) -> ConversationTopic {
        // Weight topics by personality
        var weights: [ConversationTopic: Int] = [:]

        // Recent topics (last 3) get halved weight
        let recentTopics = Array(history.suffix(3))

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

            // Halve weight for recently discussed topics
            if recentTopics.contains(topic) {
                weight /= 2
            }

            weights[topic] = max(1, weight)
        }

        // Memory-based topic bias
        if let memories = initiatorMemories {
            // Check 2-3 recent high-salience memories and adjust weights
            let recentSalient = memories.recallRecent(limit: 3)

            for memory in recentSalient {
                switch memory.eventType {
                case .attackedBy, .wasInjured, .nearDeath:
                    weights[.stories, default: 10] += 2
                    weights[.complaint, default: 10] += 2
                case .madeNewFriend, .conversationWith:
                    weights[.gossip, default: 10] += 2
                case .completedTask, .builtStructure:
                    weights[.work, default: 10] += 2
                    weights[.praise, default: 10] += 2
                default:
                    break
                }
            }

            // Emotional association with conversation partner
            if let pid = partnerId, let feeling = memories.getFeeling(about: pid) {
                if feeling > 20 {
                    weights[.memories, default: 10] += 2
                    weights[.joke, default: 10] += 2
                } else if feeling < -20 {
                    weights[.complaint, default: 10] += 2
                }
            }
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
