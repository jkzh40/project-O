// MARK: - World Generation Renderer
// Displays the world generation process in the terminal

import Foundation
import OCore

/// Renders world generation progress to the terminal
@MainActor
public final class WorldGenRenderer: Sendable {
    /// Maximum lines of history to show
    public var maxHistoryLines: Int = 20

    /// Recent messages
    private var recentMessages: [String] = []

    /// Current phase
    private var currentPhase: WorldGenPhase = .creation

    /// World name
    private var worldName: String = ""

    /// Statistics
    private var stats: GenStats = GenStats()

    private struct GenStats {
        var year: Int = 0
        var events: Int = 0
        var civilizations: Int = 0
        var figures: Int = 0
        var regions: Int = 0
        var artifacts: Int = 0
    }

    public init() {}

    // MARK: - Rendering

    /// Clears the screen
    public func clearScreen() {
        print(ANSI.clear + ANSI.home, terminator: "")
    }

    /// Hides the cursor
    public func hideCursor() {
        print(ANSI.hideCursor, terminator: "")
    }

    /// Shows the cursor
    public func showCursor() {
        print(ANSI.showCursor, terminator: "")
    }

    /// Updates with new progress
    public func update(phase: WorldGenPhase, message: String, history: WorldHistory) {
        currentPhase = phase
        worldName = history.worldName
        stats.year = history.currentYear
        stats.events = history.events.count
        stats.civilizations = history.civilizations.count
        stats.figures = history.figures.count
        stats.regions = history.regions.count
        stats.artifacts = history.artifacts.count

        // Add message to history
        recentMessages.append(message)
        while recentMessages.count > maxHistoryLines {
            recentMessages.removeFirst()
        }

        render()
    }

    /// Renders the current state
    private func render() {
        var output = ""

        // Header
        output += renderHeader()

        // Phase indicator
        output += renderPhaseIndicator()

        // Stats panel
        output += renderStats()

        // Event log
        output += renderEventLog()

        // Progress bar
        output += renderProgressBar()

        // Output
        print(ANSI.home + output, terminator: "")
        fflush(stdout)
    }

    private func renderHeader() -> String {
        var header = "\n"
        header += "  \(ANSI.bold)\(ANSI.cyan)╔══════════════════════════════════════════════════════════════════════╗\(ANSI.reset)\n"
        header += "  \(ANSI.bold)\(ANSI.cyan)║\(ANSI.reset)  \(ANSI.brightYellow)⚒\(ANSI.reset)  \(ANSI.bold)WORLD GENERATION\(ANSI.reset)                                              \(ANSI.bold)\(ANSI.cyan)║\(ANSI.reset)\n"

        let nameDisplay = worldName.isEmpty ? "..." : worldName
        let paddedName = nameDisplay.padding(toLength: 50, withPad: " ", startingAt: 0)
        header += "  \(ANSI.bold)\(ANSI.cyan)║\(ANSI.reset)  \(ANSI.white)\(paddedName)\(ANSI.reset)            \(ANSI.bold)\(ANSI.cyan)║\(ANSI.reset)\n"

        header += "  \(ANSI.bold)\(ANSI.cyan)╚══════════════════════════════════════════════════════════════════════╝\(ANSI.reset)\n"
        return header
    }

    private func renderPhaseIndicator() -> String {
        var indicator = "\n"

        let phases: [(WorldGenPhase, String)] = [
            (.creation, "Creation"),
            (.terrain, "Terrain"),
            (.regions, "Regions"),
            (.civilizations, "Civs"),
            (.history, "History"),
            (.complete, "Done")
        ]

        indicator += "  "
        for (phase, name) in phases {
            let isCurrent = phase == currentPhase
            let isPast = phaseOrder(phase) < phaseOrder(currentPhase)

            if isCurrent {
                indicator += "\(ANSI.brightGreen)[\(name)]\(ANSI.reset)"
            } else if isPast {
                indicator += "\(ANSI.green)\(name)\(ANSI.reset)"
            } else {
                indicator += "\(ANSI.gray)\(name)\(ANSI.reset)"
            }

            if phase != .complete {
                indicator += "\(ANSI.gray) → \(ANSI.reset)"
            }
        }
        indicator += "\n"

        return indicator
    }

