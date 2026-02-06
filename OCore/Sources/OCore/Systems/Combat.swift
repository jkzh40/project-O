// MARK: - Combat System
// Handles fighting, damage, and death from combat

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

// MARK: - Combat Manager

/// Manages combat interactions between units
@MainActor
public final class CombatManager: Sendable {
    /// Attack results from recent combat
    public private(set) var recentCombat: [AttackResult] = []

    /// Maximum combat history to keep
    public var maxCombatHistory: Int = 50

    public init() {}

    /// Resolve an attack between two units
    public func resolveAttack(
        attackerId: UInt64,
        attackerStrength: Int,
        attackerSkill: Int,
        defenderId: UInt64,
        defenderAgility: Int,
        defenderHealth: inout Health,
        damageType: DamageType = .blunt
    ) -> AttackResult {
        // Calculate hit chance (base 60% + skill bonus - defender agility)
        let hitChance = 60 + (attackerSkill * 2) - (defenderAgility / 50)
        let roll = Int.random(in: 1...100)
        let hit = roll <= hitChance

        var damage = 0
        var critical = false
        var description = ""

        if hit {
            // Calculate base damage from strength
            let baseDamage = 5 + (attackerStrength / 100)

            // Skill bonus (up to 50% more damage)
            let skillBonus = Double(attackerSkill) * 0.025
            damage = Int(Double(baseDamage) * (1.0 + skillBonus))

            // Critical hit chance (5% base + skill bonus)
            let critChance = 5 + attackerSkill
            if Int.random(in: 1...100) <= critChance {
                critical = true
                damage = damage * 2
                description = "Critical hit!"
            }

            // Random variance (±20%)
            let variance = Double.random(in: 0.8...1.2)
            damage = Int(Double(damage) * variance)

            // Apply damage
            defenderHealth.takeDamage(damage)

            if !critical {
                description = "Hit for \(damage) \(damageType.rawValue) damage"
            } else {
                description = "Critical hit for \(damage) \(damageType.rawValue) damage!"
            }
        } else {
            description = "Missed!"
        }

        let defenderDied = !defenderHealth.isAlive

        let result = AttackResult(
            attacker: attackerId,
            defender: defenderId,
            hit: hit,
            damage: damage,
            damageType: damageType,
            critical: critical,
            defenderDied: defenderDied,
            description: description
        )

        // Store in history
        recentCombat.append(result)
        if recentCombat.count > maxCombatHistory {
            recentCombat.removeFirst()
        }

        return result
    }

    /// Calculate flee chance based on health and bravery
    public func shouldFlee(healthPercentage: Int, bravery: Int) -> Bool {
        // Lower health = more likely to flee
        // Higher bravery = less likely to flee

        let fleeThreshold: Int
        if bravery < 30 {
            fleeThreshold = 70  // Cowards flee at 70% health
        } else if bravery < 60 {
            fleeThreshold = 40  // Normal flee at 40% health
        } else {
            fleeThreshold = 20  // Brave flee at 20% health
        }

        return healthPercentage <= fleeThreshold
    }

    /// Get a direction to flee (away from attacker)
    public func getFleeDirection(from position: Position, awayfrom attacker: Position) -> Direction {
        let dx = position.x - attacker.x
        let dy = position.y - attacker.y

        // Determine primary flee direction
        if abs(dx) >= abs(dy) {
            return dx > 0 ? .east : .west
        } else {
            return dy > 0 ? .south : .north
        }
    }

    /// Check if a unit is in melee range (adjacent)
    public func isInMeleeRange(_ pos1: Position, _ pos2: Position) -> Bool {
        guard pos1.z == pos2.z else { return false }
        let dx = abs(pos1.x - pos2.x)
        let dy = abs(pos1.y - pos2.y)
        return dx <= 1 && dy <= 1 && (dx + dy) > 0
    }

    /// Clear combat history
    public func clearHistory() {
        recentCombat.removeAll()
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
