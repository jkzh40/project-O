// MARK: - Terminal Renderer
// Renders the simulation state to the terminal for observation

import Foundation

/// Renders the simulation to the terminal
@MainActor
public final class Renderer: Sendable {
    /// The simulation to render
    public let simulation: Simulation

    /// Whether to use ANSI colors
    public var useColors: Bool = true

    /// Number of recent events to show
    public var eventHistorySize: Int = 8

    /// Creates a renderer for a simulation
    public init(simulation: Simulation) {
        self.simulation = simulation
    }

    // MARK: - ANSI Escape Codes

    private enum ANSI {
        static let reset = "\u{001B}[0m"
        static let clear = "\u{001B}[2J"
        static let home = "\u{001B}[H"
        static let clearLine = "\u{001B}[K"  // Clear from cursor to end of line
        static let hideCursor = "\u{001B}[?25l"
        static let showCursor = "\u{001B}[?25h"

        // Colors
        static let green = "\u{001B}[32m"
        static let blue = "\u{001B}[34m"
        static let yellow = "\u{001B}[33m"
        static let red = "\u{001B}[31m"
        static let cyan = "\u{001B}[36m"
        static let magenta = "\u{001B}[35m"
        static let white = "\u{001B}[37m"
        static let gray = "\u{001B}[90m"
        static let brightGreen = "\u{001B}[92m"
        static let brightYellow = "\u{001B}[93m"
        static let brightCyan = "\u{001B}[96m"
        static let brightWhite = "\u{001B}[97m"

        // Background colors
        static let bgBlue = "\u{001B}[44m"
        static let bgGreen = "\u{001B}[42m"
    }

    // MARK: - Rendering

    /// Clears the terminal and moves cursor to home
    public func clearScreen() {
        print(ANSI.clear + ANSI.home, terminator: "")
    }

    /// Renders the full simulation state
    public func render() {
        var output = ""

        // Header
        output += renderHeader()
        output += "\n"

        // Map
        output += renderMap()
        output += "\n"

        // Unit status panel
        output += renderUnitPanel()
        output += "\n"

        // Event log
        output += renderEventLog()

        // Legend
        output += renderLegend()

        // Output everything at once to reduce flicker
        print(ANSI.home + output, terminator: "")
        fflush(stdout)
    }

    /// Renders the header with tick count
    private func renderHeader() -> String {
        let tick = simulation.world.currentTick
        let dwarfCount = simulation.world.units.values.filter { $0.creatureType == .dwarf }.count
        let aliveDwarves = simulation.world.units.values.filter { $0.isAlive && $0.creatureType == .dwarf }.count
        let hostileCount = simulation.world.units.values.filter { $0.isAlive && $0.creatureType != .dwarf }.count

        let stats = simulation.stats
        let statsLine = "Kills:\(stats.totalKills) Deaths:\(stats.totalDeaths) Jobs:\(stats.totalJobsCompleted)"

        var header = "╔══════════════════════════════════════════════════════════════════╗\(ANSI.clearLine)\n"
        header += "║  🏰 DWARF SIMULATION                                             ║\(ANSI.clearLine)\n"
        header += "║  Tick: \(String(format: "%6d", tick)) │ Dwarves: \(aliveDwarves)/\(dwarfCount) │ Hostiles: \(String(format: "%2d", hostileCount))           ║\(ANSI.clearLine)\n"
        header += "║  \(statsLine.padding(toLength: 62, withPad: " ", startingAt: 0))  ║\(ANSI.clearLine)\n"
        header += "╚══════════════════════════════════════════════════════════════════╝\(ANSI.clearLine)\n"

        return header
    }

    /// Renders the map with units and items
    private func renderMap() -> String {
        let world = simulation.world
        var map = ""

        // Top border
        map += "┌" + String(repeating: "─", count: world.width) + "┐\(ANSI.clearLine)\n"

        for y in 0..<world.height {
            map += "│"
            for x in 0..<world.width {
                let position = Position(x: x, y: y, z: 0)
                if let tile = world.getTile(at: position) {
                    map += colorize(tile: tile, at: position)
                } else {
                    map += " "
                }
            }
            map += "│\(ANSI.clearLine)\n"
        }

        // Bottom border
        map += "└" + String(repeating: "─", count: world.width) + "┘\(ANSI.clearLine)"

        return map
    }

