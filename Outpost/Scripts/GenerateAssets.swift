#!/usr/bin/env swift

// GenerateAssets.swift
// Generates 32x32 pixel art PNGs for the Outpost game asset catalog.
// Run: swift GenerateAssets.swift

import Foundation
import CoreGraphics
import ImageIO

// MARK: - Path Setup

let scriptURL = URL(fileURLWithPath: #file).deletingLastPathComponent()
let assetsRoot = scriptURL
    .deletingLastPathComponent()
    .appendingPathComponent("Outpost")
    .appendingPathComponent("Assets.xcassets")

let creaturesDir = assetsRoot.appendingPathComponent("Creatures")
let terrainDir = assetsRoot.appendingPathComponent("Terrain")
let itemsDir = assetsRoot.appendingPathComponent("Items")
let uiDir = assetsRoot.appendingPathComponent("UI")

// MARK: - Color Helpers

struct C {
    let r: UInt8, g: UInt8, b: UInt8, a: UInt8
    init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    static let clear = C(0, 0, 0, 0)
}

// MARK: - Pixel Buffer

class PixelCanvas {
    var pixels: [C]
    let w: Int
    let h: Int

    init(width: Int = 32, height: Int = 32, fill: C = .clear) {
        self.w = width
        self.h = height
        self.pixels = Array(repeating: fill, count: width * height)
    }

    func set(_ x: Int, _ y: Int, _ c: C) {
        guard x >= 0, x < w, y >= 0, y < h else { return }
        pixels[y * w + x] = c
    }

    func get(_ x: Int, _ y: Int) -> C {
        guard x >= 0, x < w, y >= 0, y < h else { return .clear }
        return pixels[y * w + x]
    }

    func fillRect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: C) {
        for dy in 0..<rh {
            for dx in 0..<rw {
                set(x + dx, y + dy, c)
            }
        }
    }

    func fillCircle(cx: Int, cy: Int, radius: Int, _ c: C) {
        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy <= radius * radius {
                    set(cx + dx, cy + dy, c)
                }
            }
        }
    }

    func fillEllipse(cx: Int, cy: Int, rx: Int, ry: Int, _ c: C) {
        for dy in -ry...ry {
            for dx in -rx...rx {
                let nx = Double(dx) / Double(rx)
                let ny = Double(dy) / Double(ry)
                if nx * nx + ny * ny <= 1.0 {
                    set(cx + dx, cy + dy, c)
                }
            }
        }
    }

    func drawLine(x0: Int, y0: Int, x1: Int, y1: Int, _ c: C) {
        var x = x0, y = y0
        let dx = abs(x1 - x0), dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy
        while true {
            set(x, y, c)
            if x == x1 && y == y1 { break }
            let e2 = 2 * err
            if e2 > -dy { err -= dy; x += sx }
            if e2 < dx { err += dx; y += sy }
        }
    }

    func drawRect(_ x: Int, _ y: Int, _ rw: Int, _ rh: Int, _ c: C) {
        for dx in 0..<rw {
            set(x + dx, y, c)
            set(x + dx, y + rh - 1, c)
        }
        for dy in 0..<rh {
            set(x, y + dy, c)
            set(x + rw - 1, y + dy, c)
        }
    }

    func toCGImage() -> CGImage? {
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<pixels.count {
            data[i * 4 + 0] = pixels[i].r
            data[i * 4 + 1] = pixels[i].g
            data[i * 4 + 2] = pixels[i].b
            data[i * 4 + 3] = pixels[i].a
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: Data(data) as CFData) else { return nil }
        return CGImage(
            width: w, height: h,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}

// MARK: - Image Saving

func savePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("ERROR: Cannot create image destination at \(url.path)")
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        print("ERROR: Failed to write PNG to \(url.path)")
    }
}

func scaleNearest(_ src: CGImage, to size: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    ctx.interpolationQuality = .none
    ctx.draw(src, in: CGRect(x: 0, y: 0, width: size, height: size))
    return ctx.makeImage()
}

func writeAllScales(canvas: PixelCanvas, name: String, dir: URL) {
    guard let img1x = canvas.toCGImage() else {
        print("ERROR: Failed to create CGImage for \(name)")
        return
    }
    let imagesetDir = dir.appendingPathComponent("\(name).imageset")
    savePNG(img1x, to: imagesetDir.appendingPathComponent("\(name).png"))
    if let img2x = scaleNearest(img1x, to: 64) {
        savePNG(img2x, to: imagesetDir.appendingPathComponent("\(name)@2x.png"))
    }
    if let img3x = scaleNearest(img1x, to: 96) {
        savePNG(img3x, to: imagesetDir.appendingPathComponent("\(name)@3x.png"))
    }
    print("  Generated \(name)")
}

func createImagesetIfNeeded(name: String, dir: URL) {
    let imagesetDir = dir.appendingPathComponent("\(name).imageset")
    let fm = FileManager.default
    if !fm.fileExists(atPath: imagesetDir.path) {
        try! fm.createDirectory(at: imagesetDir, withIntermediateDirectories: true)
        let contentsJSON = """
        {
          "images": [
            { "filename": "\(name).png", "idiom": "universal", "scale": "1x" },
            { "filename": "\(name)@2x.png", "idiom": "universal", "scale": "2x" },
            { "filename": "\(name)@3x.png", "idiom": "universal", "scale": "3x" }
          ],
          "info": { "author": "xcode", "version": 1 }
        }
        """
        try! contentsJSON.data(using: .utf8)!.write(to: imagesetDir.appendingPathComponent("Contents.json"))
        print("  Created imageset directory for \(name)")
    }
}

// MARK: - Simple seeded random for deterministic dithering

struct SimpleRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state >> 33
    }
    mutating func nextInt(_ bound: Int) -> Int {
        return Int(next() % UInt64(bound))
    }
    mutating func nextBool(chance: Int = 50) -> Bool {
        return nextInt(100) < chance
    }
}

// MARK: - Creature Sprites

func drawCreatureOrc() -> PixelCanvas {
    let p = PixelCanvas()
    let skin = C(60, 120, 40)
    let skinDark = C(45, 95, 30)
    let hair = C(30, 30, 25)
    let white = C(230, 230, 230)
    let tusk = C(220, 210, 180)
    let eye = C(180, 40, 30)
    let leather = C(110, 70, 35)
    let leatherDark = C(85, 55, 25)
    let belt = C(60, 40, 20)
    let pants = C(80, 60, 40)
    let boot = C(50, 35, 20)

    // Hair (rows 2-5)
    for x in 11...20 { p.set(x, 2, hair) }
    for x in 10...21 { p.set(x, 3, hair) }
    for x in 10...21 { p.set(x, 4, hair) }
    for x in 10...21 { p.set(x, 5, hair) }

    // Head (rows 6-13)
    for y in 6...13 {
        for x in 10...21 {
            p.set(x, y, skin)
        }
    }
    // Brow ridge
    for x in 11...20 { p.set(x, 6, skinDark) }

    // Eyes (row 8-9)
    p.fillRect(12, 8, 3, 2, white)
    p.fillRect(17, 8, 3, 2, white)
    p.set(13, 8, eye); p.set(13, 9, eye)
    p.set(18, 8, eye); p.set(18, 9, eye)

    // Nose
    p.set(15, 10, skinDark); p.set(16, 10, skinDark)
    p.set(15, 11, skinDark); p.set(16, 11, skinDark)

    // Mouth
    for x in 13...18 { p.set(x, 12, skinDark) }

    // Tusks
    p.set(12, 12, tusk); p.set(12, 13, tusk)
    p.set(19, 12, tusk); p.set(19, 13, tusk)

    // Ears
    p.set(9, 8, skin); p.set(9, 9, skin)
    p.set(22, 8, skin); p.set(22, 9, skin)

    // Neck (row 14)
    for x in 13...18 { p.set(x, 14, skin) }

    // Leather armor (rows 15-22)
    for y in 15...22 {
        for x in 9...22 {
            p.set(x, y, leather)
        }
    }
    // Armor detail - center seam
    for y in 15...22 { p.set(15, y, leatherDark); p.set(16, y, leatherDark) }
    // Shoulder pads
    for x in 8...10 { p.set(x, 15, leatherDark); p.set(x, 16, leatherDark) }
    for x in 21...23 { p.set(x, 15, leatherDark); p.set(x, 16, leatherDark) }

    // Belt (row 21-22)
    for x in 9...22 { p.set(x, 21, belt); p.set(x, 22, belt) }
    p.set(15, 21, C(180, 160, 40)); p.set(16, 21, C(180, 160, 40)) // buckle
    p.set(15, 22, C(180, 160, 40)); p.set(16, 22, C(180, 160, 40))

    // Arms (rows 16-22)
    for y in 16...23 {
        p.set(7, y, skin); p.set(8, y, skin)
        p.set(23, y, skin); p.set(24, y, skin)
    }
    // Arm upper part covered by armor
    for y in 16...19 {
        p.set(7, y, leatherDark); p.set(8, y, leatherDark)
        p.set(23, y, leatherDark); p.set(24, y, leatherDark)
    }

    // Pants (rows 23-27)
    for y in 23...27 {
        for x in 10...14 { p.set(x, y, pants) }
        for x in 17...21 { p.set(x, y, pants) }
    }

    // Boots (rows 28-30)
    for y in 28...30 {
        for x in 9...14 { p.set(x, y, boot) }
        for x in 17...22 { p.set(x, y, boot) }
    }

    return p
}

func drawCreatureGoblin() -> PixelCanvas {
    let p = PixelCanvas()
    let skin = C(80, 160, 50)
    let skinDark = C(60, 130, 35)
    let white = C(230, 230, 220)
    let pupil = C(200, 50, 20)
    let rag = C(100, 75, 45)
    let ragDark = C(75, 55, 30)

    // Big pointy ears
    p.set(8, 8, skin); p.set(7, 7, skin); p.set(6, 6, skin)
    p.set(8, 9, skin); p.set(7, 8, skinDark)
    p.set(23, 8, skin); p.set(24, 7, skin); p.set(25, 6, skin)
    p.set(23, 9, skin); p.set(24, 8, skinDark)

    // Head (rows 6-14) - smaller than orc
    for y in 6...14 {
        for x in 10...21 {
            p.set(x, y, skin)
        }
    }
    // Top of head pointy
    for x in 12...19 { p.set(x, 5, skin) }
    for x in 14...17 { p.set(x, 4, skin) }

    // Big eyes (row 8-10)
    p.fillRect(11, 8, 4, 3, white)
    p.fillRect(17, 8, 4, 3, white)
    p.set(13, 9, pupil); p.set(13, 10, pupil)
    p.set(19, 9, pupil); p.set(19, 10, pupil)

    // Nose - small pointy
    p.set(15, 11, skinDark); p.set(16, 11, skinDark)

    // Mischievous grin
    for x in 12...19 { p.set(x, 13, skinDark) }
    p.set(12, 12, skinDark); p.set(19, 12, skinDark) // grin corners up
    // Teeth
    p.set(14, 13, white); p.set(16, 13, white); p.set(18, 13, white)

    // Neck (row 15)
    for x in 13...18 { p.set(x, 15, skin) }

    // Ragged clothes (rows 16-24) - thinner body
    for y in 16...24 {
        for x in 11...20 {
            p.set(x, y, rag)
        }
    }
    // Ragged edges / patches
    p.set(11, 17, ragDark); p.set(20, 19, ragDark)
    p.set(12, 22, ragDark); p.set(19, 23, ragDark)
    p.set(13, 24, ragDark); p.set(18, 24, ragDark)
    // Torn bottom edge
    p.set(11, 24, .clear); p.set(14, 24, .clear); p.set(17, 24, .clear); p.set(20, 24, .clear)

    // Thin arms
    for y in 17...23 {
        p.set(9, y, skin); p.set(10, y, skin)
        p.set(21, y, skin); p.set(22, y, skin)
    }

    // Thin legs
    for y in 25...29 {
        for x in 12...14 { p.set(x, y, skin) }
        for x in 17...19 { p.set(x, y, skin) }
    }

    // Feet
    p.fillRect(11, 30, 4, 1, skinDark)
    p.fillRect(16, 30, 4, 1, skinDark)

    return p
}

