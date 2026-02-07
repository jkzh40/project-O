// MARK: - Construction System Types
// Workshops, buildings, and construction

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
