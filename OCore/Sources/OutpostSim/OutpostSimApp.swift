// OutpostSim - An Orc Outpost simulation viewer
// Run this to watch autonomous orcs live their tiny lives

import ArgumentParser
import Foundation
import OCore

@main
struct OutpostSimApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "OutpostSim",
        abstract: "An Orc Outpost simulation viewer",
        discussion: """
            Watch autonomous orcs live their tiny lives! Each orc has hunger, \
            thirst, and drowsiness needs, unique personality traits, and emergent \
            behavior driven by needs.

            Config File Locations (searched in order):
              1. ./outpost.yaml
              2. ~/.config/outpost/outpost.yaml

            Legend:
              @  Orc      g  Goblin   w  Wolf    !  Item
              .  Grass    T  Tree     ~  Water   _  Stone   #  Wall

            States (by color):
              white=idle  cyan=moving  green=eat/drink  blue=sleep
              magenta=social  red=fight  yellow=flee

            Examples:
              OutpostSim                           # Quick start with defaults
              OutpostSim --worldgen                # Generate world history first
              OutpostSim -T -t 5000                # Turbo mode, stop at 5000 ticks
              OutpostSim -s max -r 500 -t 10000    # Max speed, render every 500, 10k ticks
              OutpostSim --headless -t 50000       # Benchmark 50k ticks with no display
              OutpostSim -s 100 -u 12              # 100 ticks/sec, 12 orcs
            """
    )

    // MARK: - Simulation Options

    @Option(name: [.customShort("w"), .long], help: "World width (20-100).")
    var width: Int?

    @Option(name: [.customShort("h"), .long], help: "World height (10-50).")
    var height: Int?

    @Option(name: [.customShort("u"), .long], help: "Number of starting orcs (1-20).")
    var units: Int?

    @Option(name: [.customShort("s"), .long], help: "Ticks per second, or \"max\"/\"turbo\" for max speed.")
    var speed: String?

    // MARK: - Speed/Testing Options

    @Flag(name: [.customShort("T"), .long], help: "Maximum speed mode (no delays).")
    var turbo: Bool = false

    @Option(name: [.customShort("r"), .customLong("render-every")], help: "Only render every N ticks.")
    var renderEvery: Int?

    @Option(name: [.customShort("t"), .customLong("max-ticks")], help: "Stop after N ticks.")
    var maxTicks: Int?

    @Flag(name: .long, help: "No rendering (for benchmarks).")
    var headless: Bool = false

    @Flag(name: .long, help: "Hard mode: minimal starting resources.")
    var hard: Bool = false

    // MARK: - World Generation Options

    @Flag(name: [.customShort("g"), .long], help: "Enable world generation with history.")
    var worldgen: Bool = false

    @Option(name: [.customShort("y"), .long], help: "Years of history to simulate (50-1000).")
    var years: Int?

    @Option(name: .customLong("gen-speed"), help: "Generation display speed (1-100).")
    var genSpeed: Double?

    // MARK: - Configuration

    @Flag(name: .customLong("show-config"), help: "Show config file search paths and loaded values.")
    var showConfig: Bool = false

    // MARK: - Run

    @MainActor
    mutating func run() async throws {
        let yamlConfig = ConfigurationLoader.loadConfiguration().validated()

        CreatureRegistry.shared.initialize(with: yamlConfig)
        ItemRegistry.shared.initialize(with: yamlConfig)

        if showConfig {
            Self.printConfigInfo(yamlConfig)
            return
        }

        var config = RuntimeConfig.fromYAMLConfig(yamlConfig)
        applyOverrides(to: &config)

        Self.printWelcome(worldGen: config.enableWorldGen)
        try await Task.sleep(nanoseconds: 1_500_000_000)

        if config.enableWorldGen {
            let history = await Self.runWorldGeneration(config: config)

            print("\n\u{001B}[?25h")  // Show cursor
            print("Press Enter to begin simulation in \(history?.worldName ?? "the world")...")
            _ = readLine()

            await Self.runSimulation(config: config, worldHistory: history)
        } else {
            await Self.runSimulation(config: config, worldHistory: nil)
        }
    }

    // MARK: - CLI Override Logic

    private func applyOverrides(to config: inout RuntimeConfig) {
        if let w = width {
            config.worldWidth = max(20, min(100, w))
        }
        if let h = height {
            config.worldHeight = max(10, min(50, h))
        }
        if let u = units {
            config.unitCount = max(1, min(20, u))
        }

        if let s = speed {
            if s == "max" || s == "turbo" || s == "0" {
                config.turboMode = true
                config.renderEvery = 100
            } else if let val = Double(s) {
                config.ticksPerSecond = max(0.1, min(10000.0, val))
                if val > 100 {
                    config.renderEvery = max(1, Int(val / 30))
                }
            }
        }

        if turbo {
            config.turboMode = true
            config.renderEvery = 100
        }

        if headless {
            config.headlessMode = true
            config.turboMode = true
        }

        if hard {
            config.hardMode = true
            config.foodCount = 3
            config.drinkCount = 3
            config.bedCount = 0
        }

        if worldgen {
            config.enableWorldGen = true
        }

        if let y = years {
            config.historyYears = max(50, min(1000, y))
        }

        if let gs = genSpeed {
            config.genSpeed = max(1.0, min(100.0, gs))
        }

        if let mt = maxTicks {
            config.maxTicks = max(1, mt)
        }

        // Explicit --render-every always wins last (can override turbo's default 100)
        if let re = renderEvery {
            config.renderEvery = max(1, min(10000, re))
        }
    }

    // MARK: - Config Info

    @MainActor
    static func printConfigInfo(_ config: OutpostConfig) {
        print("Outpost Configuration")
        print("=====================\n")

        print(ConfigurationLoader.configSearchInfo())

        print("\nCurrent Configuration Values:")
        print("  World: \(config.simulation.world.width)x\(config.simulation.world.height)")
        print("  Initial Units: \(config.simulation.units.initialCount)")
        print("  Max Population: \(config.simulation.units.maxPopulation)")
        print("  Resources: \(config.simulation.resources.foodCount) food, \(config.simulation.resources.drinkCount) drink, \(config.simulation.resources.bedCount) beds")
        print("  Speed: \(config.simulation.speed.ticksPerSecond) ticks/sec")
        print("  Hard Mode: \(config.simulation.difficulty.hardMode)")

        print("\nEvent Configuration:")
        print("  Hostile Spawn: every \(config.events.hostileSpawn.intervalTicks) ticks, \(config.events.hostileSpawn.chancePercent)% chance")
        print("  Migrant Wave: every \(config.events.migrantWave.intervalTicks) ticks")
        print("  Birth Check: every \(config.events.birthCheck.intervalTicks) ticks, \(config.events.birthCheck.chancePercent)% chance")

        print("\nHostile Spawn Pool: \(CreatureRegistry.shared.hostileSpawnPool.joined(separator: ", "))")

        let configFound = ConfigurationLoader.findConfigFile() != nil

        let creatureNames = CreatureRegistry.shared.registeredCreatures
        print("\nRegistered Creatures: \(creatureNames.count)")
        for name in creatureNames {
            if let def = CreatureRegistry.shared.getDefinition(for: name) {
                let overridden = configFound && config.creatures[name] != nil ? " [config]" : ""
                print("  \(name): HP=\(def.baseHP), DMG=\(def.baseDamage), char='\(def.displayChar)', hostile=\(def.hostileToOrcs)\(overridden)")
            }
        }

        let itemNames = ItemRegistry.shared.registeredItems
        print("\nRegistered Items: \(itemNames.count)")
        for name in itemNames {
            if let def = ItemRegistry.shared.getDefinition(for: name) {
                let overridden = configFound && config.items[name] != nil ? " [config]" : ""
                print("  \(name): value=\(def.baseValue), category=\(def.category), stackable=\(def.stackable)\(overridden)")
            }
        }
    }

    // MARK: - Welcome

    static func printWelcome(worldGen: Bool) {
        print("\u{001B}[2J\u{001B}[H", terminator: "")  // Clear screen
        if worldGen {
            print(
                """
                ╔══════════════════════════════════════════════════════════════════╗
                ║                                                                  ║
                ║   🏰  ORC OUTPOST SIMULATION  🏰                                  ║
                ║                                                                  ║
                ║   Creating a new world with history and lore...                  ║
                ║                                                                  ║
                ║   Watch as:                                                      ║
                ║   • Mountains rise and rivers form                               ║
                ║   • Civilizations are founded                                    ║
                ║   • Heroes perform great deeds                                   ║
                ║   • Wars rage and alliances form                                 ║
                ║   • Artifacts of legend are created                              ║
                ║                                                                  ║
                ║   Press Ctrl+C to exit                                           ║
                ║                                                                  ║
                ╚══════════════════════════════════════════════════════════════════╝

                Generating world...
                """)
        } else {
            print(
                """
                ╔══════════════════════════════════════════════════════════════════╗
                ║                                                                  ║
                ║   🏰  ORC OUTPOST SIMULATION  🏰                                  ║
                ║                                                                  ║
                ║   Watch autonomous orcs live their tiny lives!                   ║
                ║                                                                  ║
                ║   Each orc has:                                                  ║
                ║   • Hunger, thirst, and drowsiness needs                         ║
                ║   • Unique personality traits                                    ║
                ║   • Emergent behavior driven by needs                            ║
                ║                                                                  ║
                ║   Tip: Use --worldgen to create a world with history!            ║
                ║                                                                  ║
                ║   Press Ctrl+C to exit                                           ║
                ║                                                                  ║
                ╚══════════════════════════════════════════════════════════════════╝

                Starting simulation...
                """)
        }
    }

    // MARK: - World Generation

    @MainActor
    static func runWorldGeneration(config: RuntimeConfig) async -> WorldHistory? {
        let generator = WorldGenerator(
            worldWidth: config.worldWidth,
            worldHeight: config.worldHeight,
            historyYears: config.historyYears
        )
        generator.generationSpeed = config.genSpeed

        let renderer = WorldGenRenderer()
        renderer.hideCursor()
        renderer.clearScreen()

        // Set up progress callback
        generator.onProgress = { phase, message, history in
            renderer.update(phase: phase, message: message, history: history)
        }

        // Generate the world
        await generator.generate()

        // Show summary
        try? await Task.sleep(nanoseconds: 500_000_000)
        renderer.renderSummary(history: generator.history)
        renderer.showCursor()

        return generator.history
    }

    // MARK: - Simulation

    @MainActor
    static func runSimulation(config: RuntimeConfig, worldHistory: WorldHistory?) async {
        // Create simulation
        let simulation = Simulation(worldWidth: config.worldWidth, worldHeight: config.worldHeight)

        // Configure event parameters from config
        simulation.configure(
            hostileSpawnInterval: config.hostileSpawnInterval,
            hostileSpawnChance: config.hostileSpawnChance,
            migrantWaveInterval: config.migrantWaveInterval,
            birthCheckInterval: config.birthCheckInterval,
            birthChancePercent: config.birthChancePercent,
            maxPopulation: config.maxPopulation
        )

        // Spawn units and resources
        simulation.spawnUnits(count: config.unitCount)
        simulation.spawnResources(
            foodCount: config.foodCount,
            drinkCount: config.drinkCount,
            bedCount: config.bedCount
        )

        // If we have world history, integrate it with the simulation
        if worldHistory != nil {
            // Clear event log to start fresh
            simulation.clearEventLog()
            // Future: Could name orcs after historical figures, use world lore, etc.
        }

        // Create renderer (unless headless)
        let renderer: Renderer? = config.headlessMode ? nil : Renderer(simulation: simulation)

        // Calculate tick interval
        let tickInterval = config.turboMode ? 0.0 : (1.0 / config.ticksPerSecond)

        // Set up signal handler for clean exit
        signal(SIGINT) { _ in
            print("\u{001B}[?25h")  // Show cursor
            print("\n\nSimulation ended. Thanks for watching!")
            _Exit(0)
        }

        // Hide cursor and clear screen
        renderer?.hideCursor()
        renderer?.clearScreen()

        // Track time for stats in turbo mode
        let startTime = Date()
        var tickCount = 0

        // Main loop
        while config.maxTicks == nil || tickCount < config.maxTicks! {
            // Process simulation tick
            simulation.tick()
            tickCount += 1

            // Render (respecting render frequency)
            if !config.headlessMode && tickCount % config.renderEvery == 0 {
                renderer?.render()

                // In turbo mode, show progress indicator
                if config.turboMode && config.maxTicks != nil {
                    let percent = Double(tickCount) / Double(config.maxTicks!) * 100
                    let elapsed = Date().timeIntervalSince(startTime)
                    let tps = elapsed > 0 ? Double(tickCount) / elapsed : 0
                    print("\u{001B}[1;1H\u{001B}[K[TURBO] Tick \(tickCount)/\(config.maxTicks!) (\(String(format: "%.1f", percent))%) - \(String(format: "%.0f", tps)) ticks/sec")
                }
            }

            // Wait for next tick (unless turbo mode)
            if !config.turboMode && tickInterval > 0 {
                try? await Task.sleep(nanoseconds: UInt64(tickInterval * 1_000_000_000))
            }
        }

        // Print final stats
        let elapsed = Date().timeIntervalSince(startTime)
        let stats = simulation.stats
        renderer?.showCursor()

        print("\n")
        print("═══════════════════════════════════════════════════════════════════")
        print("  SIMULATION COMPLETE")
        print("═══════════════════════════════════════════════════════════════════")
        print("  Ticks:        \(tickCount)")
        print("  Time:         \(String(format: "%.2f", elapsed)) seconds")
        print("  Speed:        \(String(format: "%.0f", Double(tickCount) / elapsed)) ticks/sec")
        print("───────────────────────────────────────────────────────────────────")
        print("  COLONY STATUS")
        print("───────────────────────────────────────────────────────────────────")
        let wealth = simulation.calculateColonyWealth()
        let wealthTier: String
        if wealth < 500 {
            wealthTier = "Struggling"
        } else if wealth < 1500 {
            wealthTier = "Growing"
        } else if wealth < 3000 {
            wealthTier = "Established"
        } else if wealth < 6000 {
            wealthTier = "Prosperous"
        } else {
            wealthTier = "Legendary"
        }
        print("  Wealth:       \(wealth) (\(wealthTier))")
        print("  Migrants:     \(stats.migrants)")
        print("  Births:       \(stats.births)")
        print("  Marriages:    \(stats.totalMarriages)")
        print("───────────────────────────────────────────────────────────────────")
        print("  SURVIVAL")
        print("───────────────────────────────────────────────────────────────────")
        print("  Deaths:       \(stats.totalDeaths)")
        print("  Kills:        \(stats.totalKills)")
        print("  Combat Dmg:   \(stats.totalCombatDamage)")
        print("  Hostiles:     \(stats.hostileSpawns) spawned")
        print("  Meals Eaten:  \(stats.mealsEaten)")
        print("  Drinks:       \(stats.drinksDrank)")
        print("───────────────────────────────────────────────────────────────────")
        print("  SOCIAL")
        print("───────────────────────────────────────────────────────────────────")
        print("  Conversations:\(stats.totalConversations)")
        print("───────────────────────────────────────────────────────────────────")
        print("  AUTONOMOUS WORK")
        print("───────────────────────────────────────────────────────────────────")
        print("  Trees Chopped: \(stats.treesChopped)")
        print("  Tiles Mined:   \(stats.tilesMinedSIM)")
        print("  Plants Gathered:\(stats.plantsGathered)")
        print("  Fish Caught:   \(stats.fishCaught)")
        print("  Animals Hunted:\(stats.animalsHunted)")
        print("  Meals Cooked:  \(stats.mealsCookedSIM)")
        print("  Drinks Brewed: \(stats.drinksBrewedSIM)")
        print("───────────────────────────────────────────────────────────────────")

        // Show alive orcs
        let aliveOrcs = simulation.world.units.values.filter { $0.isAlive && $0.creatureType == .orc }
        print("  Orcs Alive: \(aliveOrcs.count)")
        for orc in aliveOrcs.prefix(5) {
            let hp = "\(orc.health.currentHP)/\(orc.health.maxHP)HP"
            let happiness = simulation.moodManager.getHappiness(unitId: orc.id) ?? 50
            let mood = "Mood:\(happiness)"
            print("    - \(orc.name.description): \(hp), \(mood)")
        }
        if aliveOrcs.count > 5 {
            print("    ... and \(aliveOrcs.count - 5) more")
        }
        print("═══════════════════════════════════════════════════════════════════")
    }
}