    /// Colorizes a tile character based on its content
    private func colorize(tile: Tile, at position: Position) -> String {
        guard useColors else {
            return String(tile.displayChar)
        }

        // Unit display (with state color and creature type)
        if let unitId = tile.unitId, let unit = simulation.world.getUnit(id: unitId) {
            let stateColor = colorForState(unit.state)
            let char = characterForCreature(unit.creatureType)
            return "\(stateColor)\(char)\(ANSI.reset)"
        }

        // Item display
        if !tile.itemIds.isEmpty {
            return "\(ANSI.yellow)!\(ANSI.reset)"
        }

        // Terrain display
        let char = String(tile.terrain.displayChar)
        switch tile.terrain {
        case .grass:
            return "\(ANSI.green).\(ANSI.reset)"
        case .dirt:
            return "\(ANSI.yellow),\(ANSI.reset)"
        case .stone:
            return "\(ANSI.gray)_\(ANSI.reset)"
        case .water:
            return "\(ANSI.blue)~\(ANSI.reset)"
        case .tree:
            return "\(ANSI.brightGreen)T\(ANSI.reset)"
        case .shrub:
            return "\(ANSI.green)*\(ANSI.reset)"
        case .wall:
            return "\(ANSI.white)#\(ANSI.reset)"
        default:
            return char
        }
    }

    /// Returns ANSI color for a unit state
    private func colorForState(_ state: UnitState) -> String {
        switch state {
        case .idle:
            return ANSI.white
        case .moving:
            return ANSI.cyan
        case .working:
            return ANSI.yellow
        case .eating, .drinking:
            return ANSI.green
        case .sleeping:
            return ANSI.blue
        case .socializing:
            return ANSI.magenta
        case .fighting:
            return ANSI.red
        case .fleeing:
            return ANSI.brightYellow
        case .unconscious:
            return ANSI.gray
        case .dead:
            return ANSI.red
        }
    }

    /// Returns display character for creature type
    private func characterForCreature(_ type: CreatureType) -> Character {
        switch type {
        case .dwarf:
            return "@"
        case .goblin:
            return "g"
        case .wolf:
            return "w"
        case .bear:
            return "B"
        case .giant:
            return "H"
        case .undead:
            return "Z"
        }
    }

    /// Renders the unit status panel
    private func renderUnitPanel() -> String {
        var panel = "── Unit Status ────────────────────────────────────────────────────\(ANSI.clearLine)\n"

        // Separate dwarves and hostiles
        let dwarves = Array(simulation.world.units.values)
            .filter { $0.isAlive && $0.creatureType == .dwarf }
            .prefix(5)

        let hostiles = Array(simulation.world.units.values)
            .filter { $0.isAlive && $0.creatureType != .dwarf }

        for unit in dwarves {
            let name = unit.name.description.padding(toLength: 14, withPad: " ", startingAt: 0)
            let state = unit.state.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)

            // Health and mood bars
            let healthBar = healthMoodBar(value: unit.health.currentHP, max: unit.health.maxHP, label: "♥", goodColor: ANSI.green, badColor: ANSI.red)
            let moodBar = healthMoodBar(value: unit.mood.happiness, max: 100, label: "☺", goodColor: ANSI.green, badColor: ANSI.red)

            // Need bars
            let hungerBar = needBar(value: unit.hunger, max: NeedThresholds.hungerDeath, label: "H")
            let thirstBar = needBar(value: unit.thirst, max: NeedThresholds.thirstDeath, label: "T")

            let stateColor = colorForState(unit.state)
            panel += "\(name) \(stateColor)\(state)\(ANSI.reset) \(healthBar) \(moodBar) \(hungerBar) \(thirstBar)\(ANSI.clearLine)\n"
        }

        if simulation.world.units.values.filter({ $0.creatureType == .dwarf }).count > 5 {
            let extraDwarves = simulation.world.units.values.filter { $0.creatureType == .dwarf }.count - 5
            panel += "  ... and \(extraDwarves) more dwarves\(ANSI.clearLine)\n"
        }

        // Show hostiles if any
        if !hostiles.isEmpty {
            panel += "── Hostiles: \(hostiles.count) ─────\(ANSI.clearLine)\n"
            for hostile in hostiles.prefix(3) {
                let type = hostile.creatureType.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
                let hp = "\(hostile.health.currentHP)/\(hostile.health.maxHP)HP"
                panel += "  \(ANSI.red)\(type)\(ANSI.reset) \(hp)\(ANSI.clearLine)\n"
            }
        }

