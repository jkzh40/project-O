// MARK: - Autonomous Work Manager

import Foundation
import OutpostCore

/// Manages automatic job generation based on colony needs
@MainActor
public final class AutonomousWorkManager: Sendable {
    /// Maximum pending jobs per type to prevent flooding
    public var maxPendingJobsPerType: Int = 5

    /// Maximum total autonomous jobs
    public var maxTotalAutonomousJobs: Int = 20

    /// Scan radius for finding resources
    public var resourceScanRadius: Int = 50

    /// Minimum distance between same-type jobs to spread work
    public var minJobSpacing: Int = 3

    /// Track jobs we've generated (to avoid duplicates)
    private var generatedJobPositions: Set<Position> = []

    /// Statistics
    public private(set) var stats: AutonomousWorkStats = AutonomousWorkStats()

    public init() {}

    // MARK: - Needs Assessment

    /// Assess current colony resource needs
    public func assessColonyNeeds(
        orcCount: Int,
        foodCount: Int,
        drinkCount: Int,
        rawMeatCount: Int,
        plantCount: Int,
        logCount: Int,
        stoneCount: Int,
        oreCount: Int
    ) -> ColonyNeeds {
        var needs = ColonyNeeds()
        let effectiveOrcCount = max(1, orcCount)

        // Food assessment (raw meat + cooked food + plants)
        let totalFood = foodCount + rawMeatCount + plantCount
        let foodPerOrc = totalFood / effectiveOrcCount

        if foodPerOrc < ColonyNeeds.criticalFoodPerOrc {
            needs.foodNeed = .critical
        } else if foodPerOrc < ColonyNeeds.lowFoodPerOrc {
            needs.foodNeed = .high
        } else if foodPerOrc < ColonyNeeds.adequateFoodPerOrc {
            needs.foodNeed = .normal
        } else {
            needs.foodNeed = .low
        }

        // Drink assessment
        let drinkPerOrc = drinkCount / effectiveOrcCount

        if drinkPerOrc < ColonyNeeds.criticalDrinkPerOrc {
            needs.drinkNeed = .critical
        } else if drinkPerOrc < ColonyNeeds.lowDrinkPerOrc {
            needs.drinkNeed = .high
        } else if drinkPerOrc < ColonyNeeds.adequateDrinkPerOrc {
            needs.drinkNeed = .normal
        } else {
            needs.drinkNeed = .low
        }

        // Wood assessment
        if logCount < ColonyNeeds.criticalWood {
            needs.woodNeed = .critical
        } else if logCount < ColonyNeeds.lowWood {
            needs.woodNeed = .high
        } else if logCount < ColonyNeeds.adequateWood {
            needs.woodNeed = .normal
        } else {
            needs.woodNeed = .low
        }

        // Stone assessment
        if stoneCount < ColonyNeeds.criticalStone {
            needs.stoneNeed = .critical
        } else if stoneCount < ColonyNeeds.lowStone {
            needs.stoneNeed = .high
        } else if stoneCount < ColonyNeeds.adequateStone {
            needs.stoneNeed = .normal
        } else {
            needs.stoneNeed = .low
        }

        // Ore assessment
        if oreCount < ColonyNeeds.criticalOre {
            needs.oreNeed = .critical
        } else if oreCount < ColonyNeeds.lowOre {
            needs.oreNeed = .high
        } else if oreCount < ColonyNeeds.adequateOre {
            needs.oreNeed = .normal
        } else {
            needs.oreNeed = .low
        }

        // Plant need (for brewing and food variety)
        if plantCount < 5 {
            needs.plantNeed = .high
        } else if plantCount < 15 {
            needs.plantNeed = .normal
        } else {
            needs.plantNeed = .low
        }

        return needs
    }

    // MARK: - Resource Detection

