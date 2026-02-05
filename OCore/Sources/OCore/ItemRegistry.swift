// MARK: - Item Registry
// Runtime lookup for item definitions with fallback to defaults

import Foundation

// MARK: - Item Registry

/// Manages item definitions loaded from configuration
@MainActor
public final class ItemRegistry: Sendable {

    /// Shared instance for global access
    public static let shared = ItemRegistry()

    /// Item definitions loaded from config
    private var definitions: [String: ItemDefinition] = [:]

    /// Whether the registry has been initialized with config
    private var isInitialized: Bool = false

    private init() {
        // Start empty - will be populated via initialize(with:)
        self.definitions = [:]
    }

    // MARK: - Initialization

    /// Initialize the registry with configuration (config already has bundled YAML loaded)
    public func initialize(with config: DwarfSimConfig) {
        // Config already contains merged bundled + user items from ConfigurationLoader
        self.definitions = config.items
        self.isInitialized = true
    }

    /// Reset to empty definitions (rely on hardcoded fallbacks)
    public func reset() {
        self.definitions = [:]
        self.isInitialized = false
    }

    // MARK: - Lookup Methods

    /// Get item definition by name
    public func getDefinition(for name: String) -> ItemDefinition? {
        definitions[name.lowercased().replacingOccurrences(of: "_", with: "")]
            ?? definitions[name.lowercased()]
    }

    /// Get item definition by ItemType enum
    public func getDefinition(for type: ItemType) -> ItemDefinition? {
        // Map ItemType to config key (handle naming differences)
        let key = itemTypeToKey(type)
        return definitions[key]
    }

    /// Get base value for an item type
    public func baseValue(for type: ItemType) -> Int {
        if let def = getDefinition(for: type) {
            return def.baseValue
        }
        return type.hardcodedBaseValue
    }

    /// Get category for an item type
    public func category(for type: ItemType) -> String {
        if let def = getDefinition(for: type) {
            return def.category
        }
        return type.hardcodedCategory
    }

    /// Check if an item type is stackable
    public func isStackable(_ type: ItemType) -> Bool {
        if let def = getDefinition(for: type) {
            return def.stackable
        }
        return type.hardcodedStackable
    }

    // MARK: - Registration

    /// Register a custom item definition
    public func register(name: String, definition: ItemDefinition) {
        definitions[name.lowercased()] = definition
    }

    // MARK: - Info

    /// Get all registered item names
    public var registeredItems: [String] {
        Array(definitions.keys).sorted()
    }

    /// Check if an item is registered
    public func isRegistered(_ name: String) -> Bool {
        definitions[name.lowercased()] != nil
    }

    // MARK: - Private Helpers

    /// Convert ItemType enum to config key string
    private func itemTypeToKey(_ type: ItemType) -> String {
        switch type {
        case .rawMeat: return "raw_meat"
        default: return type.rawValue
        }
    }
}

// MARK: - ItemType Hardcoded Fallbacks

extension ItemType {
    /// Hardcoded base value (fallback when registry has no definition)
    var hardcodedBaseValue: Int {
        switch self {
        case .food: return 5
        case .drink: return 3
        case .rawMeat: return 4
        case .plant: return 2
        case .bed: return 50
        case .table: return 30
        case .chair: return 20
        case .door: return 25
        case .barrel: return 15
        case .bin: return 15
        case .pickaxe: return 40
        case .axe: return 35
        case .log: return 5
        case .stone: return 3
        case .ore: return 10
        }
    }

    /// Hardcoded category (fallback when registry has no definition)
    var hardcodedCategory: String {
        switch self {
        case .food, .drink, .rawMeat, .plant:
            return "consumable"
        case .bed, .table, .chair, .door, .barrel, .bin:
            return "furniture"
        case .pickaxe, .axe:
            return "tool"
        case .log, .stone, .ore:
            return "material"
        }
    }

    /// Hardcoded stackable flag (fallback when registry has no definition)
    var hardcodedStackable: Bool {
        switch self {
        case .food, .drink, .rawMeat, .plant, .log, .stone, .ore:
            return true
        default:
            return false
        }
    }
}
