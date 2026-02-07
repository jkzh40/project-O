// MARK: - Simplex Noise
// Pure Swift OpenSimplex2 implementation (2D + 3D), no dependencies

import Foundation

/// OpenSimplex2-style noise generator — deterministic from seed
struct SimplexNoise: Sendable {
    let perm: [Int]
    let permGrad2: [(Double, Double)]
    private let permGrad3: [(Double, Double, Double)]

    private static let gradients2D: [(Double, Double)] = [
        ( 0.130526192220052,  0.99144486137381),
        ( 0.38268343236509,   0.923879532511287),
        ( 0.608761429008721,  0.793353340291235),
        ( 0.793353340291235,  0.608761429008721),
        ( 0.923879532511287,  0.38268343236509),
        ( 0.99144486137381,   0.130526192220052),
        ( 0.99144486137381,  -0.130526192220052),
        ( 0.923879532511287, -0.38268343236509),
        ( 0.793353340291235, -0.608761429008721),
        ( 0.608761429008721, -0.793353340291235),
        ( 0.38268343236509,  -0.923879532511287),
        ( 0.130526192220052, -0.99144486137381),
        (-0.130526192220052, -0.99144486137381),
        (-0.38268343236509,  -0.923879532511287),
        (-0.608761429008721, -0.793353340291235),
        (-0.793353340291235, -0.608761429008721),
        (-0.923879532511287, -0.38268343236509),
        (-0.99144486137381,  -0.130526192220052),
        (-0.99144486137381,   0.130526192220052),
        (-0.923879532511287,  0.38268343236509),
        (-0.793353340291235,  0.608761429008721),
        (-0.608761429008721,  0.793353340291235),
        (-0.38268343236509,   0.923879532511287),
        (-0.130526192220052,  0.99144486137381),
    ]

    private static let gradients3D: [(Double, Double, Double)] = [
        (-1, -1, 0), (-1, 1, 0), (1, -1, 0), (1, 1, 0),
        (-1, 0, -1), (-1, 0, 1), (1, 0, -1), (1, 0, 1),
        (0, -1, -1), (0, -1, 1), (0, 1, -1), (0, 1, 1),
        (-1, -1, 0), (-1, 1, 0), (1, -1, 0), (1, 1, 0),
    ]

    init(seed: UInt64) {
        var rng = SeededRNG(seed: seed)

        // Build permutation table
        var p = Array(0..<256)
        rng.shuffle(&p)
        // Double the table to avoid modular arithmetic
        perm = p + p

        // Build gradient lookup tables
        let g2Count = Self.gradients2D.count
        permGrad2 = perm.map { Self.gradients2D[$0 % g2Count] }

        let g3Count = Self.gradients3D.count
        permGrad3 = perm.map { Self.gradients3D[$0 % g3Count] }
    }

    // MARK: - 2D Noise

    /// Returns noise value in approximately [-1, 1] for 2D coordinates
    func noise2D(x: Double, y: Double) -> Double {
        // Skew to simplex space
        let F2 = 0.5 * (sqrt(3.0) - 1.0)
        let G2 = (3.0 - sqrt(3.0)) / 6.0

        let s = (x + y) * F2
        let i = fastFloor(x + s)
        let j = fastFloor(y + s)

        let t = Double(i + j) * G2
        let x0 = x - (Double(i) - t)
        let y0 = y - (Double(j) - t)

        let i1: Int, j1: Int
        if x0 > y0 { i1 = 1; j1 = 0 }
        else { i1 = 0; j1 = 1 }

        let x1 = x0 - Double(i1) + G2
        let y1 = y0 - Double(j1) + G2
        let x2 = x0 - 1.0 + 2.0 * G2
        let y2 = y0 - 1.0 + 2.0 * G2

        let ii = i & 255
        let jj = j & 255

        var n0 = 0.0, n1 = 0.0, n2 = 0.0

        var t0 = 0.5 - x0 * x0 - y0 * y0
        if t0 >= 0 {
            t0 *= t0
            let grad = permGrad2[ii + perm[jj]]
            n0 = t0 * t0 * (grad.0 * x0 + grad.1 * y0)
        }

        var t1 = 0.5 - x1 * x1 - y1 * y1
        if t1 >= 0 {
            t1 *= t1
            let grad = permGrad2[ii + i1 + perm[jj + j1]]
            n1 = t1 * t1 * (grad.0 * x1 + grad.1 * y1)
        }

        var t2 = 0.5 - x2 * x2 - y2 * y2
        if t2 >= 0 {
            t2 *= t2
            let grad = permGrad2[ii + 1 + perm[jj + 1]]
            n2 = t2 * t2 * (grad.0 * x2 + grad.1 * y2)
        }

        return 70.0 * (n0 + n1 + n2)
    }

