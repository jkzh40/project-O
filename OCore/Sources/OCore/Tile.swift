// MARK: - Tile

import Foundation

/// A single map cell in the game world
public struct Tile: Sendable {
    /// The terrain type of this tile
    public var terrain: TerrainType

    /// IDs of items located on this tile
    public var itemIds: [UInt64]

    /// ID of the unit occupying this tile, if any
    public var unitId: UInt64?

    /// Whether units can pass through this tile
    public var isPassable: Bool {
        terrain.isPassable
    }

    /// Movement cost for traversing this tile
    public var movementCost: Double {
        terrain.movementCost
    }

    /// Creates a new tile with the specified terrain
    /// - Parameter terrain: The terrain type for this tile
    public init(terrain: TerrainType) {
        self.terrain = terrain
        self.itemIds = []
        self.unitId = nil
    }

    /// Creates a new tile with all properties specified
    /// - Parameters:
    ///   - terrain: The terrain type for this tile
    ///   - itemIds: IDs of items on this tile
    ///   - unitId: ID of occupying unit, if any
    public init(terrain: TerrainType, itemIds: [UInt64], unitId: UInt64?) {
        self.terrain = terrain
        self.itemIds = itemIds
        self.unitId = unitId
    }

    /// Adds an item ID to this tile
    /// - Parameter itemId: The ID of the item to add
    public mutating func addItem(_ itemId: UInt64) {
        itemIds.append(itemId)
    }

    /// Removes an item ID from this tile
    /// - Parameter itemId: The ID of the item to remove
    /// - Returns: True if the item was found and removed
    @discardableResult
    public mutating func removeItem(_ itemId: UInt64) -> Bool {
        if let index = itemIds.firstIndex(of: itemId) {
            itemIds.remove(at: index)
            return true
        }
        return false
    }

    /// Character representation for terminal display
    public var displayChar: Character {
        // Show unit if present
        if unitId != nil {
            return "@"
        }
        // Show item if present
        if !itemIds.isEmpty {
            return "!"
        }
        // Otherwise show terrain
        return terrain.displayChar
    }
}