func drawCreatureWolf() -> PixelCanvas {
    let p = PixelCanvas()
    let fur = C(130, 130, 140)
    let furDark = C(100, 100, 110)
    let belly = C(170, 170, 175)
    let eye = C(200, 180, 40)
    let nose = C(30, 30, 30)

    // Body (side view, facing right) rows 12-22
    for y in 14...21 {
        for x in 6...25 {
            p.set(x, y, fur)
        }
    }
    // Round out body
    for x in 8...23 { p.set(x, 13, fur) }
    for x in 10...22 { p.set(x, 12, fur) }

    // Belly lighter
    for y in 18...21 {
        for x in 8...23 { p.set(x, y, belly) }
    }

    // Head (rows 9-16, right side)
    for y in 9...16 {
        for x in 23...30 { p.set(x, y, fur) }
    }
    for x in 25...30 { p.set(x, 8, fur) }
    // Snout
    p.set(30, 13, fur); p.set(31, 13, fur)
    p.set(30, 14, fur); p.set(31, 14, fur)
    p.set(30, 15, furDark); p.set(31, 15, furDark)
    // Nose
    p.set(31, 13, nose)
    // Eye
    p.set(27, 10, eye); p.set(28, 10, eye)
    p.set(27, 11, C(20, 20, 20)); p.set(28, 11, eye)

    // Ears (pointy)
    p.set(25, 7, fur); p.set(26, 7, fur)
    p.set(25, 6, furDark); p.set(26, 6, fur)
    p.set(26, 5, furDark)
    p.set(28, 7, fur); p.set(29, 7, fur)
    p.set(29, 6, furDark)
    p.set(29, 5, furDark)

    // Front legs
    for y in 22...29 {
        p.set(21, y, furDark); p.set(22, y, furDark); p.set(23, y, furDark)
        p.set(18, y, fur); p.set(19, y, fur); p.set(20, y, fur)
    }
    // Paws
    p.fillRect(17, 29, 4, 2, furDark)
    p.fillRect(20, 29, 4, 2, furDark)

    // Back legs
    for y in 22...29 {
        p.set(8, y, furDark); p.set(9, y, furDark); p.set(10, y, furDark)
        p.set(11, y, fur); p.set(12, y, fur)
    }
    // Haunch
    p.fillRect(6, 18, 4, 5, fur)
    // Back paws
    p.fillRect(7, 29, 4, 2, furDark)
    p.fillRect(10, 29, 3, 2, furDark)

    // Tail (bushy, going left and up)
    p.set(5, 14, fur); p.set(4, 13, fur); p.set(3, 12, fur); p.set(2, 11, fur)
    p.set(5, 13, furDark); p.set(4, 12, furDark); p.set(3, 11, furDark)
    p.set(1, 10, fur); p.set(2, 10, fur); p.set(1, 11, fur)
    p.set(6, 13, fur); p.set(5, 12, fur); p.set(4, 11, fur); p.set(3, 10, fur)

    return p
}

func drawCreatureBear() -> PixelCanvas {
    let p = PixelCanvas()
    let fur = C(120, 80, 40)
    let furDark = C(90, 60, 30)
    let furLight = C(140, 100, 55)
    let eye = C(20, 20, 20)
    let nose = C(30, 20, 15)
    let snoutC = C(150, 120, 80)

    // Large body (side view) rows 10-24, x 4-28
    for y in 10...24 {
        for x in 4...28 {
            p.set(x, y, fur)
        }
    }
    // Round top
    for x in 6...26 { p.set(x, 9, fur) }
    for x in 8...24 { p.set(x, 8, fur) }
    // Belly area lighter
    for y in 20...24 {
        for x in 8...24 { p.set(x, y, furLight) }
    }
    // Dark back
    for y in 9...12 {
        for x in 6...26 { p.set(x, y, furDark) }
    }

    // Head (rows 6-16, right side)
    for y in 6...16 {
        for x in 23...31 { p.set(x, y, fur) }
    }
    for x in 25...30 { p.set(x, 5, fur) }
    for x in 24...31 { p.set(x, 7, fur) }

    // Snout
    p.fillRect(29, 11, 2, 3, snoutC)
    p.set(31, 11, snoutC); p.set(31, 12, snoutC)
    p.set(31, 11, nose) // nose tip

    // Ears (round)
    p.fillRect(24, 4, 2, 2, fur)
    p.fillRect(28, 4, 2, 2, fur)
    p.set(24, 4, furDark); p.set(28, 4, furDark)

    // Eyes
    p.set(26, 9, eye); p.set(27, 9, eye)

    // Front legs (thick)
    for y in 24...30 {
        for x in 21...25 { p.set(x, y, furDark) }
    }
    // Front paw
    p.fillRect(20, 30, 6, 1, furDark)

    for y in 24...30 {
        for x in 17...20 { p.set(x, y, fur) }
    }
    p.fillRect(16, 30, 5, 1, furDark)

    // Back legs (thick)
    for y in 24...30 {
        for x in 6...10 { p.set(x, y, furDark) }
    }
    p.fillRect(5, 30, 6, 1, furDark)

    for y in 24...30 {
        for x in 11...14 { p.set(x, y, fur) }
    }
    p.fillRect(10, 30, 5, 1, furDark)

    // Short tail
    p.set(3, 12, fur); p.set(2, 11, fur); p.set(3, 11, furDark)

    return p
}

func drawCreatureGiant() -> PixelCanvas {
    let p = PixelCanvas()
    let skin = C(100, 100, 130)
    let skinDark = C(80, 80, 110)
    let eye = C(200, 200, 60)
    let cloth = C(90, 70, 50)
    let clothDark = C(70, 50, 35)
    let club = C(100, 70, 35)
    let clubDark = C(75, 50, 25)

    // Head (rows 1-8) - fills full height
    for y in 1...8 {
        for x in 11...20 {
            p.set(x, y, skin)
        }
    }
    for x in 12...19 { p.set(x, 0, skin) }
    // Brow
    for x in 11...20 { p.set(x, 3, skinDark) }
    // Eyes
    p.fillRect(13, 4, 2, 2, eye)
    p.fillRect(17, 4, 2, 2, eye)
    p.set(13, 5, C(20, 20, 20)); p.set(18, 5, C(20, 20, 20))
    // Nose
    p.set(15, 6, skinDark); p.set(16, 6, skinDark)
    // Mouth
    for x in 13...18 { p.set(x, 8, skinDark) }

    // Neck
    for x in 13...18 { p.set(x, 9, skin) }

    // Broad torso (rows 10-21)
    for y in 10...21 {
        for x in 7...24 {
            p.set(x, y, cloth)
        }
    }
    // Cloth detail
    for y in 10...21 { p.set(15, y, clothDark); p.set(16, y, clothDark) }
    for x in 7...24 { p.set(x, 15, clothDark) }
    // Shoulders
    for x in 6...8 { p.set(x, 10, skinDark); p.set(x, 11, skinDark) }
    for x in 23...25 { p.set(x, 10, skinDark); p.set(x, 11, skinDark) }

    // Arms - thick
    for y in 11...22 {
        p.set(5, y, skin); p.set(6, y, skin)
        p.set(25, y, skin); p.set(26, y, skin)
    }
    // Right hand holds club
    p.set(4, 22, skin); p.set(5, 22, skin)

    // Club (left side, held in right hand from viewer perspective)
    for y in 5...24 {
        p.set(3, y, club); p.set(4, y, club)
    }
    // Club head (thicker at top)
    for y in 3...7 {
        p.set(2, y, clubDark); p.set(3, y, club); p.set(4, y, club); p.set(5, y, clubDark)
    }
    p.set(2, 4, club); p.set(5, 4, club)

    // Legs (rows 22-30)
    for y in 22...30 {
        for x in 9...14 { p.set(x, y, skinDark) }
        for x in 17...22 { p.set(x, y, skinDark) }
    }

    // Feet
    for x in 8...15 { p.set(x, 31, skinDark) }
    for x in 16...23 { p.set(x, 31, skinDark) }

    return p
}

func drawCreatureUndead() -> PixelCanvas {
    let p = PixelCanvas()
    let bone = C(200, 190, 170)
    let boneDark = C(160, 150, 130)
    let glow = C(0, 220, 220)
    let glowDark = C(0, 160, 160)
    let robe = C(40, 35, 50)
    let robeDark = C(25, 20, 35)

    // Skull (rows 3-11)
    for y in 3...11 {
        for x in 11...20 {
            p.set(x, y, bone)
        }
    }
    for x in 12...19 { p.set(x, 2, bone) }
    // Skull shape
    p.set(11, 3, boneDark); p.set(20, 3, boneDark)
    p.set(11, 11, boneDark); p.set(20, 11, boneDark)

    // Eye sockets (glowing cyan)
    p.fillRect(12, 5, 3, 3, C(30, 25, 35))
    p.fillRect(17, 5, 3, 3, C(30, 25, 35))
    p.set(13, 6, glow); p.set(18, 6, glow)
    p.set(13, 7, glowDark); p.set(18, 7, glowDark)

    // Nasal cavity
    p.set(15, 8, boneDark); p.set(16, 8, boneDark)
    p.set(15, 9, boneDark); p.set(16, 9, boneDark)

    // Jaw/teeth
    for x in 12...19 { p.set(x, 10, boneDark) }
    p.set(13, 11, boneDark); p.set(15, 11, boneDark); p.set(17, 11, boneDark)

    // Spine/neck
    p.set(15, 12, bone); p.set(16, 12, bone)
    p.set(15, 13, boneDark); p.set(16, 13, boneDark)

    // Tattered robe (rows 14-29)
    for y in 14...29 {
        let w = min(y - 10, 12)
        for x in (16 - w)...(15 + w) {
            p.set(x, y, robe)
        }
    }
    // Robe detail/folds
    for y in 16...29 {
        p.set(15, y, robeDark); p.set(16, y, robeDark)
    }
    // Tattered edges at bottom
    p.set(6, 28, .clear); p.set(8, 29, .clear); p.set(10, 29, .clear)
    p.set(25, 28, .clear); p.set(23, 29, .clear); p.set(21, 29, .clear)

    // Bony arms sticking out
    for y in 16...22 {
        p.set(8, y, bone); p.set(7, y, boneDark)
        p.set(23, y, bone); p.set(24, y, boneDark)
    }
    // Hands (skeletal)
    p.set(6, 22, bone); p.set(6, 23, boneDark); p.set(7, 23, bone)
    p.set(25, 22, bone); p.set(25, 23, boneDark); p.set(24, 23, bone)

    // Faint glow around eyes (ambient)
    p.set(11, 6, glowDark); p.set(21, 6, glowDark)
    p.set(12, 4, glowDark); p.set(19, 4, glowDark)

    return p
}

