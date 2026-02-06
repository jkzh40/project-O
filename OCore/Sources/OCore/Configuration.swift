// MARK: - Configuration
// Codable structs for YAML-based configuration

import Foundation

// MARK: - Root Configuration

/// Root configuration that encompasses all config sections
public struct OutpostConfig: Codable, Sendable {
    public var simulation: SimulationConfig
    public var events: EventsConfig
    public var creatures: [String: CreatureDefinition]
    public var hostileSpawnPool: [String]
    public var items: [String: ItemDefinition]

    public init(
        simulation: SimulationConfig = SimulationConfig(),
        events: EventsConfig = EventsConfig(),
        creatures: [String: CreatureDefinition] = [:],
        hostileSpawnPool: [String] = ["goblin", "wolf"],
        items: [String: ItemDefinition] = [:]
    ) {
        self.simulation = simulation
        self.events = events
        self.creatures = creatures
        self.hostileSpawnPool = hostileSpawnPool
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case simulation
        case events
        case creatures
        case hostileSpawnPool = "hostile_spawn_pool"
        case items
    }

    // Custom Decodable to handle missing keys with defaults
    // (outpost.yaml doesn't have creatures/items sections)
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.simulation = try container.decodeIfPresent(SimulationConfig.self, forKey: .simulation) ?? SimulationConfig()
        self.events = try container.decodeIfPresent(EventsConfig.self, forKey: .events) ?? EventsConfig()
        self.creatures = try container.decodeIfPresent([String: CreatureDefinition].self, forKey: .creatures) ?? [:]
        self.hostileSpawnPool = try container.decodeIfPresent([String].self, forKey: .hostileSpawnPool) ?? ["goblin", "wolf"]
        self.items = try container.decodeIfPresent([String: ItemDefinition].self, forKey: .items) ?? [:]
    }
}

// MARK: - Simulation Config

/// Configuration for simulation settings
public struct SimulationConfig: Codable, Sendable {
    public var world: WorldConfig
    public var units: UnitsConfig
    public var resources: ResourcesConfig
    public var speed: SpeedConfig
    public var difficulty: DifficultyConfig

    public init(
        world: WorldConfig = WorldConfig(),
        units: UnitsConfig = UnitsConfig(),
        resources: ResourcesConfig = ResourcesConfig(),
        speed: SpeedConfig = SpeedConfig(),
        difficulty: DifficultyConfig = DifficultyConfig()
    ) {
        self.world = world
        self.units = units
        self.resources = resources
        self.speed = speed
        self.difficulty = difficulty
    }

    public static var `default`: SimulationConfig {
        SimulationConfig()
    }
}

/// World dimensions configuration
public struct WorldConfig: Codable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int = 50, height: Int = 20) {
        self.width = width
        self.height = height
    }
}

/// Unit configuration
public struct UnitsConfig: Codable, Sendable {
    public var initialCount: Int
    public var maxPopulation: Int

    public init(initialCount: Int = 8, maxPopulation: Int = 50) {
        self.initialCount = initialCount
        self.maxPopulation = maxPopulation
    }

    enum CodingKeys: String, CodingKey {
        case initialCount = "initial_count"
        case maxPopulation = "max_population"
    }
}

/// Starting resources configuration
public struct ResourcesConfig: Codable, Sendable {
    public var foodCount: Int
    public var drinkCount: Int
    public var bedCount: Int

    public init(foodCount: Int = 15, drinkCount: Int = 15, bedCount: Int = 5) {
        self.foodCount = foodCount
        self.drinkCount = drinkCount
        self.bedCount = bedCount
    }

    enum CodingKeys: String, CodingKey {
        case foodCount = "food_count"
        case drinkCount = "drink_count"
        case bedCount = "bed_count"
    }
}

/// Simulation speed configuration
public struct SpeedConfig: Codable, Sendable {
    public var ticksPerSecond: Double

    public init(ticksPerSecond: Double = 5.0) {
        self.ticksPerSecond = ticksPerSecond
    }

    enum CodingKeys: String, CodingKey {
        case ticksPerSecond = "ticks_per_second"
    }
}

/// Difficulty configuration
public struct DifficultyConfig: Codable, Sendable {
    public var hardMode: Bool

    public init(hardMode: Bool = false) {
        self.hardMode = hardMode
    }

