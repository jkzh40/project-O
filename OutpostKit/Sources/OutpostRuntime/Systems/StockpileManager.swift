// MARK: - Stockpile Manager

import Foundation
import OutpostCore

/// Manages stockpiles and hauling
@MainActor
public final class StockpileManager: Sendable {
    /// All stockpiles by ID
    public private(set) var stockpiles: [UInt64: Stockpile] = [:]

    /// Pending haul tasks
    public private(set) var haulTasks: [UInt64: HaulTask] = [:]

    /// Stockpile positions for quick lookup
    private var stockpilesByPosition: [Position: UInt64] = [:]

    /// Next IDs
    private var nextStockpileId: UInt64 = 1
    private var nextHaulTaskId: UInt64 = 1

    public init() {}

    // MARK: - Stockpile Management

    /// Create a new stockpile
    @discardableResult
    public func createStockpile(
        name: String = "Stockpile",
        at position: Position,
        width: Int = 3,
        height: Int = 3,
        settings: StockpileSettings = .acceptAll
    ) -> Stockpile {
        let stockpile = Stockpile(
            id: nextStockpileId,
            name: name,
            position: position,
            width: width,
            height: height,
            settings: settings
        )
        nextStockpileId += 1

        stockpiles[stockpile.id] = stockpile

        // Register all positions
        for pos in stockpile.positions {
            stockpilesByPosition[pos] = stockpile.id
        }

        return stockpile
    }

    /// Update stockpile settings
    public func updateSettings(stockpileId: UInt64, settings: StockpileSettings) {
        guard var stockpile = stockpiles[stockpileId] else { return }
        stockpile.settings = settings
        stockpiles[stockpileId] = stockpile
    }

    /// Remove a stockpile
    public func removeStockpile(stockpileId: UInt64) {
        guard let stockpile = stockpiles[stockpileId] else { return }

        // Remove position mappings
        for pos in stockpile.positions {
            stockpilesByPosition.removeValue(forKey: pos)
        }

        // Cancel related haul tasks
        for (taskId, task) in haulTasks {
            if task.destinationStockpile == stockpileId {
                haulTasks.removeValue(forKey: taskId)
            }
        }

        stockpiles.removeValue(forKey: stockpileId)
    }

    /// Get stockpile at position
    public func getStockpile(at position: Position) -> Stockpile? {
        guard let id = stockpilesByPosition[position] else { return nil }
        return stockpiles[id]
    }

    /// Find a stockpile that accepts an item type
    public func findStockpile(for itemType: ItemType, quality: ItemQuality = .standard) -> Stockpile? {
        stockpiles.values.first { stockpile in
            stockpile.isEnabled &&
            stockpile.hasRoom &&
            stockpile.settings.acceptsItem(type: itemType, quality: quality)
        }
    }

    /// Add item to stockpile
    public func addItemToStockpile(itemId: UInt64, stockpileId: UInt64) {
        guard var stockpile = stockpiles[stockpileId] else { return }
        stockpile.addItem(itemId)
        stockpiles[stockpileId] = stockpile
    }

    /// Remove item from stockpile
    public func removeItemFromStockpile(itemId: UInt64, stockpileId: UInt64) {
        guard var stockpile = stockpiles[stockpileId] else { return }
        stockpile.removeItem(itemId)
        stockpiles[stockpileId] = stockpile
    }

    // MARK: - Hauling

    /// Create a haul task for an item
    @discardableResult
    public func createHaulTask(
        itemId: UInt64,
        itemType: ItemType,
        itemQuality: ItemQuality,
        sourcePosition: Position
    ) -> HaulTask? {
        // Find appropriate stockpile
        guard let stockpile = findStockpile(for: itemType, quality: itemQuality) else {
            return nil
        }

        // Find empty position in stockpile
        let destinationPos = findEmptyPositionInStockpile(stockpile)

        var task = HaulTask(
            id: nextHaulTaskId,
            itemId: itemId,
            sourcePosition: sourcePosition,
            destinationStockpile: stockpile.id
        )
        task.destinationPosition = destinationPos
        nextHaulTaskId += 1

        haulTasks[task.id] = task
        return task
    }

    /// Find empty position within a stockpile
    private func findEmptyPositionInStockpile(_ stockpile: Stockpile) -> Position? {
        // Simple: just return the first position
        return stockpile.positions.first
    }

    /// Claim a haul task for a unit
    public func claimHaulTask(taskId: UInt64, unitId: UInt64) -> Bool {
        guard var task = haulTasks[taskId], task.assignedUnit == nil else {
            return false
        }

        task.assignedUnit = unitId
        haulTasks[taskId] = task
        return true
    }

    /// Mark item as picked up
    public func markItemPickedUp(taskId: UInt64) {
        guard var task = haulTasks[taskId] else { return }
        task.pickedUp = true
        haulTasks[taskId] = task
    }

    /// Complete a haul task
    public func completeHaulTask(taskId: UInt64) {
        guard let task = haulTasks[taskId] else { return }

        // Add item to stockpile
        addItemToStockpile(itemId: task.itemId, stockpileId: task.destinationStockpile)

        haulTasks.removeValue(forKey: taskId)
    }

    /// Cancel a haul task
    public func cancelHaulTask(taskId: UInt64) {
        haulTasks.removeValue(forKey: taskId)
    }

    /// Release a haul task (unit gave up)
    public func releaseHaulTask(taskId: UInt64) {
        guard var task = haulTasks[taskId] else { return }
        task.assignedUnit = nil
        task.pickedUp = false
        haulTasks[taskId] = task
    }

    // MARK: - Queries

    /// Get pending haul tasks (not assigned)
    public func getPendingHaulTasks() -> [HaulTask] {
        haulTasks.values.filter { $0.assignedUnit == nil }
    }

    /// Get haul tasks for a unit
    public func getHaulTasks(for unitId: UInt64) -> [HaulTask] {
        haulTasks.values.filter { $0.assignedUnit == unitId }
    }

    /// Check if item already has a haul task
    public func hasHaulTask(for itemId: UInt64) -> Bool {
        haulTasks.values.contains { $0.itemId == itemId }
    }

    /// Generate haul tasks for loose items
    public func generateHaulTasksForItems(items: [(id: UInt64, type: ItemType, quality: ItemQuality, position: Position)]) -> Int {
        var created = 0

        for item in items {
            // Skip if already has a task
            if hasHaulTask(for: item.id) { continue }

            // Skip if already in a stockpile
            if getStockpile(at: item.position) != nil { continue }

            // Try to create haul task
            if createHaulTask(
                itemId: item.id,
                itemType: item.type,
                itemQuality: item.quality,
                sourcePosition: item.position
            ) != nil {
                created += 1
            }
        }

        return created
    }
}
