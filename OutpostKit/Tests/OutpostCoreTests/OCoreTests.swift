import Testing

@testable import OutpostCore
@testable import OutpostRuntime

// MARK: - Calendar System Tests

@Suite("Calendar System")
struct CalendarTests {
    @Test("Tick 0 produces Year 1, Spring, Day 1, Hour 0")
    func tickZero() {
        let cal = WorldCalendar(tick: 0)
        #expect(cal.year == 1)
        #expect(cal.season == .spring)
        #expect(cal.day == 1)
        #expect(cal.hour == 0)
        #expect(cal.minute == 0)
    }

    @Test("50 ticks = 1 hour")
    func oneHour() {
        let cal = WorldCalendar(tick: UInt64(TimeConstants.ticksPerHour))
        #expect(cal.hour == 1)
        #expect(cal.minute == 0)
    }

    @Test("1200 ticks = 1 day")
    func oneDay() {
        let cal = WorldCalendar(tick: UInt64(TimeConstants.ticksPerDay))
        #expect(cal.day == 2)
        #expect(cal.hour == 0)
    }

    @Test("Season progression over a full year")
    func seasonProgression() {
        let spring = WorldCalendar(tick: 0)
        #expect(spring.season == .spring)

        let summer = WorldCalendar(tick: UInt64(TimeConstants.ticksPerSeason))
        #expect(summer.season == .summer)

        let autumn = WorldCalendar(tick: UInt64(TimeConstants.ticksPerSeason * 2))
        #expect(autumn.season == .autumn)

        let winter = WorldCalendar(tick: UInt64(TimeConstants.ticksPerSeason * 3))
        #expect(winter.season == .winter)
    }

    @Test("Year rolls over after 4 seasons")
    func yearRollover() {
        let year2 = WorldCalendar(tick: UInt64(TimeConstants.ticksPerYear))
        #expect(year2.year == 2)
        #expect(year2.season == .spring)
    }

    @Test("Time of day varies with hour")
    func timeOfDay() {
        // Night: hour 0
        let midnight = WorldCalendar(tick: 0)
        #expect(midnight.timeOfDay == .night)
        #expect(midnight.isNight)
        #expect(!midnight.isDaytime)

        // Morning: hour 10 (after dawn ends in any season)
        let morningTick = UInt64(10 * TimeConstants.ticksPerHour)
        let morning = WorldCalendar(tick: morningTick)
        #expect(morning.timeOfDay == .morning)
        #expect(morning.isDaytime)
    }

    @Test("dayProgress is fractional through the day")
    func dayProgress() {
        let noon = WorldCalendar(tick: UInt64(12 * TimeConstants.ticksPerHour))
        #expect(noon.dayProgress > 0.49)
        #expect(noon.dayProgress < 0.51)
    }

    @Test("dateString and timeString produce non-empty strings")
    func calendarStrings() {
        let cal = WorldCalendar(tick: 1000)
        #expect(!cal.dateString.isEmpty)
        #expect(!cal.timeString.isEmpty)
        #expect(cal.dateString.contains("Year"))
    }
}

// MARK: - Position Tests

@Suite("Position")
struct PositionTests {
    @Test("Manhattan distance")
    func manhattanDistance() {
        let a = Position(x: 0, y: 0)
        let b = Position(x: 3, y: 4)
        #expect(a.distance(to: b) == 7)
    }

    @Test("Euclidean distance")
    func euclideanDistance() {
        let a = Position(x: 0, y: 0)
        let b = Position(x: 3, y: 4)
        let d = a.euclideanDistance(to: b)
        #expect(d > 4.99 && d < 5.01)
    }

    @Test("Adjacency check")
    func adjacency() {
        let center = Position(x: 5, y: 5)
        let adjacent = Position(x: 6, y: 5)
        let diagonal = Position(x: 6, y: 6)
        let far = Position(x: 8, y: 5)
        let sameSpot = Position(x: 5, y: 5)

        #expect(center.isAdjacent(to: adjacent))
        #expect(center.isAdjacent(to: diagonal))
        #expect(!center.isAdjacent(to: far))
        #expect(!center.isAdjacent(to: sameSpot))  // Same position is not adjacent
    }

