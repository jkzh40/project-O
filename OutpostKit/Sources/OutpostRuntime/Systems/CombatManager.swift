// MARK: - Combat Manager

import Foundation
import OutpostCore

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