    /// Find trees available for chopping
    public func findTrees(
        in world: World,
        nearPosition center: Position? = nil,
        limit: Int = 10
    ) -> [WorkTarget] {
        var targets: [WorkTarget] = []
        let searchCenter = center ?? Position(x: world.width / 2, y: world.height / 2, z: 0)

        for y in 0..<world.height {
            for x in 0..<world.width {
                let pos = Position(x: x, y: y, z: 0)
                guard let tile = world.getTile(at: pos) else { continue }

                if tile.terrain.isHarvestableTree {
                    // Check distance from center
                    let distance = searchCenter.distance(to: pos)
                    if distance <= resourceScanRadius {
                        // Find an adjacent passable tile for the worker to stand on
                        var workPosition: Position? = nil
                        for dir in Direction.allCases {
                            let adjacent = pos.moved(in: dir)
                            if let adjTile = world.getTile(at: adjacent), adjTile.isPassable {
                                workPosition = adjacent
                                break
                            }
                        }

                        // Only add if there's a valid work position
                        if let workPos = workPosition {
                            let priority: ResourceNeed = distance < 10 ? .high : (distance < 25 ? .normal : .low)
                            targets.append(WorkTarget(position: workPos, type: .tree, priority: priority, targetPosition: pos))
                        }
                    }
                }

                if targets.count >= limit * 3 { break }
            }
            if targets.count >= limit * 3 { break }
        }

        // Sort by priority and distance, return limited set
        targets.sort { t1, t2 in
            if t1.priority != t2.priority {
                return t1.priority < t2.priority
            }
            return searchCenter.distance(to: t1.position) < searchCenter.distance(to: t2.position)
        }

        return Array(targets.prefix(limit))
    }

    /// Find mineable stone/ore
    public func findMineableResources(
        in world: World,
        nearPosition center: Position? = nil,
        limit: Int = 10
    ) -> [WorkTarget] {
        var targets: [WorkTarget] = []
        let searchCenter = center ?? Position(x: world.width / 2, y: world.height / 2, z: 0)

        for z in 0..<world.depth {
            for y in 0..<world.height {
                for x in 0..<world.width {
                    let pos = Position(x: x, y: y, z: z)
                    guard let tile = world.getTile(at: pos) else { continue }

                    // Only mine stone/ore that is adjacent to passable tiles (accessible)
                    if tile.terrain == .stone || tile.terrain == .ore {
                        // Find an adjacent passable tile for the worker to stand on
                        var workPosition: Position? = nil
                        for dir in Direction.allCases {
                            let adjacent = pos.moved(in: dir)
                            if let adjTile = world.getTile(at: adjacent), adjTile.isPassable {
                                workPosition = adjacent
                                break
                            }
                        }

                        if let workPos = workPosition {
                            let type: WorkTargetType = tile.terrain == .ore ? .ore : .stone
                            let priority: ResourceNeed = tile.terrain == .ore ? .high : .normal
                            targets.append(WorkTarget(position: workPos, type: type, priority: priority, targetPosition: pos))
                        }
                    }

                    if targets.count >= limit * 3 { break }
                }
                if targets.count >= limit * 3 { break }
            }
            if targets.count >= limit * 3 { break }
        }

        // Sort by priority and distance
        targets.sort { t1, t2 in
            if t1.priority != t2.priority {
                return t1.priority < t2.priority
            }
            return searchCenter.distance(to: t1.position) < searchCenter.distance(to: t2.position)
        }

        return Array(targets.prefix(limit))
    }

    /// Find shrubs for gathering plants
    public func findGatherableResources(
        in world: World,
        nearPosition center: Position? = nil,
        limit: Int = 10
    ) -> [WorkTarget] {
        var targets: [WorkTarget] = []
        let searchCenter = center ?? Position(x: world.width / 2, y: world.height / 2, z: 0)

        for y in 0..<world.height {
            for x in 0..<world.width {
                let pos = Position(x: x, y: y, z: 0)
                guard let tile = world.getTile(at: pos) else { continue }

                if tile.terrain == .shrub {
                    // Find an adjacent passable tile for the worker to stand on
                    var workPosition: Position? = nil
                    for dir in Direction.allCases {
                        let adjacent = pos.moved(in: dir)
                        if let adjTile = world.getTile(at: adjacent), adjTile.isPassable {
                            workPosition = adjacent
                            break
                        }
                    }

                    if let workPos = workPosition {
                        targets.append(WorkTarget(position: workPos, type: .shrub, priority: .normal, targetPosition: pos))
                    }
                }

                if targets.count >= limit * 3 { break }
            }
            if targets.count >= limit * 3 { break }
        }

        // Sort by distance from center
        targets.sort { t1, t2 in
            searchCenter.distance(to: t1.position) < searchCenter.distance(to: t2.position)
        }

        return Array(targets.prefix(limit))
    }

