// MARK: - Erosion Simulator
// Stage 3: Hydraulic droplet erosion + thermal talus erosion

import Foundation

/// Simulates hydraulic and thermal erosion on the heightmap
public struct ErosionSimulator: Sendable {

    // MARK: - Hydraulic Erosion Parameters

    private struct DropletParams {
        let inertia: Float = 0.05
        let capacity: Float = 4.0
        let deposition: Float = 0.3
        let erosion: Float = 0.3
        let evaporation: Float = 0.01
        let minSlope: Float = 0.01
        let gravity: Float = 4.0
        let maxLifetime: Int = 60
        let erosionRadius: Int = 3
    }

    /// Run erosion simulation on the world map
    /// - Parameters:
    ///   - map: World map with elevation data
    ///   - params: Generation parameters (controls droplet count)
    ///   - rng: Seeded RNG
    public static func simulate(map: inout WorldMap, params: WorldGenParameters, rng: inout SeededRNG) {
        let size = map.size

        // Extract elevation to a flat Float array for performance
        var elevation = [Float](repeating: 0, count: size * size)
        for i in 0..<(size * size) {
            elevation[i] = map.cells[i].elevation
        }

        // Hydraulic erosion
        hydraulicErosion(
            elevation: &elevation,
            size: size,
            dropletCount: params.erosionDroplets,
            rng: &rng
        )

        // Thermal erosion
        thermalErosion(elevation: &elevation, size: size, iterations: 5)

        // Write back and compute sediment delta
        for i in 0..<(size * size) {
            let delta = elevation[i] - map.cells[i].elevation
            map.cells[i].elevation = elevation[i]
            if delta > 0 {
                map.cells[i].sediment = delta
            }
        }
    }

    // MARK: - Hydraulic Erosion

    private static func hydraulicErosion(
        elevation: inout [Float],
        size: Int,
        dropletCount: Int,
        rng: inout SeededRNG
    ) {
        let p = DropletParams()

        for _ in 0..<dropletCount {
            var posX = Float(rng.nextDouble()) * Float(size - 2) + 1
            var posY = Float(rng.nextDouble()) * Float(size - 2) + 1
            var dirX: Float = 0
            var dirY: Float = 0
            var speed: Float = 1
            var water: Float = 1
            var sediment: Float = 0

            for _ in 0..<p.maxLifetime {
                let cellX = Int(posX)
                let cellY = Int(posY)

                // Bilinear offset within cell
                let offsetX = posX - Float(cellX)
                let offsetY = posY - Float(cellY)

                // Compute gradient via bilinear interpolation
                let (gradX, gradY, height) = computeGradient(
                    elevation: elevation,
                    size: size,
                    x: cellX, y: cellY,
                    offsetX: offsetX, offsetY: offsetY
                )

                // Update direction with inertia
                dirX = dirX * p.inertia - gradX * (1 - p.inertia)
                dirY = dirY * p.inertia - gradY * (1 - p.inertia)

                // Normalize direction
                let dirLen = sqrt(dirX * dirX + dirY * dirY)
                if dirLen > 0 {
                    dirX /= dirLen
                    dirY /= dirLen
                }

                // Move droplet
                let newPosX = posX + dirX
                let newPosY = posY + dirY

                // Check bounds
                let newCellX = Int(newPosX)
                let newCellY = Int(newPosY)
                guard newCellX >= 1, newCellX < size - 1,
                      newCellY >= 1, newCellY < size - 1 else { break }

                // Compute new height
                let newOffX = newPosX - Float(newCellX)
                let newOffY = newPosY - Float(newCellY)
                let (_, _, newHeight) = computeGradient(
                    elevation: elevation,
                    size: size,
                    x: newCellX, y: newCellY,
                    offsetX: newOffX, offsetY: newOffY
                )

                let heightDiff = newHeight - height

                // Compute sediment capacity
                let slopeAngle = max(-heightDiff, p.minSlope)
                let sedimentCapacity = slopeAngle * speed * water * p.capacity

                if sediment > sedimentCapacity || heightDiff > 0 {
                    // Deposit sediment
                    let depositAmount: Float
                    if heightDiff > 0 {
                        depositAmount = min(sediment, heightDiff)
                    } else {
                        depositAmount = (sediment - sedimentCapacity) * p.deposition
                    }
                    sediment -= depositAmount
                    depositSediment(
                        elevation: &elevation, size: size,
                        x: cellX, y: cellY,
                        offsetX: offsetX, offsetY: offsetY,
                        amount: depositAmount
                    )
                } else {
                    // Erode
                    let erodeAmount = min(
                        (sedimentCapacity - sediment) * p.erosion,
                        -heightDiff
                    )
                    erodeTerrain(
                        elevation: &elevation, size: size,
                        x: cellX, y: cellY,
                        radius: p.erosionRadius,
                        amount: erodeAmount
                    )
                    sediment += erodeAmount
                }

                // Update speed and water
                speed = sqrt(max(speed * speed + heightDiff * p.gravity, 0))
                water *= (1 - p.evaporation)

                posX = newPosX
                posY = newPosY

                if water < 0.001 { break }
            }
        }
    }