// MARK: - Terrain Sprites

func drawTerrainEmptyAir() -> PixelCanvas {
    return PixelCanvas(fill: C(20, 20, 30))
}

func drawTerrainGrass() -> PixelCanvas {
    let p = PixelCanvas(fill: C(50, 130, 40))
    var rng = SimpleRNG(seed: 42)
    let dark = C(35, 100, 28)
    let light = C(70, 155, 55)
    let lightYellow = C(90, 150, 50)

    // Grass blades and variation
    for y in 0..<32 {
        for x in 0..<32 {
            let v = rng.nextInt(100)
            if v < 15 {
                p.set(x, y, dark)
            } else if v < 22 {
                p.set(x, y, light)
            } else if v < 25 {
                p.set(x, y, lightYellow)
            }
        }
    }
    // Some grass blade clusters
    for bx in stride(from: 3, to: 30, by: 7) {
        let by = 5 + rng.nextInt(22)
        p.set(bx, by, dark); p.set(bx, by - 1, dark); p.set(bx + 1, by, dark)
        p.set(bx, by - 2, C(40, 110, 30))
    }

    return p
}

func drawTerrainDirt() -> PixelCanvas {
    let p = PixelCanvas(fill: C(140, 110, 70))
    var rng = SimpleRNG(seed: 101)
    let dark = C(120, 90, 55)
    let light = C(160, 130, 85)
    let pebble = C(110, 100, 80)

    for y in 0..<32 {
        for x in 0..<32 {
            let v = rng.nextInt(100)
            if v < 12 { p.set(x, y, dark) }
            else if v < 20 { p.set(x, y, light) }
        }
    }
    // Pebbles
    p.set(5, 10, pebble); p.set(6, 10, pebble)
    p.set(20, 5, pebble); p.set(21, 5, pebble); p.set(21, 6, pebble)
    p.set(12, 25, pebble); p.set(13, 25, pebble)
    p.set(27, 20, pebble)
    p.set(8, 18, pebble); p.set(9, 18, pebble)

    return p
}

func drawTerrainStone() -> PixelCanvas {
    let p = PixelCanvas(fill: C(130, 130, 130))
    var rng = SimpleRNG(seed: 200)
    let dark = C(105, 105, 110)
    let light = C(150, 150, 148)
    let crack = C(90, 90, 95)

    for y in 0..<32 {
        for x in 0..<32 {
            let v = rng.nextInt(100)
            if v < 10 { p.set(x, y, dark) }
            else if v < 18 { p.set(x, y, light) }
        }
    }
    // Crack lines
    p.drawLine(x0: 5, y0: 8, x1: 18, y1: 12, crack)
    p.drawLine(x0: 18, y0: 12, x1: 22, y1: 20, crack)
    p.drawLine(x0: 10, y0: 22, x1: 25, y1: 28, crack)
    p.drawLine(x0: 2, y0: 18, x1: 10, y1: 22, crack)

    return p
}

func drawTerrainWater(frameOffset: Int = 0) -> PixelCanvas {
    let p = PixelCanvas(fill: C(40, 80, 160))
    let dark = C(30, 60, 140)
    let light = C(70, 120, 190)
    let crest = C(160, 200, 230)
    let white = C(200, 220, 240)

    // Wave rows with frame offset
    for y in 0..<32 {
        let wavePhase = (y + frameOffset * 4) % 16
        for x in 0..<32 {
            let wx = (x + (y / 4) * 3 + frameOffset * 4) % 32
            if wavePhase < 2 {
                if wx % 8 < 3 { p.set(x, y, light) }
            } else if wavePhase < 4 {
                if wx % 8 < 2 { p.set(x, y, crest) }
                else if wx % 8 < 3 { p.set(x, y, light) }
            } else if wavePhase < 6 {
                if wx % 8 < 1 { p.set(x, y, white) }
                else if wx % 8 < 3 { p.set(x, y, crest) }
            } else if wavePhase < 8 {
                if wx % 8 < 2 { p.set(x, y, crest) }
                else if wx % 8 < 3 { p.set(x, y, light) }
            } else if wavePhase >= 12 && wavePhase < 14 {
                if wx % 8 >= 4 && wx % 8 < 6 { p.set(x, y, dark) }
            }
        }
    }

    return p
}

func drawTerrainTree() -> PixelCanvas {
    // Grass base
    let p = PixelCanvas(fill: C(50, 130, 40))
    var rng = SimpleRNG(seed: 77)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 15) { p.set(x, y, C(35, 100, 28)) }
        }
    }

    let trunk = C(80, 50, 20)
    let trunkDark = C(60, 35, 15)
    let canopy = C(30, 100, 25)
    let canopyLight = C(50, 125, 35)
    let canopyDark = C(20, 75, 15)

    // Trunk (center, rows 16-28)
    for y in 16...28 {
        for x in 14...17 { p.set(x, y, trunk) }
    }
    p.set(14, 17, trunkDark); p.set(14, 20, trunkDark)
    p.set(14, 24, trunkDark); p.set(17, 19, trunkDark)

    // Canopy (rows 4-18, wide ellipse)
    for y in 4...18 {
        let cy = 11
        let dy = y - cy
        let halfW = Int(sqrt(max(0, Double(8 * 8 - dy * dy))) * 1.2)
        for x in (16 - halfW)...(15 + halfW) {
            p.set(x, y, canopy)
        }
    }
    // Canopy highlights and shadows
    for y in 5...10 {
        for x in 12...19 {
            if rng.nextBool(chance: 30) { p.set(x, y, canopyLight) }
        }
    }
    for y in 14...17 {
        for x in 10...21 {
            if rng.nextBool(chance: 25) { p.set(x, y, canopyDark) }
        }
    }
    // Top highlight
    for x in 13...18 { if rng.nextBool(chance: 50) { p.set(x, 5, canopyLight) } }

    return p
}

func drawTerrainShrub() -> PixelCanvas {
    let p = PixelCanvas(fill: C(50, 130, 40))
    var rng = SimpleRNG(seed: 55)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 15) { p.set(x, y, C(35, 100, 28)) }
        }
    }

    let bush = C(40, 90, 30)
    let bushLight = C(55, 110, 40)
    let bushDark = C(25, 65, 18)

    // Small bush in center (rows 14-26)
    for y in 14...26 {
        let cy = 20
        let dy = y - cy
        let halfW = Int(sqrt(max(0, Double(7 * 7 - dy * dy))) * 1.1)
        for x in (16 - halfW)...(15 + halfW) {
            p.set(x, y, bush)
        }
    }
    // Bush detail
    for y in 15...19 {
        for x in 12...20 {
            if rng.nextBool(chance: 35) { p.set(x, y, bushLight) }
        }
    }
    for y in 22...25 {
        for x in 12...20 {
            if rng.nextBool(chance: 25) { p.set(x, y, bushDark) }
        }
    }
    // Berries
    p.set(14, 18, C(180, 40, 40))
    p.set(18, 20, C(180, 40, 40))
    p.set(16, 22, C(180, 40, 40))

    return p
}

func drawTerrainWall() -> PixelCanvas {
    let p = PixelCanvas(fill: C(80, 80, 85))
    let mortar = C(60, 60, 65)
    let brickLight = C(90, 90, 95)
    let brickDark = C(70, 70, 75)

    // Brick pattern
    for row in 0..<8 {
        let y = row * 4
        // Mortar line
        for x in 0..<32 { p.set(x, y, mortar) }
        let offset = (row % 2 == 0) ? 0 : 8
        // Vertical mortar
        for bx in stride(from: offset, to: 32, by: 16) {
            for dy in 0..<4 { p.set(bx, y + dy, mortar) }
        }
        // Brick variation
        for dy in 1..<4 {
            for x in 0..<32 {
                if (x + y) % 7 == 0 { p.set(x, y + dy, brickLight) }
                else if (x + y) % 11 == 0 { p.set(x, y + dy, brickDark) }
            }
        }
    }

    return p
}

func drawTerrainOre() -> PixelCanvas {
    let p = drawTerrainStone() // Start with stone base
    let vein = C(180, 140, 40)
    let veinBright = C(210, 170, 50)
    let veinDark = C(140, 110, 30)

    // Gold/copper veins running through
    p.drawLine(x0: 3, y0: 10, x1: 12, y1: 8, vein)
    p.drawLine(x0: 12, y0: 8, x1: 18, y1: 14, vein)
    p.drawLine(x0: 18, y0: 14, x1: 28, y1: 12, vein)

    p.drawLine(x0: 8, y0: 22, x1: 16, y1: 20, vein)
    p.drawLine(x0: 16, y0: 20, x1: 24, y1: 24, vein)

    // Bright spots on veins
    p.set(10, 8, veinBright); p.set(11, 8, veinBright)
    p.set(15, 12, veinBright); p.set(16, 13, veinBright)
    p.set(25, 12, veinBright)
    p.set(12, 21, veinBright); p.set(20, 22, veinBright)

    // Darker spots
    p.set(7, 9, veinDark); p.set(22, 13, veinDark)
    p.set(14, 20, veinDark)

    return p
}

func drawTerrainWoodenFloor() -> PixelCanvas {
    let p = PixelCanvas(fill: C(160, 120, 70))
    let dark = C(135, 100, 55)
    let grain = C(145, 108, 62)
    let light = C(175, 135, 82)
    let gap = C(110, 80, 45)

    // Plank gaps (vertical lines)
    for x in stride(from: 7, to: 32, by: 8) {
        for y in 0..<32 { p.set(x, y, gap) }
    }

    // Wood grain lines (horizontal, within planks)
    for plank in 0..<4 {
        let px = plank * 8
        for y in stride(from: 3, to: 30, by: 5) {
            for dx in 1..<7 {
                p.set(px + dx, y, grain)
            }
        }
        // Additional grain
        for y in stride(from: 6, to: 30, by: 7) {
            for dx in 2..<6 {
                p.set(px + dx, y, dark)
            }
        }
    }

    // Light highlights
    var rng = SimpleRNG(seed: 333)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 8) { p.set(x, y, light) }
        }
    }

    // Knot holes
    p.set(4, 14, dark); p.set(5, 14, dark); p.set(4, 15, dark); p.set(5, 15, dark)
    p.set(20, 8, dark); p.set(21, 8, dark); p.set(20, 9, dark)

    return p
}

