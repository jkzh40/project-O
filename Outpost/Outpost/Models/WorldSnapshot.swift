import Foundation
import OutpostRuntime

// MARK: - World Snapshot DTOs

/// Sendable snapshot of the entire world state for rendering
struct WorldSnapshot: Sendable {
    let tick: UInt64
    let width: Int
    let height: Int
    let depth: Int
    let currentZ: Int
    let season: Season
    let timeOfDay: TimeOfDay
    let hour: Int
    let calendarDescription: String
    let tiles: [[TileSnapshot]]
    let units: [UnitSnapshot]
    let items: [ItemSnapshot]
    let activeConversations: [ConversationSnapshot]
}

/// Snapshot of a single participant in a conversation
struct ConversationParticipantSnapshot: Sendable {
    let unitId: UInt64
    let name: String
    let line: String
    let isSpeaking: Bool
}

/// Snapshot of an active conversation for speech bubble display
struct ConversationSnapshot: Sendable {
    let participants: [ConversationParticipantSnapshot]
    let eavesdropperIds: Set<UInt64>
    let topic: String
    let isSuccess: Bool
}

/// Sendable snapshot of a single tile
struct TileSnapshot: Sendable {
    let x: Int
    let y: Int
    let terrain: TerrainType
    let biome: BiomeType
    let hasItems: Bool
    let hasUnit: Bool
}

/// Sendable snapshot of a unit
struct UnitSnapshot: Sendable, Identifiable {
    let id: UInt64
    let x: Int
    let y: Int
    let z: Int
    let name: String
    let fullName: String
    let state: UnitState
    let creatureType: CreatureType
    let healthPercent: Int
    let healthCurrent: Int
    let healthMax: Int
    let hungerPercent: Int
    let thirstPercent: Int
    let drowsinessPercent: Int
    let facing: Direction
    let isHostile: Bool
    let recentMemoryCount: Int
    let topMemory: String?
}

/// Sendable snapshot of an item
struct ItemSnapshot: Sendable, Identifiable {
    let id: UInt64
    let x: Int
    let y: Int
    let z: Int
    let itemType: ItemType
    let quality: ItemQuality
    let quantity: Int
}

// MARK: - Snapshot Factory

extension WorldSnapshot {
    /// Creates a snapshot from the simulation's current state
    @MainActor
    static func from(simulation: Simulation, currentZ: Int = 0, hostileUnits: Set<UInt64>) -> WorldSnapshot {
        let world = simulation.world
        let width = world.width
        let height = world.height
        let cal = world.calendar

        // Build tile snapshots for current z-level
        var tiles: [[TileSnapshot]] = []
        for y in 0..<height {
            var row: [TileSnapshot] = []
            for x in 0..<width {
                let pos = Position(x: x, y: y, z: currentZ)
                if let tile = world.getTile(at: pos) {
                    let snapshot = TileSnapshot(
                        x: x,
                        y: y,
                        terrain: tile.terrain,
                        biome: tile.biome,
                        hasItems: !tile.itemIds.isEmpty,
                        hasUnit: tile.unitId != nil
                    )
                    row.append(snapshot)
                } else {
                    // Out of bounds - use empty air
                    row.append(TileSnapshot(x: x, y: y, terrain: .emptyAir, biome: .temperateGrassland, hasItems: false, hasUnit: false))
                }
            }
            tiles.append(row)
        }

        // Build unit snapshots
        let units: [UnitSnapshot] = world.units.values.compactMap { unit in
            // Only include units on the current z-level
            guard unit.position.z == currentZ else { return nil }

            return UnitSnapshot(
                id: unit.id,
                x: unit.position.x,
                y: unit.position.y,
                z: unit.position.z,
                name: unit.name.description,
                fullName: unit.name.fullName,
                state: unit.state,
                creatureType: unit.creatureType,
                healthPercent: unit.health.percentage,
                healthCurrent: unit.health.currentHP,
                healthMax: unit.health.maxHP,
                hungerPercent: min(100, (unit.hunger * 100) / NeedThresholds.hungerDeath),
                thirstPercent: min(100, (unit.thirst * 100) / NeedThresholds.thirstDeath),
                drowsinessPercent: min(100, (unit.drowsiness * 100) / NeedThresholds.drowsyInsane),
                facing: unit.facing,
                isHostile: hostileUnits.contains(unit.id),
                recentMemoryCount: unit.memories.totalEpisodicCount,
                topMemory: unit.memories.topMemoryDescription
            )
        }

        // Build item snapshots
        let items: [ItemSnapshot] = world.items.values.compactMap { item in
            // Only include items on the current z-level
            guard item.position.z == currentZ else { return nil }

            return ItemSnapshot(
                id: item.id,
                x: item.position.x,
                y: item.position.y,
                z: item.position.z,
                itemType: item.itemType,
                quality: item.quality,
                quantity: item.quantity
            )
        }

        // Build conversation snapshots
        let currentTick = world.currentTick
        let conversations: [ConversationSnapshot] = simulation.activeConversations.map { conv in
            let participantSnapshots = conv.participantIds.map { pid in
                ConversationParticipantSnapshot(
                    unitId: pid,
                    name: conv.participantNames[pid] ?? "",
                    line: conv.lineForParticipant(pid, at: currentTick),
                    isSpeaking: conv.isSpeaking(pid, at: currentTick)
                )
            }
            return ConversationSnapshot(
                participants: participantSnapshots,
                eavesdropperIds: conv.eavesdropperIds,
                topic: conv.topic,
                isSuccess: conv.isSuccess
            )
        }

        return WorldSnapshot(
            tick: world.currentTick,
            width: width,
            height: height,
            depth: world.depth,
            currentZ: currentZ,
            season: cal.season,
            timeOfDay: cal.timeOfDay,
            hour: cal.hour,
            calendarDescription: "\(cal.dateString) \(cal.timeString)",
            tiles: tiles,
            units: units,
            items: items,
            activeConversations: conversations
        )
    }
}
