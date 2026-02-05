// MARK: - Autonomous Work System
// Automatically generates jobs based on colony needs and available resources

import Foundation

// MARK: - Resource Need Priority

/// Priority levels for different resource needs
public enum ResourceNeed: Int, Comparable, Sendable {
    case critical = 0   // Immediate survival needs
    case high = 1       // Important for colony function
    case normal = 2     // Standard maintenance
    case low = 3        // Nice to have

    public static func < (lhs: ResourceNeed, rhs: ResourceNeed) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Work Target

/// A potential work target found in the world
public struct WorkTarget: Sendable {
    public let position: Position          // Where the worker should stand
    public let targetPosition: Position?   // The actual resource position (for trees, ore, etc.)
    public let type: WorkTargetType
    public let priority: ResourceNeed

    public init(position: Position, type: WorkTargetType, priority: ResourceNeed = .normal, targetPosition: Position? = nil) {
        self.position = position
        self.targetPosition = targetPosition
        self.type = type
        self.priority = priority
    }
}

/// Types of work targets
public enum WorkTargetType: Sendable {
    case tree           // Chop for logs
    case stone          // Mine for stone blocks
    case ore            // Mine for metal ore
    case shrub          // Gather plants
    case water          // Fishing spot
    case huntable(UInt64)  // Animal to hunt (unit ID)
    case workshop(WorkshopType)  // Crafting at workshop
}

// MARK: - Colony Needs Assessment

/// Assessment of current colony resource needs
public struct ColonyNeeds: Sendable {
    public var foodNeed: ResourceNeed = .normal
    public var drinkNeed: ResourceNeed = .normal
    public var woodNeed: ResourceNeed = .normal
    public var stoneNeed: ResourceNeed = .normal
    public var oreNeed: ResourceNeed = .normal
    public var plantNeed: ResourceNeed = .normal

    /// Food/drink per dwarf thresholds
    public static let criticalFoodPerDwarf = 1
    public static let lowFoodPerDwarf = 3
    public static let adequateFoodPerDwarf = 5

    public static let criticalDrinkPerDwarf = 1
    public static let lowDrinkPerDwarf = 3
    public static let adequateDrinkPerDwarf = 5

    /// Material thresholds (absolute)
    public static let criticalWood = 5
    public static let lowWood = 15
    public static let adequateWood = 30

    public static let criticalStone = 5
    public static let lowStone = 20
    public static let adequateStone = 50

    public static let criticalOre = 0
    public static let lowOre = 10
    public static let adequateOre = 25
}

// MARK: - Autonomous Work Manager

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
        dwarfCount: Int,
        foodCount: Int,
        drinkCount: Int,
        rawMeatCount: Int,
        plantCount: Int,
        logCount: Int,
        stoneCount: Int,
        oreCount: Int
    ) -> ColonyNeeds {
        var needs = ColonyNeeds()
        let effectiveDwarfCount = max(1, dwarfCount)

        // Food assessment (raw meat + cooked food + plants)
        let totalFood = foodCount + rawMeatCount + plantCount
        let foodPerDwarf = totalFood / effectiveDwarfCount

        if foodPerDwarf < ColonyNeeds.criticalFoodPerDwarf {
            needs.foodNeed = .critical
        } else if foodPerDwarf < ColonyNeeds.lowFoodPerDwarf {
            needs.foodNeed = .high
        } else if foodPerDwarf < ColonyNeeds.adequateFoodPerDwarf {
            needs.foodNeed = .normal
        } else {
            needs.foodNeed = .low
        }

        // Drink assessment
        let drinkPerDwarf = drinkCount / effectiveDwarfCount

        if drinkPerDwarf < ColonyNeeds.criticalDrinkPerDwarf {
            needs.drinkNeed = .critical
        } else if drinkPerDwarf < ColonyNeeds.lowDrinkPerDwarf {
            needs.drinkNeed = .high
        } else if drinkPerDwarf < ColonyNeeds.adequateDrinkPerDwarf {
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

                if tile.terrain == .tree {
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

                if targets.count >= limit * 3 { break } // Get extra for filtering
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
                           neighborTile.terrain == .water {
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
            guard unit.creatureType != .dwarf else { continue }

            // Hunt wild animals (wolves, bears) - they're animals that can be hunted for food
            // regardless of whether they're currently hostile
            let priority: ResourceNeed
            switch unit.creatureType {
            case .wolf, .bear:
                priority = .normal  // Good meat source
            default:
                continue  // Don't hunt goblins, giants, undead - they're enemies, not game
            }
            targets.append(WorkTarget(position: unit.position, type: .huntable(unitId), priority: priority))
        }

        return targets
    }

    /// Check if a position is accessible (adjacent to a passable tile)
    private func isAccessible(position: Position, in world: World) -> Bool {
        for dir in Direction.allCases {
            let neighbor = position.moved(in: dir)
            if let tile = world.getTile(at: neighbor), tile.isPassable {
                return true
            }
        }
        return false
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
                    // Prioritize ore if ore need is high
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
            // Create cooking job at the meat's location
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
            // Create brewing job at plant location
            if let plant = plantItems.first {
                if createJob(type: .brew, at: plant.position, jobManager: jobManager, currentTick: currentTick) {
                    jobsCreated += 1
                    // Track brewing jobs in craft stats for now
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

// MARK: - Statistics

/// Statistics for autonomous work generation
public struct AutonomousWorkStats: Sendable {
    public var chopJobsCreated: Int = 0
    public var mineJobsCreated: Int = 0
    public var gatherJobsCreated: Int = 0
    public var huntJobsCreated: Int = 0
    public var fishJobsCreated: Int = 0
    public var cookJobsCreated: Int = 0
    public var craftJobsCreated: Int = 0

    public var totalJobsCreated: Int {
        chopJobsCreated + mineJobsCreated + gatherJobsCreated +
        huntJobsCreated + fishJobsCreated + cookJobsCreated + craftJobsCreated
    }
}
