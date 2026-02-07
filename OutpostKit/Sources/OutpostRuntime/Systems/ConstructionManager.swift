// MARK: - Construction Manager

import Foundation
import OutpostCore

/// Manages buildings and workshops
@MainActor
public final class ConstructionManager: Sendable {
    /// All workshops by ID
    public private(set) var workshops: [UInt64: Workshop] = [:]

    /// All buildings by ID
    public private(set) var buildings: [UInt64: Building] = [:]

    /// Next IDs
    private var nextWorkshopId: UInt64 = 1
    private var nextBuildingId: UInt64 = 1

    /// Buildings by position for quick lookup
    private var buildingsByPosition: [Position: UInt64] = [:]
    private var workshopsByPosition: [Position: UInt64] = [:]

    public init() {}

    // MARK: - Workshop Management

    /// Plan a new workshop
    @discardableResult
    public func planWorkshop(type: WorkshopType, at position: Position) -> Workshop? {
        // Check if position is free
        if workshopsByPosition[position] != nil { return nil }

        let workshop = Workshop(id: nextWorkshopId, type: type, position: position)
        nextWorkshopId += 1

        workshops[workshop.id] = workshop
        workshopsByPosition[position] = workshop.id

        return workshop
    }

    /// Mark workshop as materials delivered
    public func markWorkshopMaterialsReady(workshopId: UInt64) {
        guard var workshop = workshops[workshopId] else { return }
        if workshop.status == .planned || workshop.status == .materialsPending {
            workshop.status = .constructing
            workshops[workshopId] = workshop
        }
    }

    /// Complete workshop construction
    public func completeWorkshop(workshopId: UInt64) {
        guard var workshop = workshops[workshopId] else { return }
        workshop.status = .complete
        workshops[workshopId] = workshop
    }

    /// Remove a workshop
    public func removeWorkshop(workshopId: UInt64) {
        guard let workshop = workshops[workshopId] else { return }
        workshopsByPosition.removeValue(forKey: workshop.position)
        workshops.removeValue(forKey: workshopId)
    }

    /// Get workshop at position
    public func getWorkshop(at position: Position) -> Workshop? {
        guard let id = workshopsByPosition[position] else { return nil }
        return workshops[id]
    }

    /// Get workshops of a specific type
    public func getWorkshops(ofType type: WorkshopType) -> [Workshop] {
        workshops.values.filter { $0.type == type && $0.status == .complete }
    }

    // MARK: - Building Management

    /// Plan a new building
    @discardableResult
    public func planBuilding(type: BuildingType, at position: Position) -> Building? {
        if buildingsByPosition[position] != nil { return nil }

        let building = Building(id: nextBuildingId, type: type, position: position)
        nextBuildingId += 1

        buildings[building.id] = building
        buildingsByPosition[position] = building.id

        return building
    }

    /// Update building construction progress
    public func updateBuildingProgress(buildingId: UInt64, progress: Int) {
        guard var building = buildings[buildingId] else { return }
        building.constructionProgress = min(100, progress)

        if building.constructionProgress >= 100 {
            building.status = .complete
        } else if building.status == .planned {
            building.status = .constructing
        }

        buildings[buildingId] = building
    }

    /// Complete a building
    public func completeBuilding(buildingId: UInt64, quality: ItemQuality = .standard, material: ItemType? = nil) {
        guard var building = buildings[buildingId] else { return }
        building.status = .complete
        building.constructionProgress = 100
        building.quality = quality
        building.material = material
        buildings[buildingId] = building
    }

    /// Assign owner to a building (e.g., bed)
    public func assignOwner(buildingId: UInt64, ownerId: UInt64?) {
        guard var building = buildings[buildingId] else { return }
        building.ownerId = ownerId
        buildings[buildingId] = building
    }

    /// Remove a building
    public func removeBuilding(buildingId: UInt64) {
        guard let building = buildings[buildingId] else { return }
        buildingsByPosition.removeValue(forKey: building.position)
        buildings.removeValue(forKey: buildingId)
    }

    /// Get building at position
    public func getBuilding(at position: Position) -> Building? {
        guard let id = buildingsByPosition[position] else { return nil }
        return buildings[id]
    }

    /// Get buildings of a specific type
    public func getBuildings(ofType type: BuildingType) -> [Building] {
        buildings.values.filter { $0.type == type && $0.status == .complete }
    }

    /// Find unowned bed
    public func findUnownedBed() -> Building? {
        buildings.values.first { $0.type == .bed && $0.status == .complete && $0.ownerId == nil }
    }

    // MARK: - Queries

    /// Get all complete workshops
    public func getCompleteWorkshops() -> [Workshop] {
        workshops.values.filter { $0.status == .complete }
    }

    /// Get all incomplete buildings (need construction work)
    public func getIncompleteBuildings() -> [Building] {
        buildings.values.filter { $0.status != .complete }
    }

    /// Get all planned or constructing workshops
    public func getPendingWorkshops() -> [Workshop] {
        workshops.values.filter { $0.status != .complete }
    }
}
