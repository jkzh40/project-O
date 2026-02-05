// DwarfSim - A Dwarf Fortress inspired simulation viewer
// Run this to watch autonomous dwarves live their tiny lives

import Foundation
import OCore

// MARK: - Configuration

struct Config {
    var worldWidth = 50
    var worldHeight = 20
    var unitCount = 8
    var ticksPerSecond = 5.0
    var foodCount = 15
    var drinkCount = 15
    var bedCount = 5
    var maxPopulation = 50

    // Speed/testing options
    var turboMode = false           // No delays, maximum speed
    var renderEvery = 1             // Render every N ticks (for fast mode)
    var maxTicks: Int? = nil        // Stop after N ticks (nil = run forever)
    var headlessMode = false        // No rendering at all (for benchmarks)

    // Difficulty/starting conditions
    var hardMode = false            // Start with minimal resources

    // World generation options
    var enableWorldGen = false
    var historyYears = 250
    var genSpeed = 15.0

    // Event intervals and chances (from YAML config)
    var hostileSpawnInterval = 500
    var hostileSpawnChance = 50
    var migrantWaveInterval = 10000
    var birthCheckInterval = 5000
    var birthChancePercent = 5

    /// Initialize config with values from YAML configuration
    static func fromYAMLConfig(_ yamlConfig: DwarfSimConfig) -> Config {
        var config = Config()

        // Simulation settings
        config.worldWidth = yamlConfig.simulation.world.width
        config.worldHeight = yamlConfig.simulation.world.height
        config.unitCount = yamlConfig.simulation.units.initialCount
        config.maxPopulation = yamlConfig.simulation.units.maxPopulation
        config.foodCount = yamlConfig.simulation.resources.foodCount
        config.drinkCount = yamlConfig.simulation.resources.drinkCount
        config.bedCount = yamlConfig.simulation.resources.bedCount
        config.ticksPerSecond = yamlConfig.simulation.speed.ticksPerSecond
        config.hardMode = yamlConfig.simulation.difficulty.hardMode

        // Event settings
        config.hostileSpawnInterval = yamlConfig.events.hostileSpawn.intervalTicks
        config.hostileSpawnChance = yamlConfig.events.hostileSpawn.chancePercent
        config.migrantWaveInterval = yamlConfig.events.migrantWave.intervalTicks
        config.birthCheckInterval = yamlConfig.events.birthCheck.intervalTicks
        config.birthChancePercent = yamlConfig.events.birthCheck.chancePercent

        return config
    }
}

// MARK: - Main Entry Point

@main
struct DwarfSimApp {
    static func main() async {
        // Load YAML configuration first
        let yamlConfig = ConfigurationLoader.loadConfiguration().validated()

        // Initialize registries with config
        CreatureRegistry.shared.initialize(with: yamlConfig)
        ItemRegistry.shared.initialize(with: yamlConfig)

        // Parse command line arguments (CLI overrides YAML)
        let config = parseArguments(defaults: yamlConfig)

        // Print welcome message
        printWelcome(worldGen: config.enableWorldGen)

        // Small delay before starting
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        if config.enableWorldGen {
            // Run world generation first
            let history = await runWorldGeneration(config: config)

            // Show summary and wait for user
            print("\n\u{001B}[?25h")  // Show cursor
            print("Press Enter to begin simulation in \(history?.worldName ?? "the world")...")
            _ = readLine()

            // Run simulation with generated world
            await runSimulation(config: config, worldHistory: history)
        } else {
            // Run simulation directly
            await runSimulation(config: config, worldHistory: nil)
        }
    }