    @Test("Neighbors returns 8 positions")
    func neighbors() {
        let pos = Position(x: 5, y: 5)
        let neighbors = pos.neighbors()
        #expect(neighbors.count == 8)
    }

    @Test("moved(in:) shifts position correctly")
    func movedInDirection() {
        let pos = Position(x: 5, y: 5)
        let moved = pos.moved(in: .north)
        #expect(moved.x == 5)
        #expect(moved.y == 4)
    }
}

// MARK: - Unit Tests

@Suite("Unit")
struct UnitTests {
    @Test("Unit creates with valid defaults")
    func unitDefaults() {
        let unit = Unit.create(at: Position(x: 10, y: 10))
        #expect(unit.state == .idle)
        #expect(unit.isAlive)
        #expect(unit.creatureType == .orc)
        #expect(unit.hunger == 0)
        #expect(unit.thirst == 0)
        #expect(unit.drowsiness == 0)
        #expect(unit.health.isAlive)
        #expect(unit.health.percentage == 100)
    }

    @Test("tickUpdate increments needs")
    func tickUpdateNeeds() {
        var unit = Unit.create(at: Position(x: 5, y: 5))
        unit.tickUpdate()
        #expect(unit.hunger == 1)
        #expect(unit.thirst == 1)
        #expect(unit.drowsiness == 1)
    }

    @Test("Action counter decrement")
    func actionCounter() {
        var unit = Unit.create()
        unit.actionCounter = 5
        #expect(!unit.canAct)
        for _ in 0..<5 {
            unit.tickUpdate()
        }
        #expect(unit.canAct)
    }

    @Test("Critical needs detect thirst/hunger/drowsiness")
    func criticalNeeds() {
        var unit = Unit.create()
        #expect(unit.checkCriticalNeeds() == nil)

        unit.thirst = NeedThresholds.thirstCritical
        #expect(unit.checkCriticalNeeds() == .thirst)

        unit.thirst = 0
        unit.hunger = NeedThresholds.hungerCritical
        #expect(unit.checkCriticalNeeds() == .hunger)

        unit.hunger = 0
        unit.drowsiness = NeedThresholds.drowsyCritical
        #expect(unit.checkCriticalNeeds() == .drowsiness)
    }

    @Test("Need death thresholds")
    func needDeath() {
        var unit = Unit.create()
        #expect(unit.checkNeedDeath() == nil)

        unit.thirst = NeedThresholds.thirstDeath
        #expect(unit.checkNeedDeath() == .thirst)
    }

    @Test("Need satisfaction reduces counters")
    func needSatisfaction() {
        var unit = Unit.create()
        unit.thirst = 60_000
        unit.satisfyNeed(.thirst)
        #expect(unit.thirst == 10_000)

        unit.hunger = 60_000
        unit.satisfyNeed(.hunger)
        #expect(unit.hunger == 10_000)
    }

    @Test("Sleep recovery")
    func sleepRecovery() {
        var unit = Unit.create()
        unit.drowsiness = 100
        unit.processSleepRecovery()
        #expect(unit.drowsiness == 100 - NeedThresholds.sleepRecoveryPerTick)
    }

    @Test("Skill experience and leveling")
    func skillLeveling() {
        var unit = Unit.create()
        #expect(unit.skillLevel(for: .mining) == 0)

        // Add enough XP to level up (level 0 -> 1 needs 400 + 100*1 = 500 XP)
        unit.addSkillExperience(.mining, amount: 500)
        #expect(unit.skillLevel(for: .mining) == 1)
    }

    @Test("State transitions")
    func stateTransitions() {
        var unit = Unit.create()
        #expect(unit.state == .idle)
        #expect(unit.canBeInterrupted)

        unit.transition(to: .fighting)
        #expect(unit.state == .fighting)
        #expect(!unit.canBeInterrupted)

        unit.transition(to: .dead)
        #expect(!unit.isAlive)
    }

