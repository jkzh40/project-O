// MARK: - Creature Registry
// Runtime lookup for creature definitions with fallback to defaults

import Foundation

// MARK: - Creature Registry

/// Manages creature definitions loaded from configuration
@MainActor
public final class CreatureRegistry: Sendable {

    /// Shared instance for global access
    public static let shared = CreatureRegistry()

    /// Creature definitions loaded from config
    private var definitions: [String: CreatureDefinition] = [:]

    /// Hostile spawn pool (creature names that can spawn as hostiles)
    private var spawnPool: [String] = []

    /// Whether the registry has been initialized with config
    private var isInitialized: Bool = false

    private init() {
        // Start empty - will be populated via initialize(with:)
        self.definitions = [:]
        self.spawnPool = ["goblin", "wolf"]
    }

    // MARK: - Initialization

    /// Initialize the registry with configuration (config already has bundled YAML loaded)
    public func initialize(with config: OutpostConfig) {
        // Config already contains merged bundled + user creatures from ConfigurationLoader
        self.definitions = config.creatures

        // Set spawn pool from config
        if !config.hostileSpawnPool.isEmpty {
            self.spawnPool = config.hostileSpawnPool
        }

        self.isInitialized = true
    }

    /// Reset to empty definitions (rely on hardcoded fallbacks)
    public func reset() {
        self.definitions = [:]
        self.spawnPool = ["goblin", "wolf"]
        self.isInitialized = false
    }

    // MARK: - Lookup Methods

    /// Get creature definition by name
    public func getDefinition(for name: String) -> CreatureDefinition? {
        definitions[name.lowercased()]
    }

    /// Get creature definition by CreatureType enum
    public func getDefinition(for type: CreatureType) -> CreatureDefinition? {
        definitions[type.rawValue]
    }

    /// Get base HP for a creature type
    public func baseHP(for type: CreatureType) -> Int {
        definitions[type.rawValue]?.baseHP ?? type.hardcodedBaseHP
    }

    /// Get base damage for a creature type
    public func baseDamage(for type: CreatureType) -> Int {
        definitions[type.rawValue]?.baseDamage ?? type.hardcodedBaseDamage
    }

    /// Get display character for a creature type
    public func displayChar(for type: CreatureType) -> Character {
        if let def = definitions[type.rawValue], !def.displayChar.isEmpty {
            return def.displayChar.first ?? type.hardcodedDisplayChar
        }
        return type.hardcodedDisplayChar
    }

    /// Check if a creature type is hostile to orcs
    public func isHostileToOrcs(_ type: CreatureType) -> Bool {
        definitions[type.rawValue]?.hostileToOrcs ?? type.hardcodedHostileToOrcs
    }

    /// Get weapon name for a creature type
    public func weapon(for type: CreatureType) -> String? {
        definitions[type.rawValue]?.weapon
    }

    /// Get damage type for a creature type
    public func damageType(for type: CreatureType) -> String? {
        definitions[type.rawValue]?.damageType
    }

    /// Get loot definitions for a creature type
    public func lootOnDeath(for type: CreatureType) -> [LootDefinition]? {
        definitions[type.rawValue]?.lootOnDeath
    }

    // MARK: - Spawn Pool

    /// Get the hostile spawn pool as creature type names
    public var hostileSpawnPool: [String] {
        spawnPool
    }

    /// Get a random creature type from the spawn pool
    public func randomHostileType() -> CreatureType? {
        guard let name = spawnPool.randomElement() else { return nil }
        return CreatureType(rawValue: name)
    }

    /// Get all creature types in the spawn pool
    public func hostileCreatureTypes() -> [CreatureType] {
        spawnPool.compactMap { CreatureType(rawValue: $0) }
    }

    // MARK: - Registration

    /// Register a custom creature definition
    public func register(name: String, definition: CreatureDefinition) {
        definitions[name.lowercased()] = definition
    }

    /// Add a creature to the hostile spawn pool
    public func addToSpawnPool(_ name: String) {
        if !spawnPool.contains(name.lowercased()) {
            spawnPool.append(name.lowercased())
        }
    }

    /// Remove a creature from the hostile spawn pool
    public func removeFromSpawnPool(_ name: String) {
        spawnPool.removeAll { $0 == name.lowercased() }
    }

    /// Set the entire spawn pool
    public func setSpawnPool(_ pool: [String]) {
        spawnPool = pool.map { $0.lowercased() }
    }

    // MARK: - Info

    /// Get all registered creature names
    public var registeredCreatures: [String] {
        Array(definitions.keys).sorted()
    }

    /// Check if a creature is registered
    public func isRegistered(_ name: String) -> Bool {
        definitions[name.lowercased()] != nil
    }
}

// MARK: - CreatureType Hardcoded Fallbacks

extension CreatureType {
    /// Hardcoded base HP (fallback when registry has no definition)
    var hardcodedBaseHP: Int {
        switch self {
        case .orc: return 100
        case .goblin: return 60
        case .wolf: return 40
        case .bear: return 150
        case .giant: return 300
        case .undead: return 50
        }
    }

    /// Hardcoded base damage (fallback when registry has no definition)
    var hardcodedBaseDamage: Int {
        switch self {
        case .orc: return 10
        case .goblin: return 8
        case .wolf: return 12
        case .bear: return 25
        case .giant: return 40
        case .undead: return 8
        }
    }

    /// Hardcoded display character (fallback when registry has no definition)
    var hardcodedDisplayChar: Character {
        switch self {
        case .orc: return "@"
        case .goblin: return "g"
        case .wolf: return "w"
        case .bear: return "B"
        case .giant: return "G"
        case .undead: return "z"
        }
    }

    /// Hardcoded hostile flag (fallback when registry has no definition)
    var hardcodedHostileToOrcs: Bool {
        switch self {
        case .orc: return false
        case .goblin, .wolf, .bear, .giant, .undead: return true
        }
    }
}