    @MainActor
    static func parseArguments(defaults: DwarfSimConfig) -> Config {
        // Start with values from YAML config
        var config = Config.fromYAMLConfig(defaults)
        let args = CommandLine.arguments

        var i = 1
        while i < args.count {
            switch args[i] {
            case "-w", "--width":
                if i + 1 < args.count, let val = Int(args[i + 1]) {
                    config.worldWidth = max(20, min(100, val))
                    i += 1
                }
            case "-h", "--height":
                if i + 1 < args.count, let val = Int(args[i + 1]) {
                    config.worldHeight = max(10, min(50, val))
                    i += 1
                }
            case "-u", "--units":
                if i + 1 < args.count, let val = Int(args[i + 1]) {
                    config.unitCount = max(1, min(20, val))
                    i += 1
                }
            case "-s", "--speed":
                if i + 1 < args.count {
                    let arg = args[i + 1]
                    if arg == "max" || arg == "turbo" || arg == "0" {
                        config.turboMode = true
                        config.renderEvery = 100  // Default to rendering every 100 ticks in turbo
                    } else if let val = Double(arg) {
                        config.ticksPerSecond = max(0.1, min(10000.0, val))
                        // Auto-adjust render frequency for high speeds
                        if val > 100 {
                            config.renderEvery = max(1, Int(val / 30))
                        }
                    }
                    i += 1
                }
            case "--turbo", "-T":
                config.turboMode = true
                config.renderEvery = 100
            case "--render-every", "-r":
                if i + 1 < args.count, let val = Int(args[i + 1]) {
                    config.renderEvery = max(1, min(10000, val))
                    i += 1
                }
            case "--max-ticks", "-t":
                if i + 1 < args.count, let val = Int(args[i + 1]) {
                    config.maxTicks = max(1, val)
                    i += 1
                }
            case "--headless":
                config.headlessMode = true
                config.turboMode = true
            case "--hard":
                config.hardMode = true
                config.foodCount = 3
                config.drinkCount = 3
                config.bedCount = 0
            case "--worldgen", "-g":
                config.enableWorldGen = true
            case "--years", "-y":
                if i + 1 < args.count, let val = Int(args[i + 1]) {
                    config.historyYears = max(50, min(1000, val))
                    i += 1
                }
            case "--gen-speed":
                if i + 1 < args.count, let val = Double(args[i + 1]) {
                    config.genSpeed = max(1.0, min(100.0, val))
                    i += 1
                }
            case "--help":
                printHelp()
                exit(0)
            case "--show-config":
                printConfigInfo(defaults)
                exit(0)
            default:
                break
            }
            i += 1
        }

        return config
    }

    @MainActor
    static func printConfigInfo(_ config: DwarfSimConfig) {
        print("DwarfSim Configuration")
        print("======================\n")

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

        // Check if config file was found
        let configFound = ConfigurationLoader.findConfigFile() != nil

        // Show all registered creatures (merged defaults + config)
        let creatureNames = CreatureRegistry.shared.registeredCreatures
        print("\nRegistered Creatures: \(creatureNames.count)")
        for name in creatureNames {
            if let def = CreatureRegistry.shared.getDefinition(for: name) {
                // Show [config] only if a config file exists and contains this creature
                let overridden = configFound && config.creatures[name] != nil ? " [config]" : ""
                print("  \(name): HP=\(def.baseHP), DMG=\(def.baseDamage), char='\(def.displayChar)', hostile=\(def.hostileToDwarves)\(overridden)")
            }
        }

        // Show all registered items (merged defaults + config)
        let itemNames = ItemRegistry.shared.registeredItems
        print("\nRegistered Items: \(itemNames.count)")
        for name in itemNames {
            if let def = ItemRegistry.shared.getDefinition(for: name) {
                // Show [config] only if a config file exists and contains this item
                let overridden = configFound && config.items[name] != nil ? " [config]" : ""
                print("  \(name): value=\(def.baseValue), category=\(def.category), stackable=\(def.stackable)\(overridden)")
            }
        }
    }