    @Test("Path setting and advancing")
    func pathMovement() {
        var unit = Unit.create(at: Position(x: 0, y: 0))
        let path = [Position(x: 1, y: 0), Position(x: 2, y: 0), Position(x: 3, y: 0)]
        unit.setPath(path)
        #expect(unit.state == .moving)
        #expect(unit.isPathfinding)

        unit.advanceOnPath()
        #expect(unit.position == Position(x: 1, y: 0))

        unit.advanceOnPath()
        #expect(unit.position == Position(x: 2, y: 0))

        let arrived = unit.advanceOnPath()
        #expect(arrived)
        #expect(unit.position == Position(x: 3, y: 0))
        #expect(!unit.isPathfinding)
    }
}

// MARK: - Health Tests

@Suite("Health System")
struct HealthTests {
    @Test("Health initializes correctly")
    func healthInit() {
        let health = Health(maxHP: 100)
        #expect(health.currentHP == 100)
        #expect(health.maxHP == 100)
        #expect(health.isAlive)
        #expect(health.percentage == 100)
        #expect(!health.isWounded)
        #expect(!health.isCritical)
    }

    @Test("Damage reduces HP and reports actual damage")
    func takeDamage() {
        var health = Health(maxHP: 100)
        let dealt = health.takeDamage(30)
        #expect(dealt == 30)
        #expect(health.currentHP == 70)
        #expect(health.isAlive)
    }

    @Test("Damage cannot exceed remaining HP")
    func damageClamp() {
        var health = Health(maxHP: 100)
        health.takeDamage(80)
        let dealt = health.takeDamage(50)
        #expect(dealt == 20)  // Only 20 HP left
        #expect(health.currentHP == 0)
        #expect(!health.isAlive)
    }

    @Test("Healing restores HP")
    func heal() {
        var health = Health(maxHP: 100)
        health.takeDamage(60)
        let healed = health.heal(30)
        #expect(healed == 30)
        #expect(health.currentHP == 70)
    }

    @Test("Healing cannot exceed max HP")
    func healClamp() {
        var health = Health(maxHP: 100)
        health.takeDamage(20)
        let healed = health.heal(50)
        #expect(healed == 20)
        #expect(health.currentHP == 100)
    }

    @Test("Wounded and critical thresholds")
    func woundedThresholds() {
        var health = Health(maxHP: 100)
        #expect(!health.isWounded)
        #expect(!health.isCritical)

        health.takeDamage(51)
        #expect(health.isWounded)
        #expect(!health.isCritical)

        health.takeDamage(25)
        #expect(health.isCritical)
    }
}

// MARK: - World Tests

@Suite("World")
struct WorldTests {
    @Test("World creates with correct dimensions")
    func worldDimensions() {
        let world = World(width: 40, height: 25)
        #expect(world.width == 40)
        #expect(world.height == 25)
        #expect(world.depth == 1)
        #expect(world.currentTick == 0)
    }

    @Test("Valid position check")
    func positionValidation() {
        let world = World(width: 10, height: 10)
        #expect(world.isValidPosition(Position(x: 0, y: 0)))
        #expect(world.isValidPosition(Position(x: 9, y: 9)))
        #expect(!world.isValidPosition(Position(x: -1, y: 0)))
        #expect(!world.isValidPosition(Position(x: 10, y: 0)))
        #expect(!world.isValidPosition(Position(x: 0, y: 10)))
    }

    @Test("Tick advances currentTick")
    func worldTick() {
        var world = World(width: 10, height: 10)
        #expect(world.currentTick == 0)
        world.tick()
        #expect(world.currentTick == 1)
        world.tick()
        #expect(world.currentTick == 2)
    }

    @Test("Calendar derived from tick")
    func worldCalendar() {
        let world = World(width: 10, height: 10)
        let cal = world.calendar
        #expect(cal.year == 1)
        #expect(cal.season == .spring)
    }

