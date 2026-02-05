// MARK: - World

import Foundation

/// The game world containing the map, units, and items
@MainActor
public final class World: Sendable {
    /// Width of the world (x-axis)
    public let width: Int

    /// Height of the world (y-axis)
    public let height: Int

    /// Depth of the world (z-axis / levels)
    public let depth: Int

    /// 3D array of tiles [z][y][x]
    private var tiles: [[[Tile]]]

    /// All units in the world, keyed by ID
    public private(set) var units: [UInt64: Unit]

    /// All items in the world, keyed by ID
    public private(set) var items: [UInt64: Item]

    /// Current simulation tick
    public private(set) var currentTick: UInt64

    /// Creates a new world with the specified dimensions
    /// Generates a flat grass world with some terrain variation
    /// - Parameters:
    ///   - width: Width of the world
    ///   - height: Height of the world
    ///   - depth: Number of z-levels (defaults to 1)
    public init(width: Int, height: Int, depth: Int = 1) {
        self.width = width
        self.height = height
        self.depth = depth
        self.units = [:]
        self.items = [:]
        self.currentTick = 0

        // Initialize tiles with grass
        self.tiles = Array(
            repeating: Array(
                repeating: Array(
                    repeating: Tile(terrain: .grass),
                    count: width
                ),
                count: height
            ),
            count: depth
        )

        // Generate terrain variation
        generateTerrain()
    }

