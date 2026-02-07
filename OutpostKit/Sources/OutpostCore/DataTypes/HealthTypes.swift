// MARK: - Health & Combat Types

import Foundation

// MARK: - Health System

/// Tracks a unit's health and wounds
public struct Health: Sendable {
    /// Maximum hit points
    public let maxHP: Int

    /// Current hit points
    public var currentHP: Int

    /// Whether the unit is alive
    public var isAlive: Bool { currentHP > 0 }

    /// Whether the unit is wounded (below 50% HP)
    public var isWounded: Bool { currentHP < maxHP / 2 }

    /// Whether the unit is critically wounded (below 25% HP)
    public var isCritical: Bool { currentHP < maxHP / 4 }

    /// Health as percentage (0-100)
    public var percentage: Int {
        guard maxHP > 0 else { return 0 }
        return (currentHP * 100) / maxHP
    }

    public init(maxHP: Int = 100) {
        self.maxHP = maxHP
        self.currentHP = maxHP
    }

    /// Take damage, returns actual damage dealt
    @discardableResult
    public mutating func takeDamage(_ amount: Int) -> Int {
        let actualDamage = min(amount, currentHP)
        currentHP = max(0, currentHP - actualDamage)
        return actualDamage
    }

    /// Heal, returns actual healing done
    @discardableResult
    public mutating func heal(_ amount: Int) -> Int {
        let actualHealing = min(amount, maxHP - currentHP)
        currentHP = min(maxHP, currentHP + actualHealing)
        return actualHealing
    }
}

// MARK: - Damage Types

/// Types of damage that can be dealt
public enum DamageType: String, Sendable, CaseIterable {
    case blunt = "blunt"        // Hammers, fists
    case slash = "slash"        // Swords, axes
    case pierce = "pierce"      // Spears, arrows
    case bite = "bite"          // Animal attacks
    case fire = "fire"          // Burns
    case cold = "cold"          // Freezing
}

// MARK: - Attack Result

/// Result of an attack attempt
public struct AttackResult: Sendable {
    public let attacker: UInt64
    public let defender: UInt64
    public let hit: Bool
    public let damage: Int
    public let damageType: DamageType
    public let critical: Bool
    public let defenderDied: Bool
    public let description: String

    public init(
        attacker: UInt64,
        defender: UInt64,
        hit: Bool,
        damage: Int,
        damageType: DamageType,
        critical: Bool = false,
        defenderDied: Bool = false,
        description: String = ""
    ) {
        self.attacker = attacker
        self.defender = defender
        self.hit = hit
        self.damage = damage
        self.damageType = damageType
        self.critical = critical
        self.defenderDied = defenderDied
        self.description = description
    }
}

// MARK: - Creature Type

/// Types of creatures that can exist in the world
public enum CreatureType: String, Sendable, CaseIterable {
    case orc = "orc"
    case goblin = "goblin"
    case wolf = "wolf"
    case bear = "bear"
    case giant = "giant"
    case undead = "undead"

    /// Base HP for this creature type (delegates to registry with hardcoded fallback)
    @MainActor
    public var baseHP: Int {
        CreatureRegistry.shared.baseHP(for: self)
    }

    /// Base damage for this creature type (delegates to registry with hardcoded fallback)
    @MainActor
    public var baseDamage: Int {
        CreatureRegistry.shared.baseDamage(for: self)
    }

    /// Whether this creature is hostile to orcs (delegates to registry with hardcoded fallback)
    @MainActor
    public var hostileToOrcs: Bool {
        CreatureRegistry.shared.isHostileToOrcs(self)
    }

    /// Display character for this creature (delegates to registry with hardcoded fallback)
    @MainActor
    public var displayChar: Character {
        CreatureRegistry.shared.displayChar(for: self)
    }
}

// MARK: - Combat-Related Unit Extensions

extension UnitState {
    /// Whether this state allows combat
    public var allowsCombat: Bool {
        switch self {
        case .idle, .moving, .working:
            return true
        case .fighting, .fleeing:
            return true
        case .eating, .drinking, .sleeping, .socializing:
            return false
        case .unconscious, .dead:
            return false
        }
    }
}
