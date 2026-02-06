// MARK: - Hydrology Simulator
// Stage 5: Flow direction, accumulation, sink filling, river tracing

import Foundation

/// Simulates water flow: direction fields, river paths, and lake formation
struct HydrologySimulator: Sendable {

    /// Run hydrology simulation
    /// - Parameters:
    ///   - map: World map with elevation and climate data
    ///   - rng: Seeded RNG
    static func simulate(map: inout WorldMap, rng: inout SeededRNG) {
        let size = map.size

        // Step 1: Fill sinks (depressionless elevation)
        var elevation = extractElevation(map: map, size: size)
        fillSinks(elevation: &elevation, size: size)

        // Step 2: Compute flow directions (steepest descent)
        let flowDirs = computeFlowDirections(elevation: elevation, size: size)
        for y in 0..<size {
            for x in 0..<size {
                map[x, y].flowDirection = flowDirs[y * size + x]
            }
        }

        // Step 3: Compute flow accumulation
        let accumulation = computeFlowAccumulation(flowDirs: flowDirs, size: size)
        for y in 0..<size {
            for x in 0..<size {
                map[x, y].flowAccumulation = accumulation[y * size + x]
            }
        }

        // Step 4: Trace rivers
        let rivers = traceRivers(
            map: &map,
            flowDirs: flowDirs,
            accumulation: accumulation,
            size: size,
            rng: &rng
        )
        map.rivers = rivers

        // Step 5: Identify lakes
        identifyLakes(map: &map, elevation: elevation, size: size)
    }

    // MARK: - Sink Filling

    private static func extractElevation(map: WorldMap, size: Int) -> [Float] {
        (0..<(size * size)).map { map.cells[$0].elevation }
    }

    /// Fill depressions using a simplified Planchon-Darboux algorithm
    private static func fillSinks(elevation: inout [Float], size: Int) {
        let seaLevel: Float = 0.3
        var filled = [Float](repeating: Float.greatestFiniteMagnitude, count: size * size)

        // Initialize edges to their actual elevation
        for y in 0..<size {
            for x in 0..<size {
                if x == 0 || x == size - 1 || y == 0 || y == size - 1 {
                    filled[y * size + x] = elevation[y * size + x]
                }
                // Also initialize ocean cells
                if elevation[y * size + x] < seaLevel {
                    filled[y * size + x] = elevation[y * size + x]
                }
            }
        }

        // Iteratively fill until stable
        var changed = true
        var iterations = 0
        let maxIterations = 200

        while changed && iterations < maxIterations {
            changed = false
            iterations += 1

            for y in 1..<(size - 1) {
                for x in 1..<(size - 1) {
                    let idx = y * size + x
                    if filled[idx] <= elevation[idx] { continue }

                    for offset in WorldMap.neighborOffsets {
                        let nx = x + offset.dx
                        let ny = y + offset.dy
                        guard nx >= 0, nx < size, ny >= 0, ny < size else { continue }

                        let neighborFilled = filled[ny * size + nx]
                        let epsilon: Float = 0.0001

                        if elevation[idx] >= neighborFilled + epsilon {
                            filled[idx] = elevation[idx]
                            changed = true
                        } else if filled[idx] > neighborFilled + epsilon {
                            filled[idx] = neighborFilled + epsilon
                            changed = true
                        }
                    }
                }
            }
        }

        // Apply filled elevation (only raise, never lower)
        for i in 0..<(size * size) {
            elevation[i] = max(elevation[i], filled[i])
        }
    }

    // MARK: - Flow Directions

    /// Compute flow direction for each cell (index into 8-neighbor offsets, or -1)
    private static func computeFlowDirections(elevation: [Float], size: Int) -> [Int] {
        var flowDirs = [Int](repeating: -1, count: size * size)
        let offsets = WorldMap.neighborOffsets

        for y in 0..<size {
            for x in 0..<size {
                let h = elevation[y * size + x]
                var steepestSlope: Float = 0
                var bestDir = -1

                for (i, offset) in offsets.enumerated() {
                    let nx = x + offset.dx
                    let ny = y + offset.dy
                    guard nx >= 0, nx < size, ny >= 0, ny < size else { continue }

                    let nh = elevation[ny * size + nx]
                    let isDiagonal = (abs(offset.dx) + abs(offset.dy)) == 2
                    let dist: Float = isDiagonal ? 1.414 : 1.0
                    let slope = (h - nh) / dist

                    if slope > steepestSlope {
                        steepestSlope = slope
                        bestDir = i
                    }
                }

                flowDirs[y * size + x] = bestDir
            }
        }

        return flowDirs
    }

    // MARK: - Flow Accumulation

    /// Compute flow accumulation: count of upstream cells draining through each cell
    private static func computeFlowAccumulation(flowDirs: [Int], size: Int) -> [Int] {
        var accumulation = [Int](repeating: 1, count: size * size)
        let offsets = WorldMap.neighborOffsets

        // Build a sorted list by elevation (would ideally use topological sort)
        // Simple approach: count in-degree, process cells with no incoming first
        var inDegree = [Int](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                let dir = flowDirs[y * size + x]
                guard dir >= 0 else { continue }

                let nx = x + offsets[dir].dx
                let ny = y + offsets[dir].dy
                guard nx >= 0, nx < size, ny >= 0, ny < size else { continue }

                inDegree[ny * size + nx] += 1
            }
        }

