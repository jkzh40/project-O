// MARK: - Mood Manager

import Foundation
import OutpostCore

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