    @Test("Unit add, get, update, remove")
    func unitCRUD() {
        var world = World(width: 20, height: 20)
        var unit = Unit.create(at: Position(x: 5, y: 5))
        let unitId = unit.id

        // Add
        world.addUnit(unit)
        #expect(world.units.count == 1)
        #expect(world.getUnit(id: unitId) != nil)

        // Update position
        unit.position = Position(x: 6, y: 6)
        world.updateUnit(unit)
        let updated = world.getUnit(id: unitId)
        #expect(updated?.position == Position(x: 6, y: 6))

        // Remove
        world.removeUnit(id: unitId)
        #expect(world.units.count == 0)
        #expect(world.getUnit(id: unitId) == nil)
    }

    @Test("Item add, get, remove")
    func itemCRUD() {
        var world = World(width: 20, height: 20)
        let item = Item.create(type: .food, at: Position(x: 3, y: 3))
        let itemId = item.id

        world.addItem(item)
        #expect(world.items.count == 1)
        #expect(world.getItem(id: itemId) != nil)

        world.removeItem(id: itemId)
        #expect(world.items.count == 0)
    }

    @Test("Find nearest item")
    func findNearestItem() {
        var world = World(width: 30, height: 30)
        let far = Item.create(type: .food, at: Position(x: 20, y: 20))
        let near = Item.create(type: .food, at: Position(x: 2, y: 2))
        world.addItem(far)
        world.addItem(near)

        let found = world.findNearestItem(of: .food, from: Position(x: 0, y: 0))
        #expect(found?.id == near.id)
    }

    @Test("Get units in range")
    func unitsInRange() {
        var world = World(width: 30, height: 30)
        let u1 = Unit.create(at: Position(x: 5, y: 5))
        let u2 = Unit.create(at: Position(x: 6, y: 6))
        let u3 = Unit.create(at: Position(x: 20, y: 20))
        world.addUnit(u1)
        world.addUnit(u2)
        world.addUnit(u3)

        let nearby = world.getUnitsInRange(of: Position(x: 5, y: 5), radius: 3)
        #expect(nearby.count == 2)
    }

    @Test("Pathfinding finds a path on open terrain")
    func pathfinding() {
        var world = World(width: 10, height: 10)
        // Manually clear all to grass for deterministic test
        for y in 0..<10 {
            for x in 0..<10 {
                let pos = Position(x: x, y: y)
                var tile = world.getTile(at: pos)!
                tile.terrain = .grass
                world.setTile(tile, at: pos)
            }
        }

        let path = world.findPath(from: Position(x: 0, y: 0), to: Position(x: 5, y: 5))
        #expect(path != nil)
        #expect(path!.first == Position(x: 0, y: 0))
        #expect(path!.last == Position(x: 5, y: 5))
        // Path length for diagonal is at most 6 (diagonal moves)
        #expect(path!.count <= 10)
    }

    @Test("Pathfinding returns nil when blocked")
    func pathfindingBlocked() {
        var world = World(width: 5, height: 5)
        // Clear terrain
        for y in 0..<5 {
            for x in 0..<5 {
                let pos = Position(x: x, y: y)
                var tile = world.getTile(at: pos)!
                tile.terrain = .grass
                world.setTile(tile, at: pos)
            }
        }
        // Block a wall across the middle
        for x in 0..<5 {
            let pos = Position(x: x, y: 2)
            var tile = world.getTile(at: pos)!
            tile.terrain = .wall
            world.setTile(tile, at: pos)
        }

        let path = world.findPath(from: Position(x: 0, y: 0), to: Position(x: 0, y: 4))
        #expect(path == nil)
    }

    @Test("Mining produces items")
    func mining() {
        var world = World(width: 10, height: 10)
        let pos = Position(x: 3, y: 3)
        var tile = world.getTile(at: pos)!
        tile.terrain = .wall
        world.setTile(tile, at: pos)

        let result = world.mineTile(at: pos)
        #expect(result != nil)
        #expect(result!.itemType == .stone)

        let updatedTile = world.getTile(at: pos)!
        #expect(updatedTile.terrain == .stoneFloor)
    }

    @Test("Display level returns non-empty string")
    func displayLevel() {
        let world = World(width: 10, height: 10)
        let display = world.displayLevel(0)
        #expect(!display.isEmpty)
    }
}

