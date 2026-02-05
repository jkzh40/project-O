// MARK: - Job System
// Manages work assignments for dwarves

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

// MARK: - Job Manager

/// Manages all jobs in the simulation
@MainActor
public final class JobManager: Sendable {
    /// All jobs indexed by ID
    public private(set) var jobs: [UInt64: Job] = [:]

    /// Jobs by status for quick lookup
    private var pendingJobs: Set<UInt64> = []
    private var activeJobs: Set<UInt64> = []
    private var completedJobs: Set<UInt64> = []

    /// Next job ID
    private var nextJobId: UInt64 = 1

    /// Maximum completed jobs to keep in history
    public var maxCompletedHistory: Int = 100

    public init() {}

    // MARK: - Job Creation

    /// Create a new job
    @discardableResult
    public func createJob(
        type: JobType,
        position: Position,
        priority: JobPriority = .normal,
        workRequired: Int? = nil,
        currentTick: UInt64 = 0
    ) -> Job {
        let work = workRequired ?? type.baseWorkTicks
        let job = Job(
            id: nextJobId,
            type: type,
            position: position,
            priority: priority,
            workRequired: work,
            createdAt: currentTick
        )
        nextJobId += 1

        jobs[job.id] = job
        pendingJobs.insert(job.id)

        return job
    }

    /// Create a mining job
    @discardableResult
    public func createMiningJob(at position: Position, priority: JobPriority = .normal, currentTick: UInt64 = 0) -> Job {
        var job = createJob(type: .mine, position: position, priority: priority, currentTick: currentTick)
        job.requiredSkill = .mining
        jobs[job.id] = job
        return job
    }

    /// Create a hauling job
    @discardableResult
    public func createHaulJob(
        itemId: UInt64,
        from: Position,
        to: Position,
        priority: JobPriority = .normal,
        currentTick: UInt64 = 0
    ) -> Job {
        var job = createJob(type: .haul, position: from, priority: priority, currentTick: currentTick)
        job.targetItem = itemId
        job.targetPosition = to
        jobs[job.id] = job
        return job
    }

    /// Create a crafting job
    @discardableResult
    public func createCraftJob(
        at position: Position,
        resultType: ItemType,
        requiredItems: [ItemType: Int],
        workshopId: UInt64,
        priority: JobPriority = .normal,
        currentTick: UInt64 = 0
    ) -> Job {
        var job = createJob(type: .craft, position: position, priority: priority, currentTick: currentTick)
        job.requiredItems = requiredItems
        job.resultItemType = resultType
        job.workshopId = workshopId
        jobs[job.id] = job
        return job
    }

    // MARK: - Job Assignment

    /// Find the best available job for a unit
    public func findJobForUnit(
        unitId: UInt64,
        unitPosition: Position,
        laborPrefs: LaborPreferences,
        skills: [SkillType: SkillEntry]
    ) -> Job? {
        // Get all pending jobs
        var availableJobs: [Job] = []

        for jobId in pendingJobs {
            guard let job = jobs[jobId] else { continue }

            // Check if unit has this labor enabled
            guard laborPrefs.isEnabled(job.type) else { continue }

            // Check skill requirements
            if let requiredSkill = job.requiredSkill,
               job.minimumSkillLevel > 0 {
                let unitSkillLevel = skills[requiredSkill]?.rating ?? 0
                if unitSkillLevel < job.minimumSkillLevel {
                    continue
                }
            }

            availableJobs.append(job)
        }

        // Sort by priority, then by distance
        availableJobs.sort(by: { (job1: Job, job2: Job) -> Bool in
            if job1.priority != job2.priority {
                return job1.priority.rawValue > job2.priority.rawValue
            }
            let dist1 = unitPosition.distance(to: job1.position)
            let dist2 = unitPosition.distance(to: job2.position)
            return dist1 < dist2
        })

        return availableJobs.first
    }

    /// Claim a job for a unit
    public func claimJob(jobId: UInt64, unitId: UInt64) -> Bool {
        guard var job = jobs[jobId], job.canBeClaimed else {
            return false
        }

        job.status = .claimed
        job.assignedUnit = unitId
        jobs[jobId] = job

        pendingJobs.remove(jobId)
        activeJobs.insert(jobId)

        return true
    }

    /// Release a claimed job (unit gave up or died)
    public func releaseJob(jobId: UInt64) {
        guard var job = jobs[jobId] else { return }

        job.status = .pending
        job.assignedUnit = nil
        jobs[jobId] = job

        activeJobs.remove(jobId)
        pendingJobs.insert(jobId)
    }

    /// Start working on a job
    public func startJob(jobId: UInt64) {
        guard var job = jobs[jobId], job.status == .claimed else { return }

        job.status = .inProgress
        jobs[jobId] = job
    }

    /// Apply work to a job
    public func applyWork(jobId: UInt64, amount: Int = 1) -> Bool {
        guard var job = jobs[jobId], job.isActive else { return false }

        job.workRemaining = max(0, job.workRemaining - amount)
        jobs[jobId] = job

        return job.workRemaining == 0
    }

    /// Complete a job
    public func completeJob(jobId: UInt64) {
        guard var job = jobs[jobId] else { return }

        job.status = .completed
        job.workRemaining = 0
        jobs[jobId] = job

        activeJobs.remove(jobId)
        completedJobs.insert(jobId)

        // Trim history if needed
        trimCompletedHistory()
    }

