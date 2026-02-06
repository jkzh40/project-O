// MARK: - Tectonic Simulator
// Stage 1: Voronoi-based tectonic plates with drift vectors and boundary classification

import Foundation

/// Generates tectonic plates using Voronoi tessellation with drift vectors
struct TectonicSimulator: Sendable {

    /// Run tectonic simulation on a world map
    /// - Parameters:
    ///   - map: The world map to modify (plates + coarse elevation + boundary data)
    ///   - params: World generation parameters
    ///   - rng: Seeded RNG (will be mutated)
    static func simulate(map: inout WorldMap, params: WorldGenParameters, rng: inout SeededRNG) {
        let size = map.size
        let plateCount = params.plateCount

        // Generate plate centers and properties
        var plates: [TectonicPlate] = []
        for i in 0..<plateCount {
            let cx = rng.nextDouble() * Double(size)
            let cy = rng.nextDouble() * Double(size)
            let dx = rng.nextDouble(in: -1.0...1.0)
            let dy = rng.nextDouble(in: -1.0...1.0)
            // ~40% of plates are oceanic
            let oceanic = rng.nextBool(probability: 0.4)
            plates.append(TectonicPlate(id: i, centerX: cx, centerY: cy, driftX: dx, driftY: dy, isOceanic: oceanic))
        }
        map.plates = plates

        // Assign each cell to nearest plate (Voronoi)
        for y in 0..<size {
            for x in 0..<size {
                var minDist = Double.infinity
                var nearestPlate = 0

                for plate in plates {
                    // Wrap-aware distance for better edge behavior
                    let dx = min(
                        abs(Double(x) - plate.centerX),
                        Double(size) - abs(Double(x) - plate.centerX)
                    )
                    let dy = min(
                        abs(Double(y) - plate.centerY),
                        Double(size) - abs(Double(y) - plate.centerY)
                    )
                    let dist = dx * dx + dy * dy
                    if dist < minDist {
                        minDist = dist
                        nearestPlate = plate.id
                    }
                }

                map[x, y].plateId = nearestPlate
            }
        }

        // Classify boundaries and compute stress
        classifyBoundaries(map: &map, plates: plates, size: size)

        // Set coarse elevation from plates
        setCoarseElevation(map: &map, plates: plates, size: size, rng: &rng)
    }

    // MARK: - Boundary Classification

    private static func classifyBoundaries(map: inout WorldMap, plates: [TectonicPlate], size: Int) {
        for y in 0..<size {
            for x in 0..<size {
                let myPlate = map[x, y].plateId

                // Check if any neighbor has a different plate
                var isBoundary = false
                var neighborPlateId = myPlate

                for offset in WorldMap.neighborOffsets {
                    let nx = x + offset.dx
                    let ny = y + offset.dy
                    guard map.isValid(x: nx, y: ny) else { continue }

                    if map[nx, ny].plateId != myPlate {
                        isBoundary = true
                        neighborPlateId = map[nx, ny].plateId
                        break
                    }
                }

                if isBoundary {
                    let p1 = plates[myPlate]
                    let p2 = plates[neighborPlateId]

                    // Compute relative motion between plates
                    let relativeX = p1.driftX - p2.driftX
                    let relativeY = p1.driftY - p2.driftY

                    // Direction from plate 1 center to plate 2 center
                    let toOtherX = p2.centerX - p1.centerX
                    let toOtherY = p2.centerY - p1.centerY
                    let dist = sqrt(toOtherX * toOtherX + toOtherY * toOtherY)

                    if dist > 0 {
                        let normX = toOtherX / dist
                        let normY = toOtherY / dist

                        // Dot product: positive = convergent, negative = divergent
                        let dot = relativeX * normX + relativeY * normY
                        // Cross product magnitude: high = transform
                        let cross = abs(relativeX * normY - relativeY * normX)

                        if abs(dot) > cross {
                            map[x, y].boundaryType = dot > 0 ? .convergent : .divergent
                        } else {
                            map[x, y].boundaryType = .transform
                        }
                    } else {
                        map[x, y].boundaryType = .convergent
                    }

                    // Stress is based on relative speed
                    let speed = sqrt(relativeX * relativeX + relativeY * relativeY)
                    map[x, y].boundaryStress = Float(min(speed / 2.0, 1.0))
                }
            }
        }

        // Spread boundary influence to nearby cells (smoothing)
        spreadBoundaryInfluence(map: &map, size: size, radius: 8)
    }

    private static func spreadBoundaryInfluence(map: inout WorldMap, size: Int, radius: Int) {
        // Build a stress buffer from boundary cells
        var stressBuffer = [Float](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                if map[x, y].boundaryType != .none {
                    stressBuffer[y * size + x] = map[x, y].boundaryStress
                }
            }
        }

        // Simple radial spread (approximate Gaussian blur)
        var spreadBuffer = stressBuffer
        for y in 0..<size {
            for x in 0..<size {
                guard stressBuffer[y * size + x] > 0 else { continue }
                let centerStress = stressBuffer[y * size + x]

                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let nx = x + dx
                        let ny = y + dy
                        guard nx >= 0, nx < size, ny >= 0, ny < size else { continue }

                        let dist = sqrt(Float(dx * dx + dy * dy))
                        let falloff = max(0, 1.0 - dist / Float(radius))
                        let contribution = centerStress * falloff * 0.5
                        let idx = ny * size + nx
                        spreadBuffer[idx] = max(spreadBuffer[idx], contribution)
                    }
                }
            }
        }

        // Write back
        for y in 0..<size {
            for x in 0..<size {
                let existing = map[x, y].boundaryStress
                map[x, y].boundaryStress = max(existing, spreadBuffer[y * size + x])
            }
        }
    }

    // MARK: - Coarse Elevation

    private static func setCoarseElevation(map: inout WorldMap, plates: [TectonicPlate], size: Int, rng: inout SeededRNG) {
        for y in 0..<size {
            for x in 0..<size {
                let plate = plates[map[x, y].plateId]
                var elev: Float

                if plate.isOceanic {
                    // Oceanic plates: low base elevation
                    elev = Float(rng.nextDouble(in: 0.1...0.3))
                } else {
                    // Continental plates: moderate base elevation
                    elev = Float(rng.nextDouble(in: 0.35...0.55))
                }

                // Boundary effects
                let stress = map[x, y].boundaryStress
                switch map[x, y].boundaryType {
                case .convergent:
                    // Mountain building at convergent boundaries
                    if !plate.isOceanic {
                        elev += stress * 0.4
                    } else {
                        elev += stress * 0.15 // Volcanic islands
                    }
                case .divergent:
                    // Rift valleys at divergent boundaries
                    elev -= stress * 0.15
                case .transform:
                    // Moderate effect
                    elev += stress * 0.05
                case .none:
                    break
                }

                map[x, y].elevation = max(0, min(1, elev))
            }
        }
    }
}
