// MARK: - Item

import Foundation

/// A world object that can be picked up, used, or interacted with
public struct Item: Sendable, Identifiable {
    /// Unique identifier for this item
    public let id: UInt64

    /// The type of item
    public var itemType: ItemType

    /// Current position in the world
    public var position: Position

    /// Quality level of the item
    public var quality: ItemQuality

    /// Quantity for stackable items
    public var quantity: Int

    /// Counter for generating unique IDs
    /// Using nonisolated(unsafe) since access is protected by idLock
    nonisolated(unsafe) private static var nextId: UInt64 = 1
    private static let idLock = NSLock()

    /// Generates the next unique ID in a thread-safe manner
    private static func generateId() -> UInt64 {
        idLock.lock()
        defer { idLock.unlock() }
        let id = nextId
        nextId += 1
        return id
    }

    /// Creates a new item with an auto-generated ID
    /// - Parameters:
    ///   - itemType: The type of item
    ///   - position: Initial position in the world
    ///   - quality: Quality level (defaults to standard)
    ///   - quantity: Stack quantity (defaults to 1)
    public init(
        itemType: ItemType,
        position: Position,
        quality: ItemQuality = .standard,
        quantity: Int = 1
    ) {
        self.id = Self.generateId()
        self.itemType = itemType
        self.position = position
        self.quality = quality
        self.quantity = quantity
    }

    /// Creates a new item with a specific ID (for loading saved games)
    /// - Parameters:
    ///   - id: The specific ID to use
    ///   - itemType: The type of item
    ///   - position: Initial position in the world
    ///   - quality: Quality level
    ///   - quantity: Stack quantity
    public init(
        id: UInt64,
        itemType: ItemType,
        position: Position,
        quality: ItemQuality,
        quantity: Int
    ) {
        self.id = id
        self.itemType = itemType
        self.position = position
        self.quality = quality
        self.quantity = quantity
    }

    /// Sets the next ID value (useful for testing, new games, or loading saved games)
    /// - Parameter id: The next ID to use (defaults to 1 for a reset)
    public static func setNextId(_ id: UInt64 = 1) {
        idLock.lock()
        defer { idLock.unlock() }
        nextId = id
    }

    /// Factory method to create an item at a position
    public static func create(
        type: ItemType,
        at position: Position,
        quality: ItemQuality = .standard,
        quantity: Int = 1
    ) -> Item {
        Item(itemType: type, position: position, quality: quality, quantity: quantity)
    }

    /// Whether this item type is stackable (delegates to registry with hardcoded fallback)
    @MainActor
    public var isStackable: Bool {
        ItemRegistry.shared.isStackable(itemType)
    }

    /// The base value of this item (before quality multiplier) - delegates to registry
    @MainActor
    public var baseValue: Int {
        ItemRegistry.shared.baseValue(for: itemType)
    }

    /// The total value of this item (base * quality * quantity)
    @MainActor
    public var totalValue: Int {
        Int(Double(baseValue * quantity) * quality.multiplier)
    }
}
