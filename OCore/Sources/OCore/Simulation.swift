// MARK: - Simulation Engine
// The core simulation engine that processes the game loop and unit behaviors
// Now integrated with all subsystems: Jobs, Combat, Mood, Social, Construction, Crafting, Stockpiles

import Foundation

/// The main simulation engine that processes the game world
@MainActor
public final class Simulation: Sendable {
    // MARK: - Core Systems

    /// The game world
    public let world: World

    /// Job management system
    public let jobManager: JobManager

    /// Designation management system
    public let designationManager: DesignationManager

    /// Combat management system
    public let combatManager: CombatManager

    /// Mood management system
    public let moodManager: MoodManager

    /// Social/relationship management system
    public let socialManager: SocialManager

    /// Construction management system
    public let constructionManager: ConstructionManager

    /// Crafting management system
    public let craftingManager: CraftingManager

    /// Stockpile management system
    public let stockpileManager: StockpileManager

    /// Autonomous work management system
    public let autonomousWorkManager: AutonomousWorkManager

    // MARK: - Simulation State

    /// Whether the simulation is running
    public private(set) var isRunning: Bool = false

    /// Simulation speed (ticks per second)
    public var ticksPerSecond: Double = 10.0

    /// Event log for observing simulation events
    public private(set) var eventLog: [SimulationEvent] = []

    /// Maximum events to keep in log
    public var maxEventLogSize: Int = 100

    /// Hostile creatures in the world (non-orc units)
    public private(set) var hostileUnits: Set<UInt64> = []

    /// Statistics
    public private(set) var stats: SimulationStats = SimulationStats()

    /// Active conversations for display (cleared each tick, populated when socializing starts)
    public private(set) var activeConversations: [ActiveConversation] = []

    /// Duration in ticks to display a speech bubble
    private let speechBubbleDuration: UInt64 = 30

    // MARK: - Event Configuration

    /// Hostile spawn interval in ticks
    public var hostileSpawnInterval: Int = 500

    /// Hostile spawn chance (0-100)
    public var hostileSpawnChance: Int = 50

    /// Migrant wave interval in ticks
    public var migrantWaveInterval: Int = 10000

    /// Birth check interval in ticks
    public var birthCheckInterval: Int = 5000

    /// Birth chance percent (0-100)
    public var birthChancePercent: Int = 5

    /// Maximum population cap
    public var maxPopulation: Int = 50

    // MARK: - Initialization

    /// Creates a new simulation with a world
    public init(world: World) {
        self.world = world
        self.jobManager = JobManager()
        self.designationManager = DesignationManager()
        self.combatManager = CombatManager()
        self.moodManager = MoodManager()
        self.socialManager = SocialManager()
        self.constructionManager = ConstructionManager()
        self.craftingManager = CraftingManager()
        self.stockpileManager = StockpileManager()
        self.autonomousWorkManager = AutonomousWorkManager()

        // Link designation manager to job manager
        self.designationManager.setJobManager(jobManager)
    }

    /// Creates a new simulation with default world size
    public convenience init(worldWidth: Int = 40, worldHeight: Int = 25) {
        let world = World(width: worldWidth, height: worldHeight)
        self.init(world: world)
    }

    /// Configure event parameters from config
    public func configure(
        hostileSpawnInterval: Int,
        hostileSpawnChance: Int,
        migrantWaveInterval: Int,
        birthCheckInterval: Int,
        birthChancePercent: Int,
        maxPopulation: Int
    ) {
        self.hostileSpawnInterval = hostileSpawnInterval
        self.hostileSpawnChance = hostileSpawnChance
        self.migrantWaveInterval = migrantWaveInterval
        self.birthCheckInterval = birthCheckInterval
        self.birthChancePercent = birthChancePercent
        self.maxPopulation = maxPopulation
    }

    // MARK: - Simulation Control

    /// Processes a single tick of the simulation
    public func tick() {
        world.tick()

        // Process all units
        for (unitId, _) in world.units {
            processUnit(id: unitId)
        }

        // Process subsystems
        processSubsystems()

        // Periodic checks
        performPeriodicChecks()

        // Trim event log if needed
        while eventLog.count > maxEventLogSize {
            eventLog.removeFirst()
        }

        // Expire old active conversations (for speech bubble display)
        activeConversations.removeAll { conversation in
            world.currentTick - conversation.startTick > speechBubbleDuration
        }
    }

    /// Runs the simulation for a specified number of ticks
    public func run(ticks: Int) {
        for _ in 0..<ticks {
            tick()
        }
    }

    // MARK: - Subsystem Processing

    /// Process all subsystems each tick
    private func processSubsystems() {
        // Update moods every 10 ticks
        if world.currentTick % 10 == 0 {
            let stressVulnerabilities = world.units.mapValues { unit in
                unit.personality.value(for: .stressVulnerability)
            }
            moodManager.updateAll(currentTick: world.currentTick, stressVulnerabilities: stressVulnerabilities)
        }

        // Decay relationships every 500 ticks
        if world.currentTick % 500 == 0 {
            socialManager.decayRelationships(currentTick: world.currentTick)
        }

        // Generate hauling jobs every 50 ticks
        if world.currentTick % 50 == 0 {
            generateHaulJobs()
        }

        // Generate autonomous work jobs every 100 ticks
        if world.currentTick % 100 == 0 {
            generateAutonomousJobs()
        }
    }

    /// Generate autonomous jobs based on colony needs
    private func generateAutonomousJobs() {
        // Count resources
        let orcCount = world.units.values.filter { $0.creatureType == .orc && $0.isAlive }.count
        guard orcCount > 0 else { return }

        let foodCount = world.items.values.filter { $0.itemType == .food }.count
        let drinkCount = world.items.values.filter { $0.itemType == .drink }.count
        let rawMeatCount = world.items.values.filter { $0.itemType == .rawMeat }.count
        let plantCount = world.items.values.filter { $0.itemType == .plant }.count
        let logCount = world.items.values.filter { $0.itemType == .log }.count
        let stoneCount = world.items.values.filter { $0.itemType == .stone }.count
        let oreCount = world.items.values.filter { $0.itemType == .ore }.count

        // Assess colony needs
        let needs = autonomousWorkManager.assessColonyNeeds(
            orcCount: orcCount,
            foodCount: foodCount,
            drinkCount: drinkCount,
            rawMeatCount: rawMeatCount,
            plantCount: plantCount,
            logCount: logCount,
            stoneCount: stoneCount,
            oreCount: oreCount
        )

        // Log needs assessment every in-game day
        if world.currentTick % UInt64(TimeConstants.ticksPerDay) == 0 {
            logEvent(.milestone(tick: world.currentTick, message: "Needs: food=\(needs.foodNeed) drink=\(needs.drinkNeed) wood=\(needs.woodNeed) stone=\(needs.stoneNeed)"))
        }

        // Generate jobs
        let jobsCreated = autonomousWorkManager.generateJobs(
            world: world,
            jobManager: jobManager,
            needs: needs,
            hostileUnits: hostileUnits,
            currentTick: world.currentTick
        )

        if jobsCreated > 0 {
            logEvent(.milestone(tick: world.currentTick, message: "Auto-generated \(jobsCreated) work jobs (pending: \(jobManager.pendingCount))"))
        }

        // Item inventory log every 2 in-game days
        if world.currentTick % UInt64(TimeConstants.ticksPerDay * 2) == 0 {
            logEvent(.milestone(tick: world.currentTick, message: "Items: \(rawMeatCount) meat, \(plantCount) plants, \(foodCount) food, \(drinkCount) drinks, \(logCount) logs"))
        }
    }

