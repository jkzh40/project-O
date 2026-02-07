// MARK: - Climate Simulator
// Stage 4: Temperature from latitude/elevation, wind bands, orographic rainfall

import Foundation
import OutpostCore

/// Simulates climate: temperature, wind, moisture, and rainfall
struct ClimateSimulator: Sendable {

    /// Run climate simulation
    /// - Parameters:
    ///   - map: World map with elevation data
    ///   - noise: Noise generator for variation
    ///   - rng: Seeded RNG
    static func simulate(map: inout WorldMap, noise: SimplexNoise, rng: inout SeededRNG) {
        let size = map.size

        // Pass 1: Base temperature from latitude and elevation
        computeBaseTemperature(map: &map, noise: noise, size: size)

        // Pass 2: Wind patterns (simplified atmospheric circulation)
        computeWindPatterns(map: &map, size: size)

        // Pass 3: Moisture transport and orographic rainfall
        computeMoistureAndRainfall(map: &map, noise: noise, size: size)
    }

    // MARK: - Temperature

    private static func computeBaseTemperature(map: inout WorldMap, noise: SimplexNoise, size: Int) {
        let invSize = 1.0 / Double(size)

        for y in 0..<size {
            for x in 0..<size {
                // Latitude effect: warm at equator (y = size/2), cold at poles
                let normalizedY = Double(y) * invSize
                let latitudeTemp = 1.0 - 2.0 * abs(normalizedY - 0.5)

                // Elevation cooling: -6.5°C per 1000m, normalized
                let elevation = Double(map[x, y].elevation)
                let elevationCooling = max(0, elevation - 0.3) * 1.5

                // Noise variation for local climate differences
                let nx = Double(x) * invSize
                let ny = Double(y) * invSize
                let tempNoise = noise.noise2D(x: nx * 4.0 + 200, y: ny * 4.0 + 200) * 0.1

                var temperature = latitudeTemp - elevationCooling + tempNoise

                // Ocean moderating effect
                if elevation < 0.3 {
                    let oceanModerate = (0.3 - elevation) / 0.3
                    temperature = temperature * (1.0 - oceanModerate * 0.3) + 0.5 * oceanModerate * 0.3
                }

                map[x, y].temperature = Float(max(0, min(1, temperature)))
            }
        }
    }

    // MARK: - Wind

    private static func computeWindPatterns(map: inout WorldMap, size: Int) {
        let invSize = 1.0 / Float(size)

        for y in 0..<size {
            let normalizedY = Float(y) * invSize

            // Simplified atmospheric bands:
            // 0.0-0.15: Polar easterlies (N hemisphere)
            // 0.15-0.5: Westerlies
            // 0.5: Equator (weak/variable)
            // Mirror for S hemisphere

            let latFromEquator = abs(normalizedY - 0.5) * 2.0 // 0 at equator, 1 at poles

            var windX: Float
            var windY: Float

            if latFromEquator > 0.7 {
                // Polar easterlies
                windX = normalizedY < 0.5 ? -0.5 : 0.5
                windY = normalizedY < 0.5 ? 0.3 : -0.3
            } else if latFromEquator > 0.2 {
                // Westerlies
                windX = normalizedY < 0.5 ? 0.8 : -0.8
                windY = normalizedY < 0.5 ? -0.2 : 0.2
            } else {
                // Trade winds / equatorial
                windX = normalizedY < 0.5 ? -0.6 : 0.6
                windY = 0.0
            }

            for x in 0..<size {
                // Terrain deflection: wind is reduced by mountains
                let elev = map[x, y].elevation
                if elev > 0.5 {
                    let reduction = (elev - 0.5) * 2.0
                    windX *= (1.0 - reduction * 0.5)
                    windY *= (1.0 - reduction * 0.5)
                }

                map[x, y].windX = windX
                map[x, y].windY = windY
            }
        }
    }

    // MARK: - Moisture Advection (standalone for GPU path)

    /// Runs moisture transport and rainfall calculation.
    /// Called standalone when GPU handles temperature and wind.
    static func applyMoistureAdvection(map: inout WorldMap, noise: SimplexNoise, rng: inout SeededRNG) {
        computeMoistureAndRainfall(map: &map, noise: noise, size: map.size)
    }

    // MARK: - Moisture and Rainfall

    private static func computeMoistureAndRainfall(map: inout WorldMap, noise: SimplexNoise, size: Int) {
        let invSize = 1.0 / Double(size)

        // Pass 1: Initialize moisture from ocean proximity
        var moistureBuffer = [Float](repeating: 0, count: size * size)

        for y in 0..<size {
            for x in 0..<size {
                let elev = map[x, y].elevation
                if elev < 0.3 {
                    // Ocean/coastal areas start with high moisture
                    moistureBuffer[y * size + x] = 1.0
                }
            }
        }

        // Pass 2: Spread moisture along wind direction (simplified advection)
        for _ in 0..<20 { // Multiple iterations for gradual spread
            var newMoisture = moistureBuffer

            for y in 1..<(size - 1) {
                for x in 1..<(size - 1) {
                    let idx = y * size + x
                    let wx = map[x, y].windX
                    let wy = map[x, y].windY

                    // Sample upwind moisture
                    let upwindX = max(0, min(size - 1, x - Int(wx.rounded())))
                    let upwindY = max(0, min(size - 1, y - Int(wy.rounded())))
                    let upwindMoisture = moistureBuffer[upwindY * size + upwindX]

                    // Orographic effect: mountains force air up, causing rainfall
                    let elevation = map[x, y].elevation
                    var orographicLoss: Float = 0
                    if elevation > 0.4 {
                        orographicLoss = (elevation - 0.4) * 0.8
                    }

                    // Moisture at this cell
                    let transported = upwindMoisture * 0.85 // Decay during transport
                    let afterOrographic = max(0, transported - orographicLoss)

                    newMoisture[idx] = max(newMoisture[idx], afterOrographic)

                    // Rainfall is the moisture lost to orographic effect
                    if orographicLoss > 0 {
                        map[x, y].rainfall = max(map[x, y].rainfall, min(1.0, orographicLoss * transported))
                    }
                }
            }

            moistureBuffer = newMoisture
        }

        // Pass 3: Compute final moisture and rainfall with noise variation
        for y in 0..<size {
            for x in 0..<size {
                let nx = Double(x) * invSize
                let ny = Double(y) * invSize
                let moistureNoise = noise.noise2D(x: nx * 5.0 + 50, y: ny * 5.0 + 50) * 0.15

                var moisture = Double(moistureBuffer[y * size + x]) + moistureNoise
                moisture = max(0, min(1, moisture))
                map[x, y].moisture = Float(moisture)

                // Rainfall: combination of moisture and temperature (warm + moist = more rain)
                let temp = map[x, y].temperature
                let baseRainfall = Float(moisture) * (0.5 + temp * 0.5)
                let rainfallNoise = Float(noise.noise2D(x: nx * 6.0 + 150, y: ny * 6.0 + 150)) * 0.1
                map[x, y].rainfall = max(0, min(1, max(map[x, y].rainfall, baseRainfall) + rainfallNoise))
            }
        }
    }
}

// MARK: - TerrainStage Conformance

extension ClimateSimulator: TerrainStage {
    var forkLabel: String { "climate" }

    func progressMessage(context: WorldGenContext) -> String {
        "Simulating climate..."
    }

    func run(map: inout WorldMap, rng: inout SeededRNG, context: WorldGenContext) {
        Self.simulate(map: &map, noise: context.noise, rng: &rng)
    }
}