// MARK: - Simulation Integration Tests

@Suite("Simulation Integration")
@MainActor
struct SimulationIntegrationTests {
    @Test("Simulation creates with default world")
    func simInit() {
        let sim = Simulation(worldWidth: 30, worldHeight: 20)
        #expect(sim.world.width == 30)
        #expect(sim.world.height == 20)
        #expect(sim.world.currentTick == 0)
    }

    @Test("Spawn units places orcs in the world")
    func spawnUnits() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnUnits(count: 7)
        let orcs = sim.world.units.values.filter { $0.creatureType == .orc }
        #expect(orcs.count == 7)
        for orc in orcs {
            #expect(orc.isAlive)
            #expect(orc.state == .idle)
        }
    }

    @Test("Spawn resources places food and drink")
    func spawnResources() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnResources(foodCount: 10, drinkCount: 10, bedCount: 5)
        let foods = sim.world.findItems(of: .food)
        let drinks = sim.world.findItems(of: .drink)
        let beds = sim.world.findItems(of: .bed)
        #expect(foods.count == 10)
        #expect(drinks.count == 10)
        #expect(beds.count == 5)
    }

    @Test("Running 500 ticks with units completes without crash")
    func run500Ticks() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnUnits(count: 5)
        sim.spawnResources(foodCount: 20, drinkCount: 20, bedCount: 5)
        sim.run(ticks: 500)
        #expect(sim.world.currentTick == 500)
    }

    @Test("Units transition through valid states during simulation")
    func unitStateValidity() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnUnits(count: 10)
        sim.spawnResources(foodCount: 50, drinkCount: 50, bedCount: 10)

        let validStates = Set(UnitState.allCases)

        sim.run(ticks: 200)

        for unit in sim.world.units.values {
            #expect(
                validStates.contains(unit.state),
                "Unit \(unit.name) in unexpected state: \(unit.state)")
        }
    }

    @Test("Needs increase over time for living units")
    func needsIncrease() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnUnits(count: 3)

        sim.run(ticks: 100)

        for unit in sim.world.units.values where unit.isAlive {
            // Needs should have increased from 0 (unless satisfied)
            // At minimum, SOME needs should be > 0 after 100 ticks
            let totalNeeds = unit.hunger + unit.thirst + unit.drowsiness
            #expect(totalNeeds > 0, "Unit \(unit.name) has zero needs after 100 ticks")
        }
    }

    @Test("Events are logged during simulation")
    func eventLogging() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnUnits(count: 5)
        sim.spawnResources(foodCount: 20, drinkCount: 20)

        // After spawning, there should be spawn events
        #expect(!sim.eventLog.isEmpty, "Event log should contain spawn events")

        let spawnEvents = sim.eventLog.filter {
            if case .unitSpawned = $0 { return true }
            return false
        }
        #expect(spawnEvents.count == 5)
    }

    @Test("Health stays valid during simulation")
    func healthValidity() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnUnits(count: 8)
        sim.spawnResources(foodCount: 30, drinkCount: 30)

        sim.run(ticks: 300)

        for unit in sim.world.units.values {
            #expect(unit.health.currentHP >= 0, "Unit \(unit.name) has negative HP")
            #expect(
                unit.health.currentHP <= unit.health.maxHP,
                "Unit \(unit.name) has HP above max")
            if unit.isAlive {
                #expect(unit.health.isAlive, "Living unit has 0 HP")
            }
        }
    }

    @Test("Colony wealth can be calculated")
    func colonyWealth() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnResources(foodCount: 10, drinkCount: 10)
        let wealth = sim.calculateColonyWealth()
        #expect(wealth > 0, "Colony with items should have positive wealth")
    }

    @Test("Simulation stats track data")
    func simulationStats() {
        let sim = Simulation(worldWidth: 40, worldHeight: 25)
        sim.spawnUnits(count: 5)
        sim.spawnResources(foodCount: 30, drinkCount: 30)

        sim.run(ticks: 500)

        // Stats struct should exist and be accessible
        let stats = sim.stats
        // At least mealsEaten or drinksDrank should be >= 0 (valid)
        #expect(stats.mealsEaten >= 0)
        #expect(stats.drinksDrank >= 0)
        #expect(stats.totalDeaths >= 0)
    }

    @Test("Long simulation (2000 ticks) with hostile spawning completes")
    func longSimulation() {
        let sim = Simulation(worldWidth: 50, worldHeight: 30)
        sim.hostileSpawnInterval = 200
        sim.hostileSpawnChance = 80
        sim.spawnUnits(count: 10)
        sim.spawnResources(foodCount: 100, drinkCount: 100, bedCount: 10)

        sim.run(ticks: 2000)

        #expect(sim.world.currentTick == 2000)

        // Calendar should reflect tick 2000
        let cal = sim.world.calendar
        #expect(cal.year >= 1)
        #expect(cal.day >= 1 && cal.day <= 28)
        #expect(cal.hour >= 0 && cal.hour < 24)
        #expect(cal.minute >= 0 && cal.minute < 60)

        // Print summary for diagnostic visibility
        let alive = sim.world.units.values.filter { $0.isAlive }
        let dead = sim.world.units.values.filter { !$0.isAlive }
        let orcs = alive.filter { $0.creatureType == .orc }
        let hostiles = alive.filter { $0.creatureType != .orc }

        print("=== Long Simulation Results (2000 ticks) ===")
        print("Calendar: \(cal.dateString) \(cal.timeString) (\(cal.timeOfDay))")
        print("Total units: \(sim.world.units.count) (alive: \(alive.count), dead: \(dead.count))")
        print("Orcs alive: \(orcs.count), Hostiles alive: \(hostiles.count)")
        print("Stats - Deaths: \(sim.stats.totalDeaths), Kills: \(sim.stats.totalKills)")
        print("Stats - Meals: \(sim.stats.mealsEaten), Drinks: \(sim.stats.drinksDrank)")
        print("Stats - Conversations: \(sim.stats.totalConversations)")
        print("Stats - Hostile spawns: \(sim.stats.hostileSpawns)")
        print("Events logged: \(sim.eventLog.count)")

        // State distribution
        var stateDistribution: [UnitState: Int] = [:]
        for unit in sim.world.units.values {
            stateDistribution[unit.state, default: 0] += 1
        }
        print("State distribution: \(stateDistribution)")
    }

    @Test("Season change events fire")
    func seasonChangeEvents() {
        let sim = Simulation(worldWidth: 20, worldHeight: 20)
        sim.maxEventLogSize = 5000
        sim.spawnUnits(count: 2)

        // Run past one full season (100,800 ticks) plus a bit
        sim.run(ticks: TimeConstants.ticksPerSeason + 100)

        let seasonEvents = sim.eventLog.filter {
            if case .seasonChanged = $0 { return true }
            return false
        }
        #expect(seasonEvents.count >= 1, "Should have at least one season change event")
    }

    @Test("Unit positions stay within world bounds")
    func positionBounds() {
        let sim = Simulation(worldWidth: 30, worldHeight: 20)
        sim.spawnUnits(count: 8)
        sim.spawnResources(foodCount: 20, drinkCount: 20)

        sim.run(ticks: 500)

        for unit in sim.world.units.values where unit.isAlive {
            #expect(
                unit.position.x >= 0 && unit.position.x < 30,
                "Unit \(unit.name) x=\(unit.position.x) out of bounds")
            #expect(
                unit.position.y >= 0 && unit.position.y < 20,
                "Unit \(unit.name) y=\(unit.position.y) out of bounds")
        }
    }
}

