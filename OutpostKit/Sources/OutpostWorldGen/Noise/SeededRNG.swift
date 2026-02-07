// MARK: - Seeded Random Number Generator
// Xoshiro256** PRNG — deterministic, fast, forkable

import Foundation

/// A deterministic random number generator using the xoshiro256** algorithm.
/// Fork-able: create independent child generators from a parent seed.
struct SeededRNG: Sendable {
    private var state: (UInt64, UInt64, UInt64, UInt64)

    /// Creates an RNG seeded with the given value
    init(seed: UInt64) {
        // Use SplitMix64 to expand the seed into 4 state words
        var s = seed
        func splitmix() -> UInt64 {
            s &+= 0x9e3779b97f4a7c15
            var z = s
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
        state = (splitmix(), splitmix(), splitmix(), splitmix())
    }

    /// Fork a child RNG for a named stage, producing an independent stream
    func fork(_ label: String) -> SeededRNG {
        // Hash the label to produce a deterministic child seed
        var hash: UInt64 = 0xcbf29ce484222325 // FNV offset basis
        for byte in label.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3 // FNV prime
        }
        // Mix with parent state for uniqueness
        let childSeed = hash ^ state.0 ^ state.2
        return SeededRNG(seed: childSeed)
    }

    /// Returns the next UInt64 in the sequence
    mutating func nextUInt64() -> UInt64 {
        let result = rotl(state.1 &* 5, 7) &* 9
        let t = state.1 << 17
        state.2 ^= state.0
        state.3 ^= state.1
        state.1 ^= state.2
        state.0 ^= state.3
        state.2 ^= t
        state.3 = rotl(state.3, 45)
        return result
    }

    /// Returns a Double in [0, 1)
    mutating func nextDouble() -> Double {
        Double(nextUInt64() >> 11) * 0x1.0p-53
    }

    /// Returns a Double in the specified range
    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    /// Returns an Int in the specified range
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(nextUInt64() % span)
    }

    /// Returns a Bool with the given probability of being true
    mutating func nextBool(probability: Double = 0.5) -> Bool {
        nextDouble() < probability
    }

    /// Shuffles an array in place
    mutating func shuffle<T>(_ array: inout [T]) {
        for i in stride(from: array.count - 1, through: 1, by: -1) {
            let j = Int(nextUInt64() % UInt64(i + 1))
            array.swapAt(i, j)
        }
    }

    /// Returns a shuffled copy of an array
    mutating func shuffled<T>(_ array: [T]) -> [T] {
        var copy = array
        shuffle(&copy)
        return copy
    }

    private func rotl(_ x: UInt64, _ k: Int) -> UInt64 {
        (x << k) | (x >> (64 - k))
    }
}