func drawTerrainStoneFloor() -> PixelCanvas {
    let p = PixelCanvas(fill: C(150, 150, 155))
    let light = C(165, 165, 170)
    let dark = C(130, 130, 135)
    let gap = C(100, 100, 105)

    // Checkerboard tile pattern
    for ty in 0..<4 {
        for tx in 0..<4 {
            let x0 = tx * 8
            let y0 = ty * 8
            let isLight = (tx + ty) % 2 == 0
            let fill = isLight ? light : dark

            for dy in 0..<8 {
                for dx in 0..<8 {
                    p.set(x0 + dx, y0 + dy, fill)
                }
            }
            // Gap/grout lines
            for dx in 0..<8 { p.set(x0 + dx, y0, gap) }
            for dy in 0..<8 { p.set(x0, y0 + dy, gap) }
        }
    }

    return p
}

func drawTerrainConstructedWall() -> PixelCanvas {
    let p = PixelCanvas(fill: C(100, 100, 110))
    let mortar = C(80, 80, 90)
    let brickLight = C(115, 115, 125)
    let brickDark = C(90, 90, 100)

    // Neater brick pattern
    for row in 0..<8 {
        let y = row * 4
        for x in 0..<32 { p.set(x, y, mortar) }
        let offset = (row % 2 == 0) ? 0 : 8
        for bx in stride(from: offset, to: 32, by: 16) {
            for dy in 0..<4 { p.set(bx, y + dy, mortar) }
        }
        // Cleaner bricks
        for dy in 1..<4 {
            for x in 0..<32 {
                if (x + y * 3) % 9 == 0 { p.set(x, y + dy, brickLight) }
                else if (x + y * 3) % 13 == 0 { p.set(x, y + dy, brickDark) }
            }
        }
    }

    return p
}

func drawTerrainStairsUp() -> PixelCanvas {
    let p = drawTerrainStoneFloor()
    let arrow = C(220, 220, 60)
    let arrowDark = C(180, 180, 40)

    // Upward arrow
    // Arrow head
    p.set(15, 6, arrow); p.set(16, 6, arrow)
    p.set(14, 7, arrow); p.set(15, 7, arrow); p.set(16, 7, arrow); p.set(17, 7, arrow)
    p.set(13, 8, arrow); p.set(14, 8, arrow); p.set(15, 8, arrow)
    p.set(16, 8, arrow); p.set(17, 8, arrow); p.set(18, 8, arrow)
    p.set(12, 9, arrowDark); p.set(13, 9, arrow); p.set(14, 9, arrow)
    p.set(15, 9, arrow); p.set(16, 9, arrow); p.set(17, 9, arrow)
    p.set(18, 9, arrow); p.set(19, 9, arrowDark)

    // Arrow shaft
    for y in 10...22 {
        p.set(14, y, arrow); p.set(15, y, arrow)
        p.set(16, y, arrow); p.set(17, y, arrow)
    }

    // Stair steps
    let step = C(160, 160, 165)
    let stepDark = C(120, 120, 130)
    for i in 0..<3 {
        let sy = 24 + i * 2
        let sw = 20 - i * 4
        let sx = 6 + i * 2
        p.fillRect(sx, sy, sw, 1, step)
        p.fillRect(sx, sy + 1, sw, 1, stepDark)
    }

    return p
}

func drawTerrainStairsDown() -> PixelCanvas {
    let p = drawTerrainStoneFloor()
    let arrow = C(220, 220, 60)
    let arrowDark = C(180, 180, 40)

    // Downward arrow
    p.set(15, 22, arrow); p.set(16, 22, arrow)
    p.set(14, 21, arrow); p.set(15, 21, arrow); p.set(16, 21, arrow); p.set(17, 21, arrow)
    p.set(13, 20, arrow); p.set(14, 20, arrow); p.set(15, 20, arrow)
    p.set(16, 20, arrow); p.set(17, 20, arrow); p.set(18, 20, arrow)
    p.set(12, 19, arrowDark); p.set(13, 19, arrow); p.set(14, 19, arrow)
    p.set(15, 19, arrow); p.set(16, 19, arrow); p.set(17, 19, arrow)
    p.set(18, 19, arrow); p.set(19, 19, arrowDark)

    // Arrow shaft
    for y in 6...18 {
        p.set(14, y, arrow); p.set(15, y, arrow)
        p.set(16, y, arrow); p.set(17, y, arrow)
    }

    // Stair steps going down
    let step = C(160, 160, 165)
    let stepDark = C(120, 120, 130)
    for i in 0..<3 {
        let sy = 24 + i * 2
        let sw = 14 + i * 4
        let sx = 9 - i * 2
        p.fillRect(sx, sy, sw, 1, step)
        p.fillRect(sx, sy + 1, sw, 1, stepDark)
    }

    return p
}

func drawTerrainStairsUpDown() -> PixelCanvas {
    let p = drawTerrainStoneFloor()
    let arrowUp = C(220, 220, 60)
    let arrowDown = C(180, 140, 60)

    // Up arrow (left side)
    p.set(8, 6, arrowUp); p.set(9, 6, arrowUp)
    p.set(7, 7, arrowUp); p.set(8, 7, arrowUp); p.set(9, 7, arrowUp); p.set(10, 7, arrowUp)
    p.set(6, 8, arrowUp); p.set(7, 8, arrowUp); p.set(8, 8, arrowUp)
    p.set(9, 8, arrowUp); p.set(10, 8, arrowUp); p.set(11, 8, arrowUp)
    for y in 9...18 {
        p.set(8, y, arrowUp); p.set(9, y, arrowUp)
    }

    // Down arrow (right side)
    p.set(22, 25, arrowDown); p.set(23, 25, arrowDown)
    p.set(21, 24, arrowDown); p.set(22, 24, arrowDown); p.set(23, 24, arrowDown); p.set(24, 24, arrowDown)
    p.set(20, 23, arrowDown); p.set(21, 23, arrowDown); p.set(22, 23, arrowDown)
    p.set(23, 23, arrowDown); p.set(24, 23, arrowDown); p.set(25, 23, arrowDown)
    for y in 13...22 {
        p.set(22, y, arrowDown); p.set(23, y, arrowDown)
    }

    return p
}

func drawTerrainRampUp() -> PixelCanvas {
    let p = PixelCanvas(fill: C(130, 130, 130))
    let dark = C(100, 100, 105)
    let light = C(155, 155, 158)
    let edge = C(80, 80, 85)

    // Angled ramp going up to the right
    // Fill base
    for y in 0..<32 {
        for x in 0..<32 {
            // The ramp surface: diagonal from bottom-left to top-right
            let threshold = 31 - (x * 28 / 31)
            if y >= threshold {
                p.set(x, y, C(140, 140, 145))
            } else {
                p.set(x, y, dark)
            }
        }
    }

    // Ramp surface edge line
    for x in 0..<32 {
        let ey = 31 - (x * 28 / 31)
        p.set(x, ey, edge)
        if ey > 0 { p.set(x, ey - 1, light) }
    }

    // Treads/grip lines
    for i in stride(from: 4, to: 30, by: 6) {
        let ey = 31 - (i * 28 / 31)
        for dy in 0..<2 {
            p.set(i, ey + dy + 1, edge)
            p.set(i + 1, ey + dy + 1, edge)
        }
    }

    // Arrow indicator (up-right)
    let arr = C(220, 220, 60)
    p.set(24, 6, arr); p.set(25, 5, arr); p.set(26, 4, arr)
    p.set(25, 4, arr); p.set(26, 5, arr); p.set(27, 4, arr)
    p.set(26, 3, arr)

    return p
}

func drawTerrainRampDown() -> PixelCanvas {
    let p = PixelCanvas(fill: C(130, 130, 130))
    let dark = C(100, 100, 105)
    let light = C(155, 155, 158)
    let edge = C(80, 80, 85)

    // Angled ramp going down to the right
    for y in 0..<32 {
        for x in 0..<32 {
            let threshold = (x * 28 / 31) + 3
            if y >= threshold {
                p.set(x, y, C(140, 140, 145))
            } else {
                p.set(x, y, dark)
            }
        }
    }

    // Ramp surface edge
    for x in 0..<32 {
        let ey = (x * 28 / 31) + 3
        p.set(x, ey, edge)
        if ey > 0 { p.set(x, ey - 1, light) }
    }

    // Treads
    for i in stride(from: 4, to: 30, by: 6) {
        let ey = (i * 28 / 31) + 3
        for dy in 0..<2 {
            p.set(i, ey + dy + 1, edge)
            p.set(i + 1, ey + dy + 1, edge)
        }
    }

    // Arrow indicator (down-right)
    let arr = C(220, 220, 60)
    p.set(24, 24, arr); p.set(25, 25, arr); p.set(26, 26, arr)
    p.set(25, 26, arr); p.set(26, 25, arr); p.set(27, 26, arr)
    p.set(26, 27, arr)

    return p
}

// MARK: - Seasonal Terrain Sprites

// --- Spring variants ---

func drawTerrainGrassSpring() -> PixelCanvas {
    let p = PixelCanvas(fill: C(60, 150, 50))
    var rng = SimpleRNG(seed: 43)
    let dark = C(40, 120, 35)
    let light = C(80, 170, 65)
    let brightGreen = C(90, 180, 70)

    for y in 0..<32 {
        for x in 0..<32 {
            let v = rng.nextInt(100)
            if v < 15 { p.set(x, y, dark) }
            else if v < 22 { p.set(x, y, light) }
            else if v < 25 { p.set(x, y, brightGreen) }
        }
    }
    // Yellow wildflowers
    let flowerYellow = C(240, 220, 60)
    let flowerWhite = C(240, 240, 220)
    p.set(5, 8, flowerYellow); p.set(6, 8, flowerYellow)
    p.set(14, 20, flowerYellow); p.set(15, 20, flowerYellow)
    p.set(24, 12, flowerWhite); p.set(25, 12, flowerWhite)
    p.set(10, 28, flowerWhite)
    p.set(20, 4, flowerYellow)
    p.set(28, 22, flowerWhite); p.set(29, 22, flowerWhite)
    return p
}

