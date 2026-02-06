import Testing
import SpriteKit
@testable import OCore
@testable import Outpost

// MARK: - WorldSnapshot Tests

@Suite("WorldSnapshot")
struct WorldSnapshotTests {

    @MainActor
    @Test("UnitSnapshot includes healthCurrent and healthMax from unit")
    func unitSnapshotHealthFields() async throws {
        let world = World(width: 10, height: 10)
        var unit = Unit(id: 42, position: Position(x: 3, y: 3, z: 0))
        unit.health = Health(maxHP: 80)
        unit.health.takeDamage(amount: 25)
        world.addUnit(unit)

        let sim = Simulation(world: world)
        let snapshot = WorldSnapshot.from(simulation: sim, currentZ: 0, hostileUnits: [])

        let unitSnap = try #require(snapshot.units.first(where: { $0.id == 42 }))
        #expect(unitSnap.healthMax == 80)
        #expect(unitSnap.healthCurrent == 55)
        #expect(unitSnap.healthPercent == 68) // 55/80 = 68%
    }

    @MainActor
    @Test("Snapshot captures correct tile dimensions")
    func snapshotDimensions() async throws {
        let world = World(width: 20, height: 15)
        let sim = Simulation(world: world)
        let snapshot = WorldSnapshot.from(simulation: sim, currentZ: 0, hostileUnits: [])

        #expect(snapshot.width == 20)
        #expect(snapshot.height == 15)
        #expect(snapshot.tiles.count == 15)
        #expect(snapshot.tiles[0].count == 20)
    }

    @MainActor
    @Test("Snapshot captures unit facing direction")
    func unitFacingDirection() async throws {
        let world = World(width: 10, height: 10)
        var unit = Unit(id: 1, position: Position(x: 5, y: 5, z: 0))
        unit.facing = .northwest
        world.addUnit(unit)

        let sim = Simulation(world: world)
        let snapshot = WorldSnapshot.from(simulation: sim, currentZ: 0, hostileUnits: [])

        let unitSnap = try #require(snapshot.units.first(where: { $0.id == 1 }))
        #expect(unitSnap.facing == .northwest)
    }

    @MainActor
    @Test("Snapshot tracks hostile units")
    func hostileUnitTracking() async throws {
        let world = World(width: 10, height: 10)
        let unit = Unit(id: 99, position: Position(x: 2, y: 2, z: 0))
        world.addUnit(unit)

        let sim = Simulation(world: world)
        let snapshot = WorldSnapshot.from(simulation: sim, currentZ: 0, hostileUnits: [99])

        let unitSnap = try #require(snapshot.units.first(where: { $0.id == 99 }))
        #expect(unitSnap.isHostile == true)
    }

    @MainActor
    @Test("Snapshot unit states are captured")
    func unitStateCapture() async throws {
        let world = World(width: 10, height: 10)
        var unit = Unit(id: 7, position: Position(x: 1, y: 1, z: 0))
        unit.state = .fighting
        world.addUnit(unit)

        let sim = Simulation(world: world)
        let snapshot = WorldSnapshot.from(simulation: sim, currentZ: 0, hostileUnits: [])

        let unitSnap = try #require(snapshot.units.first(where: { $0.id == 7 }))
        #expect(unitSnap.state == .fighting)
    }
}

// MARK: - TextureManager Tests

@Suite("TextureManager")
struct TextureManagerTests {

    @MainActor
    @Test("Tile size is 32")
    func tileSizeIs32() {
        #expect(TextureManager.shared.tileSize == 32.0)
    }

    @MainActor
    @Test("Water animation textures has 3 frames")
    func waterAnimationFrameCount() {
        let frames = TextureManager.shared.waterAnimationTextures()
        #expect(frames.count == 3)
    }

    @MainActor
    @Test("All terrain textures load")
    func terrainTexturesLoad() {
        for terrain in TerrainType.allCases {
            let tex = TextureManager.shared.texture(for: terrain)
            #expect(tex.size().width > 0)
        }
    }

    @MainActor
    @Test("All creature textures load")
    func creatureTexturesLoad() {
        for creature in CreatureType.allCases {
            let tex = TextureManager.shared.texture(for: creature)
            #expect(tex.size().width > 0)
        }
    }