    /// Generate hauling jobs for loose items
    private func generateHaulJobs() {
        // Only generate if we have stockpiles
        guard !stockpileManager.stockpiles.isEmpty else { return }

        let looseItems = world.items.values.compactMap { item -> (id: UInt64, type: ItemType, quality: ItemQuality, position: Position)? in
            // Skip items already in stockpiles
            if stockpileManager.getStockpile(at: item.position) != nil { return nil }
            return (id: item.id, type: item.itemType, quality: item.quality, position: item.position)
        }

        let created = stockpileManager.generateHaulTasksForItems(items: looseItems)
        if created > 0 {
            stats.haulJobsGenerated += created
        }
    }

    // MARK: - Unit Processing

    /// Processes a single unit for one tick
    private func processUnit(id: UInt64) {
        guard var unit = world.getUnit(id: id) else { return }

        // Skip dead units
        guard unit.state != .dead else { return }

        // 1. Tick update (increment needs, decrement action counter)
        unit.tickUpdate()

        // 2. Update mood with tick-based thoughts
        updateUnitMood(&unit)

        // 3. Check for death from need deprivation or health
        if let deathCause = checkForDeath(&unit) {
            handleUnitDeath(&unit, cause: deathCause)
            world.updateUnit(unit)
            return
        }

        // 4. Check for combat threats (if not already in combat)
        if unit.state != .fighting && unit.state != .fleeing {
            if let threat = findNearbyThreat(for: unit) {
                handleCombatThreat(&unit, threat: threat)
                world.updateUnit(unit)
                return
            }
        }

        // 5. If can't act yet, just update and return
        guard unit.canAct else {
            world.updateUnit(unit)
            return
        }

        // 6. Check for mental break
        if let breakType = moodManager.getMentalBreak(unitId: unit.id) {
            processMentalBreak(&unit, breakType: breakType)
            world.updateUnit(unit)
            return
        }

        // 7. Process based on current state
        switch unit.state {
        case .idle:
            processIdleState(&unit)

        case .moving:
            processMovingState(&unit)

        case .eating:
            processEatingState(&unit)

        case .drinking:
            processDrinkingState(&unit)

        case .sleeping:
            processSleepingState(&unit)

        case .working:
            processWorkingState(&unit)

        case .socializing:
            processSocializingState(&unit)

        case .fighting:
            processFightingState(&unit)

        case .fleeing:
            processFleeingState(&unit)

        case .unconscious:
            processUnconsciousState(&unit)

        case .dead:
            break
        }

        // 8. Set next action delay
        unit.actionCounter = unit.calculateActionDelay()

        // 9. Update unit in world
        world.updateUnit(unit)
    }

    // MARK: - Mood Updates

    /// Update unit mood based on current situation
    private func updateUnitMood(_ unit: inout Unit) {
        let currentTick = world.currentTick

        // Add thoughts based on needs
        if unit.hunger > NeedThresholds.hungerCritical {
            moodManager.addThought(unitId: unit.id, type: .wasHungry, currentTick: currentTick)
        }
        if unit.thirst > NeedThresholds.thirstCritical {
            moodManager.addThought(unitId: unit.id, type: .wasThirsty, currentTick: currentTick)
        }
        if unit.drowsiness > NeedThresholds.drowsyCritical {
            moodManager.addThought(unitId: unit.id, type: .wasTired, currentTick: currentTick)
        }

        // Higher-level need checks (every half in-game day)
        if world.currentTick % UInt64(TimeConstants.ticksPerDay / 2) == 0 {
            // Social need: gregarious orcs become lonely without friends
            let friends = socialManager.getFriends(of: unit.id)
            if friends.isEmpty && unit.personality.value(for: .gregariousness) > 50 {
                moodManager.addThought(unitId: unit.id, type: .wasLonely, currentTick: currentTick)
            }

            // Occupation need: hard-working orcs get restless without jobs
            if unit.state == .idle && unit.personality.value(for: .perseverance) > 60 {
                if jobManager.getJobsForUnit(unit.id).isEmpty {
                    moodManager.addThought(unitId: unit.id, type: .workedTooLong, currentTick: currentTick)
                }
            }

            // Creativity need: curious orcs want to see workshops or nature
            if unit.personality.value(for: .curiosity) > 65 {
                let nearbyWorkshops = constructionManager.workshops.values.filter {
                    $0.status == .complete && $0.position.distance(to: unit.position) <= 8
                }
                if !nearbyWorkshops.isEmpty {
                    moodManager.addThought(unitId: unit.id, type: .admiredRoom, currentTick: currentTick)
                }
            }

            // Martial need: brave orcs feel good after combat
            if unit.personality.value(for: .bravery) > 70 && unit.state == .idle {
                let recentCombat = combatManager.recentCombat.suffix(10)
                let wasInCombat = recentCombat.contains { $0.attacker == unit.id }
                if wasInCombat {
                    moodManager.addThought(unitId: unit.id, type: .didGoodWork, currentTick: currentTick)
                }
            }
        }
    }

    /// Process mental break behavior
    private func processMentalBreak(_ unit: inout Unit, breakType: MentalBreakType) {
        switch breakType {
        case .minorBreak, .catatonic:
            // Do nothing - just stand there
            unit.transition(to: .idle)

        case .tantrum:
            // Destroy nearby items (not implemented - just wander angrily)
            wanderRandomly(&unit)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "is having a tantrum"))

