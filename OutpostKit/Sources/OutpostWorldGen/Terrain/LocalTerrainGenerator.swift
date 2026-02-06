// MARK: - Local Terrain Generator
// Converts a WorldMap embark region into a detailed 3D tile grid for gameplay

import Foundation

/// Converts a region of the world map into the detailed 3D tile grid used by the World
struct LocalTerrainGenerator: Sendable {

    /// Generate a 3D tile grid from a world map region
    /// - Parameters:
    ///   - worldMap: The complete world map
    ///   - region: The embark region to extract
    ///   - depth: Number of z-levels to generate
    ///   - rng: Seeded RNG for detail variation
    /// - Returns: 3D tile array [z][y][x]
    static func generate(
        from worldMap: WorldMap,
        region: EmbarkRegion,
        depth: Int = 1,
        rng: inout SeededRNG
    ) -> [[[Tile]]] {
        let width = region.width
        let height = region.height

        // Initialize all tiles
        var tiles = Array(
            repeating: Array(
                repeating: Array(
                    repeating: Tile(terrain: .grass),
                    count: width
                ),
                count: height
            ),
            count: depth
        )

        // Generate surface level (z = 0)
        for y in 0..<height {
            for x in 0..<width {
                let mapX = region.startX + x
                let mapY = region.startY + y

                guard worldMap.isValid(x: mapX, y: mapY) else { continue }
                let cell = worldMap[mapX, mapY]

                let terrain = terrainForCell(cell, rng: &rng)
                let biome = cell.biome
                let elevation = UInt8(clamping: Int(cell.elevation * 255))
                let moisture = UInt8(clamping: Int(cell.moisture * 255))

                tiles[0][y][x] = Tile(
                    terrain: terrain,
                    biome: biome,
                    elevation: elevation,
                    moisture: moisture
                )
            }
        }

        // Generate underground levels (z > 0)
        if depth > 1 {
            generateUnderground(
                tiles: &tiles,
                worldMap: worldMap,
                region: region,
                depth: depth,
                rng: &rng
            )
        }

        return tiles
    }

    // MARK: - Surface Terrain Mapping

    /// Map a world map cell to a specific terrain type
    private static func terrainForCell(_ cell: WorldMapCell, rng: inout SeededRNG) -> TerrainType {
        // Water bodies
        if cell.isLake {
            return cell.waterDepth > 0.4 ? .deepWater : .water
        }
        if cell.isRiver {
            return .water
        }
        if cell.elevation < 0.3 {
            return cell.elevation < 0.2 ? .deepWater : .water
        }

        // Map biome to terrain
        switch cell.biome {
        // Cold biomes
        case .iceCap, .frozenOcean, .frozenLake:
            return .ice
        case .snowPeak:
            return rng.nextBool(probability: 0.7) ? .snow : .frozenGround
        case .tundra:
            if rng.nextBool(probability: 0.3) { return .snow }
            if rng.nextBool(probability: 0.2) { return .moss }
            return .frozenGround
        case .alpineMeadow:
            if rng.nextBool(probability: 0.15) { return .stone }
            if rng.nextBool(probability: 0.2) { return .moss }
            return .grass

        // Forest biomes
        case .borealForest:
            if cell.vegetationDensity > 0.5 {
                return rng.nextBool(probability: 0.6) ? .coniferTree : .shrub
            }
            if rng.nextBool(probability: 0.2) { return .moss }
            return .grass
        case .temperateForest:
            if cell.vegetationDensity > 0.5 {
                return rng.nextBool(probability: 0.5) ? .tree : .shrub
            }
            if rng.nextBool(probability: 0.15) { return .tallGrass }
            return .grass
        case .temperateRainforest:
            if cell.vegetationDensity > 0.4 {
                return rng.nextBool(probability: 0.6) ? .tree : .shrub
            }
            if rng.nextBool(probability: 0.3) { return .moss }
            return .grass
        case .tropicalForest:
            if cell.vegetationDensity > 0.4 {
                return rng.nextBool(probability: 0.5) ? .palmTree : .tree
            }
            return .grass
        case .tropicalRainforest:
            if cell.vegetationDensity > 0.3 {
                return rng.nextBool(probability: 0.6) ? .palmTree : .tree
            }
            if rng.nextBool(probability: 0.2) { return .tallGrass }
            return .grass

        // Grassland biomes
        case .temperateGrassland:
            if cell.vegetationDensity > 0.6 { return .tallGrass }
            if rng.nextBool(probability: 0.08) { return .shrub }
            if rng.nextBool(probability: 0.03) { return .tree }
            return .grass
        case .savanna:
            if rng.nextBool(probability: 0.05) { return .tree }
            if rng.nextBool(probability: 0.15) { return .tallGrass }
            return .grass

        // Wet biomes
        case .swamp:
            if rng.nextBool(probability: 0.3) { return .water }
            if rng.nextBool(probability: 0.25) { return .deadTree }
            if rng.nextBool(probability: 0.2) { return .mud }
            return .marsh
        case .marsh:
            if rng.nextBool(probability: 0.2) { return .water }
            if rng.nextBool(probability: 0.3) { return .reeds }
            return .marsh
        case .mangrove:
            if rng.nextBool(probability: 0.3) { return .water }
            if rng.nextBool(probability: 0.3) { return .tree }
            return .mud

        // Dry biomes
        case .desert, .hotDesert:
            if rng.nextBool(probability: 0.05) { return .cactus }
            if rng.nextBool(probability: 0.1) { return .gravel }
            return .sand
        case .coldDesert:
            if rng.nextBool(probability: 0.15) { return .gravel }
            if rng.nextBool(probability: 0.1) { return .frozenGround }
            return .sand
        case .scrubland:
            if rng.nextBool(probability: 0.2) { return .shrub }
            if rng.nextBool(probability: 0.1) { return .tallGrass }
            if rng.nextBool(probability: 0.05) { return .gravel }
            return .dirt

        // Mountain
        case .mountain:
            if rng.nextBool(probability: 0.3) { return .stone }
            if rng.nextBool(probability: 0.2) { return .granite }
            if rng.nextBool(probability: 0.1) { return .gravel }
            return .stone
        case .volcanicWaste:
            if rng.nextBool(probability: 0.1) { return .lava }
            if rng.nextBool(probability: 0.3) { return .obsidian }
            return .gravel

        // Transitional
        case .beach:
            return .sand
        case .riverBank:
            if rng.nextBool(probability: 0.3) { return .mud }
            if rng.nextBool(probability: 0.2) { return .clay }
            return .dirt

        // Aquatic (shouldn't reach here for surface, but handle)
        case .ocean, .deepOcean, .coastalWaters:
            return .deepWater
        case .lake:
            return .water
        case .river:
            return .water
        }
    }