func drawTerrainTreeSpring() -> PixelCanvas {
    let p = PixelCanvas(fill: C(60, 150, 50))
    var rng = SimpleRNG(seed: 78)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 15) { p.set(x, y, C(40, 120, 35)) }
        }
    }
    let trunk = C(80, 50, 20)
    let trunkDark = C(60, 35, 15)
    let canopy = C(40, 120, 30)
    let canopyLight = C(60, 145, 45)
    let blossom = C(240, 180, 200)
    let blossomDark = C(220, 150, 170)

    for y in 16...28 {
        for x in 14...17 { p.set(x, y, trunk) }
    }
    p.set(14, 17, trunkDark); p.set(14, 20, trunkDark)
    for y in 4...18 {
        let dy = y - 11
        let halfW = Int(sqrt(max(0, Double(8 * 8 - dy * dy))) * 1.2)
        for x in (16 - halfW)...(15 + halfW) { p.set(x, y, canopy) }
    }
    for y in 5...10 {
        for x in 12...19 { if rng.nextBool(chance: 30) { p.set(x, y, canopyLight) } }
    }
    // Pink blossoms scattered on canopy
    for y in 4...14 {
        for x in 9...22 {
            if rng.nextBool(chance: 18) {
                let dy = y - 11
                let halfW = Int(sqrt(max(0, Double(8 * 8 - dy * dy))) * 1.2)
                if x >= (16 - halfW) && x <= (15 + halfW) {
                    p.set(x, y, rng.nextBool(chance: 50) ? blossom : blossomDark)
                }
            }
        }
    }
    return p
}

func drawTerrainShrubSpring() -> PixelCanvas {
    let p = PixelCanvas(fill: C(60, 150, 50))
    var rng = SimpleRNG(seed: 56)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 15) { p.set(x, y, C(40, 120, 35)) }
        }
    }
    let bush = C(50, 110, 38)
    let bushLight = C(65, 130, 50)
    let bud = C(200, 220, 100)

    for y in 14...26 {
        let dy = y - 20
        let halfW = Int(sqrt(max(0, Double(7 * 7 - dy * dy))) * 1.1)
        for x in (16 - halfW)...(15 + halfW) { p.set(x, y, bush) }
    }
    for y in 15...19 {
        for x in 12...20 { if rng.nextBool(chance: 35) { p.set(x, y, bushLight) } }
    }
    // Spring buds
    p.set(13, 17, bud); p.set(17, 19, bud); p.set(15, 15, bud)
    p.set(19, 18, bud); p.set(11, 20, bud)
    return p
}

// --- Autumn variants ---

func drawTerrainGrassAutumn() -> PixelCanvas {
    let p = PixelCanvas(fill: C(140, 130, 60))
    var rng = SimpleRNG(seed: 44)
    let dark = C(120, 105, 45)
    let light = C(160, 150, 75)
    let orange = C(170, 120, 50)

    for y in 0..<32 {
        for x in 0..<32 {
            let v = rng.nextInt(100)
            if v < 15 { p.set(x, y, dark) }
            else if v < 22 { p.set(x, y, light) }
            else if v < 28 { p.set(x, y, orange) }
        }
    }
    return p
}

func drawTerrainTreeAutumn() -> PixelCanvas {
    let p = PixelCanvas(fill: C(140, 130, 60))
    var rng = SimpleRNG(seed: 79)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 15) { p.set(x, y, C(120, 105, 45)) }
        }
    }
    let trunk = C(80, 50, 20)
    let trunkDark = C(60, 35, 15)
    let canopyOrange = C(200, 100, 30)
    let canopyRed = C(180, 50, 25)
    let canopyYellow = C(210, 170, 40)

    for y in 16...28 {
        for x in 14...17 { p.set(x, y, trunk) }
    }
    p.set(14, 17, trunkDark); p.set(14, 20, trunkDark)
    for y in 4...18 {
        let dy = y - 11
        let halfW = Int(sqrt(max(0, Double(8 * 8 - dy * dy))) * 1.2)
        for x in (16 - halfW)...(15 + halfW) { p.set(x, y, canopyOrange) }
    }
    for y in 5...12 {
        for x in 11...20 {
            if rng.nextBool(chance: 35) { p.set(x, y, canopyYellow) }
            if rng.nextBool(chance: 20) { p.set(x, y, canopyRed) }
        }
    }
    return p
}

func drawTerrainShrubAutumn() -> PixelCanvas {
    let p = PixelCanvas(fill: C(140, 130, 60))
    var rng = SimpleRNG(seed: 57)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 15) { p.set(x, y, C(120, 105, 45)) }
        }
    }
    let bush = C(120, 70, 30)
    let bushBare = C(90, 55, 25)

    for y in 14...26 {
        let dy = y - 20
        let halfW = Int(sqrt(max(0, Double(7 * 7 - dy * dy))) * 1.1)
        for x in (16 - halfW)...(15 + halfW) {
            p.set(x, y, rng.nextBool(chance: 40) ? bushBare : bush)
        }
    }
    return p
}

func drawTerrainWaterAutumn(frameOffset: Int = 0) -> PixelCanvas {
    let p = PixelCanvas(fill: C(35, 65, 130))
    let dark = C(25, 50, 110)
    let light = C(55, 90, 150)
    let crest = C(120, 160, 190)

    for y in 0..<32 {
        let wavePhase = (y + frameOffset * 4) % 16
        for x in 0..<32 {
            let wx = (x + (y / 4) * 3 + frameOffset * 4) % 32
            if wavePhase < 2 {
                if wx % 8 < 3 { p.set(x, y, light) }
            } else if wavePhase < 4 {
                if wx % 8 < 2 { p.set(x, y, crest) }
                else if wx % 8 < 3 { p.set(x, y, light) }
            } else if wavePhase >= 12 && wavePhase < 14 {
                if wx % 8 >= 4 && wx % 8 < 6 { p.set(x, y, dark) }
            }
        }
    }
    return p
}

// --- Winter variants ---

func drawTerrainGrassWinter() -> PixelCanvas {
    let p = PixelCanvas(fill: C(200, 210, 220))
    var rng = SimpleRNG(seed: 45)
    let dark = C(170, 180, 195)
    let light = C(220, 225, 235)
    let brown = C(140, 120, 90)

    for y in 0..<32 {
        for x in 0..<32 {
            let v = rng.nextInt(100)
            if v < 12 { p.set(x, y, dark) }
            else if v < 18 { p.set(x, y, light) }
            else if v < 22 { p.set(x, y, brown) }
        }
    }
    return p
}

func drawTerrainTreeWinter() -> PixelCanvas {
    let p = PixelCanvas(fill: C(200, 210, 220))
    var rng = SimpleRNG(seed: 80)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 15) { p.set(x, y, C(170, 180, 195)) }
        }
    }
    let trunk = C(70, 45, 20)
    let trunkDark = C(55, 35, 15)
    let branch = C(80, 55, 25)
    let snow = C(230, 235, 240)

    for y in 16...28 {
        for x in 14...17 { p.set(x, y, trunk) }
    }
    p.set(14, 17, trunkDark); p.set(14, 20, trunkDark)
    // Bare branches
    p.drawLine(x0: 15, y0: 16, x1: 8, y1: 8, branch)
    p.drawLine(x0: 16, y0: 16, x1: 23, y1: 8, branch)
    p.drawLine(x0: 15, y0: 12, x1: 10, y1: 5, branch)
    p.drawLine(x0: 16, y0: 12, x1: 21, y1: 5, branch)
    p.drawLine(x0: 14, y0: 14, x1: 7, y1: 12, branch)
    p.drawLine(x0: 17, y0: 14, x1: 24, y1: 12, branch)
    // Snow on branches
    p.set(8, 7, snow); p.set(9, 7, snow); p.set(10, 8, snow)
    p.set(22, 7, snow); p.set(23, 7, snow); p.set(21, 8, snow)
    p.set(10, 4, snow); p.set(11, 4, snow)
    p.set(20, 4, snow); p.set(21, 4, snow)
    p.set(7, 11, snow); p.set(8, 11, snow)
    p.set(23, 11, snow); p.set(24, 11, snow)
    return p
}

func drawTerrainShrubWinter() -> PixelCanvas {
    let p = PixelCanvas(fill: C(200, 210, 220))
    var rng = SimpleRNG(seed: 58)
    for y in 0..<32 {
        for x in 0..<32 {
            if rng.nextBool(chance: 15) { p.set(x, y, C(170, 180, 195)) }
        }
    }
    let snow = C(225, 230, 238)
    let snowDark = C(190, 200, 215)
    let twig = C(80, 55, 25)

    // Snow mound shape
    for y in 16...26 {
        let dy = y - 21
        let halfW = Int(sqrt(max(0, Double(6 * 6 - dy * dy))) * 1.2)
        for x in (16 - halfW)...(15 + halfW) {
            p.set(x, y, rng.nextBool(chance: 30) ? snowDark : snow)
        }
    }
    // Twigs poking out
    p.set(12, 17, twig); p.set(11, 16, twig)
    p.set(19, 18, twig); p.set(20, 17, twig)
    p.set(15, 16, twig); p.set(15, 15, twig)
    return p
}

func drawTerrainDirtWinter() -> PixelCanvas {
    let p = PixelCanvas(fill: C(160, 150, 130))
    var rng = SimpleRNG(seed: 102)
    let dark = C(140, 130, 110)
    let frost = C(200, 210, 220)
    let pebble = C(130, 120, 100)

    for y in 0..<32 {
        for x in 0..<32 {
            let v = rng.nextInt(100)
            if v < 12 { p.set(x, y, dark) }
            else if v < 25 { p.set(x, y, frost) }
        }
    }
    p.set(5, 10, pebble); p.set(6, 10, pebble)
    p.set(20, 5, pebble); p.set(21, 5, pebble)
    p.set(12, 25, pebble); p.set(13, 25, pebble)
    return p
}

func drawTerrainWaterWinter(frameOffset: Int = 0) -> PixelCanvas {
    // Frozen ice — mostly static regardless of frame
    let p = PixelCanvas(fill: C(180, 210, 230))
    var rng = SimpleRNG(seed: 300 + UInt64(frameOffset))
    let iceDark = C(150, 190, 215)
    let iceLight = C(210, 230, 245)
    let crack = C(130, 170, 200)

    for y in 0..<32 {
        for x in 0..<32 {
            let v = rng.nextInt(100)
            if v < 10 { p.set(x, y, iceDark) }
            else if v < 18 { p.set(x, y, iceLight) }
        }
    }
    // Ice cracks
    p.drawLine(x0: 4, y0: 10, x1: 15, y1: 14, crack)
    p.drawLine(x0: 15, y0: 14, x1: 28, y1: 10, crack)
    p.drawLine(x0: 8, y0: 22, x1: 20, y1: 26, crack)
    // Slight shimmer variation per frame
    let shimmerX = 10 + frameOffset * 7
    let shimmerY = 5 + frameOffset * 5
    if shimmerX < 32 && shimmerY < 32 {
        p.set(shimmerX, shimmerY, iceLight)
        p.set(shimmerX + 1, shimmerY, iceLight)
    }
    return p
}

// MARK: - Item Sprites