        return panel
    }

    /// Creates a health/mood bar visualization
    private func healthMoodBar(value: Int, max: Int, label: String, goodColor: String, badColor: String) -> String {
        let percent = max > 0 ? min(1.0, Double(value) / Double(max)) : 0.0
        let barWidth = 3
        let filled = Int(percent * Double(barWidth))

        var bar = "\(label)["
        let color = percent > 0.5 ? goodColor : (percent > 0.25 ? ANSI.yellow : badColor)

        bar += color
        bar += String(repeating: "█", count: filled)
        bar += ANSI.gray
        bar += String(repeating: "░", count: barWidth - filled)
        bar += ANSI.reset + "]"

        return bar
    }

    /// Creates a small need bar visualization
    private func needBar(value: Int, max: Int, label: String) -> String {
        let percent = min(1.0, Double(value) / Double(max))
        let barWidth = 5
        let filled = Int(percent * Double(barWidth))

        var bar = "\(label)["
        let color: String
        if percent < 0.3 {
            color = ANSI.green
        } else if percent < 0.6 {
            color = ANSI.yellow
        } else {
            color = ANSI.red
        }

        bar += color
        bar += String(repeating: "█", count: filled)
        bar += ANSI.gray
        bar += String(repeating: "░", count: barWidth - filled)
        bar += ANSI.reset + "]"

        return bar
    }

    /// Renders the recent event log
    private func renderEventLog() -> String {
        var log = "── Recent Events ──────────────────────────────────────────────────\(ANSI.clearLine)\n"

        let recentEvents = simulation.eventLog.suffix(eventHistorySize)

        if recentEvents.isEmpty {
            log += "  (no events yet)\(ANSI.clearLine)\n"
        } else {
            for event in recentEvents {
                // Pad description to consistent width to avoid artifacts
                let desc = String(event.description.prefix(64)).padding(toLength: 64, withPad: " ", startingAt: 0)
                log += "  • \(desc)\(ANSI.clearLine)\n"
            }
        }

        return log
    }

    /// Renders the legend
    private func renderLegend() -> String {
        var legend = "── Legend ─────────────────────────────────────────────────────────\(ANSI.clearLine)\n"
        legend += "  \(ANSI.white)@\(ANSI.reset)=Dwarf  "
        legend += "\(ANSI.red)g\(ANSI.reset)=Goblin  "
        legend += "\(ANSI.red)w\(ANSI.reset)=Wolf  "
        legend += "\(ANSI.yellow)!\(ANSI.reset)=Item  "
        legend += "\(ANSI.green).\(ANSI.reset)=Grass  "
        legend += "\(ANSI.brightGreen)T\(ANSI.reset)=Tree  "
        legend += "\(ANSI.blue)~\(ANSI.reset)=Water  "
        legend += "\(ANSI.gray)_\(ANSI.reset)=Stone\(ANSI.clearLine)\n"
        legend += "  States: "
        legend += "\(ANSI.white)idle\(ANSI.reset) "
        legend += "\(ANSI.cyan)moving\(ANSI.reset) "
        legend += "\(ANSI.green)eat/drink\(ANSI.reset) "
        legend += "\(ANSI.blue)sleep\(ANSI.reset) "
        legend += "\(ANSI.magenta)social\(ANSI.reset) "
        legend += "\(ANSI.red)fight\(ANSI.reset) "
        legend += "\(ANSI.brightYellow)flee\(ANSI.reset)\(ANSI.clearLine)\n"

        return legend
    }

    // MARK: - Cursor Control

    /// Hides the terminal cursor
    public func hideCursor() {
        print(ANSI.hideCursor, terminator: "")
    }

    /// Shows the terminal cursor
    public func showCursor() {
        print(ANSI.showCursor, terminator: "")
    }
}

// MARK: - Simple Runner

/// Runs the simulation in watch mode
@MainActor
public func runWatchSimulation(
    worldWidth: Int = 50,
    worldHeight: Int = 20,
    unitCount: Int = 8,
    ticksPerSecond: Double = 5.0,
    maxTicks: Int? = nil
) async {
    // Create simulation
    let simulation = Simulation(worldWidth: worldWidth, worldHeight: worldHeight)

    // Spawn units and resources
    simulation.spawnUnits(count: unitCount)
    simulation.spawnResources(foodCount: 15, drinkCount: 15, bedCount: 5)

    // Create renderer
    let renderer = Renderer(simulation: simulation)

    // Calculate tick interval
    let tickInterval = 1.0 / ticksPerSecond

    // Hide cursor and clear screen
    renderer.hideCursor()
    renderer.clearScreen()

    var tickCount = 0

    // Main loop
    while maxTicks == nil || tickCount < maxTicks! {
        // Process simulation tick
        simulation.tick()
        tickCount += 1

        // Render
        renderer.render()

        // Wait for next tick
        try? await Task.sleep(nanoseconds: UInt64(tickInterval * 1_000_000_000))
    }

    // Show cursor when done
    renderer.showCursor()
}