    // MARK: - Underground Generation

    private static func generateUnderground(
        tiles: inout [[[Tile]]],
        worldMap: WorldMap,
        region: EmbarkRegion,
        depth: Int,
        rng: inout SeededRNG
    ) {
        let width = region.width
        let height = region.height

        for z in 1..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    let mapX = region.startX + x
                    let mapY = region.startY + y

                    var terrain: TerrainType = .wall
                    var biome = tiles[0][y][x].biome

                    if worldMap.isValid(x: mapX, y: mapY) {
                        let cell = worldMap[mapX, mapY]

                        // Rock type based on geology
                        if cell.boundaryStress > 0.5 {
                            terrain = rng.nextBool(probability: 0.2) ? .obsidian : .granite
                        } else if cell.elevation > 0.6 {
                            terrain = rng.nextBool(probability: 0.3) ? .granite : .wall
                        } else {
                            terrain = rng.nextBool(probability: 0.15) ? .limestone : .wall
                        }

                        // Ore veins
                        if let oreType = cell.oreType {
                            // Probability increases with depth and richness
                            let oreChance = Double(cell.oreRichness) * 0.15 * Double(z)
                            if rng.nextBool(probability: min(0.3, oreChance)) {
                                terrain = .ore
                            }
                        }

                        // Natural cavities
                        if rng.nextBool(probability: 0.02) {
                            terrain = .stoneFloor
                        }

                        biome = cell.biome
                    }

                    tiles[z][y][x] = Tile(
                        terrain: terrain,
                        biome: biome,
                        elevation: tiles[0][y][x].elevation,
                        moisture: tiles[0][y][x].moisture
                    )
                }
            }

            // Add natural cavities
            let cavityCount = rng.nextInt(in: 0...2)
            for _ in 0..<cavityCount {
                let cx = rng.nextInt(in: 5...(width - 6))
                let cy = rng.nextInt(in: 5...(height - 6))
                let radius = rng.nextInt(in: 2...4)

                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let tx = cx + dx
                        let ty = cy + dy
                        guard tx >= 0, tx < width, ty >= 0, ty < height else { continue }

                        let dist = sqrt(Double(dx * dx + dy * dy))
                        if dist <= Double(radius) * 0.8 {
                            tiles[z][ty][tx].terrain = .stoneFloor
                        }
                    }
                }
            }
        }

        // Create entrance from surface
        let entranceX = width / 2
        let entranceY = height / 2

        // Clear surface area around entrance
        for dy in -1...1 {
            for dx in -1...1 {
                let ex = entranceX + dx
                let ey = entranceY + dy
                if ex >= 0 && ex < width && ey >= 0 && ey < height {
                    let t = tiles[0][ey][ex].terrain
                    if t.isVegetation {
                        tiles[0][ey][ex].terrain = .grass
                    }
                }
            }
        }

        // Stairs down at entrance
        if depth > 1 {
            tiles[0][entranceY][entranceX].terrain = .stairsDown

            // Connect underground levels with stairs
            for z in 1..<depth {
                tiles[z][entranceY][entranceX].terrain = z == depth - 1 ? .stairsUp : .stairsUpDown
            }
        }
    }
}
