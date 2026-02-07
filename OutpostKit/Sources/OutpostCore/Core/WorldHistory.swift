// MARK: - History System
// Historical events, figures, and civilizations for world generation

import Foundation

// MARK: - World Generation Phase

/// Phases of world generation
public enum WorldGenPhase: String, Sendable {
    case creation = "Creating World"
    case tectonics = "Simulating Tectonics"
    case heightmap = "Generating Heightmap"
    case erosion = "Simulating Erosion"
    case strata = "Generating Strata"
    case climate = "Simulating Climate"
    case hydrology = "Tracing Rivers"
    case biomes = "Classifying Biomes"
    case detailPass = "Adding Detail"
    case embark = "Selecting Embark Site"
    case terrain = "Shaping Terrain"
    case regions = "Defining Regions"
    case civilizations = "Founding Civilizations"
    case history = "Simulating History"
    case complete = "Generation Complete"
}

// MARK: - Historical Figure

/// A notable figure in world history
public struct HistoricalFigure: Sendable, Identifiable {
    public let id: UInt64
    public var name: UnitName
    public var birthYear: Int
    public var deathYear: Int?
    public var civilizationId: UInt64?
    public var title: String?
    public var notableDeeds: [String]

    public var isAlive: Bool { deathYear == nil }

    public var age: Int? {
        guard let death = deathYear else { return nil }
        return death - birthYear
    }

    public init(id: UInt64, name: UnitName, birthYear: Int, civilizationId: UInt64? = nil) {
        self.id = id
        self.name = name
        self.birthYear = birthYear
        self.deathYear = nil
        self.civilizationId = civilizationId
        self.title = nil
        self.notableDeeds = []
    }
}

// MARK: - Civilization

/// A civilization in the world
public struct Civilization: Sendable, Identifiable {
    public let id: UInt64
    public var name: String
    public var foundingYear: Int
    public var fallYear: Int?
    public var population: Int
    public var territories: [String]  // Region names
    public var leader: UInt64?  // HistoricalFigure ID
    public var traits: [CivilizationTrait]
    public var relations: [UInt64: CivRelation]  // Other civ ID -> relation

    public var isActive: Bool { fallYear == nil && population > 0 }

    public init(id: UInt64, name: String, foundingYear: Int) {
        self.id = id
        self.name = name
        self.foundingYear = foundingYear
        self.fallYear = nil
        self.population = 100
        self.territories = []
        self.leader = nil
        self.traits = []
        self.relations = [:]
    }
}

/// Traits that define a civilization's character
public enum CivilizationTrait: String, CaseIterable, Sendable {
    case warlike = "warlike"
    case peaceful = "peaceful"
    case traders = "traders"
    case isolationist = "isolationist"
    case expansionist = "expansionist"
    case scholarly = "scholarly"
    case artistic = "artistic"
    case industrious = "industrious"
}

/// Relationship between civilizations
public enum CivRelation: String, Sendable {
    case allied = "allied"
    case friendly = "friendly"
    case neutral = "neutral"
    case tense = "tense"
    case hostile = "hostile"
    case atWar = "at war"
}

// MARK: - Historical Event

/// An event that occurred in world history
public struct HistoricalEvent: Sendable, Identifiable {
    public let id: UInt64
    public let year: Int
    public let eventType: HistoricalEventType
    public let description: String
    public let involvedFigures: [UInt64]
    public let involvedCivs: [UInt64]

    public init(
        id: UInt64,
        year: Int,
        eventType: HistoricalEventType,
        description: String,
        involvedFigures: [UInt64] = [],
        involvedCivs: [UInt64] = []
    ) {
        self.id = id
        self.year = year
        self.eventType = eventType
        self.description = description
        self.involvedFigures = involvedFigures
        self.involvedCivs = involvedCivs
    }
}

/// Types of historical events
public enum HistoricalEventType: String, CaseIterable, Sendable {
    // World events
    case worldCreated = "world created"
    case continentFormed = "continent formed"
    case mountainRaised = "mountain raised"
    case riverCarved = "river carved"
    case forestGrew = "forest grew"

    // Civilization events
    case civFounded = "civilization founded"
    case civExpanded = "territory claimed"
    case civFell = "civilization fell"
    case cityFounded = "city founded"
    case cityDestroyed = "city destroyed"

    // Political events
    case leaderRose = "leader rose to power"
    case leaderDied = "leader died"
    case allianceFormed = "alliance formed"
    case warDeclared = "war declared"
    case warEnded = "war ended"
    case treatySigned = "treaty signed"

