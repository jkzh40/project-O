// MARK: - Construction System
// Handles workshops, buildings, and construction

import Foundation

// MARK: - Workshop Types

/// Types of workshops that can be built
public enum WorkshopType: String, Sendable, CaseIterable {
    case carpenterWorkshop = "Carpenter's Workshop"
    case masonWorkshop = "Mason's Workshop"
    case craftsorcWorkshop = "Craftsorc's Workshop"
    case kitchen = "Kitchen"
    case brewery = "Brewery"
    case forge = "Forge"
    case smelter = "Smelter"
    case mechanicsWorkshop = "Mechanics Workshop"
    case butcherShop = "Butcher Shop"
    case tannerShop = "Tanner's Shop"
    case clothierShop = "Clothier's Shop"

    /// Required skill to operate this workshop
    public var requiredSkill: SkillType {
        switch self {
        case .carpenterWorkshop: return .carpentry
        case .masonWorkshop: return .masonry
        case .craftsorcWorkshop: return .carpentry  // General crafting
        case .kitchen: return .cooking
        case .brewery: return .brewing
        case .forge, .smelter: return .mining  // Metalworking skill would be ideal
        case .mechanicsWorkshop: return .mining  // Mechanics skill would be ideal
        case .butcherShop, .tannerShop: return .cooking  // Animal skill would be ideal
        case .clothierShop: return .carpentry  // Clothier skill would be ideal
        }
    }

    /// Size of the workshop (width x height) — all workshops are standard 3x3
    public var size: (width: Int, height: Int) { (3, 3) }

    /// Materials required to build
    public var buildRequirements: [ItemType: Int] {
        switch self {
        case .carpenterWorkshop:
            return [.log: 3]
        case .masonWorkshop:
            return [.stone: 3]
        case .craftsorcWorkshop:
            return [.log: 1, .stone: 1]
        case .kitchen:
            return [.stone: 2, .log: 1]
        case .brewery:
            return [.log: 2, .stone: 1]
        case .forge:
            return [.stone: 4]
        case .smelter:
            return [.stone: 5]
        case .mechanicsWorkshop:
            return [.stone: 2, .log: 1]
        case .butcherShop, .tannerShop, .clothierShop:
            return [.log: 2]
        }
    }

    /// Display character for map
    public var displayChar: Character {
        switch self {
        case .carpenterWorkshop: return "W"
        case .masonWorkshop: return "M"
        case .craftsorcWorkshop: return "C"
        case .kitchen: return "K"
        case .brewery: return "B"
        case .forge: return "F"
        case .smelter: return "S"
        case .mechanicsWorkshop: return "m"
        case .butcherShop: return "b"
        case .tannerShop: return "t"
        case .clothierShop: return "c"
        }
    }
}

// MARK: - Building Types

/// Types of buildings/furniture
public enum BuildingType: String, Sendable, CaseIterable {
    // Furniture
    case bed = "Bed"
    case table = "Table"
    case chair = "Chair"
    case door = "Door"
    case cabinet = "Cabinet"
    case coffer = "Coffer"
    case statue = "Statue"

    // Storage
    case barrel = "Barrel"
    case bin = "Bin"
    case chest = "Chest"

    // Infrastructure
    case well = "Well"
    case lever = "Lever"
    case floodgate = "Floodgate"
    case bridge = "Bridge"

    // Defense
    case trap = "Trap"
    case wall = "Wall"

    /// Associated item type (for furniture that comes from items)
    public var itemType: ItemType? {
        switch self {
        case .bed: return .bed
        case .table: return .table
        case .chair: return .chair
        case .door: return .door
        case .barrel: return .barrel
        case .bin: return .bin
        default: return nil
        }
    }
}

// MARK: - Building Status

/// Status of a building under construction
public enum BuildingStatus: String, Sendable {
    case planned = "planned"
    case materialsPending = "materials pending"
    case constructing = "constructing"
    case complete = "complete"
    case deconstructing = "deconstructing"
}

// MARK: - Workshop

/// A workshop that can produce items
public struct Workshop: Sendable, Identifiable {
    public let id: UInt64
    public let type: WorkshopType
    public var position: Position
    public var status: BuildingStatus

    /// Currently queued jobs
    public var jobQueue: [UInt64]

    /// Currently working unit (if any)
    public var workerUnit: UInt64?

    /// Items stored at this workshop
    public var storedItems: [UInt64]

    public init(id: UInt64, type: WorkshopType, position: Position) {
        self.id = id
        self.type = type
        self.position = position
        self.status = .planned
        self.jobQueue = []
        self.workerUnit = nil
        self.storedItems = []
    }

    /// Whether the workshop can accept new jobs
    public var canAcceptJobs: Bool {
        status == .complete && jobQueue.count < 10
    }

    /// Add a job to the queue
    public mutating func queueJob(_ jobId: UInt64) {
        guard canAcceptJobs else { return }
        jobQueue.append(jobId)
    }

    /// Get and remove the next job
    public mutating func dequeueJob() -> UInt64? {
        guard !jobQueue.isEmpty else { return nil }
        return jobQueue.removeFirst()
    }
}

// MARK: - Building

/// A placed building or furniture
public struct Building: Sendable, Identifiable {
    public let id: UInt64
    public let type: BuildingType
    public var position: Position
    public var status: BuildingStatus

    /// Material used (affects quality appearance)
    public var material: ItemType?

    /// Quality of the building
    public var quality: ItemQuality

    /// Owner unit (for furniture like beds)
    public var ownerId: UInt64?

    /// Construction progress (0-100)
    public var constructionProgress: Int

    public init(id: UInt64, type: BuildingType, position: Position) {
        self.id = id
        self.type = type
        self.position = position
        self.status = .planned
        self.material = nil
        self.quality = .standard
        self.ownerId = nil
        self.constructionProgress = 0
    }

    /// Whether construction is complete
    public var isComplete: Bool {
        status == .complete
    }
}

// MARK: - Construction Manager

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