    /// Cancel a job
    public func cancelJob(jobId: UInt64) {
        guard var job = jobs[jobId] else { return }

        job.status = .cancelled
        jobs[jobId] = job

        pendingJobs.remove(jobId)
        activeJobs.remove(jobId)
        completedJobs.insert(jobId)

        trimCompletedHistory()
    }

    /// Suspend a job temporarily
    public func suspendJob(jobId: UInt64) {
        guard var job = jobs[jobId] else { return }

        job.status = .suspended
        job.assignedUnit = nil
        jobs[jobId] = job

        activeJobs.remove(jobId)
        pendingJobs.insert(jobId)
    }

    // MARK: - Queries

    /// Get all pending jobs
    public func getPendingJobs() -> [Job] {
        pendingJobs.compactMap { jobs[$0] }
    }

    /// Get all active jobs
    public func getActiveJobs() -> [Job] {
        activeJobs.compactMap { jobs[$0] }
    }

    /// Get jobs assigned to a unit
    public func getJobsForUnit(_ unitId: UInt64) -> [Job] {
        jobs.values.filter { $0.assignedUnit == unitId && $0.isActive }
    }

    /// Get jobs at a position
    public func getJobsAtPosition(_ position: Position) -> [Job] {
        jobs.values.filter { $0.position == position && ($0.status == .pending || $0.isActive) }
    }

    /// Get jobs by type
    public func getJobsByType(_ type: JobType) -> [Job] {
        jobs.values.filter { $0.type == type && $0.status != .completed && $0.status != .cancelled }
    }

    /// Count of pending jobs
    public var pendingCount: Int { pendingJobs.count }

    /// Count of active jobs
    public var activeCount: Int { activeJobs.count }

    /// Update a job's target position
    public func setTargetPosition(jobId: UInt64, targetPosition: Position) {
        guard var job = jobs[jobId] else { return }
        job.targetPosition = targetPosition
        jobs[jobId] = job
    }

    public func setTargetUnit(jobId: UInt64, targetUnit: UInt64) {
        guard var job = jobs[jobId] else { return }
        job.targetUnit = targetUnit
        jobs[jobId] = job
    }

    // MARK: - Private

    private func trimCompletedHistory() {
        while completedJobs.count > maxCompletedHistory {
            // Remove oldest completed job
            if let oldestId = completedJobs.min(by: {
                (jobs[$0]?.createdAt ?? 0) < (jobs[$1]?.createdAt ?? 0)
            }) {
                completedJobs.remove(oldestId)
                jobs.removeValue(forKey: oldestId)
            }
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

// MARK: - Designation Manager

/// Manages terrain designations
@MainActor
public final class DesignationManager: Sendable {
    /// All designations indexed by ID
    public private(set) var designations: [UInt64: Designation] = [:]

    /// Designations by position for quick lookup
    private var designationsByPosition: [Position: UInt64] = [:]

    /// Next designation ID
    private var nextDesignationId: UInt64 = 1

    /// Reference to job manager
    private weak var jobManager: JobManager?

    public init(jobManager: JobManager? = nil) {
        self.jobManager = jobManager
    }

    public func setJobManager(_ manager: JobManager) {
        self.jobManager = manager
    }

    /// Add a designation
    @discardableResult
    public func addDesignation(type: DesignationType, at position: Position) -> Designation? {
        // Check if position already has a designation
        if designationsByPosition[position] != nil {
            return nil
        }

        let designation = Designation(id: nextDesignationId, type: type, position: position)
        nextDesignationId += 1

        designations[designation.id] = designation
        designationsByPosition[position] = designation.id

        // Create associated job
        createJobForDesignation(designation)

        return designation
    }

    /// Remove a designation
    public func removeDesignation(at position: Position) {
        guard let designationId = designationsByPosition[position],
              let designation = designations[designationId] else {
            return
        }

        // Cancel associated job
        if let jobId = designation.jobId {
            jobManager?.cancelJob(jobId: jobId)
        }

        designations.removeValue(forKey: designationId)
        designationsByPosition.removeValue(forKey: position)
    }

    /// Get designation at position
    public func getDesignation(at position: Position) -> Designation? {
        guard let id = designationsByPosition[position] else { return nil }
        return designations[id]
    }

    /// Complete a designation (called when job finishes)
    public func completeDesignation(at position: Position) {
        guard let designationId = designationsByPosition[position] else { return }

        designations.removeValue(forKey: designationId)
        designationsByPosition.removeValue(forKey: position)
    }

    /// Create job for a designation
    private func createJobForDesignation(_ designation: Designation) {
        guard let jobManager = jobManager else { return }

        let jobType: JobType
        switch designation.type {
        case .dig, .channel, .upStair, .downStair, .upDownStair, .ramp, .smoothWall, .carveTrack:
            jobType = .mine
        case .chopTree:
            jobType = .chopTree
        case .gatherPlants:
            jobType = .harvest
        }

        let job = jobManager.createJob(type: jobType, position: designation.position)

        // Link designation and job
        var updatedDesignation = designation
        updatedDesignation.jobId = job.id
        designations[designation.id] = updatedDesignation
    }

    /// Get all active designations
    public func getAllDesignations() -> [Designation] {
        Array(designations.values)
    }

    /// Count of designations
    public var count: Int { designations.count }
}