    private func phaseOrder(_ phase: WorldGenPhase) -> Int {
        switch phase {
        case .creation: return 0
        case .tectonics: return 1
        case .heightmap: return 2
        case .erosion: return 3
        case .climate: return 4
        case .hydrology: return 5
        case .biomes: return 6
        case .detailPass: return 7
        case .terrain: return 8
        case .embark: return 9
        case .regions: return 10
        case .civilizations: return 11
        case .history: return 12
        case .complete: return 13
        }
    }

    private func renderStats() -> String {
        var panel = "\n"
        panel += "  \(ANSI.cyan)┌─ Statistics ─────────────────────────────────────────────────────────┐\(ANSI.reset)\n"

        let col1 = "Year: \(ANSI.yellow)\(String(format: "%5d", stats.year))\(ANSI.reset)"
        let col2 = "Events: \(ANSI.yellow)\(String(format: "%4d", stats.events))\(ANSI.reset)"
        let col3 = "Civs: \(ANSI.yellow)\(stats.civilizations)\(ANSI.reset)"
        let col4 = "Figures: \(ANSI.yellow)\(stats.figures)\(ANSI.reset)"

        panel += "  \(ANSI.cyan)│\(ANSI.reset)  \(col1)   \(col2)   \(col3)   \(col4)                      \(ANSI.cyan)│\(ANSI.reset)\n"

        let col5 = "Regions: \(ANSI.green)\(stats.regions)\(ANSI.reset)"
        let col6 = "Artifacts: \(ANSI.magenta)\(stats.artifacts)\(ANSI.reset)"

        panel += "  \(ANSI.cyan)│\(ANSI.reset)  \(col5)   \(col6)                                              \(ANSI.cyan)│\(ANSI.reset)\n"
        panel += "  \(ANSI.cyan)└──────────────────────────────────────────────────────────────────────┘\(ANSI.reset)\n"

        return panel
    }

    private func renderEventLog() -> String {
        var log = "\n"
        log += "  \(ANSI.cyan)┌─ Chronicle ──────────────────────────────────────────────────────────┐\(ANSI.reset)\n"

        // Show recent messages
        let displayMessages = recentMessages.suffix(12)
        for message in displayMessages {
            let coloredMessage = colorizeMessage(message)
            let truncated = String(coloredMessage.prefix(68))
            log += "  \(ANSI.cyan)│\(ANSI.reset)  \(truncated)\n"
        }

        // Pad remaining lines
        let remaining = 12 - displayMessages.count
        for _ in 0..<remaining {
            log += "  \(ANSI.cyan)│\(ANSI.reset)\n"
        }

        log += "  \(ANSI.cyan)└──────────────────────────────────────────────────────────────────────┘\(ANSI.reset)\n"

        return log
    }

    private func colorizeMessage(_ message: String) -> String {
        var colored = message

        // Highlight years
        if let range = message.range(of: "Year \\d+", options: .regularExpression) {
            let year = message[range]
            colored = colored.replacingCharacters(in: range, with: "\(ANSI.yellow)\(year)\(ANSI.reset)")
        }

        // Highlight important events
        if message.contains("WAR") {
            colored = "\(ANSI.red)\(colored)\(ANSI.reset)"
        } else if message.contains("alliance") || message.contains("treaty") {
            colored = "\(ANSI.green)\(colored)\(ANSI.reset)"
        } else if message.contains("died") || message.contains("perished") {
            colored = "\(ANSI.gray)\(colored)\(ANSI.reset)"
        } else if message.contains("created") || message.contains("artifact") {
            colored = "\(ANSI.magenta)\(colored)\(ANSI.reset)"
        } else if message.contains("founded") || message.contains("rose") {
            colored = "\(ANSI.brightCyan)\(colored)\(ANSI.reset)"
        } else if message.contains("═══") {
            colored = "\(ANSI.brightYellow)\(colored)\(ANSI.reset)"
        }

        return colored
    }

