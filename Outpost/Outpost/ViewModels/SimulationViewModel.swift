import Foundation
import OutpostRuntime
import Observation

/// Main ViewModel that owns the simulation and runs the tick loop
@MainActor
@Observable
final class SimulationViewModel {
    // MARK: - Published State

    /// The simulation engine
    private(set) var simulation: Simulation

    /// Current tick number
    private(set) var currentTick: UInt64 = 0

    /// Recent events from the simulation
    private(set) var recentEvents: [String] = []

    /// Currently selected unit ID (for detail panel)
    var selectedUnitId: UInt64? = nil

    /// Whether the simulation is running
    var isRunning = false

    /// Target ticks per second
    var ticksPerSecond: Double = 10.0

    /// Whether enhanced rendering (animations, shadows, particles) is enabled
    var enhancedAnimations: Bool = true

    /// Current z-level being viewed
    var currentZ: Int = 0

    /// Population statistics
    private(set) var orcCount: Int = 0
    private(set) var hostileCount: Int = 0
    private(set) var totalUnits: Int = 0

    /// Cached world snapshot for rendering
    private(set) var worldSnapshot: WorldSnapshot?

    // MARK: - Private State

    private var tickTask: Task<Void, Never>?
    private let maxRecentEvents = 50

    // MARK: - Initialization

    init(worldWidth: Int = 50, worldHeight: Int = 40) {
        self.simulation = Simulation(worldWidth: worldWidth, worldHeight: worldHeight)
        setupSimulation()
    }

    private func setupSimulation() {
        // Spawn initial orcs
        simulation.spawnUnits(count: 7)

        // Spawn initial resources
        simulation.spawnResources(foodCount: 20, drinkCount: 20, bedCount: 5)

        // Create a default stockpile
        simulation.createDefaultStockpile()

        // Update initial state
        updateState()
    }

    // MARK: - Simulation Control

    /// Starts the simulation tick loop
    func startSimulation() {
        guard !isRunning else { return }
        isRunning = true

        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self, self.isRunning else { break }

                // Run one tick
                self.simulation.tick()
                self.updateState()

                // Calculate delay for target tick rate
                let delayNs = UInt64(1_000_000_000 / self.ticksPerSecond)
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
    }

    /// Pauses the simulation
    func pauseSimulation() {
        isRunning = false
        tickTask?.cancel()
        tickTask = nil
    }

    /// Toggles simulation running state
    func toggleSimulation() {
        if isRunning {
            pauseSimulation()
        } else {
            startSimulation()
        }
    }

    /// Runs a single tick (when paused)
    func stepSimulation() {
        guard !isRunning else { return }
        simulation.tick()
        updateState()
    }

    // MARK: - State Updates

    private func updateState() {
        currentTick = simulation.world.currentTick

        // Update population counts
        orcCount = simulation.world.units.values.filter { $0.creatureType == .orc && $0.state != .dead }.count
        hostileCount = simulation.hostileUnits.count
        totalUnits = simulation.world.units.count

        // Update recent events
        let newEvents = simulation.eventLog.suffix(maxRecentEvents).map { $0.description }
        recentEvents = Array(newEvents)

        // Update world snapshot
        worldSnapshot = WorldSnapshot.from(
            simulation: simulation,
            currentZ: currentZ,
            hostileUnits: simulation.hostileUnits
        )
    }

    // MARK: - Queries

    /// Gets the selected unit snapshot
    var selectedUnit: UnitSnapshot? {
        guard let id = selectedUnitId else { return nil }
        return worldSnapshot?.units.first { $0.id == id }
    }

    /// Gets detailed unit info for the selected unit
    func getSelectedUnitDetail() -> UnitDetail? {
        guard let id = selectedUnitId,
              let unit = simulation.world.getUnit(id: id) else { return nil }

        // Build memory summary
        let recentMemories = unit.memories.recallRecent(limit: 5).map { $0.detail }
        let topBeliefs = unit.memories.topBeliefs(limit: 3).map { $0.belief }
        let positiveAssoc = unit.memories.topPositiveAssociations(limit: 3).map { (name: $0.entityName, feeling: $0.feeling) }
        let negativeAssoc = unit.memories.topNegativeAssociations(limit: 3).map { (name: $0.entityName, feeling: $0.feeling) }

        return UnitDetail(
            id: unit.id,
            name: unit.name.description,
            fullName: unit.name.fullName,
            state: unit.state,
            creatureType: unit.creatureType,
            position: "\(unit.position.x), \(unit.position.y), \(unit.position.z)",
            healthCurrent: unit.health.currentHP,
            healthMax: unit.health.maxHP,
            healthPercent: unit.health.percentage,
            hunger: unit.hunger,
            hungerPercent: min(100, (unit.hunger * 100) / NeedThresholds.hungerDeath),
            thirst: unit.thirst,
            thirstPercent: min(100, (unit.thirst * 100) / NeedThresholds.thirstDeath),
            drowsiness: unit.drowsiness,
            drowsinessPercent: min(100, (unit.drowsiness * 100) / NeedThresholds.drowsyInsane),
            facing: unit.facing,
            recentMemories: recentMemories,
            topBeliefs: topBeliefs,
            positiveAssociations: positiveAssoc,
            negativeAssociations: negativeAssoc
        )
    }

    /// Selects a unit at the given grid position
    func selectUnit(at x: Int, y: Int) {
        if let unit = worldSnapshot?.units.first(where: { $0.x == x && $0.y == y }) {
            selectedUnitId = unit.id
        } else {
            selectedUnitId = nil
        }
    }

    /// Clears the current selection
    func clearSelection() {
        selectedUnitId = nil
    }

    // MARK: - Z-Level Navigation

    func moveZLevelUp() {
        if currentZ < simulation.world.depth - 1 {
            currentZ += 1
            updateState()
        }
    }

    func moveZLevelDown() {
        if currentZ > 0 {
            currentZ -= 1
            updateState()
        }
    }
}

// MARK: - Unit Detail DTO

struct UnitDetail: Sendable {
    let id: UInt64
    let name: String
    let fullName: String
    let state: UnitState
    let creatureType: CreatureType
    let position: String
    let healthCurrent: Int
    let healthMax: Int
    let healthPercent: Int
    let hunger: Int
    let hungerPercent: Int
    let thirst: Int
    let thirstPercent: Int
    let drowsiness: Int
    let drowsinessPercent: Int
    let facing: Direction
    let recentMemories: [String]
    let topBeliefs: [String]
    let positiveAssociations: [(name: String, feeling: Int)]
    let negativeAssociations: [(name: String, feeling: Int)]
}