        // BFS from cells with in-degree 0
        var queue: [Int] = []
        for i in 0..<(size * size) {
            if inDegree[i] == 0 {
                queue.append(i)
            }
        }

        var head = 0
        while head < queue.count {
            let idx = queue[head]
            head += 1

            let x = idx % size
            let y = idx / size
            let dir = flowDirs[idx]
            guard dir >= 0 else { continue }

            let nx = x + offsets[dir].dx
            let ny = y + offsets[dir].dy
            guard nx >= 0, nx < size, ny >= 0, ny < size else { continue }

            let nidx = ny * size + nx
            accumulation[nidx] += accumulation[idx]

            inDegree[nidx] -= 1
            if inDegree[nidx] == 0 {
                queue.append(nidx)
            }
        }

        return accumulation
    }

    // MARK: - River Tracing

    /// Trace river paths from high-accumulation source cells
    private static func traceRivers(
        map: inout WorldMap,
        flowDirs: [Int],
        accumulation: [Int],
        size: Int,
        rng: inout SeededRNG
    ) -> [River] {
        let offsets = WorldMap.neighborOffsets
        let seaLevel: Float = 0.3
        let riverThreshold = size * 2 // Minimum accumulation to be a river

        // Find candidate source points
        var sources: [(x: Int, y: Int, acc: Int)] = []
        for y in 0..<size {
            for x in 0..<size {
                let acc = accumulation[y * size + x]
                if acc >= riverThreshold && map[x, y].elevation > seaLevel + 0.05 {
                    sources.append((x, y, acc))
                }
            }
        }

        // Sort by accumulation (highest first) and take top rivers
        sources.sort { $0.acc > $1.acc }
        let maxRivers = min(20, sources.count)
        var usedCells = Set<Int>()
        var rivers: [River] = []

        for i in 0..<maxRivers {
            let source = sources[i]
            let startIdx = source.y * size + source.x
            if usedCells.contains(startIdx) { continue }

            var river = River()
            var x = source.x
            var y = source.y
            var visited = Set<Int>()

            while true {
                let idx = y * size + x
                if visited.contains(idx) { break }
                visited.insert(idx)
                usedCells.insert(idx)

                river.path.append((x: x, y: y))
                map[x, y].isRiver = true

                // Stop at sea level or map edge
                if map[x, y].elevation < seaLevel { break }

                let dir = flowDirs[idx]
                guard dir >= 0 else { break }

                let nx = x + offsets[dir].dx
                let ny = y + offsets[dir].dy
                guard nx >= 0, nx < size, ny >= 0, ny < size else { break }

                x = nx
                y = ny
            }

            if river.path.count >= 5 {
                river.volume = Float(accumulation[source.y * size + source.x]) / Float(size * size)
                rivers.append(river)
            }
        }

        return rivers
    }

    // MARK: - Lake Identification

    /// Identify lakes: areas where water pools (low elevation surrounded by higher terrain)
    private static func identifyLakes(map: inout WorldMap, elevation: [Float], size: Int) {
        let seaLevel: Float = 0.3

        // Simple approach: find flat low areas with high incoming flow that aren't rivers
        for y in 2..<(size - 2) {
            for x in 2..<(size - 2) {
                let elev = map[x, y].elevation
                // Must be above sea level but below moderate elevation
                guard elev > seaLevel && elev < seaLevel + 0.1 else { continue }
                guard !map[x, y].isRiver else { continue }

                // Check if this cell has high moisture and high flow accumulation
                let acc = map[x, y].flowAccumulation
                let moisture = map[x, y].moisture

                if acc > size && moisture > 0.6 {
                    // Check if surrounded by higher terrain
                    var higherCount = 0
                    for offset in WorldMap.neighborOffsets {
                        let nx = x + offset.dx
                        let ny = y + offset.dy
                        if map.isValid(x: nx, y: ny) && map[nx, ny].elevation > elev {
                            higherCount += 1
                        }
                    }

                    if higherCount >= 5 {
                        map[x, y].isLake = true
                        map[x, y].waterDepth = 0.3 + map[x, y].moisture * 0.4
                    }
                }
            }
        }

        // Expand lakes slightly for more natural shapes
        var lakeExpansion: [(x: Int, y: Int)] = []
        for y in 1..<(size - 1) {
            for x in 1..<(size - 1) {
                guard map[x, y].isLake else { continue }
                for offset in WorldMap.neighborOffsets {
                    let nx = x + offset.dx
                    let ny = y + offset.dy
                    if map.isValid(x: nx, y: ny) && !map[nx, ny].isLake && !map[nx, ny].isRiver {
                        let neighborElev = map[nx, ny].elevation
                        if abs(neighborElev - map[x, y].elevation) < 0.02 {
                            lakeExpansion.append((nx, ny))
                        }
                    }
                }
            }
        }

        for pos in lakeExpansion {
            map[pos.x, pos.y].isLake = true
            map[pos.x, pos.y].waterDepth = 0.2
        }
    }
}
