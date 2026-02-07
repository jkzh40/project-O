// MARK: - Heightmap Generator
// Stage 2: Multi-octave noise blended with tectonic data for detailed elevation

import Foundation
import OutpostCore

/// Generates detailed heightmap by blending tectonic coarse elevation with multi-octave noise
struct HeightmapGenerator: Sendable {

    /// Generate the detailed heightmap
    /// - Parameters:
    ///   - map: World map with tectonic data already computed
    ///   - noise: Simplex noise generator
    ///   - rng: Seeded RNG
    static func generate(map: inout WorldMap, noise: SimplexNoise, rng: inout SeededRNG) {
        let size = map.size
        let invSize = 1.0 / Double(size)

        // Generate noise-based heightmap
        for y in 0..<size {
            for x in 0..<size {
                let nx = Double(x) * invSize
                let ny = Double(y) * invSize

                // Base continental shape using fBm
                let baseNoise = NoiseUtilities.fbm(
                    noise: noise,
                    x: nx, y: ny,
                    octaves: 6,
                    frequency: 3.0,
                    lacunarity: 2.0,
                    persistence: 0.5
                )

                // Mountain ridges using ridged multifractal
                let ridgeNoise = NoiseUtilities.ridgedMultifractal(
                    noise: noise,
                    x: nx, y: ny,
                    octaves: 5,
                    frequency: 2.0,
                    lacunarity: 2.2,
                    gain: 2.0
                )

                // Domain-warped detail for organic feel
                let warpedDetail = NoiseUtilities.domainWarp(
                    noise: noise,
                    x: nx + 100.0, y: ny + 100.0,
                    frequency: 4.0,
                    warpStrength: 0.3,
                    octaves: 3
                )

                // Get tectonic coarse elevation
                let tectonicElev = Double(map[x, y].elevation)
                let stress = Double(map[x, y].boundaryStress)

                // Blend: tectonic provides large-scale shape, noise adds detail
                var elevation = tectonicElev * 0.5                  // 50% tectonic
                    + (baseNoise * 0.5 + 0.5) * 0.25               // 25% fBm continents
                    + ridgeNoise * stress * 0.15                    // 15% ridges at boundaries
                    + warpedDetail * 0.1                            // 10% organic detail

                // Edge falloff — push edges toward ocean
                let edgeFalloff = computeEdgeFalloff(x: x, y: y, size: size)
                elevation *= edgeFalloff

                // Clamp
                elevation = max(0.0, min(1.0, elevation))

                map[x, y].elevation = Float(elevation)
            }
        }

        // Smooth pass to reduce noise artifacts at plate transitions
        smoothElevation(map: &map, size: size, iterations: 2)
    }

    // MARK: - Edge Falloff

    /// Creates a smooth falloff near map edges to create an ocean border
    private static func computeEdgeFalloff(x: Int, y: Int, size: Int) -> Double {
        let margin = Double(size) * 0.1 // 10% margin
        let fx = Double(x)
        let fy = Double(y)
        let fs = Double(size)

        let left = NoiseUtilities.smoothstep(0, margin, fx)
        let right = NoiseUtilities.smoothstep(0, margin, fs - fx)
        let top = NoiseUtilities.smoothstep(0, margin, fy)
        let bottom = NoiseUtilities.smoothstep(0, margin, fs - fy)

        return min(min(left, right), min(top, bottom))
    }

    // MARK: - Smoothing

    /// Box-blur smoothing pass for elevation
    private static func smoothElevation(map: inout WorldMap, size: Int, iterations: Int) {
        for _ in 0..<iterations {
            var buffer = [Float](repeating: 0, count: size * size)

            for y in 0..<size {
                for x in 0..<size {
                    var sum: Float = 0
                    var count: Float = 0

                    for dy in -1...1 {
                        for dx in -1...1 {
                            let nx = x + dx
                            let ny = y + dy
                            if map.isValid(x: nx, y: ny) {
                                sum += map[nx, ny].elevation
                                count += 1
                            }
                        }
                    }

                    // Weighted: 60% original + 40% average of neighbors
                    buffer[y * size + x] = map[x, y].elevation * 0.6 + (sum / count) * 0.4
                }
            }

            for y in 0..<size {
                for x in 0..<size {
                    map[x, y].elevation = buffer[y * size + x]
                }
            }
        }
    }
}