func drawItemFood() -> PixelCanvas {
    let p = PixelCanvas()
    let bread = C(190, 150, 70)
    let breadDark = C(160, 120, 50)
    let breadLight = C(210, 175, 90)
    let plate = C(200, 200, 205)
    let plateDark = C(170, 170, 178)

    // Plate (bottom)
    p.fillEllipse(cx: 15, cy: 22, rx: 12, ry: 5, plate)
    p.fillEllipse(cx: 15, cy: 22, rx: 10, ry: 4, plateDark)
    p.fillEllipse(cx: 15, cy: 22, rx: 10, ry: 3, plate)

    // Bread loaf
    for y in 12...20 {
        let cy = 16
        let dy = y - cy
        let halfW = Int(sqrt(max(0, Double(5 * 5 - dy * dy))) * 1.8)
        for x in (15 - halfW)...(15 + halfW) {
            p.set(x, y, bread)
        }
    }
    // Top highlight
    for x in 11...19 { p.set(x, 12, breadLight); p.set(x, 13, breadLight) }
    // Bottom shadow
    for x in 10...20 { p.set(x, 19, breadDark); p.set(x, 20, breadDark) }
    // Score line on top
    p.drawLine(x0: 12, y0: 14, x1: 18, y1: 14, breadDark)
    // Slight texture
    p.set(13, 15, breadDark); p.set(17, 16, breadDark)

    return p
}

func drawItemDrink() -> PixelCanvas {
    let p = PixelCanvas()
    let wood = C(120, 75, 35)
    let woodDark = C(90, 55, 25)
    let woodLight = C(145, 100, 50)
    let liquid = C(50, 90, 170)
    let froth = C(230, 225, 200)
    let frothDark = C(200, 195, 170)

    // Mug body (rows 10-28)
    for y in 10...28 {
        for x in 9...22 {
            p.set(x, y, wood)
        }
    }
    // Left edge dark
    for y in 10...28 { p.set(9, y, woodDark) }
    // Right edge light
    for y in 10...28 { p.set(22, y, woodLight) }
    // Bottom
    for x in 9...22 { p.set(x, 28, woodDark) }

    // Handle (right side)
    for y in 14...24 { p.set(23, y, wood); p.set(24, y, wood) }
    for y in 15...23 { p.set(25, y, woodDark) }
    p.set(23, 14, woodDark); p.set(24, 14, woodDark)
    p.set(23, 24, woodDark); p.set(24, 24, woodDark)

    // Liquid visible at top
    for x in 10...21 { p.set(x, 12, liquid); p.set(x, 13, liquid) }

    // Froth/foam
    for x in 9...22 {
        p.set(x, 9, froth); p.set(x, 10, froth); p.set(x, 11, froth)
    }
    p.set(11, 8, froth); p.set(14, 8, froth); p.set(17, 8, froth); p.set(20, 8, froth)
    // Froth shading
    for x in 9...22 { p.set(x, 11, frothDark) }

    // Stave lines on mug
    for y in 10...28 {
        p.set(13, y, woodDark)
        p.set(18, y, woodDark)
    }
    // Metal band
    for x in 9...22 {
        p.set(x, 17, C(160, 160, 165))
        p.set(x, 24, C(160, 160, 165))
    }

    return p
}

func drawItemRawMeat() -> PixelCanvas {
    let p = PixelCanvas()
    let meat = C(180, 50, 50)
    let meatDark = C(140, 35, 35)
    let meatLight = C(200, 80, 70)
    let fat = C(220, 190, 170)
    let slab = C(160, 155, 145)

    // Stone slab
    p.fillEllipse(cx: 15, cy: 24, rx: 12, ry: 4, slab)
    p.fillEllipse(cx: 15, cy: 24, rx: 11, ry: 3, C(145, 140, 130))

    // Meat chunk (irregular shape)
    for y in 10...22 {
        let cy = 16
        let dy = y - cy
        let halfW = Int(sqrt(max(0, Double(7 * 7 - dy * dy))) * 1.3)
        for x in (14 - halfW)...(14 + halfW) {
            p.set(x, y, meat)
        }
    }
    // Texture
    p.fillRect(10, 13, 3, 2, meatLight)
    p.fillRect(16, 17, 2, 2, meatLight)
    p.fillRect(8, 18, 2, 2, meatDark)
    p.fillRect(14, 14, 2, 3, meatDark)
    // Fat marbling
    p.drawLine(x0: 9, y0: 15, x1: 13, y1: 13, fat)
    p.drawLine(x0: 12, y0: 19, x1: 17, y1: 17, fat)
    // Bone sticking out
    p.set(19, 14, C(230, 220, 200)); p.set(20, 13, C(230, 220, 200))
    p.set(21, 12, C(230, 220, 200)); p.set(22, 12, C(230, 220, 200))

    return p
}

func drawItemPlant() -> PixelCanvas {
    let p = PixelCanvas()
    let stem = C(60, 110, 30)
    let stemDark = C(45, 85, 22)
    let leaf = C(50, 140, 35)
    let leafLight = C(70, 165, 50)
    let leafDark = C(35, 105, 25)
    let pot = C(160, 90, 50)
    let potDark = C(130, 70, 35)

    // Small pot
    for y in 22...29 {
        let w = 5 + (y - 22) / 2
        for x in (15 - w)...(16 + w) {
            p.set(x, y, pot)
        }
    }
    // Pot rim
    for x in 9...22 { p.set(x, 22, potDark); p.set(x, 23, potDark) }
    // Pot shading
    for y in 24...29 { p.set(10, y, potDark); p.set(21, y, potDark) }

    // Stem
    for y in 10...22 { p.set(15, y, stem); p.set(16, y, stem) }

    // Leaves
    // Left leaf
    p.fillEllipse(cx: 11, cy: 14, rx: 4, ry: 2, leaf)
    p.set(11, 13, leafLight); p.set(12, 13, leafLight)
    p.set(10, 15, leafDark)
    // Right leaf
    p.fillEllipse(cx: 20, cy: 12, rx: 4, ry: 2, leaf)
    p.set(20, 11, leafLight); p.set(21, 11, leafLight)
    p.set(19, 13, leafDark)
    // Top leaf
    p.fillEllipse(cx: 15, cy: 8, rx: 3, ry: 3, leaf)
    p.set(15, 6, leafLight); p.set(16, 6, leafLight)
    p.set(14, 10, leafDark); p.set(16, 10, leafDark)
    // Small leaf
    p.fillEllipse(cx: 13, cy: 10, rx: 2, ry: 1, leafDark)

    return p
}

func drawItemBed() -> PixelCanvas {
    let p = PixelCanvas()
    let wood = C(120, 80, 35)
    let woodDark = C(90, 60, 25)
    let sheet = C(200, 200, 210)
    let sheetDark = C(170, 170, 180)
    let pillow = C(220, 220, 230)

    // Bed frame (top-down view, head at top)
    // Frame outline
    p.fillRect(4, 3, 24, 26, wood)
    p.fillRect(5, 4, 22, 24, sheet)

    // Wood frame edges
    for y in 3...28 { p.set(4, y, woodDark); p.set(27, y, woodDark) }
    for x in 4...27 { p.set(x, 3, woodDark); p.set(x, 28, woodDark) }

    // Headboard (thicker at top)
    p.fillRect(4, 2, 24, 3, wood)
    for x in 4...27 { p.set(x, 2, woodDark) }

    // Pillow
    p.fillRect(8, 5, 16, 5, pillow)
    p.fillRect(8, 5, 16, 1, C(210, 210, 220)) // pillow shadow
    p.set(8, 5, sheetDark); p.set(23, 5, sheetDark)
    p.set(8, 9, sheetDark); p.set(23, 9, sheetDark)

    // Sheet fold line
    for x in 5...26 { p.set(x, 16, sheetDark) }
    for x in 5...26 { p.set(x, 17, sheetDark) }

    // Blanket texture
    var rng = SimpleRNG(seed: 444)
    for y in 11...27 {
        for x in 5...26 {
            if rng.nextBool(chance: 10) { p.set(x, y, sheetDark) }
        }
    }

    // Corner posts
    p.fillRect(3, 2, 2, 2, woodDark)
    p.fillRect(27, 2, 2, 2, woodDark)
    p.fillRect(3, 28, 2, 2, woodDark)
    p.fillRect(27, 28, 2, 2, woodDark)

    return p
}

func drawItemTable() -> PixelCanvas {
    let p = PixelCanvas()
    let wood = C(140, 100, 50)
    let woodDark = C(110, 75, 35)
    let woodLight = C(165, 125, 65)

    // Table top (top-down, rectangle)
    p.fillRect(3, 6, 26, 20, wood)

    // Edge shading
    for x in 3...28 { p.set(x, 6, woodLight); p.set(x, 25, woodDark) }
    for y in 6...25 { p.set(3, y, woodLight); p.set(28, y, woodDark) }

    // Wood grain
    for y in stride(from: 9, to: 24, by: 3) {
        for x in 5...26 { p.set(x, y, woodDark) }
    }

    // Legs visible at corners
    p.fillRect(4, 4, 3, 3, woodDark)
    p.fillRect(25, 4, 3, 3, woodDark)
    p.fillRect(4, 25, 3, 3, woodDark)
    p.fillRect(25, 25, 3, 3, woodDark)

    // Highlight
    for x in 8...20 { p.set(x, 8, woodLight) }

    return p
}

func drawItemChair() -> PixelCanvas {
    let p = PixelCanvas()
    let wood = C(130, 90, 45)
    let woodDark = C(100, 65, 30)
    let woodLight = C(155, 115, 60)

    // Seat (top-down-ish, front-facing)
    p.fillRect(8, 14, 16, 10, wood)
    for x in 8...23 { p.set(x, 14, woodLight) }
    for x in 8...23 { p.set(x, 23, woodDark) }

    // Backrest
    p.fillRect(8, 4, 16, 11, woodDark)
    p.fillRect(9, 5, 14, 9, wood)
    // Back slats
    for y in 5...13 { p.set(12, y, woodDark); p.set(19, y, woodDark) }

    // Top rail
    for x in 8...23 { p.set(x, 4, woodDark) }

    // Front legs
    p.fillRect(8, 24, 2, 6, woodDark)
    p.fillRect(22, 24, 2, 6, woodDark)

    // Back legs (partially visible)
    p.fillRect(8, 13, 2, 2, woodDark)
    p.fillRect(22, 13, 2, 2, woodDark)

    // Seat edge highlight
    for x in 9...22 { p.set(x, 15, woodLight) }

    return p
}

func drawItemDoor() -> PixelCanvas {
    let p = PixelCanvas()
    let wood = C(140, 95, 45)
    let woodDark = C(110, 70, 30)
    let woodLight = C(165, 120, 60)
    let hinge = C(30, 30, 35)
    let handle = C(180, 170, 50)

    // Door frame (dark border)
    p.fillRect(5, 2, 22, 28, woodDark)
    // Door body
    p.fillRect(7, 3, 18, 26, wood)

    // Panels
    // Top panel
    p.drawRect(9, 5, 14, 10, woodDark)
    p.fillRect(10, 6, 12, 8, woodLight)
    // Bottom panel
    p.drawRect(9, 17, 14, 10, woodDark)
    p.fillRect(10, 18, 12, 8, woodLight)

    // Hinges (left side, black)
    p.fillRect(5, 7, 3, 2, hinge)
    p.fillRect(5, 20, 3, 2, hinge)

    // Handle (right side)
    p.fillRect(22, 15, 2, 2, handle)
    p.set(22, 17, C(150, 140, 40))

    // Wood grain in panels
    for y in stride(from: 7, to: 13, by: 2) {
        for x in 11...20 { p.set(x, y, C(155, 112, 55)) }
    }
    for y in stride(from: 19, to: 25, by: 2) {
        for x in 11...20 { p.set(x, y, C(155, 112, 55)) }
    }

    return p
}