    static func printWelcome(worldGen: Bool) {
        print("\u{001B}[2J\u{001B}[H", terminator: "")  // Clear screen
        if worldGen {
            print("""
            ╔══════════════════════════════════════════════════════════════════╗
            ║                                                                  ║
            ║   🏰  DWARF FORTRESS INSPIRED SIMULATION  🏰                     ║
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
            print("""
            ╔══════════════════════════════════════════════════════════════════╗
            ║                                                                  ║
            ║   🏰  DWARF FORTRESS INSPIRED SIMULATION  🏰                     ║
            ║                                                                  ║
            ║   Watch autonomous dwarves live their tiny lives!                ║
            ║                                                                  ║
            ║   Each dwarf has:                                                ║
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

    static func printHelp() {
        print("""
        DwarfSim - A Dwarf Fortress inspired simulation viewer

        Usage: DwarfSim [options]

        Simulation Options:
          -w, --width <n>      World width (20-100, default: 50)
          -h, --height <n>     World height (10-50, default: 20)
          -u, --units <n>      Number of dwarves (1-20, default: 8)
          -s, --speed <n>      Ticks per second (0.1-10000, default: 5.0)
                               Use "max", "turbo", or "0" for maximum speed

        Speed/Testing Options:
          -T, --turbo          Maximum speed mode (no delays)
          -r, --render-every   Only render every N ticks (default: 1, turbo: 100)
          -t, --max-ticks <n>  Stop after N ticks (for testing)
          --headless           No rendering, just run simulation (for benchmarks)
          --hard               Hard mode: minimal starting resources (fewer migrants)

        World Generation Options:
          -g, --worldgen       Enable world generation with history
          -y, --years <n>      Years of history to simulate (50-1000, default: 250)
          --gen-speed <n>      Generation display speed (1-100, default: 15)

        Configuration:
          --show-config        Show config file search paths and loaded values

        Config File Locations (searched in order):
          1. ./dwarfsim.yaml
          2. ~/.config/dwarfsim/dwarfsim.yaml

        Other:
          --help               Show this help message

        Controls:
          Ctrl+C               Exit the simulation

        Examples:
          DwarfSim                           # Quick start with defaults
          DwarfSim --worldgen                # Generate world history first
          DwarfSim -T -t 5000                # Turbo mode, stop at 5000 ticks
          DwarfSim -s max -r 500 -t 10000    # Max speed, render every 500, 10k ticks
          DwarfSim --headless -t 50000       # Benchmark 50k ticks with no display
          DwarfSim -s 100 -u 12              # 100 ticks/sec, 12 dwarves

        Legend:
          @  Dwarf    g  Goblin   w  Wolf    !  Item
          .  Grass    T  Tree     ~  Water   _  Stone   #  Wall

        States (by color):
          white=idle  cyan=moving  green=eat/drink  blue=sleep
          magenta=social  red=fight  yellow=flee
        """)
    }

    @MainActor
    static func runWorldGeneration(config: Config) async -> WorldHistory? {
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

    @MainActor
    static func runSimulation(config: Config, worldHistory: WorldHistory?) async {
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
            // Future: Could name dwarves after historical figures, use world lore, etc.
        }

        // Create renderer (unless headless)
        let renderer: Renderer? = config.headlessMode ? nil : Renderer(simulation: simulation)

        // Calculate tick interval
        let tickInterval = config.turboMode ? 0.0 : (1.0 / config.ticksPerSecond)

        // Set up signal handler for clean exit
        signal(SIGINT) { _ in
            print("\u{001B}[?25h")  // Show cursor
            print("\n\nSimulation ended. Thanks for watching!")
            exit(0)
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
        if wealth < 500 { wealthTier = "Struggling" }
        else if wealth < 1500 { wealthTier = "Growing" }
        else if wealth < 3000 { wealthTier = "Established" }
        else if wealth < 6000 { wealthTier = "Prosperous" }
        else { wealthTier = "Legendary" }
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

        // Show alive dwarves
        let aliveDwarves = simulation.world.units.values.filter { $0.isAlive && $0.creatureType == .dwarf }
        print("  Dwarves Alive: \(aliveDwarves.count)")
        for dwarf in aliveDwarves.prefix(5) {
            let hp = "\(dwarf.health.currentHP)/\(dwarf.health.maxHP)HP"
            let mood = "Mood:\(dwarf.mood.happiness)"
            print("    - \(dwarf.name.description): \(hp), \(mood)")
        }
        if aliveDwarves.count > 5 {
            print("    ... and \(aliveDwarves.count - 5) more")
        }
        print("═══════════════════════════════════════════════════════════════════")
    }
}