    /// Find fishing spots (water tiles adjacent to passable land)
    public func findFishingSpots(
        in world: World,
        nearPosition center: Position? = nil,
        limit: Int = 5
    ) -> [WorkTarget] {
        var targets: [WorkTarget] = []
        let searchCenter = center ?? Position(x: world.width / 2, y: world.height / 2, z: 0)

        for y in 0..<world.height {
            for x in 0..<world.width {
                let pos = Position(x: x, y: y, z: 0)
                guard let tile = world.getTile(at: pos) else { continue }

                // Look for passable tiles adjacent to water
                if tile.isPassable {
                    // Check if adjacent to water
                    for dir in Direction.allCases {
                        let neighborPos = pos.moved(in: dir)
                        if let neighborTile = world.getTile(at: neighborPos),
                           neighborTile.terrain.isWaterBody {
                            targets.append(WorkTarget(position: pos, type: .water, priority: .normal))
                            break
                        }
                    }
                }

                if targets.count >= limit * 3 { break }
            }
            if targets.count >= limit * 3 { break }
        }

        // Sort by distance
        targets.sort { t1, t2 in
            searchCenter.distance(to: t1.position) < searchCenter.distance(to: t2.position)
        }

        return Array(targets.prefix(limit))
    }

    /// Find huntable creatures (wild animals like wolves, bears)
    public func findHuntableCreatures(
        in world: World,
        hostileUnits: Set<UInt64>
    ) -> [WorkTarget] {
        var targets: [WorkTarget] = []

        for (unitId, unit) in world.units {
            guard unit.isAlive else { continue }
            guard unit.creatureType != .orc else { continue }

            let priority: ResourceNeed
            switch unit.creatureType {
            case .wolf, .bear:
                priority = .normal
            default:
                continue
            }
            targets.append(WorkTarget(position: unit.position, type: .huntable(unitId), priority: priority))
        }

        return targets
    }

    // MARK: - Job Generation

    /// Generate jobs based on colony needs
    /// Returns the number of new jobs created
    @discardableResult
    public func generateJobs(
        world: World,
        jobManager: JobManager,
        needs: ColonyNeeds,
        hostileUnits: Set<UInt64>,
        currentTick: UInt64
    ) -> Int {
        var jobsCreated = 0

        // Clean up old generated positions that may have been completed
        cleanupGeneratedPositions(jobManager: jobManager)

        // Count current pending autonomous jobs by type
        let pendingJobs = jobManager.getPendingJobs()
        var jobCountByType: [JobType: Int] = [:]
        for job in pendingJobs {
            jobCountByType[job.type, default: 0] += 1
        }

        let totalPending = pendingJobs.count
        guard totalPending < maxTotalAutonomousJobs else { return 0 }

        // Priority-based job generation
        // Critical food need -> hunting, fishing, gathering
        if needs.foodNeed == .critical || needs.foodNeed == .high {
            // Hunting
            if (jobCountByType[.hunt] ?? 0) < 2 {
                let huntTargets = findHuntableCreatures(in: world, hostileUnits: hostileUnits)
                for target in huntTargets.prefix(2) {
                    if case .huntable(let unitId) = target.type {
                        if createJob(type: .hunt, at: target.position, jobManager: jobManager, currentTick: currentTick, targetUnit: unitId) {
                            jobsCreated += 1
                            stats.huntJobsCreated += 1
                        }
                    }
                }
            }

            // Fishing
            if (jobCountByType[.fish] ?? 0) < 2 {
                let fishingSpots = findFishingSpots(in: world, limit: 3)
                for target in fishingSpots.prefix(2) {
                    if createJob(type: .fish, at: target.position, jobManager: jobManager, currentTick: currentTick) {
                        jobsCreated += 1
                        stats.fishJobsCreated += 1
                    }
                }
            }

            // Gathering plants
            if (jobCountByType[.harvest] ?? 0) < 3 {
                let gatherTargets = findGatherableResources(in: world, limit: 5)
                for target in gatherTargets.prefix(3) {
                    if createJob(type: .harvest, at: target.position, jobManager: jobManager, currentTick: currentTick, targetPosition: target.targetPosition) {
                        jobsCreated += 1
                        stats.gatherJobsCreated += 1
                    }
                }
            }
        }

        // Wood need -> tree chopping
        if needs.woodNeed <= .normal {
            let maxChopJobs = needs.woodNeed == .critical ? 4 : (needs.woodNeed == .high ? 3 : 2)
            if (jobCountByType[.chopTree] ?? 0) < maxChopJobs {
                let treeTargets = findTrees(in: world, limit: maxChopJobs + 2)
                for target in treeTargets {
                    if (jobCountByType[.chopTree] ?? 0) >= maxChopJobs { break }
                    if createJob(type: .chopTree, at: target.position, jobManager: jobManager, currentTick: currentTick, targetPosition: target.targetPosition) {
                        jobsCreated += 1
                        jobCountByType[.chopTree, default: 0] += 1
                        stats.chopJobsCreated += 1
                    }
                }
            }
        }

        // Stone/ore need -> mining
        if needs.stoneNeed <= .normal || needs.oreNeed <= .high {
            let maxMineJobs = needs.stoneNeed == .critical ? 4 : (needs.stoneNeed == .high ? 3 : 2)
            if (jobCountByType[.mine] ?? 0) < maxMineJobs {
                let mineTargets = findMineableResources(in: world, limit: maxMineJobs + 2)
                for target in mineTargets {
                    if (jobCountByType[.mine] ?? 0) >= maxMineJobs { break }
                    if case .ore = target.type, needs.oreNeed <= .high {
                        if createJob(type: .mine, at: target.position, jobManager: jobManager, currentTick: currentTick, priority: .high, targetPosition: target.targetPosition) {
                            jobsCreated += 1
                            jobCountByType[.mine, default: 0] += 1
                            stats.mineJobsCreated += 1
                        }
                    } else if case .stone = target.type {
                        if createJob(type: .mine, at: target.position, jobManager: jobManager, currentTick: currentTick, targetPosition: target.targetPosition) {
                            jobsCreated += 1
                            jobCountByType[.mine, default: 0] += 1
                            stats.mineJobsCreated += 1
                        }
                    }
                }
            }
        }

        // Normal priority gathering when not critical
        if needs.plantNeed <= .normal && (jobCountByType[.harvest] ?? 0) < 2 {
            let gatherTargets = findGatherableResources(in: world, limit: 3)
            for target in gatherTargets.prefix(2) {
                if createJob(type: .harvest, at: target.position, jobManager: jobManager, currentTick: currentTick, priority: .belowNormal, targetPosition: target.targetPosition) {
                    jobsCreated += 1
                    stats.gatherJobsCreated += 1
                }
            }
        }

        // Cooking - when we have raw meat, create cooking jobs
        let rawMeatItems = world.items.values.filter { $0.itemType == .rawMeat }
        if (jobCountByType[.cook] ?? 0) < 2 && !rawMeatItems.isEmpty {
            for meat in rawMeatItems.prefix(2) {
                if createJob(type: .cook, at: meat.position, jobManager: jobManager, currentTick: currentTick) {
                    jobsCreated += 1
                    stats.cookJobsCreated += 1
                }
            }
        }

        // Brewing - when we have plants and need drinks
        let plantItems = world.items.values.filter { $0.itemType == .plant }
        if needs.drinkNeed <= .normal && (jobCountByType[.brew] ?? 0) < 2 && plantItems.count >= 2 {
            if let plant = plantItems.first {
                if createJob(type: .brew, at: plant.position, jobManager: jobManager, currentTick: currentTick) {
                    jobsCreated += 1
                    stats.craftJobsCreated += 1
                }
            }
        }

        return jobsCreated
    }

