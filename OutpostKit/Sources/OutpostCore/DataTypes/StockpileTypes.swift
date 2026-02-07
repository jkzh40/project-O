// MARK: - Stockpile & Hauling Types
// Storage zones and item transportation

import Foundation

// MARK: - Stockpile Settings

/// Settings for what a stockpile accepts
public struct StockpileSettings: Sendable {
    /// Accepted item types
    public var acceptedTypes: Set<ItemType>

    /// Maximum items (0 = unlimited)
    public var maxItems: Int

    /// Accept all quality levels?
    public var acceptAllQualities: Bool

    /// Minimum quality to accept
    public var minimumQuality: ItemQuality

    public init(
        acceptedTypes: Set<ItemType> = [],
        maxItems: Int = 0,
        acceptAllQualities: Bool = true,
        minimumQuality: ItemQuality = .standard
    ) {
        self.acceptedTypes = acceptedTypes
        self.maxItems = maxItems
        self.acceptAllQualities = acceptAllQualities
        self.minimumQuality = minimumQuality
    }

    /// Preset: Accept all items
    public static let acceptAll = StockpileSettings(
        acceptedTypes: Set(ItemType.allCases)
    )

    /// Preset: Food only
    public static let foodOnly = StockpileSettings(
        acceptedTypes: [.food, .rawMeat, .plant]
    )

    /// Preset: Drinks only
    public static let drinksOnly = StockpileSettings(
        acceptedTypes: [.drink]
    )

    /// Preset: Furniture
    public static let furniture = StockpileSettings(
        acceptedTypes: [.bed, .table, .chair, .door, .barrel, .bin]
    )

    /// Preset: Materials
    public static let materials = StockpileSettings(
        acceptedTypes: [.log, .stone, .ore]
    )

    /// Preset: Tools
    public static let tools = StockpileSettings(
        acceptedTypes: [.pickaxe, .axe]
    )

    /// Check if an item type is accepted
    public func accepts(_ type: ItemType) -> Bool {
        acceptedTypes.isEmpty || acceptedTypes.contains(type)
    }

    /// Check if an item is accepted
    public func acceptsItem(type: ItemType, quality: ItemQuality) -> Bool {
        guard accepts(type) else { return false }
        if acceptAllQualities { return true }
        return quality.multiplier >= minimumQuality.multiplier
    }
}

// MARK: - Stockpile

/// A storage zone for items
public struct Stockpile: Sendable, Identifiable {
    public let id: UInt64
    public var name: String

    /// Top-left position of the stockpile
    public var position: Position

    /// Size of the stockpile
    public var width: Int
    public var height: Int

    /// Settings for what this stockpile accepts
    public var settings: StockpileSettings

    /// Items currently stored (item IDs)
    public var storedItems: Set<UInt64>

    /// Whether the stockpile is enabled
    public var isEnabled: Bool

    public init(
        id: UInt64,
        name: String = "Stockpile",
        position: Position,
        width: Int = 3,
        height: Int = 3,
        settings: StockpileSettings = .acceptAll
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.width = width
        self.height = height
        self.settings = settings
        self.storedItems = []
        self.isEnabled = true
    }

    /// All positions within this stockpile
    public var positions: [Position] {
        var result: [Position] = []
        for dy in 0..<height {
            for dx in 0..<width {
                result.append(Position(x: position.x + dx, y: position.y + dy, z: position.z))
            }
        }
        return result
    }

    /// Check if a position is within this stockpile
    public func contains(_ pos: Position) -> Bool {
        guard pos.z == position.z else { return false }
        let dx = pos.x - position.x
        let dy = pos.y - position.y
        return dx >= 0 && dx < width && dy >= 0 && dy < height
    }

    /// Current capacity usage
    public var usedCapacity: Int { storedItems.count }

    /// Total capacity (positions * items per tile, simplified to positions)
    public var totalCapacity: Int {
        if settings.maxItems > 0 {
            return settings.maxItems
        }
        return width * height * 5  // Assume 5 items per tile
    }

    /// Whether the stockpile has room
    public var hasRoom: Bool {
        usedCapacity < totalCapacity
    }

    /// Add an item to storage
    public mutating func addItem(_ itemId: UInt64) {
        storedItems.insert(itemId)
    }

    /// Remove an item from storage
    public mutating func removeItem(_ itemId: UInt64) {
        storedItems.remove(itemId)
    }
}

// MARK: - Haul Task

/// A pending hauling task
public struct HaulTask: Sendable, Identifiable {
    public let id: UInt64
    public let itemId: UInt64
    public let sourcePosition: Position
    public let destinationStockpile: UInt64
    public var destinationPosition: Position?

    /// Assigned hauler (if any)
    public var assignedUnit: UInt64?

    /// Whether the item has been picked up
    public var pickedUp: Bool

    public init(
        id: UInt64,
        itemId: UInt64,
        sourcePosition: Position,
        destinationStockpile: UInt64
    ) {
        self.id = id
        self.itemId = itemId
        self.sourcePosition = sourcePosition
        self.destinationStockpile = destinationStockpile
        self.destinationPosition = nil
        self.assignedUnit = nil
        self.pickedUp = false
    }
}
