// MARK: - World Map Types
// Data structures for the large-scale world map

import Foundation

// MARK: - World Seed

/// A seed for deterministic world generation
public struct WorldSeed: Sendable, Hashable {
    public let value: UInt64

    public init(_ value: UInt64) {
        self.value = value
    }

    public init(random: Bool = true) {
        self.value = UInt64.random(in: 0...UInt64.max)
    }
}

// MARK: - World Map Cell

/// A single cell in the world map containing all geological/climate data
public struct WorldMapCell: Sendable {
    // Geology
    public var elevation: Float = 0.0       // 0.0 = deep ocean, 1.0 = highest peak
    public var plateId: Int = 0
    public var neighborPlateId: Int? = nil   // Plate ID of nearest different plate (for subduction detection)
    public var boundaryType: PlateBoundaryType = .none
    public var boundaryStress: Float = 0.0  // 0-1, how close to plate boundary
    public var geologicalColumn: GeologicalColumn? = nil  // Subsurface strata profile

    // Erosion
    public var sediment: Float = 0.0        // Deposited sediment thickness

    // Climate
    public var temperature: Float = 0.5     // 0.0 = frozen, 1.0 = scorching
    public var moisture: Float = 0.5        // 0.0 = arid, 1.0 = saturated
    public var rainfall: Float = 0.5        // Annual precipitation
    public var windX: Float = 0.0
    public var windY: Float = 0.0

    // Hydrology
    public var flowDirection: Int = -1      // Index into 8 neighbors, or -1
    public var flowAccumulation: Int = 0    // Number of upstream cells
    public var isRiver: Bool = false
    public var isLake: Bool = false
    public var waterDepth: Float = 0.0      // Depth for lakes/oceans

    // Biome & Detail
    public var biome: BiomeType = .temperateGrassland
    public var vegetationDensity: Float = 0.0  // 0-1
    public var soilDepth: Float = 0.0       // 0-1
    public var oreType: OreType? = nil
    public var oreRichness: Float = 0.0     // 0-1
    public var gemstoneType: GemstoneType? = nil

    public init() {}
}

// MARK: - River

/// A traced river path
public struct River: Sendable {
    public var path: [(x: Int, y: Int)]
    public var volume: Float // Accumulated flow

    public init(path: [(x: Int, y: Int)] = [], volume: Float = 0) {
        self.path = path
        self.volume = volume
    }
}

// MARK: - Embark Region

/// Defines a rectangular region of the world map for local terrain extraction
public struct EmbarkRegion: Sendable {
    public let startX: Int
    public let startY: Int
    public let width: Int
    public let height: Int

    public init(startX: Int, startY: Int, width: Int, height: Int) {
        self.startX = startX
        self.startY = startY
        self.width = width
        self.height = height
    }

    /// Creates an embark region centered on the given position, clamped to map bounds
    public static func centered(x: Int, y: Int, size: Int, mapSize: Int) -> EmbarkRegion {
        let halfSize = size / 2
        let startX = max(0, min(x - halfSize, mapSize - size))
        let startY = max(0, min(y - halfSize, mapSize - size))
        return EmbarkRegion(startX: startX, startY: startY, width: size, height: size)
    }
}

// MARK: - World Map

/// The large-scale world map holding all geological and climate data
public struct WorldMap: Sendable {
    public let size: Int
    public var cells: [WorldMapCell]
    public var plates: [TectonicPlate]
    public var rivers: [River]
    public let seed: WorldSeed

    public init(size: Int, seed: WorldSeed) {
        self.size = size
        self.cells = Array(repeating: WorldMapCell(), count: size * size)
        self.plates = []
        self.rivers = []
        self.seed = seed
    }

    /// Access a cell by (x, y) coordinates
    public subscript(x: Int, y: Int) -> WorldMapCell {
        get { cells[y * size + x] }
        set { cells[y * size + x] = newValue }
    }

    /// Whether coordinates are within bounds
    public func isValid(x: Int, y: Int) -> Bool {
        x >= 0 && x < size && y >= 0 && y < size
    }

    /// Get the 8 neighbor offsets
    public static let neighborOffsets: [(dx: Int, dy: Int)] = [
        (0, -1), (1, -1), (1, 0), (1, 1),
        (0, 1), (-1, 1), (-1, 0), (-1, -1)
    ]
}
