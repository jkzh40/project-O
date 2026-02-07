// MARK: - Noise Utilities
// Compositors: fBm, ridged multifractal, domain warping

import Foundation

/// Utility functions for combining and transforming noise
enum NoiseUtilities {

    // MARK: - Fractal Brownian Motion (fBm)

    /// Multi-octave fractal Brownian motion noise
    /// - Parameters:
    ///   - noise: The base noise generator
    ///   - x: X coordinate
    ///   - y: Y coordinate
    ///   - octaves: Number of noise octaves (more = more detail)
    ///   - frequency: Base sampling frequency
    ///   - lacunarity: Frequency multiplier per octave (typically 2.0)
    ///   - persistence: Amplitude multiplier per octave (typically 0.5)
    /// - Returns: Noise value (range depends on octaves, roughly [-1, 1])
    static func fbm(
        noise: SimplexNoise,
        x: Double, y: Double,
        octaves: Int = 6,
        frequency: Double = 1.0,
        lacunarity: Double = 2.0,
        persistence: Double = 0.5
    ) -> Double {
        var value = 0.0
        var amplitude = 1.0
        var freq = frequency
        var maxAmplitude = 0.0

        for _ in 0..<octaves {
            value += noise.noise2D(x: x * freq, y: y * freq) * amplitude
            maxAmplitude += amplitude
            amplitude *= persistence
            freq *= lacunarity
        }

        return value / maxAmplitude
    }

    // MARK: - Ridged Multifractal

    /// Ridged multifractal noise — creates sharp ridges like mountain ranges
    static func ridgedMultifractal(
        noise: SimplexNoise,
        x: Double, y: Double,
        octaves: Int = 6,
        frequency: Double = 1.0,
        lacunarity: Double = 2.0,
        gain: Double = 2.0
    ) -> Double {
        var value = 0.0
        var weight = 1.0
        var freq = frequency
        let offset = 1.0

        for _ in 0..<octaves {
            var signal = noise.noise2D(x: x * freq, y: y * freq)
            signal = offset - abs(signal)
            signal *= signal
            signal *= weight
            weight = min(max(signal * gain, 0.0), 1.0)
            value += signal
            freq *= lacunarity
        }

        return value / Double(octaves) * 1.25
    }

    // MARK: - Domain Warping

    /// Applies domain warping: distorts coordinates using noise before sampling
    /// Creates organic, flowing patterns
    static func domainWarp(
        noise: SimplexNoise,
        x: Double, y: Double,
        frequency: Double = 1.0,
        warpStrength: Double = 0.5,
        octaves: Int = 4
    ) -> Double {
        // First pass: warp coordinates
        let warpX = fbm(
            noise: noise,
            x: x + 0.0, y: y + 0.0,
            octaves: octaves, frequency: frequency
        )
        let warpY = fbm(
            noise: noise,
            x: x + 5.2, y: y + 1.3,
            octaves: octaves, frequency: frequency
        )

        // Second pass: sample at warped coordinates
        return fbm(
            noise: noise,
            x: x + warpX * warpStrength,
            y: y + warpY * warpStrength,
            octaves: octaves, frequency: frequency
        )
    }

    // MARK: - Utility

    /// Remaps a value from one range to another
    static func remap(
        _ value: Double,
        from fromRange: ClosedRange<Double>,
        to toRange: ClosedRange<Double>
    ) -> Double {
        let normalized = (value - fromRange.lowerBound) / (fromRange.upperBound - fromRange.lowerBound)
        return toRange.lowerBound + normalized * (toRange.upperBound - toRange.lowerBound)
    }

    /// Clamps a value to [0, 1]
    static func saturate(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    /// Smooth hermite interpolation (smoothstep)
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = saturate((x - edge0) / (edge1 - edge0))
        return t * t * (3.0 - 2.0 * t)
    }

    /// Applies a gaussian-like falloff around a center point
    static func falloff(
        x: Double, y: Double,
        centerX: Double, centerY: Double,
        radius: Double
    ) -> Double {
        let dx = x - centerX
        let dy = y - centerY
        let dist = sqrt(dx * dx + dy * dy)
        return saturate(1.0 - dist / radius)
    }

    /// 2D distance
    static func distance(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        let dx = x1 - x2
        let dy = y1 - y2
        return sqrt(dx * dx + dy * dy)
    }
}