    // MARK: - Gradient Computation

    private static func computeGradient(
        elevation: [Float],
        size: Int,
        x: Int, y: Int,
        offsetX: Float, offsetY: Float
    ) -> (gradX: Float, gradY: Float, height: Float) {
        let idx = y * size + x
        let h00 = elevation[idx]
        let h10 = (x + 1 < size) ? elevation[idx + 1] : h00
        let h01 = (y + 1 < size) ? elevation[idx + size] : h00
        let h11 = (x + 1 < size && y + 1 < size) ? elevation[idx + size + 1] : h00

        let gradX = (h10 - h00) * (1 - offsetY) + (h11 - h01) * offsetY
        let gradY = (h01 - h00) * (1 - offsetX) + (h11 - h10) * offsetX
        let height = h00 * (1 - offsetX) * (1 - offsetY)
            + h10 * offsetX * (1 - offsetY)
            + h01 * (1 - offsetX) * offsetY
            + h11 * offsetX * offsetY

        return (gradX, gradY, height)
    }

    // MARK: - Deposit/Erode

    private static func depositSediment(
        elevation: inout [Float], size: Int,
        x: Int, y: Int,
        offsetX: Float, offsetY: Float,
        amount: Float
    ) {
        let idx = y * size + x
        elevation[idx] += amount * (1 - offsetX) * (1 - offsetY)
        if x + 1 < size { elevation[idx + 1] += amount * offsetX * (1 - offsetY) }
        if y + 1 < size { elevation[idx + size] += amount * (1 - offsetX) * offsetY }
        if x + 1 < size && y + 1 < size { elevation[idx + size + 1] += amount * offsetX * offsetY }
    }

    private static func erodeTerrain(
        elevation: inout [Float], size: Int,
        x: Int, y: Int,
        radius: Int,
        amount: Float
    ) {
        // Distribute erosion in a weighted circle
        var totalWeight: Float = 0
        var weights: [(idx: Int, w: Float)] = []

        for dy in -radius...radius {
            for dx in -radius...radius {
                let nx = x + dx
                let ny = y + dy
                guard nx >= 0, nx < size, ny >= 0, ny < size else { continue }

                let dist = sqrt(Float(dx * dx + dy * dy))
                if dist <= Float(radius) {
                    let w = max(0, Float(radius) - dist)
                    weights.append((ny * size + nx, w))
                    totalWeight += w
                }
            }
        }

        guard totalWeight > 0 else { return }

        for (idx, w) in weights {
            elevation[idx] -= amount * (w / totalWeight)
        }
    }

    // MARK: - Thermal Erosion

    /// Thermal talus erosion: material slides to lower neighbors when slope exceeds threshold
    private static func thermalErosion(elevation: inout [Float], size: Int, iterations: Int) {
        let talusAngle: Float = 0.02 // Maximum stable slope difference

        for _ in 0..<iterations {
            for y in 1..<(size - 1) {
                for x in 1..<(size - 1) {
                    let idx = y * size + x
                    let h = elevation[idx]

                    // Find lowest neighbor
                    var minNeighborH = h
                    var minNeighborIdx = idx

                    for offset in WorldMap.neighborOffsets {
                        let nx = x + offset.dx
                        let ny = y + offset.dy
                        guard nx >= 0, nx < size, ny >= 0, ny < size else { continue }
                        let ni = ny * size + nx
                        if elevation[ni] < minNeighborH {
                            minNeighborH = elevation[ni]
                            minNeighborIdx = ni
                        }
                    }

                    let diff = h - minNeighborH
                    if diff > talusAngle {
                        let transfer = (diff - talusAngle) * 0.5
                        elevation[idx] -= transfer
                        elevation[minNeighborIdx] += transfer
                    }
                }
            }
        }
    }
}