        case .berserk:
            // Attack nearest unit
            let nearbyUnits = world.getUnitsInRange(of: unit.position, radius: 5)
                .filter { $0.id != unit.id && $0.state != .dead }
            if let target = nearbyUnits.randomElement() {
                if let path = world.findPath(from: unit.position, to: target.position) {
                    unit.setPath(Array(path.dropFirst()))
                    unit.transition(to: .fighting)
                    logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "has gone berserk!"))
                }
            }

        case .wandering:
            wanderRandomly(&unit)

        case .bingeEating:
            if let food = world.findNearestItem(of: .food, from: unit.position) {
                if let path = world.findPath(from: unit.position, to: food.position) {
                    unit.setPath(Array(path.dropFirst()))
                    unit.transition(to: .moving)
                }
            }

        case .bingeDrinking:
            if let drink = world.findNearestItem(of: .drink, from: unit.position) {
                if let path = world.findPath(from: unit.position, to: drink.position) {
                    unit.setPath(Array(path.dropFirst()))
                    unit.transition(to: .moving)
                }
            }
        }
    }

    // MARK: - Death Handling

    /// Check if unit should die
    private func checkForDeath(_ unit: inout Unit) -> String? {
        // Check need death
        if let needDeath = unit.checkNeedDeath() {
            return "died from \(needDeath.rawValue)"
        }

        // Check health death
        if !unit.health.isAlive {
            return "died from wounds"
        }

        return nil
    }

    /// Handle unit death
    private func handleUnitDeath(_ unit: inout Unit, cause: String) {
        unit.transition(to: .dead)
        logEvent(.unitDied(unitId: unit.id, cause: "\(unit.name.firstName) \(cause)"))

        // Add grief to friends
        let friends = socialManager.getFriends(of: unit.id)
        for friendId in friends {
            moodManager.addThought(
                unitId: friendId,
                type: .friendDied,
                currentTick: world.currentTick,
                source: unit.name.firstName
            )
        }

        // Notify nearby units they witnessed death
        let witnesses = world.getUnitsInRange(of: unit.position, radius: 5)
            .filter { $0.id != unit.id }
        for witness in witnesses {
            moodManager.addThought(unitId: witness.id, type: .sawDeath, currentTick: world.currentTick)
        }

        // Clear social relationships
        socialManager.clearRelationships(for: unit.id)
        moodManager.removeMood(unitId: unit.id)

        stats.totalDeaths += 1
    }

    // MARK: - Combat

    /// Find nearby hostile threat
    private func findNearbyThreat(for unit: Unit) -> Unit? {
        // Only orcs care about threats
        guard unit.creatureType == .orc else { return nil }

        let nearbyUnits = world.getUnitsInRange(of: unit.position, radius: 8)
        return nearbyUnits.first { other in
            other.id != unit.id &&
            other.state != .dead &&
            other.creatureType.hostileToOrcs &&
            hostileUnits.contains(other.id)
        }
    }

    /// Handle combat threat
    private func handleCombatThreat(_ unit: inout Unit, threat: Unit) {
        let bravery = unit.personality.value(for: .bravery)

        // Decide fight or flight based on bravery and health
        let shouldFlee = combatManager.shouldFlee(
            healthPercentage: unit.health.percentage,
            bravery: bravery
        )

        if shouldFlee {
            let fleeDir = combatManager.getFleeDirection(from: unit.position, awayfrom: threat.position)
            let fleeTarget = unit.position.moved(in: fleeDir)
            if world.isPassable(fleeTarget) {
                unit.setPath([fleeTarget])
                unit.transition(to: .fleeing)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "is fleeing from \(threat.creatureType.rawValue)"))
            }
        } else {
            // Fight!
            if let path = world.findPath(from: unit.position, to: threat.position) {
                unit.setPath(Array(path.dropFirst()))
                unit.transition(to: .fighting)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "is engaging \(threat.creatureType.rawValue)"))
            }
        }

        moodManager.addThought(unitId: unit.id, type: .wasAttacked, currentTick: world.currentTick)
    }

    /// Process fighting state
    private func processFightingState(_ unit: inout Unit) {
        // Find target to attack
        let nearbyHostiles = world.getUnitsInRange(of: unit.position, radius: 2)
            .filter { $0.id != unit.id && $0.state != .dead && (hostileUnits.contains($0.id) || moodManager.getMentalBreak(unitId: unit.id) == .berserk) }

        guard var target = nearbyHostiles.first else {
            // No more targets - stop fighting
            unit.transition(to: .idle)
            return
        }

        // In melee range?
        if combatManager.isInMeleeRange(unit.position, target.position) {
            // Determine weapon and damage type based on creature type and equipment
            let (weapon, damageType) = determineWeaponAndDamage(for: unit)

            // Attack!
            let attackerStrength = unit.physicalAttributes[.strength]?.base ?? 1000
            let attackerSkill = unit.skills[.meleeCombat]?.rating ?? 0
            let defenderAgility = target.physicalAttributes[.agility]?.base ?? 1000

            let result = combatManager.resolveAttack(
                attackerId: unit.id,
                attackerStrength: attackerStrength,
                attackerSkill: attackerSkill,
                defenderId: target.id,
                defenderAgility: defenderAgility,
                defenderHealth: &target.health,
                damageType: damageType
            )

            // Update target
            world.updateUnit(target)

            // Get names for logging
            let attackerName = unit.creatureType == .orc ? unit.name.firstName : unit.creatureType.rawValue
            let defenderName = target.creatureType == .orc ? target.name.firstName : target.creatureType.rawValue

            if result.hit {
                logEvent(.combat(
                    attackerName: attackerName,
                    defenderName: defenderName,
                    damage: result.damage,
                    damageType: damageType.rawValue,
                    weapon: weapon,
                    critical: result.critical,
                    killed: result.defenderDied
                ))
                stats.totalCombatDamage += result.damage

                // Give skill XP
                unit.addSkillExperience(.meleeCombat, amount: 10)

                // Add thought about having to kill
                if result.defenderDied {
                    moodManager.addThought(unitId: unit.id, type: .hadToKill, currentTick: world.currentTick)
                    stats.totalKills += 1

                    // Remove from hostile list
                    hostileUnits.remove(target.id)

                    // If a wild animal was killed, produce meat (counts as hunted)
                    if target.creatureType == .wolf || target.creatureType == .bear {
                        let meatCount = Int.random(in: 2...4)
                        for _ in 0..<meatCount {
                            let meat = Item.create(type: .rawMeat, at: target.position, quality: .standard)
                            world.addItem(meat)
                        }
                        stats.animalsHunted += 1
                    }
                }
            } else {
                // Log misses too (less frequently)
                if Int.random(in: 0...3) == 0 {
                    logEvent(.unitAction(unitId: unit.id, unitName: attackerName, action: "missed \(defenderName)"))
                }
            }

            // Check if unit should flee after combat exchange
            if combatManager.shouldFlee(healthPercentage: unit.health.percentage, bravery: unit.personality.value(for: .bravery)) {
                unit.transition(to: .fleeing)
                moodManager.addThought(unitId: unit.id, type: .wasInjured, currentTick: world.currentTick)
            }
        } else {
            // Move toward target
            if let path = world.findPath(from: unit.position, to: target.position) {
                unit.setPath(Array(path.dropFirst()))
            }
            _ = unit.advanceOnPath()
        }
    }

    /// Determine weapon and damage type for a unit based on creature type and equipment
    private func determineWeaponAndDamage(for unit: Unit) -> (weapon: String, damageType: DamageType) {
        switch unit.creatureType {
        case .orc:
            // Check for equipped weapon (simplified - check if they have any weapon items)
            // For now, orcs use fists by default
            return ("fists", .blunt)
        case .goblin:
            return ("crude sword", .slash)
        case .wolf:
            return ("fangs", .bite)
        case .bear:
            return ("claws", .slash)
        case .giant:
            return ("club", .blunt)
        case .undead:
            return ("rotting hands", .blunt)
        }
    }

    /// Process fleeing state
    private func processFleeingState(_ unit: inout Unit) {
        // Check if still in danger
        let nearbyThreats = world.getUnitsInRange(of: unit.position, radius: 10)
            .filter { hostileUnits.contains($0.id) && $0.state != .dead }

        if nearbyThreats.isEmpty {
            // Safe now
            unit.transition(to: .idle)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "escaped danger"))
            return
        }

        // Keep fleeing
        if unit.currentPath?.isEmpty ?? true {
            if let threat = nearbyThreats.first {
                let fleeDir = combatManager.getFleeDirection(from: unit.position, awayfrom: threat.position)
                let fleeTarget = unit.position.moved(in: fleeDir)
                if world.isPassable(fleeTarget) {
                    unit.setPath([fleeTarget])
                }
            }
        }

        _ = unit.advanceOnPath()
    }

    /// Process unconscious state
    private func processUnconsciousState(_ unit: inout Unit) {
        // Slowly recover
        if Int.random(in: 0...100) < 5 {
            unit.transition(to: .idle)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "regained consciousness"))
        }
    }

    // MARK: - State Processing

    /// Processes a unit in idle state - the main decision tree
    private func processIdleState(_ unit: inout Unit) {
        // Priority 1: Check critical needs (interrupt anything)
        if let criticalNeed = unit.checkCriticalNeeds() {
            handleCriticalNeed(&unit, need: criticalNeed)
            return
        }

        // Priority 2: Check for available jobs
        if let job = findJobForUnit(&unit) {
            handleJob(&unit, job: job)
            return
        }

        // Priority 3: Check soft needs (when idle)
        if let softNeed = unit.checkNeedConsideration() {
            handleCriticalNeed(&unit, need: softNeed)
            return
        }

        // Priority 4: Wander or socialize based on personality
        selectIdleActivity(&unit)
    }

    /// Find a job for the unit
    private func findJobForUnit(_ unit: inout Unit) -> Job? {
        // Only orcs work
        guard unit.creatureType == .orc else { return nil }

        let job = jobManager.findJobForUnit(
            unitId: unit.id,
            unitPosition: unit.position,
            laborPrefs: unit.laborPreferences,
            skills: unit.skills
        )

        // Debug: log when we find (or don't find) a job
        if job == nil && jobManager.pendingCount > 0 && world.currentTick % 500 == 0 {
            logEvent(.milestone(tick: world.currentTick, message: "\(unit.name.firstName) couldn't find job (pending: \(jobManager.pendingCount))"))
        }

        return job
    }

    /// Handle a job assignment
    private func handleJob(_ unit: inout Unit, job: Job) {
        guard jobManager.claimJob(jobId: job.id, unitId: unit.id) else { return }

        // Path to job location
        if let path = world.findPath(from: unit.position, to: job.position) {
            unit.setPath(Array(path.dropFirst()))
            unit.transition(to: .moving)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "going to \(job.type.rawValue) job at \(job.position)"))
        } else {
            // Can't reach job - log this
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "can't reach \(job.type.rawValue) job at \(job.position)"))
            jobManager.releaseJob(jobId: job.id)
        }
    }

    /// Handles a critical need by finding resources
    private func handleCriticalNeed(_ unit: inout Unit, need: NeedType) {
        switch need {
        case .thirst:
            if let drink = world.findNearestItem(of: .drink, from: unit.position) {
                if let path = world.findPath(from: unit.position, to: drink.position) {
                    unit.setPath(Array(path.dropFirst()))
                    unit.transition(to: .moving)
                    logEvent(.unitSeeking(unitId: unit.id, unitName: unit.name.firstName, target: "drink"))
                } else {
                    unit.satisfyNeed(.thirst)
                    logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "drank (emergency)"))
                }
            } else {
                unit.satisfyNeed(.thirst)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "drank (spawned)"))
            }

        case .hunger:
            if let food = world.findNearestItem(of: .food, from: unit.position) {
                if let path = world.findPath(from: unit.position, to: food.position) {
                    unit.setPath(Array(path.dropFirst()))
                    unit.transition(to: .moving)
                    logEvent(.unitSeeking(unitId: unit.id, unitName: unit.name.firstName, target: "food"))
                } else {
                    unit.satisfyNeed(.hunger)
                    logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "ate (emergency)"))
                }
            } else {
                unit.satisfyNeed(.hunger)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "ate (spawned)"))
            }

        case .drowsiness:
            if let bed = world.findNearestItem(of: .bed, from: unit.position) {
                if let path = world.findPath(from: unit.position, to: bed.position) {
                    unit.setPath(Array(path.dropFirst()))
                    unit.transition(to: .moving)
                    logEvent(.unitSeeking(unitId: unit.id, unitName: unit.name.firstName, target: "bed"))
                } else {
                    unit.transition(to: .sleeping)
                    moodManager.addThought(unitId: unit.id, type: .sleptOnGround, currentTick: world.currentTick)
                    logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "sleeping on ground"))
                }
            } else {
                unit.transition(to: .sleeping)
                moodManager.addThought(unitId: unit.id, type: .sleptOnGround, currentTick: world.currentTick)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "sleeping on ground"))
            }

        default:
            break
        }
    }

    /// Selects an idle activity based on personality using the IdleActivity enum
    private func selectIdleActivity(_ unit: inout Unit) {
        let activity = chooseIdleActivity(for: unit)

        switch activity {
        case .socialize:
            let nearbyUnits = world.getUnitsInRange(of: unit.position, radius: 10)
                .filter { $0.id != unit.id && $0.state == .idle && $0.creatureType == .orc }
            if let target = nearbyUnits.randomElement(),
               let path = world.findPath(from: unit.position, to: target.position) {
                unit.setPath(Array(path.dropFirst()))
                unit.transition(to: .moving)
                logEvent(.unitSeeking(unitId: unit.id, unitName: unit.name.firstName, target: "friend"))
                return
            }
            // Fallback to wandering if no one to talk to
            wanderRandomly(&unit)

        case .wander:
            wanderRandomly(&unit)

        case .rest:
            // Stay put and recover — do nothing this tick
            break

        case .selfTrain:
            // Practice a random enabled labor skill
            let trainableSkills: [SkillType] = [.mining, .woodcutting, .carpentry, .masonry, .cooking]
            if let skill = trainableSkills.randomElement() {
                unit.addSkillExperience(skill, amount: 2)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "practicing \(skill.rawValue)"))
            }

        case .appreciateArt:
            // Admire a nearby workshop or building — small mood boost
            let nearbyWorkshops = constructionManager.workshops.values.filter {
                $0.status == .complete && $0.position.distance(to: unit.position) <= 10
            }
            if !nearbyWorkshops.isEmpty {
                moodManager.addThought(unitId: unit.id, type: .admiredRoom, currentTick: world.currentTick)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "admiring craftsmanship"))
            }

        case .contemplateNature:
            // Enjoy nearby trees/water — small mood boost
            let neighbors = unit.position.neighbors()
            let hasNature = neighbors.contains { pos in
                guard let tile = world.getTile(at: pos) else { return false }
                return tile.terrain == .tree || tile.terrain == .water || tile.terrain == .shrub
            }
            if hasNature {
                moodManager.addThought(unitId: unit.id, type: .sawNature, currentTick: world.currentTick)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "enjoying nature"))
            }
        }
    }

    /// Chooses an idle activity weighted by personality
    private func chooseIdleActivity(for unit: Unit) -> IdleActivity {
        let gregariousness = unit.personality.value(for: .gregariousness)
        let activityLevel = unit.personality.value(for: .activityLevel)
        let curiosity = unit.personality.value(for: .curiosity)
        let perseverance = unit.personality.value(for: .perseverance)

        // Build weighted choices based on personality
        var weights: [(IdleActivity, Int)] = [
            (.wander, 20 + activityLevel / 2),
            (.socialize, 10 + gregariousness),
            (.rest, 30 + (100 - activityLevel) / 2),
            (.selfTrain, 5 + perseverance / 2),
            (.appreciateArt, 5 + curiosity / 3),
            (.contemplateNature, 5 + (100 - gregariousness) / 3),
        ]

        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 1...total)

        for (activity, weight) in weights {
            roll -= weight
            if roll <= 0 { return activity }
        }
        return .rest
    }

    /// Makes a unit wander to a random nearby passable tile
    private func wanderRandomly(_ unit: inout Unit) {
        let wanderRadius = 5
        var attempts = 0
        let maxAttempts = 10

        while attempts < maxAttempts {
            let dx = Int.random(in: -wanderRadius...wanderRadius)
            let dy = Int.random(in: -wanderRadius...wanderRadius)
            let target = Position(x: unit.position.x + dx, y: unit.position.y + dy, z: unit.position.z)

            if world.isPassable(target), let path = world.findPath(from: unit.position, to: target) {
                unit.setPath(Array(path.dropFirst()))
                unit.transition(to: .moving)
                return
            }
            attempts += 1
        }
    }

    /// Processes a unit in moving state
    private func processMovingState(_ unit: inout Unit) {
        // Check for critical need interrupt
        if let criticalNeed = unit.checkCriticalNeeds() {
            if criticalNeed == .thirst && unit.thirst >= NeedThresholds.thirstDehydrated {
                unit.clearPath()
                handleCriticalNeed(&unit, need: criticalNeed)
                return
            }
        }

        // Advance along path
        let arrived = unit.advanceOnPath()

        if arrived {
            handleArrival(&unit)
        }
    }

    /// Handle arrival at destination
    private func handleArrival(_ unit: inout Unit) {
        let itemsHere = world.getItems(at: unit.position)

        // Check if we arrived at food
        if itemsHere.contains(where: { $0.itemType == .food }) {
            if unit.hunger > NeedThresholds.hungerConsider {
                unit.transition(to: .eating)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "eating"))
                return
            }
        }

        // Check if we arrived at drink
        if itemsHere.contains(where: { $0.itemType == .drink }) {
            if unit.thirst > NeedThresholds.thirstConsider {
                unit.transition(to: .drinking)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "drinking"))
                return
            }
        }

        // Check if we arrived at bed
        if itemsHere.contains(where: { $0.itemType == .bed }) {
            if unit.drowsiness > NeedThresholds.drowsyConsider {
                unit.transition(to: .sleeping)
                moodManager.addThought(unitId: unit.id, type: .sleptWell, currentTick: world.currentTick)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "sleeping in bed"))
                return
            }
        }

        // Check if arrived at job location
        let unitJobs = jobManager.getJobsForUnit(unit.id)
        if let job = unitJobs.first(where: { $0.position == unit.position }) {
            jobManager.startJob(jobId: job.id)
            unit.transition(to: .working)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "starting \(job.type.rawValue)"))
            return
        }

        // Check if arrived near another unit for socializing
        let nearbyUnits = world.getUnitsInRange(of: unit.position, radius: 2)
            .filter { $0.id != unit.id && $0.state != .dead && $0.creatureType == .orc }
        if !nearbyUnits.isEmpty {
            unit.transition(to: .socializing)

            // Have a conversation
            if let partner = nearbyUnits.first {
                let result = socialManager.haveConversation(
                    participant1: unit.id,
                    participant2: partner.id,
                    personality1: unit.personality,
                    personality2: partner.personality,
                    currentTick: world.currentTick
                )

                if result.success {
                    moodManager.addThought(unitId: unit.id, type: .talkedWithFriend, currentTick: world.currentTick)
                }

                logEvent(.social(unit1Name: unit.name.firstName, unit2Name: partner.name.firstName, message: result.description))
                stats.totalConversations += 1

                // Track active conversation for speech bubble display
                let conversation = ActiveConversation(
                    participant1Id: unit.id,
                    participant2Id: partner.id,
                    participant1Name: unit.name.firstName,
                    participant2Name: partner.name.firstName,
                    topic: result.topic.rawValue,
                    isSuccess: result.success,
                    startTick: world.currentTick
                )
                activeConversations.append(conversation)
            }
            return
        }

        // Otherwise go idle
        unit.transition(to: .idle)
    }

    /// Processes a unit in eating state
    private func processEatingState(_ unit: inout Unit) {
        if Int.random(in: 0...10) < 3 {
            unit.satisfyNeed(.hunger)
            unit.transition(to: .idle)
            stats.mealsEaten += 1

            // Consume the food item
            if let food = world.getItems(at: unit.position).first(where: { $0.itemType == .food }) {
                world.removeItem(id: food.id)
            }

            // Add positive thought for good meal
            moodManager.addThought(unitId: unit.id, type: .ateGoodFood, currentTick: world.currentTick)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "finished eating"))
        }
    }

    /// Processes a unit in drinking state
    private func processDrinkingState(_ unit: inout Unit) {
        if Int.random(in: 0...10) < 4 {
            unit.satisfyNeed(.thirst)
            unit.transition(to: .idle)
            stats.drinksDrank += 1

            // Consume the drink item
            if let drink = world.getItems(at: unit.position).first(where: { $0.itemType == .drink }) {
                world.removeItem(id: drink.id)
            }

            // Add positive thought for drink (alcohol bonus!)
            moodManager.addThought(unitId: unit.id, type: .drankAlcohol, currentTick: world.currentTick)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "finished drinking"))
        }
    }

    /// Processes a unit in sleeping state
    private func processSleepingState(_ unit: inout Unit) {
        unit.processSleepRecovery()

        if unit.isFullyRested {
            unit.transition(to: .idle)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "woke up rested"))
        }
    }

    /// Processes a unit in working state
    private func processWorkingState(_ unit: inout Unit) {
        // Check for need interrupts
        if let criticalNeed = unit.checkCriticalNeeds() {
            // Release current job
            if let job = jobManager.getJobsForUnit(unit.id).first {
                jobManager.releaseJob(jobId: job.id)
            }
            unit.transition(to: .idle)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "interrupted by \(criticalNeed.rawValue)"))
            return
        }

        // Apply work to current job
        if let job = jobManager.getJobsForUnit(unit.id).first {
            let completed = jobManager.applyWork(jobId: job.id, amount: 1)

            if completed {
                jobManager.completeJob(jobId: job.id)

                // Handle job completion based on type
                handleJobCompletion(&unit, job: job)

                unit.transition(to: .idle)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "completed \(job.type.rawValue)"))

                // Good work thought
                moodManager.addThought(unitId: unit.id, type: .didGoodWork, currentTick: world.currentTick)
                stats.totalJobsCompleted += 1

                // Give skill XP
                if let skill = job.type.associatedSkill {
                    unit.addSkillExperience(skill, amount: 20)
                }
            }
        } else {
            // No job - go idle
            unit.transition(to: .idle)
        }
    }

    /// Handle job completion effects
    private func handleJobCompletion(_ unit: inout Unit, job: Job) {
        switch job.type {
        case .mine:
            // Mine the tile at targetPosition (or job.position if not set)
            let minePos = job.targetPosition ?? job.position
            if let item = world.mineTile(at: minePos) {
                stats.tilesMinedSIM += 1
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "mined \(item.itemType.rawValue)"))
            }
            // Complete designation if any
            designationManager.completeDesignation(at: minePos)

        case .chopTree:
            // Chop tree at targetPosition (or job.position if not set)
            let chopPos = job.targetPosition ?? job.position
            // Create logs at worker position
            let log = Item.create(type: .log, at: job.position, quality: .standard)
            world.addItem(log)
            // Change terrain to grass at tree position
            if var tile = world.getTile(at: chopPos) {
                tile.terrain = .grass
                world.setTile(tile, at: chopPos)
            }
            stats.treesChopped += 1
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "chopped down a tree"))

        case .haul:
            // Complete haul task
            if let haulTask = stockpileManager.getHaulTasks(for: unit.id).first {
                stockpileManager.completeHaulTask(taskId: haulTask.id)
            }

        case .craft:
            // Create crafted item
            if let resultType = job.resultItemType {
                let quality = craftingManager.calculateQuality(skillLevel: unit.skills[.carpentry]?.rating ?? 0)
                let item = Item.create(type: resultType, at: job.position, quality: quality)
                world.addItem(item)
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "crafted \(quality.rawValue) \(resultType.rawValue)"))
            }

        case .harvest:
            // Gather plants from shrub at targetPosition (or job.position if not set)
            let harvestPos = job.targetPosition ?? job.position
            if var tile = world.getTile(at: harvestPos), tile.terrain == .shrub {
                // Create plant item at worker position
                let plant = Item.create(type: .plant, at: job.position, quality: .standard)
                world.addItem(plant)
                // Shrub is "depleted" - change to grass
                tile.terrain = .grass
                world.setTile(tile, at: harvestPos)
                stats.plantsGathered += 1
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "gathered plants"))
            }

        case .fish:
            // Fishing produces raw fish (as rawMeat or food)
            // Success chance based on skill
            let fishingSkill = unit.skills[.cooking]?.rating ?? 0  // Using cooking for now
            let successChance = 50 + fishingSkill * 5
            if Int.random(in: 1...100) <= successChance {
                let fish = Item.create(type: .rawMeat, at: job.position, quality: .standard)
                world.addItem(fish)
                stats.fishCaught += 1
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "caught a fish"))
            } else {
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "fishing was unsuccessful"))
            }

        case .hunt:
            // Hunting was completed - find the target creature
            // First try to get the specific target unit, then fall back to nearby search
            var prey: Unit? = nil
            if let targetId = job.targetUnit, let targetUnit = world.units[targetId], targetUnit.isAlive {
                prey = targetUnit
            } else {
                // Fallback: find any nearby huntable creature
                let nearbyCreatures = world.getUnitsInRange(of: unit.position, radius: 5)
                    .filter { $0.id != unit.id && $0.creatureType != .orc && $0.isAlive }
                    .filter { $0.creatureType == .wolf || $0.creatureType == .bear }
                prey = nearbyCreatures.first
            }

            if let prey = prey {
                // Combat-like resolution
                let attackerStrength = unit.physicalAttributes[.strength]?.base ?? 1000
                let attackerSkill = unit.skills[.meleeCombat]?.rating ?? 0
                var preyUnit = prey
                let result = combatManager.resolveAttack(
                    attackerId: unit.id,
                    attackerStrength: attackerStrength,
                    attackerSkill: attackerSkill + 5,  // Hunting bonus
                    defenderId: prey.id,
                    defenderAgility: prey.physicalAttributes[.agility]?.base ?? 500,
                    defenderHealth: &preyUnit.health,
                    damageType: .slash
                )
                world.updateUnit(preyUnit)

                if result.defenderDied {
                    // Produce raw meat from the kill
                    let meatCount = Int.random(in: 2...4)
                    for _ in 0..<meatCount {
                        let meat = Item.create(type: .rawMeat, at: prey.position, quality: .standard)
                        world.addItem(meat)
                    }
                    stats.animalsHunted += 1
                    logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "hunted \(prey.creatureType.rawValue), got \(meatCount) meat"))
                    hostileUnits.remove(prey.id)
                } else {
                    logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "hunting \(prey.creatureType.rawValue)..."))
                }
            } else {
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "hunt target escaped"))
            }

        case .cook:
            // Cooking combines raw ingredients into meals
            // Find raw meat and plants at position
            let itemsHere = world.getItems(at: job.position)
            let rawMeat = itemsHere.first { $0.itemType == .rawMeat }
            let plant = itemsHere.first { $0.itemType == .plant }

            if let meat = rawMeat {
                world.removeItem(id: meat.id)
                let quality = craftingManager.calculateQuality(skillLevel: unit.skills[.cooking]?.rating ?? 0)
                let meal = Item.create(type: .food, at: job.position, quality: quality)
                world.addItem(meal)

                // If we also have a plant, make a better meal
                if let p = plant {
                    world.removeItem(id: p.id)
                    let bonusMeal = Item.create(type: .food, at: job.position, quality: quality)
                    world.addItem(bonusMeal)
                    stats.mealsCookedSIM += 2
                    logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "cooked a fine meal"))
                } else {
                    stats.mealsCookedSIM += 1
                    logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "cooked a meal"))
                }
            }

        case .brew:
            // Brewing converts plants into drinks
            // Find plants anywhere in the world (simplified brewing - no hauling required)
            let allPlants = world.items.values.filter { $0.itemType == .plant }
            let plantsArray = Array(allPlants)

            if plantsArray.count >= 2 {
                // Consume 2 plants
                for plant in plantsArray.prefix(2) {
                    world.removeItem(id: plant.id)
                }
                // Produce drinks at worker position
                let quality = craftingManager.calculateQuality(skillLevel: unit.skills[.brewing]?.rating ?? 0)
                for _ in 0..<3 {
                    let drink = Item.create(type: .drink, at: job.position, quality: quality)
                    world.addItem(drink)
                }
                stats.drinksBrewedSIM += 3
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "brewed ale"))
            } else {
                logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "couldn't brew - not enough plants"))
            }

        default:
            break
        }
    }

    /// Processes a unit in socializing state
    private func processSocializingState(_ unit: inout Unit) {
        if unit.checkCriticalNeeds() != nil {
            unit.transition(to: .idle)
            return
        }

        if Int.random(in: 0...15) < 2 {
            unit.transition(to: .idle)
            logEvent(.unitAction(unitId: unit.id, unitName: unit.name.firstName, action: "finished socializing"))
        }
    }

    // MARK: - Periodic Checks

    /// Performs checks that happen every N ticks
    private func performPeriodicChecks() {
        let tick = world.currentTick

        // Log milestone every in-game day
        if tick % UInt64(TimeConstants.ticksPerDay) == 0 && tick > 0 {
            logEvent(.milestone(tick: tick, message: "Day \(tick / UInt64(TimeConstants.ticksPerDay)) - \(world.units.count) units"))
        }

        // Spawn hostile creature (configurable interval and chance)
        if tick % UInt64(hostileSpawnInterval) == 0 && tick > 0 && Int.random(in: 0...100) < hostileSpawnChance {
            spawnHostileCreature()
        }

        // Check for potential marriages every in-game day
        if tick % UInt64(TimeConstants.ticksPerDay) == 0 {
            checkForMarriages()
        }

        // Migrant wave (configurable interval, based on colony wealth)
        if tick % UInt64(migrantWaveInterval) == 0 && tick > 0 {
            let orcCount = world.units.values.filter { $0.creatureType == .orc && $0.isAlive }.count
            if orcCount < maxPopulation {
                spawnMigrantsBasedOnWealth()
            }
        }

        // Check for births from married couples (configurable interval)
        if tick % UInt64(birthCheckInterval) == 0 && tick > 0 {
            checkForBirths()
        }
    }

    /// Calculate colony wealth/strength score
    /// Based on: population, items, workshops, buildings, combat victories, food/drink stocks
    public func calculateColonyWealth() -> Int {
        var wealth = 0

        // Population value (each orc is worth 100)
        let orcCount = world.units.values.filter { $0.creatureType == .orc && $0.isAlive }.count
        wealth += orcCount * 100

        // Item wealth (varies by type and quality)
        for item in world.items.values {
            let baseValue: Int
            switch item.itemType {
            case .food, .drink, .plant, .rawMeat:
                baseValue = 5
            case .log, .stone:
                baseValue = 10
            case .ore:
                baseValue = 25
            case .bed, .table, .chair, .door:
                baseValue = 50
            case .barrel, .bin:
                baseValue = 30
            case .pickaxe, .axe:
                baseValue = 100
            }
            // Quality multiplier
            let qualityMultiplier = item.quality.multiplier
            wealth += Int(Double(baseValue) * qualityMultiplier)
        }

        // Workshop value (each complete workshop is worth 200)
        let completeWorkshops = constructionManager.workshops.values.filter { $0.status == .complete }.count
        wealth += completeWorkshops * 200

        // Building value (each complete building is worth 50)
        let completeBuildings = constructionManager.buildings.values.filter { $0.status == .complete }.count
        wealth += completeBuildings * 50

        // Combat victories bonus (each kill adds 25)
        wealth += stats.totalKills * 25

        // Food security bonus
        let foodCount = world.items.values.filter { $0.itemType == .food }.count
        let drinkCount = world.items.values.filter { $0.itemType == .drink }.count
        wealth += (foodCount + drinkCount) * 10

        // Marriage/family bonus (stable society)
        wealth += stats.totalMarriages * 100
        wealth += stats.births * 50

        return wealth
    }

    /// Spawn migrants based on colony wealth/strength
    private func spawnMigrantsBasedOnWealth() {
        let wealth = calculateColonyWealth()
        let orcCount = world.units.values.filter { $0.creatureType == .orc && $0.isAlive }.count

        // Determine migrant count based on wealth tiers
        // Weak colony (< 500 wealth): 0-1 migrants, 30% chance of any
        // Growing colony (500-1500): 1-2 migrants
        // Established colony (1500-3000): 2-4 migrants
        // Prosperous colony (3000-6000): 3-5 migrants
        // Legendary colony (6000+): 4-7 migrants

        let baseMigrants: Int
        let migrantChance: Int  // Percentage chance migrants arrive at all

        if wealth < 500 {
            baseMigrants = Int.random(in: 0...1)
            migrantChance = 30
        } else if wealth < 1500 {
            baseMigrants = Int.random(in: 1...2)
            migrantChance = 60
        } else if wealth < 3000 {
            baseMigrants = Int.random(in: 2...4)
            migrantChance = 80
        } else if wealth < 6000 {
            baseMigrants = Int.random(in: 3...5)
            migrantChance = 90
        } else {
            baseMigrants = Int.random(in: 4...7)
            migrantChance = 95
        }

        // Check if migrants arrive at all
        guard Int.random(in: 1...100) <= migrantChance else {
            logEvent(.milestone(tick: world.currentTick, message: "No migrants this season (wealth: \(wealth))"))
            return
        }

        // Reduce migrants if population is already high
        let populationPenalty = max(0, (orcCount - 10) / 5)
        let finalMigrantCount = max(0, baseMigrants - populationPenalty)

        guard finalMigrantCount > 0 else {
            logEvent(.milestone(tick: world.currentTick, message: "Colony too crowded for migrants (pop: \(orcCount))"))
            return
        }

        var spawned = 0
        for _ in 0..<finalMigrantCount {
            if let position = findRandomPassablePosition() {
                var migrant = Unit.create(at: position)
                migrant.creatureType = .orc
                moodManager.initializeMood(
                    unitId: migrant.id,
                    cheerfulness: migrant.personality.value(for: .cheerfulness),
                    stressVulnerability: migrant.personality.value(for: .stressVulnerability)
                )
                world.addUnit(migrant)
                logEvent(.unitSpawned(unitId: migrant.id, name: "\(migrant.name.firstName) migrated to the outpost"))
                stats.migrants += 1
                spawned += 1
            }
        }

        if spawned > 0 {
            let wealthTier: String
            if wealth < 500 { wealthTier = "struggling" }
            else if wealth < 1500 { wealthTier = "growing" }
            else if wealth < 3000 { wealthTier = "established" }
            else if wealth < 6000 { wealthTier = "prosperous" }
            else { wealthTier = "legendary" }

            logEvent(.milestone(tick: world.currentTick, message: "Migrant wave! \(spawned) orcs drawn to our \(wealthTier) outpost (wealth: \(wealth))"))
        }
    }

    /// Check for births from married couples
    private func checkForBirths() {
        for (unitId, unit) in world.units {
            guard unit.creatureType == .orc && unit.isAlive else { continue }
            guard let spouseId = socialManager.getSpouse(of: unitId) else { continue }
            guard let spouse = world.getUnit(id: spouseId), spouse.isAlive else { continue }

            // Configurable chance of birth per check for married couples
            if Int.random(in: 0...100) < birthChancePercent {
                if let position = findRandomPassablePosition() {
                    var baby = Unit.create(at: position)
                    baby.creatureType = .orc

                    // Initialize mood
                    moodManager.initializeMood(
                        unitId: baby.id,
                        cheerfulness: baby.personality.value(for: .cheerfulness),
                        stressVulnerability: baby.personality.value(for: .stressVulnerability)
                    )

                    // Set family relationships
                    socialManager.setFamilyRelationship(parent: unitId, child: baby.id, currentTick: world.currentTick)
                    socialManager.setFamilyRelationship(parent: spouseId, child: baby.id, currentTick: world.currentTick)

                    world.addUnit(baby)
                    logEvent(.unitSpawned(unitId: baby.id, name: "\(baby.name.firstName) was born to \(unit.name.firstName) and \(spouse.name.firstName)!"))
                    stats.births += 1
                    return  // Only one birth per check
                }
            }
        }
    }

    /// Spawn a hostile creature at the edge of the map
    private func spawnHostileCreature() {
        // Pick random edge position
        let edge = Int.random(in: 0...3)
        var x: Int
        var y: Int

        switch edge {
        case 0: // Top
            x = Int.random(in: 0..<world.width)
            y = 0
        case 1: // Bottom
            x = Int.random(in: 0..<world.width)
            y = world.height - 1
        case 2: // Left
            x = 0
            y = Int.random(in: 0..<world.height)
        default: // Right
            x = world.width - 1
            y = Int.random(in: 0..<world.height)
        }

        let position = Position(x: x, y: y, z: 0)
        guard world.isPassable(position) else { return }

        // Get creature type from registry spawn pool (with fallback)
        guard let creatureType = CreatureRegistry.shared.randomHostileType() ?? [CreatureType.goblin, .wolf].randomElement() else {
            return
        }

        var creature = Unit.create(at: position)
        creature.creatureType = creatureType
        creature.health = Health(maxHP: creatureType.baseHP)

        world.addUnit(creature)
        hostileUnits.insert(creature.id)

        logEvent(.unitSpawned(unitId: creature.id, name: "\(creatureType.rawValue) appeared!"))
        stats.hostileSpawns += 1
    }

    /// Check for potential marriages between close friends
    private func checkForMarriages() {
        for (unitId, unit) in world.units {
            guard unit.creatureType == .orc && unit.state != .dead else { continue }
            guard socialManager.getSpouse(of: unitId) == nil else { continue }

            // Find potential partner
            let friends = socialManager.getFriends(of: unitId)
            for friendId in friends {
                guard let friend = world.getUnit(id: friendId) else { continue }
                guard friend.creatureType == .orc && friend.state != .dead else { continue }
                guard socialManager.getSpouse(of: friendId) == nil else { continue }

                // Check if can become lovers
                if socialManager.canBecomLovers(unit1: unitId, unit2: friendId) {
                    if Int.random(in: 0...100) < 10 {  // 10% chance
                        if socialManager.marry(unit1: unitId, unit2: friendId, currentTick: world.currentTick) {
                            logEvent(.social(unit1Name: unit.name.firstName, unit2Name: friend.name.firstName, message: "got married!"))
                            stats.totalMarriages += 1
                            return  // Only one marriage per check
                        }
                    }
                }
            }
        }
    }

    // MARK: - Event Logging

    /// Logs a simulation event
    private func logEvent(_ event: SimulationEvent) {
        eventLog.append(event)
    }

    /// Clears the event log
    public func clearEventLog() {
        eventLog.removeAll()
    }

    // MARK: - Setup Helpers

    /// Spawns orc units at random passable positions
    public func spawnUnits(count: Int) {
        var spawned = 0
        var attempts = 0
        let maxAttempts = count * 10

        while spawned < count && attempts < maxAttempts {
            let x = Int.random(in: 0..<world.width)
            let y = Int.random(in: 0..<world.height)
            let position = Position(x: x, y: y, z: 0)

            if world.isPassable(position) {
                var unit = Unit.create(at: position)
                unit.creatureType = .orc

                // Initialize mood
                moodManager.initializeMood(
                    unitId: unit.id,
                    cheerfulness: unit.personality.value(for: .cheerfulness),
                    stressVulnerability: unit.personality.value(for: .stressVulnerability)
                )

                world.addUnit(unit)
                logEvent(.unitSpawned(unitId: unit.id, name: unit.name.description))
                spawned += 1
            }
            attempts += 1
        }
    }

    /// Spawns food and drink items at random positions
    public func spawnResources(foodCount: Int, drinkCount: Int, bedCount: Int = 0) {
        for _ in 0..<foodCount {
            if let position = findRandomPassablePosition() {
                let food = Item.create(type: .food, at: position)
                world.addItem(food)
            }
        }

        for _ in 0..<drinkCount {
            if let position = findRandomPassablePosition() {
                let drink = Item.create(type: .drink, at: position)
                world.addItem(drink)
            }
        }

        for _ in 0..<bedCount {
            if let position = findRandomPassablePosition() {
                let bed = Item.create(type: .bed, at: position)
                world.addItem(bed)
            }
        }
    }

    /// Creates a default stockpile for items
    public func createDefaultStockpile() {
        // Create a stockpile in the center
        let centerX = world.width / 2
        let centerY = world.height / 2

        stockpileManager.createStockpile(
            name: "Main Stockpile",
            at: Position(x: centerX - 2, y: centerY - 2, z: 0),
            width: 5,
            height: 5,
            settings: .acceptAll
        )
    }

    /// Finds a random passable position in the world
    private func findRandomPassablePosition() -> Position? {
        var attempts = 0
        let maxAttempts = 100

        while attempts < maxAttempts {
            let x = Int.random(in: 0..<world.width)
            let y = Int.random(in: 0..<world.height)
            let position = Position(x: x, y: y, z: 0)

            if world.isPassable(position) {
                return position
            }
            attempts += 1
        }
        return nil
    }
}