    // MARK: - 3D Noise

    /// Returns noise value in approximately [-1, 1] for 3D coordinates
    func noise3D(x: Double, y: Double, z: Double) -> Double {
        let F3 = 1.0 / 3.0
        let G3 = 1.0 / 6.0

        let s = (x + y + z) * F3
        let i = fastFloor(x + s)
        let j = fastFloor(y + s)
        let k = fastFloor(z + s)

        let t = Double(i + j + k) * G3
        let x0 = x - (Double(i) - t)
        let y0 = y - (Double(j) - t)
        let z0 = z - (Double(k) - t)

        let i1, j1, k1, i2, j2, k2: Int
        if x0 >= y0 {
            if y0 >= z0      { i1=1; j1=0; k1=0; i2=1; j2=1; k2=0 }
            else if x0 >= z0 { i1=1; j1=0; k1=0; i2=1; j2=0; k2=1 }
            else              { i1=0; j1=0; k1=1; i2=1; j2=0; k2=1 }
        } else {
            if y0 < z0       { i1=0; j1=0; k1=1; i2=0; j2=1; k2=1 }
            else if x0 < z0  { i1=0; j1=1; k1=0; i2=0; j2=1; k2=1 }
            else              { i1=0; j1=1; k1=0; i2=1; j2=1; k2=0 }
        }

        let x1 = x0 - Double(i1) + G3
        let y1 = y0 - Double(j1) + G3
        let z1 = z0 - Double(k1) + G3
        let x2 = x0 - Double(i2) + 2.0 * G3
        let y2 = y0 - Double(j2) + 2.0 * G3
        let z2 = z0 - Double(k2) + 2.0 * G3
        let x3 = x0 - 1.0 + 3.0 * G3
        let y3 = y0 - 1.0 + 3.0 * G3
        let z3 = z0 - 1.0 + 3.0 * G3

        let ii = i & 255
        let jj = j & 255
        let kk = k & 255

        var n0 = 0.0, n1 = 0.0, n2 = 0.0, n3 = 0.0

        var t0 = 0.6 - x0*x0 - y0*y0 - z0*z0
        if t0 >= 0 {
            t0 *= t0
            let grad = permGrad3[ii + perm[jj + perm[kk]]]
            n0 = t0 * t0 * (grad.0 * x0 + grad.1 * y0 + grad.2 * z0)
        }

        var t1 = 0.6 - x1*x1 - y1*y1 - z1*z1
        if t1 >= 0 {
            t1 *= t1
            let grad = permGrad3[ii + i1 + perm[jj + j1 + perm[kk + k1]]]
            n1 = t1 * t1 * (grad.0 * x1 + grad.1 * y1 + grad.2 * z1)
        }

        var t2 = 0.6 - x2*x2 - y2*y2 - z2*z2
        if t2 >= 0 {
            t2 *= t2
            let grad = permGrad3[ii + i2 + perm[jj + j2 + perm[kk + k2]]]
            n2 = t2 * t2 * (grad.0 * x2 + grad.1 * y2 + grad.2 * z2)
        }

        var t3 = 0.6 - x3*x3 - y3*y3 - z3*z3
        if t3 >= 0 {
            t3 *= t3
            let grad = permGrad3[ii + 1 + perm[jj + 1 + perm[kk + 1]]]
            n3 = t3 * t3 * (grad.0 * x3 + grad.1 * y3 + grad.2 * z3)
        }

        return 32.0 * (n0 + n1 + n2 + n3)
    }

    // MARK: - Helpers

    private func fastFloor(_ x: Double) -> Int {
        let xi = Int(x)
        return x < Double(xi) ? xi - 1 : xi
    }
}
