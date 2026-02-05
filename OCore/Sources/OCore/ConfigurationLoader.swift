// MARK: - Configuration Loader
// Handles loading and parsing YAML configuration files

import Foundation
import Yams

// MARK: - Configuration Loader

/// Loads configuration from YAML files with fallback to bundled defaults
public struct ConfigurationLoader: Sendable {

    /// Search paths for user configuration files (in order of priority)
    public static let userConfigPaths: [String] = {
        var paths: [String] = []

        // 1. Current directory
        paths.append("./dwarfsim.yaml")

        // 2. User config directory
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            paths.append("\(home)/.config/dwarfsim/dwarfsim.yaml")
            paths.append("\(home)/.config/dwarfsim/config.yaml")
        }

        return paths
    }()

    /// Search paths for user creature config files
    public static let userCreaturePaths: [String] = {
        var paths: [String] = []
        paths.append("./creatures.yaml")
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            paths.append("\(home)/.config/dwarfsim/creatures.yaml")
        }
        return paths
    }()

    /// Search paths for user item config files
    public static let userItemPaths: [String] = {
        var paths: [String] = []
        paths.append("./items.yaml")
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            paths.append("\(home)/.config/dwarfsim/items.yaml")
        }
        return paths
    }()

    // MARK: - Main Loading Method

    /// Loads the full configuration from bundled defaults, then applies user overrides
    public static func loadConfiguration() -> DwarfSimConfig {
        // Step 1: Load bundled defaults (the source of truth)
        var config = loadBundledDefaults()

        // Step 2: Apply user overrides from main config file
        if let userConfig = loadUserMainConfig() {
            // Override simulation settings
            config.simulation = userConfig.simulation
            config.events = userConfig.events

            // Merge creatures (user overrides bundled)
            if !userConfig.creatures.isEmpty {
                for (name, creature) in userConfig.creatures {
                    config.creatures[name] = creature
                }
            }

            // Override spawn pool if specified
            if !userConfig.hostileSpawnPool.isEmpty {
                config.hostileSpawnPool = userConfig.hostileSpawnPool
            }

            // Merge items (user overrides bundled)
            if !userConfig.items.isEmpty {
                for (name, item) in userConfig.items {
                    config.items[name] = item
                }
            }
        }

        // Step 3: Apply user overrides from separate creature file
        if let creatures = loadUserCreaturesConfig() {
            for (name, creature) in creatures.creatures {
                config.creatures[name] = creature
            }
            if let pool = creatures.hostileSpawnPool {
                config.hostileSpawnPool = pool
            }
        }

        // Step 4: Apply user overrides from separate items file
        if let items = loadUserItemsConfig() {
            for (name, item) in items {
                config.items[name] = item
            }
        }

        return config
    }

    // MARK: - Bundled Defaults Loading

    /// Loads default configuration from bundled YAML resources
    private static func loadBundledDefaults() -> DwarfSimConfig {
        var config = DwarfSimConfig()

        // Load bundled main config
        if let mainConfig = loadBundledYAML("dwarfsim", as: DwarfSimConfig.self) {
            config.simulation = mainConfig.simulation
            config.events = mainConfig.events
            if !mainConfig.hostileSpawnPool.isEmpty {
                config.hostileSpawnPool = mainConfig.hostileSpawnPool
            }
        }

        // Load bundled creatures
        if let creatures = loadBundledYAML("creatures", as: CreaturesFileConfig.self) {
            config.creatures = creatures.creatures
            if let pool = creatures.hostileSpawnPool {
                config.hostileSpawnPool = pool
            }
        }

        // Load bundled items
        if let items = loadBundledYAML("items", as: ItemsFileConfig.self) {
            config.items = items.items
        }

        return config
    }

    /// Loads a YAML file from the bundle
    private static func loadBundledYAML<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        // Try to find the resource in the bundle
        guard let url = Bundle.module.url(forResource: name, withExtension: "yaml") else {
            print("Warning: Bundled resource '\(name).yaml' not found")
            return nil
        }

        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let decoder = YAMLDecoder()
            return try decoder.decode(type, from: contents)
        } catch {
            print("Warning: Failed to load bundled '\(name).yaml': \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - User Config Loading

    /// Loads user's main configuration file (if present)
    private static func loadUserMainConfig() -> DwarfSimConfig? {
        for path in userConfigPaths {
            if let config = loadYAMLFile(at: path, as: DwarfSimConfig.self) {
                return config
            }
        }
        return nil
    }

    /// Loads user's creatures configuration (if present)
    private static func loadUserCreaturesConfig() -> CreaturesFileConfig? {
        for path in userCreaturePaths {
            if let config = loadYAMLFile(at: path, as: CreaturesFileConfig.self) {
                return config
            }
        }
        return nil
    }

    /// Loads user's items configuration (if present)
    private static func loadUserItemsConfig() -> [String: ItemDefinition]? {
        for path in userItemPaths {
            if let config = loadYAMLFile(at: path, as: ItemsFileConfig.self) {
                return config.items
            }
        }
        return nil
    }

    /// Generic YAML file loader for filesystem paths
    private static func loadYAMLFile<T: Decodable>(at path: String, as type: T.Type) -> T? {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }

        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let decoder = YAMLDecoder()
            let config = try decoder.decode(type, from: contents)
            return config
        } catch {
            print("Warning: Failed to load config from \(path): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Info Methods

    /// Finds the first existing user config file path
    public static func findConfigFile() -> String? {
        for path in userConfigPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return expandedPath
            }
        }
        return nil
    }

    /// Returns info about config file search paths and what was found
    public static func configSearchInfo() -> String {
        var info = "Configuration file search order:\n"
        for (index, path) in userConfigPaths.enumerated() {
            let expandedPath = NSString(string: path).expandingTildeInPath
            let exists = FileManager.default.fileExists(atPath: expandedPath)
            let marker = exists ? "[FOUND]" : "[not found]"
            info += "  \(index + 1). \(expandedPath) \(marker)\n"
        }
        info += "  (Bundled defaults used as base)\n"
        return info
    }
}