func drawItemBarrel() -> PixelCanvas {
    let p = PixelCanvas()
    let wood = C(140, 95, 45)
    let woodDark = C(110, 70, 30)
    let woodLight = C(165, 120, 60)
    let band = C(140, 140, 150)
    let bandDark = C(110, 110, 120)

    // Barrel body (slightly wider in middle)
    for y in 5...28 {
        let cy = 16
        let dy = abs(y - cy)
        let halfW = 9 + max(0, 3 - dy / 3)
        for x in (15 - halfW)...(16 + halfW) {
            p.set(x, y, wood)
        }
    }

    // Stave lines
    for y in 5...28 {
        let cy = 16
        let dy = abs(y - cy)
        let halfW = 9 + max(0, 3 - dy / 3)
        // Left/right edge dark
        p.set(15 - halfW, y, woodDark)
        p.set(16 + halfW, y, woodDark)
    }
    // Vertical stave lines
    for x in stride(from: 9, to: 24, by: 3) {
        for y in 5...28 { p.set(x, y, woodDark) }
    }
    // Light highlight
    for y in 6...27 { p.set(17, y, woodLight); p.set(18, y, woodLight) }

    // Metal bands
    for x in 5...26 {
        p.set(x, 9, band); p.set(x, 10, band)
        p.set(x, 22, band); p.set(x, 23, band)
    }
    // Band rivets
    p.set(8, 9, bandDark); p.set(15, 9, bandDark); p.set(22, 9, bandDark)
    p.set(8, 22, bandDark); p.set(15, 22, bandDark); p.set(22, 22, bandDark)

    // Top rim
    p.fillEllipse(cx: 15, cy: 5, rx: 10, ry: 3, woodDark)
    p.fillEllipse(cx: 15, cy: 5, rx: 8, ry: 2, wood)

    return p
}

func drawItemBin() -> PixelCanvas {
    let p = PixelCanvas()
    let wood = C(120, 100, 70)
    let woodDark = C(90, 75, 50)
    let woodLight = C(145, 125, 90)
    let inside = C(50, 40, 30)

    // Open box (slightly 3/4 view)
    // Back wall
    p.fillRect(5, 8, 22, 4, woodDark)

    // Left wall
    for y in 8...26 { p.set(5, y, woodDark); p.set(6, y, woodDark) }

    // Right wall
    for y in 8...26 { p.set(26, y, woodDark); p.set(25, y, woodDark) }

    // Inside dark
    p.fillRect(7, 10, 18, 17, inside)

    // Front wall (lower, since it's open)
    p.fillRect(5, 22, 22, 5, wood)
    for x in 5...26 { p.set(x, 22, woodDark) }
    for x in 5...26 { p.set(x, 26, woodDark) }

    // Front wood plank lines
    for x in 5...26 { p.set(x, 24, woodLight) }

    // Side visible planks
    for y in stride(from: 10, to: 26, by: 3) {
        p.set(6, y, woodLight); p.set(25, y, woodLight)
    }

    // Bottom
    for x in 5...26 { p.set(x, 27, woodDark) }

    // Inside shadow gradient
    for y in 12...20 {
        for x in 8...24 {
            if (x + y) % 3 == 0 { p.set(x, y, C(40, 32, 24)) }
        }
    }

    return p
}

func drawItemPickaxe() -> PixelCanvas {
    let p = PixelCanvas()
    let handle = C(140, 100, 45)
    let handleDark = C(110, 75, 30)
    let metal = C(170, 175, 180)
    let metalDark = C(130, 135, 140)
    let metalBright = C(200, 205, 210)

    // Handle (diagonal, bottom-left to upper-right)
    p.drawLine(x0: 8, y0: 28, x1: 22, y1: 8, handle)
    p.drawLine(x0: 9, y0: 28, x1: 23, y1: 8, handle)
    p.drawLine(x0: 9, y0: 29, x1: 23, y1: 9, handleDark)

    // Pick head (horizontal at top of handle)
    // Left pick point
    for dy in 0..<2 {
        for x in 10...16 {
            p.set(x, 7 + dy, metal)
        }
    }
    p.set(9, 8, metal); p.set(8, 9, metal); p.set(7, 10, metalDark)
    p.set(9, 9, metalDark)

    // Right pick point
    for dy in 0..<2 {
        for x in 24...30 {
            p.set(x, 7 + dy, metal)
        }
    }
    p.set(30, 7, metalDark); p.set(31, 8, metalDark)

    // Head connecting piece
    for x in 16...24 {
        p.set(x, 6, metal); p.set(x, 7, metal)
        p.set(x, 8, metalDark); p.set(x, 9, metalDark)
    }

    // Bright edge on pick
    for x in 10...14 { p.set(x, 7, metalBright) }
    for x in 26...30 { p.set(x, 7, metalBright) }

    // Handle binding
    p.set(18, 12, C(80, 60, 30)); p.set(19, 12, C(80, 60, 30))
    p.set(18, 13, C(80, 60, 30)); p.set(19, 13, C(80, 60, 30))

    return p
}

func drawItemAxe() -> PixelCanvas {
    let p = PixelCanvas()
    let handle = C(140, 100, 45)
    let handleDark = C(110, 75, 30)
    let metal = C(170, 175, 180)
    let metalDark = C(130, 135, 140)
    let metalBright = C(210, 215, 220)

    // Handle (vertical)
    for y in 8...29 {
        p.set(15, y, handle); p.set(16, y, handle)
    }
    for y in 8...29 { p.set(14, y, handleDark) }

    // Axe head (right side)
    // Blade shape
    for y in 6...16 {
        let cy = 11
        let dy = abs(y - cy)
        let w = max(0, 8 - dy)
        for dx in 0...w {
            p.set(17 + dx, y, metal)
        }
    }
    // Blade edge (bright)
    for y in 7...15 {
        let cy = 11
        let dy = abs(y - cy)
        let w = max(0, 8 - dy)
        p.set(17 + w, y, metalBright)
    }
    // Inner shadow
    for y in 8...14 {
        p.set(17, y, metalDark); p.set(18, y, metalDark)
    }
    // Socket
    p.fillRect(14, 8, 4, 3, metalDark)
    p.fillRect(14, 13, 4, 3, metalDark)

    // Handle bottom
    p.set(15, 29, handleDark); p.set(16, 29, handleDark)

    return p
}

func drawItemLog() -> PixelCanvas {
    let p = PixelCanvas()
    let bark = C(110, 70, 30)
    let barkDark = C(80, 50, 20)
    let barkLight = C(135, 90, 40)
    let wood = C(180, 145, 90)
    let woodDark = C(150, 120, 70)
    let ring = C(140, 110, 65)

    // Horizontal log body
    for y in 12...22 {
        for x in 2...26 {
            p.set(x, y, bark)
        }
    }
    // Top highlight
    for x in 2...26 { p.set(x, 12, barkLight); p.set(x, 13, barkLight) }
    // Bottom shadow
    for x in 2...26 { p.set(x, 21, barkDark); p.set(x, 22, barkDark) }
    // Bark texture
    for x in stride(from: 5, to: 26, by: 4) {
        for y in 14...20 { p.set(x, y, barkDark) }
    }

    // Cross-section on right end
    p.fillCircle(cx: 27, cy: 17, radius: 5, wood)
    p.fillCircle(cx: 27, cy: 17, radius: 4, woodDark)
    p.fillCircle(cx: 27, cy: 17, radius: 3, wood)
    // Rings
    p.set(27, 15, ring); p.set(27, 19, ring)
    p.set(25, 17, ring); p.set(29, 17, ring)
    p.set(27, 17, woodDark) // center dot
    // Bark edge on cross section
    for y in 12...22 { p.set(26, y, barkDark) }

    return p
}

func drawItemStone() -> PixelCanvas {
    let p = PixelCanvas()
    let stone = C(140, 140, 140)
    let stoneDark = C(110, 110, 115)
    let stoneLight = C(170, 170, 172)
    let highlight = C(190, 190, 192)

    // Rough stone chunk (irregular shape)
    // Main body using filled circle approach but irregular
    for y in 10...25 {
        let cy = 17
        let dy = y - cy
        var halfW = Int(sqrt(max(0, Double(8 * 8 - dy * dy))) * 1.2)
        // Make irregular
        if y == 12 || y == 13 { halfW += 1 }
        if y == 23 || y == 24 { halfW -= 1 }
        for x in (15 - halfW)...(16 + halfW) {
            p.set(x, y, stone)
        }
    }
    // Top highlight
    for y in 10...14 {
        let cy = 17
        let dy = y - cy
        let halfW = Int(sqrt(max(0, Double(8 * 8 - dy * dy))) * 1.2)
        let lo = 15 - halfW + 1, hi = 16 + halfW - 1
        if lo <= hi { for x in lo...hi { p.set(x, y, stoneLight) } }
    }
    // Bottom shadow
    for y in 21...25 {
        let cy = 17
        let dy = y - cy
        let halfW = Int(sqrt(max(0, Double(8 * 8 - dy * dy))) * 1.2)
        let lo = 15 - halfW + 1, hi = 16 + halfW - 1
        if lo <= hi { for x in lo...hi { p.set(x, y, stoneDark) } }
    }
    // Bright spot
    p.set(13, 12, highlight); p.set(14, 12, highlight)
    p.set(13, 13, highlight)

    // Facet lines
    p.drawLine(x0: 10, y0: 16, x1: 16, y1: 14, stoneDark)
    p.drawLine(x0: 16, y0: 14, x1: 22, y1: 17, stoneDark)

    return p
}

func drawItemOre() -> PixelCanvas {
    let p = drawItemStone() // Base stone
    let gold = C(200, 160, 40)
    let goldBright = C(230, 200, 60)
    let goldDark = C(160, 120, 30)

    // Gold/mineral spots
    p.fillRect(11, 14, 3, 2, gold)
    p.set(12, 14, goldBright)

    p.fillRect(17, 18, 2, 3, gold)
    p.set(17, 18, goldBright)

    p.fillRect(14, 20, 3, 2, goldDark)
    p.set(15, 20, gold)

    p.set(19, 13, gold); p.set(20, 13, goldBright)
    p.set(10, 18, gold)

    return p
}

// MARK: - UI Sprites