    private func renderProgressBar() -> String {
        var bar = "\n"

        let progress: Double
        switch currentPhase {
        case .creation: progress = 0.05
        case .tectonics: progress = 0.08
        case .heightmap: progress = 0.11
        case .erosion: progress = 0.14
        case .climate: progress = 0.17
        case .hydrology: progress = 0.20
        case .biomes: progress = 0.23
        case .detailPass: progress = 0.26
        case .terrain: progress = 0.29
        case .embark: progress = 0.32
        case .regions: progress = 0.35
        case .civilizations: progress = 0.40
        case .history:
            // Calculate based on year progress (assuming 250 years)
            progress = 0.4 + 0.6 * min(1.0, Double(stats.year) / 250.0)
        case .complete: progress = 1.0
        }

        let barWidth = 60
        let filled = Int(progress * Double(barWidth))
        let empty = barWidth - filled

        bar += "  \(ANSI.gray)Progress: \(ANSI.reset)"
        bar += "\(ANSI.green)"
        bar += String(repeating: "█", count: filled)
        bar += "\(ANSI.gray)"
        bar += String(repeating: "░", count: empty)
        bar += "\(ANSI.reset)"
        bar += " \(Int(progress * 100))%\n"

        return bar
    }

    // MARK: - Summary

    /// Renders a final summary of the generated world
    public func renderSummary(history: WorldHistory) {
        clearScreen()

        var output = "\n"
        output += "  \(ANSI.bold)\(ANSI.brightGreen)╔══════════════════════════════════════════════════════════════════════╗\(ANSI.reset)\n"
        output += "  \(ANSI.bold)\(ANSI.brightGreen)║\(ANSI.reset)  \(ANSI.bold)WORLD GENERATION COMPLETE\(ANSI.reset)                                        \(ANSI.bold)\(ANSI.brightGreen)║\(ANSI.reset)\n"
        output += "  \(ANSI.bold)\(ANSI.brightGreen)╚══════════════════════════════════════════════════════════════════════╝\(ANSI.reset)\n\n"

        output += "  \(ANSI.bold)\(ANSI.white)\(history.worldName)\(ANSI.reset)\n\n"

        output += "  \(ANSI.cyan)History:\(ANSI.reset) \(history.currentYear) years\n"
        output += "  \(ANSI.cyan)Events:\(ANSI.reset) \(history.events.count) recorded\n"
        output += "  \(ANSI.cyan)Civilizations:\(ANSI.reset) \(history.civilizations.count) founded"
        let active = history.activeCivilizations.count
        output += " (\(active) active)\n"
        output += "  \(ANSI.cyan)Notable Figures:\(ANSI.reset) \(history.figures.count)"
        let living = history.livingFigures.count
        output += " (\(living) living)\n"
        output += "  \(ANSI.cyan)Regions:\(ANSI.reset) \(history.regions.count)\n"
        output += "  \(ANSI.cyan)Artifacts:\(ANSI.reset) \(history.artifacts.count)\n\n"

        // List civilizations
        output += "  \(ANSI.bold)Civilizations:\(ANSI.reset)\n"
        for civ in history.civilizations.values.sorted(by: { $0.foundingYear < $1.foundingYear }) {
            let status = civ.isActive ? "\(ANSI.green)●\(ANSI.reset)" : "\(ANSI.red)○\(ANSI.reset)"
            let traits = civ.traits.map { $0.rawValue }.joined(separator: ", ")
            output += "  \(status) \(civ.name) (founded \(civ.foundingYear))"
            if !traits.isEmpty {
                output += " - \(ANSI.gray)\(traits)\(ANSI.reset)"
            }
            output += "\n"
        }

        // List artifacts
        if !history.artifacts.isEmpty {
            output += "\n  \(ANSI.bold)Legendary Artifacts:\(ANSI.reset)\n"
            for artifact in history.artifacts.prefix(10) {
                output += "  \(ANSI.magenta)★\(ANSI.reset) \(artifact)\n"
            }
            if history.artifacts.count > 10 {
                output += "  \(ANSI.gray)... and \(history.artifacts.count - 10) more\(ANSI.reset)\n"
            }
        }

        output += "\n  \(ANSI.gray)Press Enter to continue to simulation...\(ANSI.reset)\n"

        print(output)
    }
}