// MARK: - Simulation Statistics

/// Statistics tracked during simulation
public struct SimulationStats: Sendable {
    public var totalDeaths: Int = 0
    public var totalKills: Int = 0
    public var totalCombatDamage: Int = 0
    public var totalJobsCompleted: Int = 0
    public var totalConversations: Int = 0
    public var totalMarriages: Int = 0
    public var hostileSpawns: Int = 0
    public var haulJobsGenerated: Int = 0
    public var mealsEaten: Int = 0
    public var drinksDrank: Int = 0
    public var migrants: Int = 0
    public var births: Int = 0

    // Autonomous work stats
    public var treesChopped: Int = 0
    public var tilesMinedSIM: Int = 0
    public var plantsGathered: Int = 0
    public var fishCaught: Int = 0
    public var animalsHunted: Int = 0
    public var mealsCookedSIM: Int = 0
    public var drinksBrewedSIM: Int = 0
}

// MARK: - Simulation Events

/// Events that can occur during simulation for logging/display
public enum SimulationEvent: Sendable, CustomStringConvertible {
    case unitSpawned(unitId: UInt64, name: String)
    case unitDied(unitId: UInt64, cause: String)
    case unitAction(unitId: UInt64, unitName: String, action: String)
    case unitSeeking(unitId: UInt64, unitName: String, target: String)
    case combat(attackerName: String, defenderName: String, damage: Int, damageType: String, weapon: String, critical: Bool, killed: Bool)
    case social(unit1Name: String, unit2Name: String, message: String)
    case milestone(tick: UInt64, message: String)