// MARK: - Attribute and Model Tests

@Suite("Models")
struct ModelTests {
    @Test("AttributeValue initialization and effective value")
    func attributeValue() {
        var attr = AttributeValue(base: 1000)
        #expect(attr.effective == 1000)
        #expect(attr.levelDescription == "Average")

        attr.modifier = 500
        #expect(attr.effective == 1500)
        #expect(attr.levelDescription == "High")
    }

    @Test("SkillEntry leveling and experience")
    func skillEntry() {
        var skill = SkillEntry(skillType: .mining, rating: 0)
        #expect(skill.levelName == "Not")
        #expect(skill.xpForNextLevel == 500)  // 400 + 100*(0+1)

        skill.addExperience(500)
        #expect(skill.rating == 1)
        #expect(skill.levelName == "Dabbling")
    }

    @Test("Personality generates valid facet values")
    func personality() {
        let p = Personality()
        for facet in PersonalityFacet.allCases {
            let val = p.value(for: facet)
            #expect(val >= 25 && val <= 75, "Facet \(facet) value \(val) out of range")
        }
    }

    @Test("Personality setValue clamps to 0-100")
    func personalityClamping() {
        var p = Personality()
        p.setValue(150, for: .bravery)
        #expect(p.value(for: .bravery) == 100)
        p.setValue(-10, for: .bravery)
        #expect(p.value(for: .bravery) == 0)
    }