func drawUISelection() -> PixelCanvas {
    let p = PixelCanvas()
    let gold = C(220, 180, 40)
    let goldBright = C(240, 210, 60)

    // Selection ring - 2px wide circle outline
    let cx = 15, cy = 15
    let outerR = 14, innerR = 12

    for y in 0..<32 {
        for x in 0..<32 {
            let dx = x - cx
            let dy = y - cy
            let distSq = dx * dx + dy * dy
            if distSq <= outerR * outerR && distSq >= innerR * innerR {
                p.set(x, y, gold)
            }
        }
    }
    // Bright highlights at cardinal points
    p.set(15, 1, goldBright); p.set(16, 1, goldBright)
    p.set(15, 29, goldBright); p.set(16, 29, goldBright)
    p.set(1, 15, goldBright); p.set(1, 16, goldBright)
    p.set(29, 15, goldBright); p.set(29, 16, goldBright)

    // Corner accents
    p.set(5, 5, goldBright); p.set(26, 5, goldBright)
    p.set(5, 26, goldBright); p.set(26, 26, goldBright)

    return p
}

func drawUIHealthbarBG() -> PixelCanvas {
    let p = PixelCanvas()
    let bg = C(40, 40, 40)
    let border = C(60, 60, 65)

    // Rounded rectangle 24x4 centered in 32x32
    // Center: x=4..27, y=14..17
    let rx = 4, ry = 14, rw = 24, rh = 4

    // Border (1px around)
    p.fillRect(rx - 1, ry - 1, rw + 2, rh + 2, border)

    // Rounded corners (remove outer corners of border)
    p.set(rx - 1, ry - 1, .clear)
    p.set(rx + rw, ry - 1, .clear)
    p.set(rx - 1, ry + rh, .clear)
    p.set(rx + rw, ry + rh, .clear)

    // Background fill
    p.fillRect(rx, ry, rw, rh, bg)

    return p
}

func drawUIHealthbarFill() -> PixelCanvas {
    let p = PixelCanvas()
    let fill = C(40, 180, 40)
    let fillLight = C(60, 210, 60)

    // Fill rectangle 22x2 centered in 32x32
    let rx = 5, ry = 15, rw = 22, rh = 2

    p.fillRect(rx, ry, rw, rh, fill)
    // Top edge highlight
    for x in rx..<(rx + rw) { p.set(x, ry, fillLight) }

    return p
}

// MARK: - Main Generation

print("=== Outpost Asset Generator ===")
print("Asset catalog: \(assetsRoot.path)")
print("")

// Verify asset catalog exists
let fm = FileManager.default
guard fm.fileExists(atPath: assetsRoot.path) else {
    print("ERROR: Asset catalog not found at \(assetsRoot.path)")
    exit(1)
}

// Create new imagesets
let newImagesets: [(String, URL)] = [
    ("terrain_water_0", terrainDir),
    ("terrain_water_1", terrainDir),
    ("terrain_water_2", terrainDir),
    ("ui_healthbar_bg", uiDir),
    ("ui_healthbar_fill", uiDir),
    // Seasonal terrain
    ("terrain_grass_spring", terrainDir),
    ("terrain_grass_autumn", terrainDir),
    ("terrain_grass_winter", terrainDir),
    ("terrain_tree_spring", terrainDir),
    ("terrain_tree_autumn", terrainDir),
    ("terrain_tree_winter", terrainDir),
    ("terrain_shrub_spring", terrainDir),
    ("terrain_shrub_autumn", terrainDir),
    ("terrain_shrub_winter", terrainDir),
    ("terrain_dirt_winter", terrainDir),
    ("terrain_water_autumn_0", terrainDir),
    ("terrain_water_autumn_1", terrainDir),
    ("terrain_water_autumn_2", terrainDir),
    ("terrain_water_winter_0", terrainDir),
    ("terrain_water_winter_1", terrainDir),
    ("terrain_water_winter_2", terrainDir),
]
print("Creating new imagesets...")
for (name, dir) in newImagesets {
    createImagesetIfNeeded(name: name, dir: dir)
}
print("")

// Generate Creatures
print("Generating Creatures...")
writeAllScales(canvas: drawCreatureOrc(), name: "creature_orc", dir: creaturesDir)
writeAllScales(canvas: drawCreatureGoblin(), name: "creature_goblin", dir: creaturesDir)
writeAllScales(canvas: drawCreatureWolf(), name: "creature_wolf", dir: creaturesDir)
writeAllScales(canvas: drawCreatureBear(), name: "creature_bear", dir: creaturesDir)
writeAllScales(canvas: drawCreatureGiant(), name: "creature_giant", dir: creaturesDir)
writeAllScales(canvas: drawCreatureUndead(), name: "creature_undead", dir: creaturesDir)
print("")

// Generate Terrain
print("Generating Terrain...")
writeAllScales(canvas: drawTerrainEmptyAir(), name: "terrain_empty_air", dir: terrainDir)
writeAllScales(canvas: drawTerrainGrass(), name: "terrain_grass", dir: terrainDir)
writeAllScales(canvas: drawTerrainDirt(), name: "terrain_dirt", dir: terrainDir)
writeAllScales(canvas: drawTerrainStone(), name: "terrain_stone", dir: terrainDir)
writeAllScales(canvas: drawTerrainWater(frameOffset: 0), name: "terrain_water", dir: terrainDir)
writeAllScales(canvas: drawTerrainWater(frameOffset: 0), name: "terrain_water_0", dir: terrainDir)
writeAllScales(canvas: drawTerrainWater(frameOffset: 1), name: "terrain_water_1", dir: terrainDir)
writeAllScales(canvas: drawTerrainWater(frameOffset: 2), name: "terrain_water_2", dir: terrainDir)
writeAllScales(canvas: drawTerrainTree(), name: "terrain_tree", dir: terrainDir)
writeAllScales(canvas: drawTerrainShrub(), name: "terrain_shrub", dir: terrainDir)
writeAllScales(canvas: drawTerrainWall(), name: "terrain_wall", dir: terrainDir)
writeAllScales(canvas: drawTerrainOre(), name: "terrain_ore", dir: terrainDir)
writeAllScales(canvas: drawTerrainWoodenFloor(), name: "terrain_wooden_floor", dir: terrainDir)
writeAllScales(canvas: drawTerrainStoneFloor(), name: "terrain_stone_floor", dir: terrainDir)
writeAllScales(canvas: drawTerrainConstructedWall(), name: "terrain_constructed_wall", dir: terrainDir)
writeAllScales(canvas: drawTerrainStairsUp(), name: "terrain_stairs_up", dir: terrainDir)
writeAllScales(canvas: drawTerrainStairsDown(), name: "terrain_stairs_down", dir: terrainDir)
writeAllScales(canvas: drawTerrainStairsUpDown(), name: "terrain_stairs_updown", dir: terrainDir)
writeAllScales(canvas: drawTerrainRampUp(), name: "terrain_ramp_up", dir: terrainDir)
writeAllScales(canvas: drawTerrainRampDown(), name: "terrain_ramp_down", dir: terrainDir)
print("")

// Generate Seasonal Terrain
print("Generating Seasonal Terrain...")
// Spring
writeAllScales(canvas: drawTerrainGrassSpring(), name: "terrain_grass_spring", dir: terrainDir)
writeAllScales(canvas: drawTerrainTreeSpring(), name: "terrain_tree_spring", dir: terrainDir)
writeAllScales(canvas: drawTerrainShrubSpring(), name: "terrain_shrub_spring", dir: terrainDir)
// Autumn
writeAllScales(canvas: drawTerrainGrassAutumn(), name: "terrain_grass_autumn", dir: terrainDir)
writeAllScales(canvas: drawTerrainTreeAutumn(), name: "terrain_tree_autumn", dir: terrainDir)
writeAllScales(canvas: drawTerrainShrubAutumn(), name: "terrain_shrub_autumn", dir: terrainDir)
writeAllScales(canvas: drawTerrainWaterAutumn(frameOffset: 0), name: "terrain_water_autumn_0", dir: terrainDir)
writeAllScales(canvas: drawTerrainWaterAutumn(frameOffset: 1), name: "terrain_water_autumn_1", dir: terrainDir)
writeAllScales(canvas: drawTerrainWaterAutumn(frameOffset: 2), name: "terrain_water_autumn_2", dir: terrainDir)
// Winter
writeAllScales(canvas: drawTerrainGrassWinter(), name: "terrain_grass_winter", dir: terrainDir)
writeAllScales(canvas: drawTerrainTreeWinter(), name: "terrain_tree_winter", dir: terrainDir)
writeAllScales(canvas: drawTerrainShrubWinter(), name: "terrain_shrub_winter", dir: terrainDir)
writeAllScales(canvas: drawTerrainDirtWinter(), name: "terrain_dirt_winter", dir: terrainDir)
writeAllScales(canvas: drawTerrainWaterWinter(frameOffset: 0), name: "terrain_water_winter_0", dir: terrainDir)
writeAllScales(canvas: drawTerrainWaterWinter(frameOffset: 1), name: "terrain_water_winter_1", dir: terrainDir)
writeAllScales(canvas: drawTerrainWaterWinter(frameOffset: 2), name: "terrain_water_winter_2", dir: terrainDir)
print("")

// Generate Items
print("Generating Items...")
writeAllScales(canvas: drawItemFood(), name: "item_food", dir: itemsDir)
writeAllScales(canvas: drawItemDrink(), name: "item_drink", dir: itemsDir)
writeAllScales(canvas: drawItemRawMeat(), name: "item_raw_meat", dir: itemsDir)
writeAllScales(canvas: drawItemPlant(), name: "item_plant", dir: itemsDir)
writeAllScales(canvas: drawItemBed(), name: "item_bed", dir: itemsDir)
writeAllScales(canvas: drawItemTable(), name: "item_table", dir: itemsDir)
writeAllScales(canvas: drawItemChair(), name: "item_chair", dir: itemsDir)
writeAllScales(canvas: drawItemDoor(), name: "item_door", dir: itemsDir)
writeAllScales(canvas: drawItemBarrel(), name: "item_barrel", dir: itemsDir)
writeAllScales(canvas: drawItemBin(), name: "item_bin", dir: itemsDir)
writeAllScales(canvas: drawItemPickaxe(), name: "item_pickaxe", dir: itemsDir)
writeAllScales(canvas: drawItemAxe(), name: "item_axe", dir: itemsDir)
writeAllScales(canvas: drawItemLog(), name: "item_log", dir: itemsDir)
writeAllScales(canvas: drawItemStone(), name: "item_stone", dir: itemsDir)
writeAllScales(canvas: drawItemOre(), name: "item_ore", dir: itemsDir)
print("")

// Generate UI
print("Generating UI...")
writeAllScales(canvas: drawUISelection(), name: "ui_selection", dir: uiDir)
writeAllScales(canvas: drawUIHealthbarBG(), name: "ui_healthbar_bg", dir: uiDir)
writeAllScales(canvas: drawUIHealthbarFill(), name: "ui_healthbar_fill", dir: uiDir)
print("")

print("=== Done! All assets generated. ===")