    public var description: String {
        switch self {
        case .unitSpawned(_, let name):
            return "\(name) arrived"
        case .unitDied(_, let cause):
            return cause
        case .unitAction(_, let unitName, let action):
            return "\(unitName) \(action)"
        case .unitSeeking(_, let unitName, let target):
            return "\(unitName) seeking \(target)"
        case .combat(let attackerName, let defenderName, let damage, let damageType, let weapon, let critical, let killed):
            var msg = "\(attackerName)"
            if critical {
                msg += " CRIT"
            }
            msg += " hit \(defenderName) for \(damage) \(damageType)"
            if !weapon.isEmpty {
                msg += " (\(weapon))"
            }
            if killed {
                msg += " [KILLED]"
            }
            return msg
        case .social(let unit1Name, let unit2Name, let message):
            return "\(unit1Name) & \(unit2Name): \(message)"
        case .milestone(_, let message):
            return message
        }
    }

    /// Whether this is an important event (for highlighting)
    public var isImportant: Bool {
        switch self {
        case .unitDied, .milestone:
            return true
        case .combat(_, _, _, _, _, _, let killed) where killed:
            return true
        case .combat(_, _, _, _, _, let critical, _) where critical:
            return true
        case .social(_, _, let message) where message.contains("married"):
            return true
        default:
            return false
        }
    }
}

// MARK: - Active Conversation

/// Represents a conversation currently being displayed with speech bubbles
public struct ActiveConversation: Sendable {
    public let participant1Id: UInt64
    public let participant2Id: UInt64
    public let participant1Name: String
    public let participant2Name: String
    public let topic: String
    public let isSuccess: Bool
    public let startTick: UInt64

    public init(
        participant1Id: UInt64,
        participant2Id: UInt64,
        participant1Name: String,
        participant2Name: String,
        topic: String,
        isSuccess: Bool,
        startTick: UInt64
    ) {
        self.participant1Id = participant1Id
        self.participant2Id = participant2Id
        self.participant1Name = participant1Name
        self.participant2Name = participant2Name
        self.topic = topic
        self.isSuccess = isSuccess
        self.startTick = startTick
    }
}