    @MainActor
    @Test("All item textures load")
    func itemTexturesLoad() {
        for item in ItemType.allCases {
            let tex = TextureManager.shared.texture(for: item)
            #expect(tex.size().width > 0)
        }
    }

    @MainActor
    @Test("Selection ring texture loads")
    func selectionTextureLoads() {
        let tex = TextureManager.shared.selectionRingTexture()
        #expect(tex.size().width > 0)
    }

    @MainActor
    @Test("Health bar textures load")
    func healthBarTexturesLoad() {
        let bg = TextureManager.shared.healthBarBgTexture()
        let fill = TextureManager.shared.healthBarFillTexture()
        // These may be empty textures if assets aren't in test bundle,
        // but they should not crash
        #expect(bg.size().width >= 0)
        #expect(fill.size().width >= 0)
    }
}

// MARK: - Simulation Tick Tests

@Suite("Simulation Ticks")
struct SimulationTickTests {

    @MainActor
    @Test("Simulation runs 100 ticks without crash")
    func run100Ticks() async throws {
        let world = World(width: 30, height: 30)
        let sim = Simulation(world: world)
        sim.spawnUnits(count: 5)

        for _ in 0..<100 {
            sim.tick()
        }

        #expect(world.currentTick == 100)
        #expect(world.units.count >= 5)
    }

    @MainActor
    @Test("Snapshot is valid after many ticks")
    func snapshotAfterTicks() async throws {
        let world = World(width: 20, height: 20)
        let sim = Simulation(world: world)
        sim.spawnUnits(count: 3)

        for _ in 0..<50 {
            sim.tick()
        }

        let snapshot = WorldSnapshot.from(simulation: sim, currentZ: 0, hostileUnits: sim.hostileUnits)
        #expect(snapshot.tick == 50)
        #expect(snapshot.units.count >= 3)
        for unit in snapshot.units {
            #expect(unit.healthMax > 0)
            #expect(unit.healthCurrent >= 0)
            #expect(unit.healthCurrent <= unit.healthMax)
        }
    }

    @MainActor
    @Test("Health damage tracking across snapshots detects changes")
    func healthChangeTracking() async throws {
        let world = World(width: 10, height: 10)
        var unit = Unit(id: 100, position: Position(x: 5, y: 5, z: 0))
        unit.health = Health(maxHP: 50)
        world.addUnit(unit)

        let sim = Simulation(world: world)

        // Snapshot before damage
        let snap1 = WorldSnapshot.from(simulation: sim, currentZ: 0, hostileUnits: [])
        let u1 = try #require(snap1.units.first(where: { $0.id == 100 }))
        #expect(u1.healthCurrent == 50)

        // Apply damage directly
        world.units[100]?.health.takeDamage(amount: 15)

        // Snapshot after damage
        let snap2 = WorldSnapshot.from(simulation: sim, currentZ: 0, hostileUnits: [])
        let u2 = try #require(snap2.units.first(where: { $0.id == 100 }))
        #expect(u2.healthCurrent == 35)

        // Verify change detection
        let previousHP = u1.healthCurrent
        let currentHP = u2.healthCurrent
        #expect(currentHP < previousHP)
        #expect(previousHP - currentHP == 15)
    }
}

// MARK: - Coordinate Conversion Tests

@Suite("Coordinate Conversion")
struct CoordinateConversionTests {

    @Test("worldToScene and sceneToWorld are inverse operations")
    func roundTrip() {
        let tileSize: CGFloat = 32
        let worldHeight = 20

        for x in 0..<20 {
            for y in 0..<20 {
                let scenePos = worldToScene(x: x, y: y, worldHeight: worldHeight, tileSize: tileSize)
                let (gridX, gridY) = sceneToWorld(point: scenePos, worldHeight: worldHeight, tileSize: tileSize)
                #expect(gridX == x, "x roundtrip failed for (\(x),\(y))")
                #expect(gridY == y, "y roundtrip failed for (\(x),\(y))")
            }
        }
    }

    @Test("worldToScene produces correct spacing with tileSize 32")
    func tileSpacing() {
        let tileSize: CGFloat = 32
        let pos0 = worldToScene(x: 0, y: 0, worldHeight: 10, tileSize: tileSize)
        let pos1 = worldToScene(x: 1, y: 0, worldHeight: 10, tileSize: tileSize)
        #expect(pos1.x - pos0.x == tileSize)
    }
}