    /// Generates terrain features for the world
    private func generateTerrain() {
        let random = { () -> Double in Double.random(in: 0...1) }

        // Scatter trees (about 8% of the map)
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    if random() < 0.08 {
                        tiles[z][y][x].terrain = .tree
                    }
                }
            }
        }

        // Add some stone patches (clusters)
        let stoneClusterCount = max(1, (width * height) / 200)
        for _ in 0..<stoneClusterCount {
            let centerX = Int.random(in: 0..<width)
            let centerY = Int.random(in: 0..<height)
            let radius = Int.random(in: 2...5)

            for dy in -radius...radius {
                for dx in -radius...radius {
                    let x = centerX + dx
                    let y = centerY + dy
                    guard x >= 0, x < width, y >= 0, y < height else { continue }

                    let distance = sqrt(Double(dx * dx + dy * dy))
                    if distance <= Double(radius) && random() < 0.7 {
                        tiles[0][y][x].terrain = .stone
                    }
                }
            }
        }

        // Add a water feature (small pond)
        let pondX = Int.random(in: width / 4...(3 * width / 4))
        let pondY = Int.random(in: height / 4...(3 * height / 4))
        let pondRadius = Int.random(in: 3...6)

        for dy in -pondRadius...pondRadius {
            for dx in -pondRadius...pondRadius {
                let x = pondX + dx
                let y = pondY + dy
                guard x >= 0, x < width, y >= 0, y < height else { continue }

                let distance = sqrt(Double(dx * dx + dy * dy))
                if distance <= Double(pondRadius) * 0.8 {
                    tiles[0][y][x].terrain = .water
                } else if distance <= Double(pondRadius) && random() < 0.5 {
                    tiles[0][y][x].terrain = .water
                }
            }
        }

        // Add shrubs around trees
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    if tiles[z][y][x].terrain == .grass {
                        // Check for nearby trees
                        var nearbyTrees = 0
                        for dy in -2...2 {
                            for dx in -2...2 {
                                let nx = x + dx
                                let ny = y + dy
                                if nx >= 0, nx < width, ny >= 0, ny < height {
                                    if tiles[z][ny][nx].terrain == .tree {
                                        nearbyTrees += 1
                                    }
                                }
                            }
                        }

                        if nearbyTrees > 0 && random() < Double(nearbyTrees) * 0.05 {
                            tiles[z][y][x].terrain = .shrub
                        }
                    }
                }
            }
        }

        // Add some dirt patches
        for z in 0..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    if tiles[z][y][x].terrain == .grass && random() < 0.03 {
                        tiles[z][y][x].terrain = .dirt
                    }
                }
            }
        }
    }

    // MARK: - Tile Access

    /// Gets the tile at the specified position
    /// - Parameter position: The position to check
    /// - Returns: The tile at that position, or nil if out of bounds
    public func getTile(at position: Position) -> Tile? {
        guard isValidPosition(position) else { return nil }
        return tiles[position.z][position.y][position.x]
    }

    /// Sets the tile at the specified position
    /// - Parameters:
    ///   - tile: The tile to set
    ///   - position: The position to set it at
    public func setTile(_ tile: Tile, at position: Position) {
        guard isValidPosition(position) else { return }
        tiles[position.z][position.y][position.x] = tile
    }

    /// Checks if a position is passable
    /// - Parameter position: The position to check
    /// - Returns: True if the position is valid and passable
    public func isPassable(_ position: Position) -> Bool {
        guard let tile = getTile(at: position) else { return false }
        return tile.isPassable && tile.unitId == nil
    }

    /// Checks if a position is within world bounds
    /// - Parameter position: The position to check
    /// - Returns: True if the position is within bounds
    public func isValidPosition(_ position: Position) -> Bool {
        position.x >= 0 && position.x < width &&
        position.y >= 0 && position.y < height &&
        position.z >= 0 && position.z < depth
    }

    // MARK: - Unit Management

    /// Adds a unit to the world
    /// - Parameter unit: The unit to add
    /// - Returns: The ID of the added unit
    @discardableResult
    public func addUnit(_ unit: Unit) -> UInt64 {
        units[unit.id] = unit

        // Mark the tile as occupied
        if isValidPosition(unit.position) {
            tiles[unit.position.z][unit.position.y][unit.position.x].unitId = unit.id
        }

        return unit.id
    }

    /// Removes a unit from the world
    /// - Parameter id: The ID of the unit to remove
    public func removeUnit(id: UInt64) {
        guard let unit = units[id] else { return }

        // Clear the tile occupation
        if isValidPosition(unit.position) {
            tiles[unit.position.z][unit.position.y][unit.position.x].unitId = nil
        }

        units.removeValue(forKey: id)
    }

    /// Gets a unit by ID
    /// - Parameter id: The unit ID
    /// - Returns: The unit, or nil if not found
    public func getUnit(id: UInt64) -> Unit? {
        units[id]
    }

    /// Updates a unit in the world
    /// - Parameter unit: The updated unit
    public func updateUnit(_ unit: Unit) {
        guard let oldUnit = units[unit.id] else { return }

        // If position changed, update tile occupancy
        if oldUnit.position != unit.position {
            // Clear old tile
            if isValidPosition(oldUnit.position) {
                tiles[oldUnit.position.z][oldUnit.position.y][oldUnit.position.x].unitId = nil
            }
            // Mark new tile
            if isValidPosition(unit.position) {
                tiles[unit.position.z][unit.position.y][unit.position.x].unitId = unit.id
            }
        }

        units[unit.id] = unit
    }

    /// Moves a unit to a new position
    /// - Parameters:
    ///   - unitId: The ID of the unit to move
    ///   - newPosition: The destination position
    /// - Returns: True if the move was successful
    @discardableResult
    public func moveUnit(_ unitId: UInt64, to newPosition: Position) -> Bool {
        guard var unit = units[unitId] else { return false }
        guard isPassable(newPosition) else { return false }

        let oldPosition = unit.position

        // Clear old tile
        if isValidPosition(oldPosition) {
            tiles[oldPosition.z][oldPosition.y][oldPosition.x].unitId = nil
        }

        // Update unit position
        unit.position = newPosition
        units[unitId] = unit

        // Mark new tile
        tiles[newPosition.z][newPosition.y][newPosition.x].unitId = unitId

        return true
    }

    // MARK: - Item Management

    /// Adds an item to the world
    /// - Parameter item: The item to add
    /// - Returns: The ID of the added item
    @discardableResult
    public func addItem(_ item: Item) -> UInt64 {
        items[item.id] = item

        // Add item to tile
        if isValidPosition(item.position) {
            tiles[item.position.z][item.position.y][item.position.x].addItem(item.id)
        }

        return item.id
    }

    /// Removes an item from the world
    /// - Parameter id: The ID of the item to remove
    public func removeItem(id: UInt64) {
        guard let item = items[id] else { return }

        // Remove from tile
        if isValidPosition(item.position) {
            tiles[item.position.z][item.position.y][item.position.x].removeItem(id)
        }

        items.removeValue(forKey: id)
    }

    /// Gets an item by ID
    /// - Parameter id: The item ID
    /// - Returns: The item, or nil if not found
    public func getItem(id: UInt64) -> Item? {
        items[id]
    }

    /// Moves an item to a new position
    /// - Parameters:
    ///   - itemId: The ID of the item to move
    ///   - newPosition: The destination position
    /// - Returns: True if the move was successful
    @discardableResult
    public func moveItem(_ itemId: UInt64, to newPosition: Position) -> Bool {
        guard var item = items[itemId] else { return false }
        guard isValidPosition(newPosition) else { return false }

        let oldPosition = item.position

        // Remove from old tile
        if isValidPosition(oldPosition) {
            tiles[oldPosition.z][oldPosition.y][oldPosition.x].removeItem(itemId)
        }

        // Update item position
        item.position = newPosition
        items[itemId] = item

        // Add to new tile
        tiles[newPosition.z][newPosition.y][newPosition.x].addItem(itemId)

        return true
    }

    // MARK: - Queries

    /// Gets all units within a radius of a position
    /// - Parameters:
    ///   - position: The center position
    ///   - radius: The search radius (Chebyshev distance)
    /// - Returns: Array of units within range
    public func getUnitsInRange(of position: Position, radius: Int) -> [Unit] {
        var result: [Unit] = []

        for unit in units.values {
            guard unit.position.z == position.z else { continue }

            let dx = abs(unit.position.x - position.x)
            let dy = abs(unit.position.y - position.y)
            let distance = max(dx, dy)

            if distance <= radius {
                result.append(unit)
            }
        }

        return result
    }

    /// Finds the nearest item of a specific type
    /// - Parameters:
    ///   - type: The item type to search for
    ///   - position: The position to search from
    /// - Returns: The nearest item of that type, or nil if none found
    public func findNearestItem(of type: ItemType, from position: Position) -> Item? {
        var nearestItem: Item?
        var nearestDistance = Double.infinity

        for item in items.values {
            guard item.itemType == type else { continue }

            let distance = position.euclideanDistance(to: item.position)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestItem = item
            }
        }

        return nearestItem
    }

    /// Finds all items of a specific type
    /// - Parameter type: The item type to search for
    /// - Returns: Array of items of that type
    public func findItems(of type: ItemType) -> [Item] {
        items.values.filter { $0.itemType == type }
    }

    /// Gets all items at a specific position
    /// - Parameter position: The position to check
    /// - Returns: Array of items at that position
    public func getItems(at position: Position) -> [Item] {
        guard let tile = getTile(at: position) else { return [] }
        return tile.itemIds.compactMap { items[$0] }
    }

    // MARK: - Pathfinding

    /// Finds a path from one position to another using A* algorithm with 3D support
    /// - Parameters:
    ///   - from: Starting position
    ///   - to: Destination position
    /// - Returns: Array of positions forming the path, or nil if no path exists
    public func findPath(from: Position, to: Position) -> [Position]? {
        // Early exit if destination is invalid or impassable
        guard isValidPosition(to) else { return nil }
        guard let destTile = getTile(at: to), destTile.isPassable else { return nil }

        // If already at destination
        if from == to { return [from] }

        // A* implementation using a simple priority queue
        var openSet = PriorityQueue<PathNode>()
        var closedSet = Set<Position>()
        var cameFrom: [Position: Position] = [:]
        var gScore: [Position: Double] = [from: 0]

        let heuristic = { (pos: Position) -> Double in
            // Use 3D diagonal distance (Chebyshev with z-level cost)
            let dx = abs(pos.x - to.x)
            let dy = abs(pos.y - to.y)
            let dz = abs(pos.z - to.z)
            // Z-level changes are more expensive
            return Double(max(dx, dy)) + 0.414 * Double(min(dx, dy)) + Double(dz) * 2.0
        }

        openSet.insert(PathNode(position: from, priority: heuristic(from)))

        while let currentNode = openSet.extractMin() {
            let current = currentNode.position

            if current == to {
                // Reconstruct path
                var path: [Position] = [current]
                var node = current
                while let prev = cameFrom[node] {
                    path.insert(prev, at: 0)
                    node = prev
                }
                return path
            }

            closedSet.insert(current)

            // Get all possible neighbors (including z-level changes)
            let neighbors = getPathfindingNeighbors(from: current)

            for neighbor in neighbors {
                guard !closedSet.contains(neighbor) else { continue }
                guard let tile = getTile(at: neighbor), tile.isPassable else { continue }

                // Allow destination even if occupied
                if neighbor != to && tile.unitId != nil { continue }

                // Calculate movement cost
                let moveCost = calculateMovementCost(from: current, to: neighbor, tile: tile)

                let tentativeG = gScore[current, default: .infinity] + moveCost

                if tentativeG < gScore[neighbor, default: .infinity] {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeG
                    let fScore = tentativeG + heuristic(neighbor)
                    openSet.insert(PathNode(position: neighbor, priority: fScore))
                }
            }
        }

        // No path found
        return nil
    }

    /// Get all valid neighbors for pathfinding, including z-level transitions
    private func getPathfindingNeighbors(from position: Position) -> [Position] {
        var neighbors: [Position] = []

        guard let currentTile = getTile(at: position) else { return neighbors }

        // Check all 8 horizontal neighbors on the same z-level
        for direction in Direction.allCases {
            let neighbor = position.moved(in: direction)
            if isValidPosition(neighbor) {
                neighbors.append(neighbor)
            }
        }

        // Check z-level transitions
        let terrain = currentTile.terrain

        // Can we go up?
        if terrain.allowsMovementUp && position.z + 1 < depth {
            let above = Position(x: position.x, y: position.y, z: position.z + 1)
            if isValidPosition(above) {
                if let aboveTile = getTile(at: above), aboveTile.isPassable {
                    // If current is ramp, check the tile above is accessible
                    if terrain == .rampUp || terrain == .stairsUp || terrain == .stairsUpDown {
                        neighbors.append(above)
                    }
                }
            }
        }

        // Can we go down?
        if terrain.allowsMovementDown && position.z > 0 {
            let below = Position(x: position.x, y: position.y, z: position.z - 1)
            if isValidPosition(below) {
                if let belowTile = getTile(at: below), belowTile.isPassable {
                    neighbors.append(below)
                }
            }
        }

        // Also check if we can go down via stairs/ramp below us
        if position.z > 0 {
            let below = Position(x: position.x, y: position.y, z: position.z - 1)
            if isValidPosition(below) {
                if let belowTile = getTile(at: below) {
                    let belowTerrain = belowTile.terrain
                    if belowTerrain.allowsMovementUp && belowTile.isPassable {
                        if !neighbors.contains(below) {
                            neighbors.append(below)
                        }
                    }
                }
            }
        }

        return neighbors
    }

    /// Calculate movement cost between two positions
    private func calculateMovementCost(from: Position, to: Position, tile: Tile) -> Double {
        // Z-level change cost
        if from.z != to.z {
            return 2.0 * tile.movementCost
        }

        // Diagonal movement on same level
        let dx = abs(from.x - to.x)
        let dy = abs(from.y - to.y)
        let isDiagonal = dx + dy == 2

        let baseCost = isDiagonal ? 1.414 : 1.0
        return baseCost * tile.movementCost
    }

    // MARK: - Simulation

    /// Advances the simulation by one tick
    public func tick() {
        currentTick += 1
    }

    // MARK: - Display

    /// Generates a string representation of a z-level for display
    /// - Parameter z: The z-level to display
    /// - Returns: A string showing the map
    public func displayLevel(_ z: Int = 0) -> String {
        guard z >= 0 && z < depth else { return "" }

        var result = ""
        for y in 0..<height {
            for x in 0..<width {
                result.append(tiles[z][y][x].displayChar)
            }
            result.append("\n")
        }
        return result
    }

    // MARK: - Mining & Terrain Modification

    /// Mine out a tile, converting wall/stone to floor
    /// - Parameter position: Position to mine
    /// - Returns: Item produced by mining (stone, ore), or nil
    @discardableResult
    public func mineTile(at position: Position) -> Item? {
        guard isValidPosition(position) else { return nil }
        guard var tile = getTile(at: position) else { return nil }

        let terrain = tile.terrain

        // Can only mine mineable terrain
        guard terrain.isMinable else { return nil }

        // Determine what item is produced
        var resultItem: Item?
        switch terrain {
        case .wall, .stone:
            tile.terrain = .stoneFloor
            resultItem = Item.create(type: .stone, at: position, quality: .standard)
        case .ore:
            tile.terrain = .stoneFloor
            resultItem = Item.create(type: .ore, at: position, quality: .standard)
        default:
            return nil
        }

        // Update the tile
        tiles[position.z][position.y][position.x] = tile

        // Add item to world if produced
        if let item = resultItem {
            addItem(item)
        }

        return resultItem
    }

    /// Carve stairs at a position
    /// - Parameters:
    ///   - position: Position to carve
    ///   - type: Type of stairs (up, down, upDown)
    /// - Returns: Whether carving succeeded
    @discardableResult
    public func carveStairs(at position: Position, type: TerrainType) -> Bool {
        guard isValidPosition(position) else { return false }
        guard type == .stairsUp || type == .stairsDown || type == .stairsUpDown else { return false }

        var tile = tiles[position.z][position.y][position.x]

        // Can only carve in minable terrain or floors
        guard tile.terrain.isMinable || tile.terrain == .stoneFloor || tile.terrain == .dirt else {
            return false
        }

        tile.terrain = type
        tiles[position.z][position.y][position.x] = tile

        // If carving down stairs, also need to ensure the level below is accessible
        if (type == .stairsDown || type == .stairsUpDown) && position.z > 0 {
            let belowPos = Position(x: position.x, y: position.y, z: position.z - 1)
            var belowTile = tiles[belowPos.z][belowPos.y][belowPos.x]

            // If below is solid, carve it out with up stairs
            if belowTile.terrain.isMinable {
                belowTile.terrain = .stairsUp
                tiles[belowPos.z][belowPos.y][belowPos.x] = belowTile
            }
        }

        return true
    }

    /// Carve a ramp at a position
    @discardableResult
    public func carveRamp(at position: Position) -> Bool {
        guard isValidPosition(position) else { return false }

        var tile = tiles[position.z][position.y][position.x]
        guard tile.terrain.isMinable else { return false }

        tile.terrain = .rampUp
        tiles[position.z][position.y][position.x] = tile

        // Create ramp down entry point on level above
        if position.z + 1 < depth {
            let abovePos = Position(x: position.x, y: position.y, z: position.z + 1)
            var aboveTile = tiles[abovePos.z][abovePos.y][abovePos.x]
            if aboveTile.terrain == .emptyAir || aboveTile.terrain == .grass {
                aboveTile.terrain = .rampDown
                tiles[abovePos.z][abovePos.y][abovePos.x] = aboveTile
            }
        }

        return true
    }

    /// Channel out a tile (remove floor, create hole to level below)
    @discardableResult
    public func channelTile(at position: Position) -> Bool {
        guard isValidPosition(position) else { return false }

        var tile = tiles[position.z][position.y][position.x]
        guard tile.terrain.isPassable && !tile.terrain.isMinable else { return false }

        // Turn current tile into empty air
        tile.terrain = .emptyAir
        tiles[position.z][position.y][position.x] = tile

        // If there's a level below, create a ramp down entry
        if position.z > 0 {
            let belowPos = Position(x: position.x, y: position.y, z: position.z - 1)
            var belowTile = tiles[belowPos.z][belowPos.y][belowPos.x]
            if belowTile.terrain.isMinable {
                belowTile.terrain = .rampUp
                tiles[belowPos.z][belowPos.y][belowPos.x] = belowTile
            }
        }

        return true
    }

    // MARK: - Multi-Level Terrain Generation

    /// Generates a fortress-style multi-level world
    /// Call this after init for a proper underground fortress map
    public func generateFortressTerrain() {
        guard depth > 1 else { return }

        // Level 0 (surface): Keep existing terrain generation

        // Underground levels: solid rock with some features
        for z in 1..<depth {
            for y in 0..<height {
                for x in 0..<width {
                    // Underground is mostly wall/rock
                    if Double.random(in: 0...1) < 0.95 {
                        tiles[z][y][x].terrain = .wall
                    } else if Double.random(in: 0...1) < 0.3 {
                        // Some ore veins
                        tiles[z][y][x].terrain = .ore
                    } else {
                        tiles[z][y][x].terrain = .stone
                    }
                }
            }

            // Add some natural cavities/caves
            let cavityCount = Int.random(in: 0...2)
            for _ in 0..<cavityCount {
                let cx = Int.random(in: 5..<(width - 5))
                let cy = Int.random(in: 5..<(height - 5))
                let radius = Int.random(in: 2...4)

                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let x = cx + dx
                        let y = cy + dy
                        guard x >= 0, x < width, y >= 0, y < height else { continue }

                        let distance = sqrt(Double(dx * dx + dy * dy))
                        if distance <= Double(radius) * 0.8 {
                            tiles[z][y][x].terrain = .stoneFloor
                        }
                    }
                }
            }
        }

        // Create a starting entrance (stairs from surface to z=1)
        let entranceX = width / 2
        let entranceY = height / 2

        // Clear surface area around entrance
        for dy in -1...1 {
            for dx in -1...1 {
                let x = entranceX + dx
                let y = entranceY + dy
                if x >= 0 && x < width && y >= 0 && y < height {
                    if tiles[0][y][x].terrain == .tree || tiles[0][y][x].terrain == .shrub {
                        tiles[0][y][x].terrain = .grass
                    }
                }
            }
        }

        // Create stairs down at entrance
        tiles[0][entranceY][entranceX].terrain = .stairsDown

        // Create stairs up on first underground level
        if depth > 1 {
            tiles[1][entranceY][entranceX].terrain = .stairsUpDown
        }

        // Connect underground levels with stairs
        for z in 2..<depth {
            tiles[z][entranceY][entranceX].terrain = .stairsUpDown
        }
    }
}

