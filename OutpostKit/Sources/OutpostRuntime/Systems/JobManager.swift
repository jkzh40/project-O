// MARK: - Job Manager & Designation Manager

import Foundation
import OutpostCore

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