    /// Create a single job if not already exists at position
    private func createJob(
        type: JobType,
        at position: Position,
        jobManager: JobManager,
        currentTick: UInt64,
        priority: JobPriority = .normal,
        targetPosition: Position? = nil,
        targetUnit: UInt64? = nil
    ) -> Bool {
        // Check if we already have a job at this position
        if generatedJobPositions.contains(position) {
            return false
        }

        // Also check target position to avoid duplicate jobs on same resource
        if let target = targetPosition, generatedJobPositions.contains(target) {
            return false
        }

        // Check if job manager already has a job at this position
        let existingJobs = jobManager.getJobsAtPosition(position)
        if !existingJobs.isEmpty {
            return false
        }

        // Check spacing from other same-type jobs
        for existingPos in generatedJobPositions {
            if existingPos.distance(to: position) < minJobSpacing {
                return false
            }
        }

        // Create the job
        let job = jobManager.createJob(
            type: type,
            position: position,
            priority: priority,
            currentTick: currentTick
        )

        // Set target position for the actual resource
        if let target = targetPosition {
            jobManager.setTargetPosition(jobId: job.id, targetPosition: target)
            generatedJobPositions.insert(target)
        }

        // Set target unit for hunting jobs
        if let unitId = targetUnit {
            jobManager.setTargetUnit(jobId: job.id, targetUnit: unitId)
        }

        generatedJobPositions.insert(position)
        return true
    }

    /// Clean up positions for completed jobs
    private func cleanupGeneratedPositions(jobManager: JobManager) {
        var toRemove: Set<Position> = []

        for position in generatedJobPositions {
            let jobs = jobManager.getJobsAtPosition(position)
            if jobs.isEmpty {
                toRemove.insert(position)
            }
        }

        for position in toRemove {
            generatedJobPositions.remove(position)
        }
    }

    /// Clear all tracked positions (for reset)
    public func reset() {
        generatedJobPositions.removeAll()
        stats = AutonomousWorkStats()
    }
}