    // Figure events
    case figureBorn = "notable birth"
    case figureDied = "notable death"
    case heroicDeed = "heroic deed"
    case artifactCreated = "artifact created"
    case discovery = "discovery made"
    case betrayal = "betrayal"

    // Disasters
    case plague = "plague"
    case famine = "famine"
    case naturalDisaster = "natural disaster"
    case monsterAttack = "monster attack"
}

// MARK: - World History

/// Container for all historical data
public struct WorldHistory: Sendable {
    public var worldName: String
    public var creationYear: Int
    public var currentYear: Int
    public var events: [HistoricalEvent]
    public var figures: [UInt64: HistoricalFigure]
    public var civilizations: [UInt64: Civilization]
    public var regions: [String]
    public var artifacts: [String]

    public init(worldName: String) {
        self.worldName = worldName
        self.creationYear = 0
        self.currentYear = 0
        self.events = []
        self.figures = [:]
        self.civilizations = [:]
        self.regions = []
        self.artifacts = []
    }

    public var activeCivilizations: [Civilization] {
        civilizations.values.filter { $0.isActive }
    }

    public var livingFigures: [HistoricalFigure] {
        figures.values.filter { $0.isAlive }
    }
}

// MARK: - Name Generators

public enum WorldNameGenerator {
    private static let prefixes = [
        "The Realm of", "The Land of", "The Kingdom of", "The World of",
        "The Domain of", "The Empire of", "The Valleys of", "The Mountains of"
    ]

    private static let names = [
        "Eternal Shadows", "Golden Dawn", "Crimson Peaks", "Silver Mists",
        "Ancient Stones", "Whispering Winds", "Frozen Hearts", "Burning Sands",
        "Emerald Depths", "Obsidian Nights", "Crystal Waters", "Iron Will",
        "Sacred Oaths", "Forgotten Dreams", "Rising Stars", "Fallen Kings"
    ]

    public static func generate() -> String {
        let prefix = prefixes.randomElement()!
        let name = names.randomElement()!
        return "\(prefix) \(name)"
    }
}

public enum CivilizationNameGenerator {
    private static let prefixes = [
        "The", "Great", "Ancient", "Noble", "United", "Free", "Sacred", "Eternal"
    ]

    private static let roots = [
        "Mountain", "River", "Forest", "Stone", "Iron", "Gold", "Silver", "Crystal",
        "Storm", "Sun", "Moon", "Star", "Shadow", "Light", "Fire", "Ice"
    ]

    private static let suffixes = [
        "Kingdom", "Empire", "Dominion", "Confederacy", "Alliance", "Realm",
        "Holdings", "Clans", "Tribes", "Federation", "Commonwealth", "League"
    ]

    public static func generate() -> String {
        let usePrefix = Bool.random()
        let prefix = usePrefix ? "\(prefixes.randomElement()!) " : ""
        let root = roots.randomElement()!
        let suffix = suffixes.randomElement()!
        return "\(prefix)\(root) \(suffix)"
    }
}

public enum RegionNameGenerator {
    private static let adjectives = [
        "Northern", "Southern", "Eastern", "Western", "Central", "Upper", "Lower",
        "Greater", "Lesser", "Old", "New", "Dark", "Bright", "Wild", "Peaceful"
    ]

    private static let terrains = [
        "Plains", "Mountains", "Valleys", "Forests", "Marshes", "Highlands",
        "Lowlands", "Steppes", "Tundra", "Desert", "Coast", "Islands", "Hills"
    ]

    public static func generate() -> String {
        let adj = adjectives.randomElement()!
        let terrain = terrains.randomElement()!
        return "\(adj) \(terrain)"
    }
}

public enum ArtifactNameGenerator {
    private static let prefixes = [
        "The", "Ancient", "Legendary", "Cursed", "Blessed", "Lost", "Sacred"
    ]

    private static let items = [
        "Sword", "Crown", "Scepter", "Amulet", "Ring", "Tome", "Staff",
        "Shield", "Helm", "Gauntlet", "Chalice", "Orb", "Hammer", "Axe"
    ]

    private static let suffixes = [
        "of Power", "of Wisdom", "of Kings", "of Shadows", "of Light",
        "of the Ancients", "of Doom", "of Hope", "of Destiny", "of Truth"
    ]

    public static func generate() -> String {
        let prefix = prefixes.randomElement()!
        let item = items.randomElement()!
        let suffix = suffixes.randomElement()!
        return "\(prefix) \(item) \(suffix)"
    }
}
