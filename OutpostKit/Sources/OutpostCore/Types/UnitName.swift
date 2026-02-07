// MARK: - Name

import Foundation

/// A unit's name with optional components
public struct UnitName: Sendable, CustomStringConvertible {
    public var firstName: String
    public var nickname: String?
    public var lastName: String?

    public init(firstName: String, nickname: String? = nil, lastName: String? = nil) {
        self.firstName = firstName
        self.nickname = nickname
        self.lastName = lastName
    }

    public var description: String {
        if let nick = nickname {
            return "\"\(nick)\" \(firstName)"
        }
        return firstName
    }

    public var fullName: String {
        var parts = [firstName]
        if let last = lastName {
            parts.append(last)
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Random Name Generator

public enum NameGenerator {
    private static let firstNames = [
        "Urist", "Doren", "Morul", "Lokum", "Kadol", "Etur", "Mafol", "Rigoth",
        "Zuntir", "Ablel", "Bomrek", "Cerol", "Dastot", "Erith", "Fikod", "Goden",
        "Ingish", "Kogan", "Led", "Mistem", "Nil", "Onol", "Reg", "Shem", "Tosid",
        "Udib", "Vabok", "Zulban", "Asmel", "Bembul", "Catten", "Deduk", "Edem"
    ]

    private static let lastNames = [
        "Metaltreasure", "Copperguild", "Ironaxe", "Silvervein", "Goldenshield",
        "Bronzepick", "Steelhammer", "Dirtyfist", "Cleanstone", "Oldgranite",
        "Youngrock", "Deepforge", "Tallhelm", "Shortbeard", "Longaxe", "Quickpick",
        "Slowbrew", "Strongale", "Wildmountain", "Calmriver", "Brightgem"
    ]

    public static func generate() -> UnitName {
        let firstName = firstNames.randomElement()!
        let lastName = lastNames.randomElement()!
        return UnitName(firstName: firstName, lastName: lastName)
    }
}