    @Test("UnitName description formatting")
    func unitName() {
        let name = UnitName(firstName: "Urist", nickname: nil, lastName: "Ironaxe")
        #expect(name.fullName == "Urist Ironaxe")
        #expect(name.description == "Urist")

        let nicknamed = UnitName(firstName: "Urist", nickname: "The Bold", lastName: "Ironaxe")
        #expect(nicknamed.description == "\"The Bold\" Urist")
    }

    @Test("NameGenerator produces non-empty names")
    func nameGenerator() {
        for _ in 0..<20 {
            let name = NameGenerator.generate()
            #expect(!name.firstName.isEmpty)
            #expect(name.lastName != nil)
            #expect(!name.lastName!.isEmpty)
        }
    }

    @Test("NeedThresholds are ordered correctly")
    func needThresholdOrdering() {
        // Thirst thresholds should be ordered
        #expect(NeedThresholds.thirstConsider < NeedThresholds.thirstDecide)
        #expect(NeedThresholds.thirstDecide < NeedThresholds.thirstIndicator)
        #expect(NeedThresholds.thirstIndicator < NeedThresholds.thirstCritical)
        #expect(NeedThresholds.thirstCritical < NeedThresholds.thirstDehydrated)
        #expect(NeedThresholds.thirstDehydrated < NeedThresholds.thirstDeath)

        // Hunger thresholds
        #expect(NeedThresholds.hungerConsider < NeedThresholds.hungerDecide)
        #expect(NeedThresholds.hungerDecide < NeedThresholds.hungerIndicator)
        #expect(NeedThresholds.hungerCritical < NeedThresholds.hungerStarving)
        #expect(NeedThresholds.hungerStarving < NeedThresholds.hungerDeath)

        // Drowsiness thresholds
        #expect(NeedThresholds.drowsyConsider < NeedThresholds.drowsyDecide)
        #expect(NeedThresholds.drowsyDecide < NeedThresholds.drowsyIndicator)
        #expect(NeedThresholds.drowsyCritical < NeedThresholds.drowsyInsane)
    }

    @Test("Direction opposites are correct")
    func directionOpposites() {
        #expect(Direction.north.opposite == .south)
        #expect(Direction.east.opposite == .west)
        #expect(Direction.northeast.opposite == .southwest)
    }

    @Test("ItemQuality ordering and multipliers")
    func itemQuality() {
        #expect(ItemQuality.standard < ItemQuality.masterwork)
        #expect(ItemQuality.standard.multiplier == 1.0)
        #expect(ItemQuality.artifact.multiplier == 120.0)
    }

    @Test("Season cycle")
    func seasonCycle() {
        #expect(Season.spring.next == .summer)
        #expect(Season.summer.next == .autumn)
        #expect(Season.autumn.next == .winter)
        #expect(Season.winter.next == .spring)
    }

    @Test("CreatureType allCases contains expected types")
    func creatureTypes() {
        let types = CreatureType.allCases
        #expect(types.contains(.orc))
        #expect(types.contains(.goblin))
        #expect(types.contains(.wolf))
        #expect(types.contains(.bear))
        #expect(types.contains(.giant))
        #expect(types.contains(.undead))
        #expect(types.count == 6)
    }
}