// MARK: - Path Node for A* Algorithm

/// A node in the pathfinding priority queue
private struct PathNode: Comparable {
    let position: Position
    let priority: Double

    static func < (lhs: PathNode, rhs: PathNode) -> Bool {
        lhs.priority < rhs.priority
    }
}

// MARK: - Priority Queue Implementation

/// A simple min-heap priority queue for pathfinding
private struct PriorityQueue<Element: Comparable> {
    private var heap: [Element] = []

    var isEmpty: Bool { heap.isEmpty }
    var count: Int { heap.count }

    mutating func insert(_ element: Element) {
        heap.append(element)
        siftUp(from: heap.count - 1)
    }

    mutating func extractMin() -> Element? {
        guard !heap.isEmpty else { return nil }

        if heap.count == 1 {
            return heap.removeLast()
        }

        let min = heap[0]
        heap[0] = heap.removeLast()
        siftDown(from: 0)
        return min
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        var parent = (child - 1) / 2

        while child > 0 && heap[child] < heap[parent] {
            heap.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index

        while true {
            let leftChild = 2 * parent + 1
            let rightChild = 2 * parent + 2
            var candidate = parent

            if leftChild < heap.count && heap[leftChild] < heap[candidate] {
                candidate = leftChild
            }

            if rightChild < heap.count && heap[rightChild] < heap[candidate] {
                candidate = rightChild
            }

            if candidate == parent {
                return
            }

            heap.swapAt(parent, candidate)
            parent = candidate
        }
    }
}
