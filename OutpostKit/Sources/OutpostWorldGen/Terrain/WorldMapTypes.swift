// MARK: - World Map Types
// Data structures for the large-scale world map used during terrain generation

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

    /// Creates an RNG from this seed
    func makeRNG() -> SeededRNG {
        SeededRNG(seed: value)
    }
}

// MARK: - World Gen Parameters

/// Configuration for world generation
public struct WorldGenParameters: Sendable {
    public let seed: WorldSeed
    public let mapSize: Int              // World map dimensions (square)
    public let plateCount: Int           // Number of tectonic plates
    public let erosionDroplets: Int      // Number of erosion droplets
    public let embarkSize: Int           // Size of embark region to extract

    public init(
        seed: WorldSeed = WorldSeed(),
        mapSize: Int = 257,
        plateCount: Int = 12,
        erosionDroplets: Int = 500_000,
        embarkSize: Int = 50
    ) {
        self.seed = seed
        self.mapSize = mapSize
        self.plateCount = plateCount
        self.erosionDroplets = erosionDroplets
        self.embarkSize = embarkSize
    }
}

// MARK: - Tectonic Plate

/// A tectonic plate with drift vector and type
struct TectonicPlate: Sendable {
    let id: Int
    let centerX: Double
    let centerY: Double
    let driftX: Double
    let driftY: Double
    let isOceanic: Bool

    init(id: Int, centerX: Double, centerY: Double, driftX: Double, driftY: Double, isOceanic: Bool) {
        self.id = id
        self.centerX = centerX
        self.centerY = centerY
        self.driftX = driftX
        self.driftY = driftY
        self.isOceanic = isOceanic
    }
}

// MARK: - Plate Boundary

/// Classification of plate boundary types
enum PlateBoundaryType: Sendable {
    case convergent   // Plates moving toward each other → mountains
    case divergent    // Plates moving apart → rifts/valleys
    case transform    // Plates sliding past → moderate elevation
    case none         // Interior of plate
}

// MARK: - Ore Type

/// Types of mineable ore deposits
enum OreType: String, CaseIterable, Sendable {
    case iron
    case copper
    case tin
    case gold
    case silver
    case coal
    case gemstone
}

// MARK: - World Map Cell

/// A single cell in the world map containing all geological/climate data
struct WorldMapCell: Sendable {
    // Geology
    var elevation: Float = 0.0       // 0.0 = deep ocean, 1.0 = highest peak
    var plateId: Int = 0
    var neighborPlateId: Int? = nil   // Plate ID of nearest different plate (for subduction detection)
    var boundaryType: PlateBoundaryType = .none
    var boundaryStress: Float = 0.0  // 0-1, how close to plate boundary
    var geologicalColumn: GeologicalColumn? = nil  // Subsurface strata profile

    // Erosion
    var sediment: Float = 0.0        // Deposited sediment thickness

    // Climate
    var temperature: Float = 0.5     // 0.0 = frozen, 1.0 = scorching
    var moisture: Float = 0.5        // 0.0 = arid, 1.0 = saturated
    var rainfall: Float = 0.5        // Annual precipitation
    var windX: Float = 0.0
    var windY: Float = 0.0

    // Hydrology
    var flowDirection: Int = -1      // Index into 8 neighbors, or -1
    var flowAccumulation: Int = 0    // Number of upstream cells
    var isRiver: Bool = false
    var isLake: Bool = false
    var waterDepth: Float = 0.0      // Depth for lakes/oceans

    // Biome & Detail
    var biome: BiomeType = .temperateGrassland
    var vegetationDensity: Float = 0.0  // 0-1
    var soilDepth: Float = 0.0       // 0-1
    var oreType: OreType? = nil
    var oreRichness: Float = 0.0     // 0-1

    init() {}
}

// MARK: - River

/// A traced river path
struct River: Sendable {
    var path: [(x: Int, y: Int)]
    var volume: Float // Accumulated flow

    init(path: [(x: Int, y: Int)] = [], volume: Float = 0) {
        self.path = path
        self.volume = volume
    }
}

// MARK: - Embark Region

/// Defines a rectangular region of the world map for local terrain extraction
struct EmbarkRegion: Sendable {
    let startX: Int
    let startY: Int
    let width: Int
    let height: Int

    init(startX: Int, startY: Int, width: Int, height: Int) {
        self.startX = startX
        self.startY = startY
        self.width = width
        self.height = height
    }

    /// Creates an embark region centered on the given position, clamped to map bounds
    static func centered(x: Int, y: Int, size: Int, mapSize: Int) -> EmbarkRegion {
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
    var cells: [WorldMapCell]
    var plates: [TectonicPlate]
    var rivers: [River]
    public let seed: WorldSeed

    init(size: Int, seed: WorldSeed) {
        self.size = size
        self.cells = Array(repeating: WorldMapCell(), count: size * size)
        self.plates = []
        self.rivers = []
        self.seed = seed
    }

    /// Access a cell by (x, y) coordinates
    subscript(x: Int, y: Int) -> WorldMapCell {
        get { cells[y * size + x] }
        set { cells[y * size + x] = newValue }
    }

    /// Whether coordinates are within bounds
    func isValid(x: Int, y: Int) -> Bool {
        x >= 0 && x < size && y >= 0 && y < size
    }

    /// Get the 8 neighbor offsets
    static let neighborOffsets: [(dx: Int, dy: Int)] = [
        (0, -1), (1, -1), (1, 0), (1, 1),
        (0, 1), (-1, 1), (-1, 0), (-1, -1)
    ]
}
