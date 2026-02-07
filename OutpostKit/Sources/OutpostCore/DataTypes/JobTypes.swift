// MARK: - Job System Types

import Foundation

// MARK: - Job Status

/// Current status of a job
public enum JobStatus: String, Sendable {
    case pending = "pending"        // Waiting to be claimed
    case claimed = "claimed"        // Assigned to a worker
    case inProgress = "in progress" // Being worked on
    case suspended = "suspended"    // Temporarily paused
    case completed = "completed"    // Finished successfully
    case cancelled = "cancelled"    // Cancelled/impossible
}

// MARK: - Job

/// A task that can be performed by a unit
public struct Job: Sendable, Identifiable {
    public let id: UInt64
    public let type: JobType
    public var status: JobStatus
    public var priority: JobPriority

    /// Location where the job is performed
    public var position: Position

    /// Unit currently assigned to this job (nil if unclaimed)
    public var assignedUnit: UInt64?

    /// Required items for the job (item type -> count needed)
    public var requiredItems: [ItemType: Int]

    /// Items reserved for this job (item IDs)
    public var reservedItems: [UInt64]

    /// Required skill for this job
    public var requiredSkill: SkillType?

    /// Minimum skill level required (0 = any)
    public var minimumSkillLevel: Int

    /// Work remaining (ticks of work needed)
    public var workRemaining: Int

    /// Total work required
    public let totalWork: Int

    /// Target position for movement/hauling jobs
    public var targetPosition: Position?

    /// Target item for item-related jobs
    public var targetItem: UInt64?

    /// Target unit for hunting/combat jobs
    public var targetUnit: UInt64?

    /// Workshop this job belongs to (if any)
    public var workshopId: UInt64?

    /// Creation tick
    public let createdAt: UInt64

    /// Result item type (for crafting jobs)
    public var resultItemType: ItemType?

    public init(
        id: UInt64,
        type: JobType,
        position: Position,
        priority: JobPriority = .normal,
        workRequired: Int = 100,
        createdAt: UInt64 = 0
    ) {
        self.id = id
        self.type = type
        self.status = .pending
        self.priority = priority
        self.position = position
        self.assignedUnit = nil
        self.requiredItems = [:]
        self.reservedItems = []
        self.requiredSkill = type.associatedSkill
        self.minimumSkillLevel = 0
        self.workRemaining = workRequired
        self.totalWork = workRequired
        self.targetPosition = nil
        self.targetItem = nil
        self.targetUnit = nil
        self.workshopId = nil
        self.createdAt = createdAt
        self.resultItemType = nil
    }

    /// Progress as percentage (0-100)
    public var progress: Int {
        guard totalWork > 0 else { return 100 }
        return 100 - (workRemaining * 100 / totalWork)
    }

    /// Whether the job can be claimed
    public var canBeClaimed: Bool {
        status == .pending || status == .suspended
    }

    /// Whether the job is active
    public var isActive: Bool {
        status == .claimed || status == .inProgress
    }
}

// MARK: - Job Type Extensions

extension JobType {
    /// The skill associated with this job type
    public var associatedSkill: SkillType? {
        switch self {
        case .mine, .dig: return .mining
        case .chopTree: return .woodcutting
        case .construct, .buildWorkshop: return .masonry
        case .craft: return .carpentry
        case .haul, .store: return nil  // No skill needed
        case .cook: return .cooking
        case .brew: return .brewing
        case .plant, .harvest: return .farming
        case .hunt: return .meleeCombat
        case .fish: return nil  // Could add fishing skill
        }
    }

    /// Base work ticks required for this job type
    public var baseWorkTicks: Int {
        switch self {
        case .mine, .dig: return 150
        case .chopTree: return 200
        case .construct: return 100
        case .buildWorkshop: return 300
        case .craft: return 150
        case .haul: return 20
        case .store: return 10
        case .cook: return 100
        case .brew: return 120
        case .plant: return 50
        case .harvest: return 30
        case .hunt: return 50
        case .fish: return 80
        }
    }
}

// MARK: - Labor Preferences

/// Tracks which labors a unit is willing to perform
public struct LaborPreferences: Sendable {
    /// Enabled labors (job types this unit will do)
    public var enabledLabors: Set<JobType>

    public init() {
        // By default, enable all labors
        self.enabledLabors = Set(JobType.allCases)
    }

    public init(enabled: Set<JobType>) {
        self.enabledLabors = enabled
    }

    /// Check if a labor is enabled
    public func isEnabled(_ jobType: JobType) -> Bool {
        enabledLabors.contains(jobType)
    }

    /// Enable a labor
    public mutating func enable(_ jobType: JobType) {
        enabledLabors.insert(jobType)
    }

    /// Disable a labor
    public mutating func disable(_ jobType: JobType) {
        enabledLabors.remove(jobType)
    }

    /// Toggle a labor
    public mutating func toggle(_ jobType: JobType) {
        if enabledLabors.contains(jobType) {
            enabledLabors.remove(jobType)
        } else {
            enabledLabors.insert(jobType)
        }
    }
}

// MARK: - Designation

/// A designation for terrain modification
public struct Designation: Sendable, Identifiable {
    public let id: UInt64
    public let type: DesignationType
    public let position: Position
    public var jobId: UInt64?  // Associated job once created

    public init(id: UInt64, type: DesignationType, position: Position) {
        self.id = id
        self.type = type
        self.position = position
        self.jobId = nil
    }
}

/// Types of terrain designations
public enum DesignationType: String, Sendable, CaseIterable {
    case dig = "dig"                    // Mine out tile
    case channel = "channel"            // Remove floor, create hole
    case upStair = "up stair"           // Carve upward stairs
    case downStair = "down stair"       // Carve downward stairs
    case upDownStair = "up/down stair"  // Carve both-way stairs
    case ramp = "ramp"                  // Carve ramp
    case smoothWall = "smooth"          // Smooth natural wall
    case carveTrack = "carve track"     // Carve minecart track
    case chopTree = "chop tree"         // Cut down tree
    case gatherPlants = "gather plants" // Collect plants
}