    enum CodingKeys: String, CodingKey {
        case hardMode = "hard_mode"
    }
}

// MARK: - Events Config

/// Configuration for simulation events
public struct EventsConfig: Codable, Sendable {
    public var hostileSpawn: HostileSpawnConfig
    public var migrantWave: MigrantWaveConfig
    public var birthCheck: BirthCheckConfig

    public init(
        hostileSpawn: HostileSpawnConfig = HostileSpawnConfig(),
        migrantWave: MigrantWaveConfig = MigrantWaveConfig(),
        birthCheck: BirthCheckConfig = BirthCheckConfig()
    ) {
        self.hostileSpawn = hostileSpawn
        self.migrantWave = migrantWave
        self.birthCheck = birthCheck
    }

    enum CodingKeys: String, CodingKey {
        case hostileSpawn = "hostile_spawn"
        case migrantWave = "migrant_wave"
        case birthCheck = "birth_check"
    }

    public static var `default`: EventsConfig {
        EventsConfig()
    }
}

/// Hostile creature spawn configuration
public struct HostileSpawnConfig: Codable, Sendable {
    public var intervalTicks: Int
    public var chancePercent: Int

    public init(intervalTicks: Int = 500, chancePercent: Int = 50) {
        self.intervalTicks = intervalTicks
        self.chancePercent = chancePercent
    }

    enum CodingKeys: String, CodingKey {
        case intervalTicks = "interval_ticks"
        case chancePercent = "chance_percent"
    }
}

/// Migrant wave configuration
public struct MigrantWaveConfig: Codable, Sendable {
    public var intervalTicks: Int

    public init(intervalTicks: Int = 10000) {
        self.intervalTicks = intervalTicks
    }

    enum CodingKeys: String, CodingKey {
        case intervalTicks = "interval_ticks"
    }
}

/// Birth check configuration
public struct BirthCheckConfig: Codable, Sendable {
    public var intervalTicks: Int
    public var chancePercent: Int

    public init(intervalTicks: Int = 5000, chancePercent: Int = 5) {
        self.intervalTicks = intervalTicks
        self.chancePercent = chancePercent
    }

    enum CodingKeys: String, CodingKey {
        case intervalTicks = "interval_ticks"
        case chancePercent = "chance_percent"
    }
}

// MARK: - Creature Definition

/// Definition for a creature type
public struct CreatureDefinition: Codable, Sendable {
    public var displayChar: String
    public var baseHP: Int
    public var baseDamage: Int
    public var hostileToOrcs: Bool
    public var weapon: String?
    public var damageType: String?
    public var lootOnDeath: [LootDefinition]?

    public init(
        displayChar: String,
        baseHP: Int,
        baseDamage: Int,
        hostileToOrcs: Bool,
        weapon: String? = nil,
        damageType: String? = nil,
        lootOnDeath: [LootDefinition]? = nil
    ) {
        self.displayChar = displayChar
        self.baseHP = baseHP
        self.baseDamage = baseDamage
        self.hostileToOrcs = hostileToOrcs
        self.weapon = weapon
        self.damageType = damageType
        self.lootOnDeath = lootOnDeath
    }

    enum CodingKeys: String, CodingKey {
        case displayChar = "display_char"
        case baseHP = "base_hp"
        case baseDamage = "base_damage"
        case hostileToOrcs = "hostile_to_orcs"
        case weapon
        case damageType = "damage_type"
        case lootOnDeath = "loot_on_death"
    }

}

/// Loot dropped on creature death
public struct LootDefinition: Codable, Sendable {
    public var item: String
    public var quantityMin: Int
    public var quantityMax: Int

    public init(item: String, quantityMin: Int, quantityMax: Int) {
        self.item = item
        self.quantityMin = quantityMin
        self.quantityMax = quantityMax
    }

    enum CodingKeys: String, CodingKey {
        case item
        case quantityMin = "quantity_min"
        case quantityMax = "quantity_max"
    }
}

// MARK: - Item Definition

/// Definition for an item type
public struct ItemDefinition: Codable, Sendable {
    public var category: String
    public var baseValue: Int
    public var stackable: Bool

    public init(category: String, baseValue: Int, stackable: Bool) {
        self.category = category
        self.baseValue = baseValue
        self.stackable = stackable
    }

    enum CodingKeys: String, CodingKey {
        case category
        case baseValue = "base_value"
        case stackable
    }

}