// MARK: - Separate File Configs

/// Structure for creatures.yaml file
struct CreaturesFileConfig: Codable {
    var creatures: [String: CreatureDefinition]
    var hostileSpawnPool: [String]?

    enum CodingKeys: String, CodingKey {
        case creatures
        case hostileSpawnPool = "hostile_spawn_pool"
    }
}

/// Structure for items.yaml file
struct ItemsFileConfig: Codable {
    var items: [String: ItemDefinition]
}

// MARK: - Config Validation

extension DwarfSimConfig {
    /// Validates configuration values and returns warnings
    public func validate() -> [String] {
        var warnings: [String] = []

        // World size validation
        if simulation.world.width < 10 {
            warnings.append("World width too small (\(simulation.world.width)), minimum is 10")
        }
        if simulation.world.width > 200 {
            warnings.append("World width too large (\(simulation.world.width)), maximum is 200")
        }
        if simulation.world.height < 10 {
            warnings.append("World height too small (\(simulation.world.height)), minimum is 10")
        }
        if simulation.world.height > 100 {
            warnings.append("World height too large (\(simulation.world.height)), maximum is 100")
        }

        // Unit validation
        if simulation.units.initialCount < 1 {
            warnings.append("Initial unit count too small (\(simulation.units.initialCount)), minimum is 1")
        }
        if simulation.units.initialCount > simulation.units.maxPopulation {
            warnings.append("Initial count (\(simulation.units.initialCount)) exceeds max population (\(simulation.units.maxPopulation))")
        }

        // Event timing validation
        if events.hostileSpawn.intervalTicks < 10 {
            warnings.append("Hostile spawn interval too short (\(events.hostileSpawn.intervalTicks)), minimum is 10")
        }
        if events.hostileSpawn.chancePercent < 0 || events.hostileSpawn.chancePercent > 100 {
            warnings.append("Hostile spawn chance must be 0-100, got \(events.hostileSpawn.chancePercent)")
        }

        // Creature validation
        for (name, creature) in creatures {
            if creature.baseHP <= 0 {
                warnings.append("Creature '\(name)' has invalid HP (\(creature.baseHP))")
            }
            if creature.displayChar.isEmpty {
                warnings.append("Creature '\(name)' has no display character")
            }
        }

        // Spawn pool validation - check against loaded creatures
        for creatureName in hostileSpawnPool {
            if creatures[creatureName] == nil {
                warnings.append("Hostile spawn pool references unknown creature '\(creatureName)'")
            }
        }

        // Loot validation - check that loot items exist
        for (creatureName, creature) in creatures {
            if let loot = creature.lootOnDeath {
                for lootItem in loot {
                    if items[lootItem.item] == nil {
                        warnings.append("Creature '\(creatureName)' drops unknown item '\(lootItem.item)'")
                    }
                }
            }
        }

        return warnings
    }

    /// Returns a validated and clamped configuration
    public func validated() -> DwarfSimConfig {
        var config = self

        // Clamp world size
        config.simulation.world.width = max(10, min(200, config.simulation.world.width))
        config.simulation.world.height = max(10, min(100, config.simulation.world.height))

        // Clamp unit counts
        config.simulation.units.initialCount = max(1, min(50, config.simulation.units.initialCount))
        config.simulation.units.maxPopulation = max(config.simulation.units.initialCount, min(100, config.simulation.units.maxPopulation))

        // Clamp event intervals
        config.events.hostileSpawn.intervalTicks = max(10, config.events.hostileSpawn.intervalTicks)
        config.events.hostileSpawn.chancePercent = max(0, min(100, config.events.hostileSpawn.chancePercent))
        config.events.migrantWave.intervalTicks = max(100, config.events.migrantWave.intervalTicks)
        config.events.birthCheck.intervalTicks = max(100, config.events.birthCheck.intervalTicks)
        config.events.birthCheck.chancePercent = max(0, min(100, config.events.birthCheck.chancePercent))

        return config
    }
}
