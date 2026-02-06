// MARK: - Shared ANSI Escape Codes
// Common terminal escape codes used by all renderers

import Foundation

/// ANSI escape codes for terminal rendering
enum ANSI {
    // Control
    static let reset = "\u{001B}[0m"
    static let clear = "\u{001B}[2J"
    static let home = "\u{001B}[H"
    static let clearLine = "\u{001B}[K"
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

    // Styles
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
}
