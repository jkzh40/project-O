import SpriteKit
import OCore

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Main SpriteKit scene for rendering the simulation
class GameScene: SKScene {

    // MARK: - Properties

    /// Callback when a unit is tapped
    var onUnitSelected: ((UInt64?) -> Void)?

    /// Current world snapshot to render
    private var worldSnapshot: WorldSnapshot?

    /// Selected unit ID
    private var selectedUnitId: UInt64?

    /// Texture manager
    private var textureManager: TextureManager { TextureManager.shared }

    /// Tile size
    private var tileSize: CGFloat { textureManager.tileSize }

    // MARK: - Layers (back to front)

    private let tileLayer = SKNode()         // z: 0
    private let ambientLayer = SKNode()      // z: 1
    private let itemLayer = SKNode()         // z: 2
    private let unitLayer = SKNode()         // z: 10
    private let healthBarLayer = SKNode()    // z: 15
    private let selectionLayer = SKNode()    // z: 20
    private let speechBubbleLayer = SKNode() // z: 30
    private let effectsLayer = SKNode()      // z: 40
    private var dayNightOverlay: SKSpriteNode!  // z: 500

    // MARK: - Sprite Pools

    private var tileSprites: [[SKSpriteNode]] = []
    private var unitSprites: [UInt64: SKSpriteNode] = [:]
    private var itemSprites: [UInt64: SKSpriteNode] = [:]
    private var selectionSprite: SKSpriteNode?

    // MARK: - Animation Tracking

    private var unitAnimationStates: [UInt64: UnitState] = [:]
    private var previousUnitHealth: [UInt64: Int] = [:]
    private var waterAnimated: Set<Int> = [] // track which tile indices have water anim
    private var treeSwayApplied: Set<Int> = []
    private var currentRenderedSeason: Season?

    // MARK: - Camera

    private var cameraNode: SKCameraNode!

    #if os(iOS)
    private var initialPinchScale: CGFloat = 1.0
    #elseif os(macOS)
    private var initialMagnificationScale: CGFloat = 1.0
    #endif

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(white: 0.1, alpha: 1)

        // Setup camera
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)

        // Add layers in order (back to front)
        tileLayer.zPosition = 0
        ambientLayer.zPosition = 1
        itemLayer.zPosition = 2
        unitLayer.zPosition = 10
        healthBarLayer.zPosition = 15
        selectionLayer.zPosition = 20
        speechBubbleLayer.zPosition = 30
        effectsLayer.zPosition = 40

        addChild(tileLayer)
        addChild(ambientLayer)
        addChild(itemLayer)
        addChild(unitLayer)
        addChild(healthBarLayer)
        addChild(selectionLayer)
        addChild(speechBubbleLayer)
        addChild(effectsLayer)

        // Day/night overlay
        dayNightOverlay = SKSpriteNode(color: .clear, size: CGSize(width: 4000, height: 4000))
        dayNightOverlay.zPosition = 500
        dayNightOverlay.blendMode = .alpha
        #if os(iOS)
        dayNightOverlay.isUserInteractionEnabled = false
        #endif
        addChild(dayNightOverlay)

        // Ambient dust particles
        setupAmbientParticles()

        // Setup gesture recognizers
        setupGestureRecognizers()
    }

    private func setupAmbientParticles() {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 2
        emitter.particleLifetime = 8
        emitter.particleLifetimeRange = 4
        emitter.particlePositionRange = CGVector(dx: 2000, dy: 2000)
        emitter.particleSpeed = 5
        emitter.particleSpeedRange = 3
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi
        emitter.particleAlpha = 0.15
        emitter.particleAlphaRange = 0.1
        emitter.particleAlphaSpeed = -0.02
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.3
        emitter.particleColor = SKColor(white: 0.9, alpha: 1)
        emitter.particleColorBlendFactor = 1.0
        let tex = SKTexture(imageNamed: "UI/ui_selection") // reuse a small texture
        emitter.particleTexture = tex
        emitter.particleSize = CGSize(width: 2, height: 2)
        emitter.zPosition = 0
        ambientLayer.addChild(emitter)
    }

    private func setupGestureRecognizers() {
        guard let view = self.view else { return }

        #if os(iOS)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)

        #elseif os(macOS)
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)

        let magnifyGesture = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        view.addGestureRecognizer(magnifyGesture)

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        view.addGestureRecognizer(clickGesture)
        #endif
    }

    // MARK: - Update World

    func updateWorld(with snapshot: WorldSnapshot, selectedUnitId: UInt64?) {
        self.worldSnapshot = snapshot
        self.selectedUnitId = selectedUnitId

        updateTiles(snapshot)
        updateItems(snapshot)
        updateUnits(snapshot)
        updateHealthBars(snapshot)
        updateSelection()
        updateSpeechBubbles(snapshot)
        updateDayNightOverlay(snapshot)

        // Keep ambient particles centered on camera
        ambientLayer.position = cameraNode?.position ?? .zero
    }

    // MARK: - Tile Rendering

    private func updateTiles(_ snapshot: WorldSnapshot) {
        // Initialize tile grid if needed
        if tileSprites.isEmpty || tileSprites.count != snapshot.height {
            tileLayer.removeAllChildren()
            tileSprites.removeAll()
            waterAnimated.removeAll()
            treeSwayApplied.removeAll()

            for y in 0..<snapshot.height {
                var row: [SKSpriteNode] = []
                for x in 0..<snapshot.width {
                    let sprite = SKSpriteNode()
                    sprite.size = CGSize(width: tileSize, height: tileSize)
                    sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    sprite.position = worldToScene(
                        x: x, y: y,
                        worldHeight: snapshot.height,
                        tileSize: tileSize
                    )
                    tileLayer.addChild(sprite)
                    row.append(sprite)
                }
                tileSprites.append(row)
            }
        }

        // Detect season change — force full texture refresh
        let seasonChanged = currentRenderedSeason != snapshot.season
        if seasonChanged {
            currentRenderedSeason = snapshot.season
            waterAnimated.removeAll()
        }

        let waterFrames = textureManager.waterAnimationTextures(for: snapshot.season)

        for y in 0..<snapshot.height {
            for x in 0..<snapshot.width {
                let tile = snapshot.tiles[y][x]
                let sprite = tileSprites[y][x]
                let tileIndex = y * snapshot.width + x

                if tile.terrain == .water && !waterFrames.isEmpty {
                    // Animated water (seasonal)
                    if !waterAnimated.contains(tileIndex) || seasonChanged {
                        waterAnimated.insert(tileIndex)
                        sprite.removeAction(forKey: "waterAnim")
                        let anim = SKAction.animate(with: waterFrames, timePerFrame: 0.5)
                        sprite.run(SKAction.repeatForever(anim), withKey: "waterAnim")
                    }
                } else {
                    if waterAnimated.contains(tileIndex) {
                        sprite.removeAction(forKey: "waterAnim")
                        waterAnimated.remove(tileIndex)
                    }
                    sprite.texture = textureManager.texture(for: tile.terrain, season: snapshot.season)
                }

                // Tree/shrub sway
                if (tile.terrain == .tree || tile.terrain == .shrub) {
                    if !treeSwayApplied.contains(tileIndex) {
                        treeSwayApplied.insert(tileIndex)
                        let angle: CGFloat = 1.5 * .pi / 180.0
                        let duration = 2.0 + Double.random(in: 0...1.0)
                        let swayRight = SKAction.rotate(toAngle: angle, duration: duration / 2)
                        let swayLeft = SKAction.rotate(toAngle: -angle, duration: duration / 2)
                        let sway = SKAction.sequence([swayRight, swayLeft])
                        // Random initial delay for phase offset
                        let delay = SKAction.wait(forDuration: Double.random(in: 0...2.0))
                        sprite.run(SKAction.sequence([delay, SKAction.repeatForever(sway)]), withKey: "sway")
                    }
                } else if treeSwayApplied.contains(tileIndex) {
                    sprite.removeAction(forKey: "sway")
                    sprite.zRotation = 0
                    treeSwayApplied.remove(tileIndex)
                }
            }
        }
    }

    // MARK: - Item Rendering

    private func updateItems(_ snapshot: WorldSnapshot) {
        var presentItemIds = Set<UInt64>()

        for item in snapshot.items {
            presentItemIds.insert(item.id)

            if let sprite = itemSprites[item.id] {
                sprite.position = worldToScene(
                    x: item.x, y: item.y,
                    worldHeight: snapshot.height,
                    tileSize: tileSize
                )
            } else {
                let sprite = SKSpriteNode(texture: textureManager.texture(for: item.itemType))
                sprite.size = CGSize(width: tileSize * 0.5, height: tileSize * 0.5)
                sprite.position = worldToScene(
                    x: item.x, y: item.y,
                    worldHeight: snapshot.height,
                    tileSize: tileSize
                )
                sprite.zPosition = 1
                itemLayer.addChild(sprite)
                itemSprites[item.id] = sprite
            }
        }

        for (id, sprite) in itemSprites {
            if !presentItemIds.contains(id) {
                sprite.removeFromParent()
                itemSprites.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Unit Rendering

    private func updateUnits(_ snapshot: WorldSnapshot) {
        var presentUnitIds = Set<UInt64>()

        for unit in snapshot.units {
            presentUnitIds.insert(unit.id)

            let newPosition = worldToScene(
                x: unit.x, y: unit.y,
                worldHeight: snapshot.height,
                tileSize: tileSize
            )

            if let sprite = unitSprites[unit.id] {
                // Smooth move if position changed
                if sprite.position.distance(to: newPosition) > 1 {
                    sprite.run(SKAction.move(to: newPosition, duration: 0.08))
                }

                sprite.texture = textureManager.texture(for: unit.creatureType)

                // Facing direction
                applyFacing(sprite: sprite, facing: unit.facing)

                // State-driven animation
                let previousState = unitAnimationStates[unit.id]
                if previousState != unit.state {
                    unitAnimationStates[unit.id] = unit.state
                    applyStateAnimation(sprite: sprite, state: unit.state)
                }

                // Combat FX: damage detection
                let prevHP = previousUnitHealth[unit.id] ?? unit.healthCurrent
                if unit.healthCurrent < prevHP {
                    let damage = prevHP - unit.healthCurrent
                    spawnDamageNumber(damage: damage, at: newPosition)
                    applyHitFlash(sprite: sprite)
                    spawnImpactParticles(at: newPosition)
                }
                previousUnitHealth[unit.id] = unit.healthCurrent

            } else {
                // Create new sprite
                let sprite = SKSpriteNode(texture: textureManager.texture(for: unit.creatureType))
                sprite.size = CGSize(width: tileSize * 0.8, height: tileSize * 0.8)
                sprite.position = newPosition
                sprite.zPosition = 10
                sprite.name = "unit_\(unit.id)"
                unitLayer.addChild(sprite)
                unitSprites[unit.id] = sprite

                applyFacing(sprite: sprite, facing: unit.facing)
                unitAnimationStates[unit.id] = unit.state
                applyStateAnimation(sprite: sprite, state: unit.state)
                previousUnitHealth[unit.id] = unit.healthCurrent
            }
        }

        // Remove sprites for units that no longer exist
        for (id, sprite) in unitSprites {
            if !presentUnitIds.contains(id) {
                sprite.removeFromParent()
                unitSprites.removeValue(forKey: id)
                unitAnimationStates.removeValue(forKey: id)
                previousUnitHealth.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Facing Direction

    private func applyFacing(sprite: SKSpriteNode, facing: Direction) {
        switch facing {
        case .west, .southwest, .northwest:
            sprite.xScale = -abs(sprite.xScale)
        case .east, .southeast, .northeast:
            sprite.xScale = abs(sprite.xScale)
        case .north, .south:
            break // keep current
        }
    }

    // MARK: - State Animations

    private func applyStateAnimation(sprite: SKSpriteNode, state: UnitState) {
        sprite.removeAction(forKey: "stateAnim")
        sprite.removeAction(forKey: "sleepZzz")
        // Reset transforms that states might have set
        sprite.alpha = 1.0
        sprite.zRotation = 0
        sprite.colorBlendFactor = 0

        let baseScale: CGFloat = 0.8  // matches sprite size factor
        let spriteXSign: CGFloat = sprite.xScale < 0 ? -1 : 1

        switch state {
        case .idle:
            // Gentle Y bob
            let up = SKAction.moveBy(x: 0, y: 1, duration: 0.6)
            let down = SKAction.moveBy(x: 0, y: -1, duration: 0.6)
            up.timingMode = .easeInEaseOut
            down.timingMode = .easeInEaseOut
            sprite.run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "stateAnim")

        case .moving:
            // Bounce
            let up = SKAction.moveBy(x: 0, y: 2, duration: 0.15)
            let down = SKAction.moveBy(x: 0, y: -2, duration: 0.15)
            up.timingMode = .easeOut
            down.timingMode = .easeIn
            sprite.run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "stateAnim")

        case .sleeping:
            sprite.alpha = 0.6
            // Zzz particles
            let spawnZ = SKAction.run { [weak self, weak sprite] in
                guard let self, let sprite else { return }
                self.spawnSleepZ(at: sprite.position)
            }
            let wait = SKAction.wait(forDuration: 1.5)
            sprite.run(SKAction.repeatForever(SKAction.sequence([spawnZ, wait])), withKey: "sleepZzz")

        case .eating:
            // Scale pulse
            let scaleUp = SKAction.scaleX(to: spriteXSign * baseScale * 1.05, y: baseScale * 1.05, duration: 0.2)
            let scaleDown = SKAction.scaleX(to: spriteXSign * baseScale, y: baseScale, duration: 0.2)
            sprite.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])), withKey: "stateAnim")

        case .drinking:
            // Scale pulse + blue tint flash
            let scaleUp = SKAction.scaleX(to: spriteXSign * baseScale * 1.05, y: baseScale * 1.05, duration: 0.2)
            let scaleDown = SKAction.scaleX(to: spriteXSign * baseScale, y: baseScale, duration: 0.2)
            let tintOn = SKAction.colorize(with: SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1), colorBlendFactor: 0.3, duration: 0.1)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0, duration: 0.3)
            let pulse = SKAction.sequence([scaleUp, scaleDown])
            let tint = SKAction.sequence([tintOn, tintOff])
            sprite.run(SKAction.repeatForever(SKAction.group([pulse, tint])), withKey: "stateAnim")

        case .working:
            // Rotation wobble
            let angle: CGFloat = 3.0 * .pi / 180.0
            let left = SKAction.rotate(toAngle: -angle, duration: 0.15)
            let right = SKAction.rotate(toAngle: angle, duration: 0.15)
            sprite.run(SKAction.repeatForever(SKAction.sequence([left, right])), withKey: "stateAnim")

        case .fighting:
            // Red tint flash + shake
            sprite.color = .red
            let tintOn = SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.075)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0, duration: 0.075)
            let shakeL = SKAction.moveBy(x: -1, y: 0, duration: 0.05)
            let shakeR = SKAction.moveBy(x: 2, y: 0, duration: 0.05)
            let shakeBack = SKAction.moveBy(x: -1, y: 0, duration: 0.05)
            let flash = SKAction.sequence([tintOn, tintOff])
            let shake = SKAction.sequence([shakeL, shakeR, shakeBack])
            sprite.run(SKAction.repeatForever(SKAction.group([flash, shake])), withKey: "stateAnim")

        case .fleeing:
            // Fast bounce + stretched
            sprite.xScale = spriteXSign * baseScale * 1.1
            let up = SKAction.moveBy(x: 0, y: 2, duration: 0.075)
            let down = SKAction.moveBy(x: 0, y: -2, duration: 0.075)
            up.timingMode = .easeOut
            down.timingMode = .easeIn
            sprite.run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "stateAnim")

        case .socializing:
            // Gentle lean
            let angle: CGFloat = 2.0 * .pi / 180.0
            let left = SKAction.rotate(toAngle: -angle, duration: 0.4)
            let right = SKAction.rotate(toAngle: angle, duration: 0.4)
            left.timingMode = .easeInEaseOut
            right.timingMode = .easeInEaseOut
            sprite.run(SKAction.repeatForever(SKAction.sequence([left, right])), withKey: "stateAnim")

        case .unconscious:
            sprite.zRotation = .pi / 2
            sprite.alpha = 0.5

        case .dead:
            sprite.zRotation = .pi / 2
            sprite.alpha = 0.3
            sprite.color = .gray
            sprite.colorBlendFactor = 0.5
        }
    }

    // MARK: - Sleep Zzz

    private func spawnSleepZ(at position: CGPoint) {
        let z = SKLabelNode(fontNamed: "Helvetica-Bold")
        z.text = "Z"
        z.fontSize = 10
        z.fontColor = SKColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1)
        z.position = CGPoint(x: position.x + 4, y: position.y + tileSize * 0.3)
        z.zPosition = 41
        z.setScale(0.5)

        let floatUp = SKAction.moveBy(x: 0, y: 20, duration: 1.5)
        let grow = SKAction.scale(to: 1.0, duration: 1.5)
        let fade = SKAction.fadeOut(withDuration: 1.5)
        let wave = SKAction.customAction(withDuration: 1.5) { node, elapsed in
            node.position.x += sin(elapsed * 3) * 0.3
        }
        let group = SKAction.group([floatUp, grow, fade, wave])
        let remove = SKAction.removeFromParent()

        effectsLayer.addChild(z)
        z.run(SKAction.sequence([group, remove]))
    }

    // MARK: - Combat FX

    private func spawnDamageNumber(damage: Int, at position: CGPoint) {
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = "-\(damage)"
        label.fontSize = 14
        label.fontColor = .red
        label.position = CGPoint(x: position.x, y: position.y + tileSize * 0.4)
        label.zPosition = 41

        let moveUp = SKAction.moveBy(x: 0, y: 24, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()

        effectsLayer.addChild(label)
        label.run(SKAction.sequence([group, remove]))
    }

    private func applyHitFlash(sprite: SKSpriteNode) {
        let flashOn = SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05)
        let flashOff = SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        sprite.run(SKAction.sequence([flashOn, flashOff]), withKey: "hitFlash")
    }

    private func spawnImpactParticles(at position: CGPoint) {
        let count = Int.random(in: 3...5)
        for _ in 0..<count {
            let particle = SKSpriteNode(color: .red, size: CGSize(width: 2, height: 2))
            particle.position = position
            particle.zPosition = 41

            let dx = CGFloat.random(in: -12...12)
            let dy = CGFloat.random(in: -4...16)
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.3)
            let fade = SKAction.fadeOut(withDuration: 0.3)
            let group = SKAction.group([move, fade])
            let remove = SKAction.removeFromParent()

            effectsLayer.addChild(particle)
            particle.run(SKAction.sequence([group, remove]))
        }
    }

    // MARK: - Health Bars

    private func updateHealthBars(_ snapshot: WorldSnapshot) {
        healthBarLayer.removeAllChildren()

        for unit in snapshot.units {
            guard unit.healthPercent < 100, unit.state != .dead else { continue }

            let pos = worldToScene(
                x: unit.x, y: unit.y,
                worldHeight: snapshot.height,
                tileSize: tileSize
            )

            let barWidth: CGFloat = 24
            let barHeight: CGFloat = 3
            let yOffset = tileSize * 0.5 + 4

            // Background
            let bg = SKSpriteNode(texture: textureManager.healthBarBgTexture())
            bg.size = CGSize(width: barWidth, height: barHeight)
            bg.position = CGPoint(x: pos.x, y: pos.y + yOffset)
            bg.zPosition = 15
            healthBarLayer.addChild(bg)

            // Fill
            let fillPercent = CGFloat(unit.healthPercent) / 100.0
            let fillWidth = (barWidth - 2) * fillPercent
            let fill = SKSpriteNode(texture: textureManager.healthBarFillTexture())
            fill.size = CGSize(width: fillWidth, height: barHeight - 2)
            fill.anchorPoint = CGPoint(x: 0, y: 0.5)
            fill.position = CGPoint(x: pos.x - (barWidth - 2) / 2, y: pos.y + yOffset)
            fill.zPosition = 16

            // Color based on health percentage
            if unit.healthPercent > 60 {
                fill.color = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1)
            } else if unit.healthPercent > 30 {
                fill.color = SKColor(red: 0.9, green: 0.8, blue: 0.1, alpha: 1)
            } else {
                fill.color = SKColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1)
            }
            fill.colorBlendFactor = 0.5

            healthBarLayer.addChild(fill)
        }
    }

    // MARK: - Day/Night Overlay

    private func updateDayNightOverlay(_ snapshot: WorldSnapshot) {
        guard let overlay = dayNightOverlay else { return }

        // Position overlay at camera center
        overlay.position = cameraNode?.position ?? .zero

        // Use calendar for smooth fractional hour
        let cal = WorldCalendar(tick: snapshot.tick)
        let dl = cal.seasonalDaylightHours
        let fractionalHour = CGFloat(cal.hour) + CGFloat(cal.minute) / 60.0

        let color: SKColor
        let alpha: CGFloat

        let dawnStart = CGFloat(dl.dawnStart)
        let dawnEnd = CGFloat(dl.dawnEnd)
        let duskStart = CGFloat(dl.duskStart)
        let duskEnd = CGFloat(dl.duskEnd)

        if fractionalHour >= dawnStart && fractionalHour < dawnEnd {
            // Dawn: orange tint fading out
            let progress = (fractionalHour - dawnStart) / (dawnEnd - dawnStart)
            color = SKColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1)
            alpha = 0.05 * (1.0 - progress)
        } else if fractionalHour >= dawnEnd && fractionalHour < duskStart {
            // Day: clear
            color = .clear
            alpha = 0
        } else if fractionalHour >= duskStart && fractionalHour < duskEnd {
            // Dusk: orange → purple
            let progress = (fractionalHour - duskStart) / (duskEnd - duskStart)
            let r = 1.0 - progress * 0.5
            let g = 0.5 - progress * 0.3
            let b = 0.3 + progress * 0.5
            color = SKColor(red: r, green: g, blue: b, alpha: 1)
            alpha = progress * 0.12
        } else if fractionalHour >= duskEnd {
            // Evening/night after dusk
            let nightProgress = min((fractionalHour - duskEnd) / 2.0, 1.0)
            color = SKColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1)
            alpha = 0.12 + nightProgress * 0.03
        } else {
            // Night before dawn
            let nightProgress = min((dawnStart - fractionalHour) / 2.0, 1.0)
            color = SKColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1)
            alpha = 0.12 + nightProgress * 0.03
        }

        overlay.color = color
        overlay.alpha = alpha
    }

    // MARK: - Selection Rendering

    private func updateSelection() {
        selectionLayer.removeAllChildren()

        guard let selectedId = selectedUnitId,
              let unitSprite = unitSprites[selectedId] else { return }

        let selection = SKSpriteNode(texture: textureManager.selectionRingTexture())
        selection.size = CGSize(width: tileSize, height: tileSize)
        selection.position = unitSprite.position
        selection.zPosition = 20

        let scaleUp = SKAction.scale(to: 1.1, duration: 0.5)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        selection.run(SKAction.repeatForever(pulse))

        selectionLayer.addChild(selection)
        selectionSprite = selection
    }

    // MARK: - Speech Bubble Rendering

    private func updateSpeechBubbles(_ snapshot: WorldSnapshot) {
        speechBubbleLayer.removeAllChildren()

        for conversation in snapshot.activeConversations {
            guard let unit1 = snapshot.units.first(where: { $0.id == conversation.participant1Id }),
                  let unit2 = snapshot.units.first(where: { $0.id == conversation.participant2Id }) else {
                continue
            }

            let bubble1 = createSpeechBubble(
                text: conversation.topic,
                isSuccess: conversation.isSuccess,
                isInitiator: true
            )
            bubble1.position = worldToScene(
                x: unit1.x, y: unit1.y,
                worldHeight: snapshot.height,
                tileSize: tileSize
            )
            bubble1.position.y += tileSize * 0.8
            speechBubbleLayer.addChild(bubble1)

            let bubble2 = createSpeechBubble(
                text: "...",
                isSuccess: conversation.isSuccess,
                isInitiator: false
            )
            bubble2.position = worldToScene(
                x: unit2.x, y: unit2.y,
                worldHeight: snapshot.height,
                tileSize: tileSize
            )
            bubble2.position.y += tileSize * 0.8
            speechBubbleLayer.addChild(bubble2)
        }
    }

    private func createSpeechBubble(text: String, isSuccess: Bool, isInitiator: Bool) -> SKNode {
        let container = SKNode()
        container.zPosition = 100

        let fontSize: CGFloat = isInitiator ? 8 : 6
        let padding: CGFloat = isInitiator ? 4 : 2
        let maxWidth: CGFloat = isInitiator ? tileSize * 2.5 : tileSize

        let label = SKLabelNode(fontNamed: "Helvetica")
        label.text = text.capitalized
        label.fontSize = fontSize
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        let textWidth = min(label.frame.width, maxWidth)
        let bubbleWidth = textWidth + padding * 2
        let bubbleHeight = label.frame.height + padding * 2

        let bubbleRect = CGRect(
            x: -bubbleWidth / 2,
            y: -bubbleHeight / 2,
            width: bubbleWidth,
            height: bubbleHeight
        )

        let bubble = SKShapeNode(rect: bubbleRect, cornerRadius: 4)
        bubble.fillColor = isSuccess ?
            SKColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 0.9) :
            SKColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 0.9)
        bubble.strokeColor = .white
        bubble.lineWidth = 0.5

        let pointerPath = CGMutablePath()
        pointerPath.move(to: CGPoint(x: -3, y: -bubbleHeight / 2))
        pointerPath.addLine(to: CGPoint(x: 0, y: -bubbleHeight / 2 - 4))
        pointerPath.addLine(to: CGPoint(x: 3, y: -bubbleHeight / 2))
        pointerPath.closeSubpath()

        let pointer = SKShapeNode(path: pointerPath)
        pointer.fillColor = bubble.fillColor
        pointer.strokeColor = .white
        pointer.lineWidth = 0.5

        container.addChild(bubble)
        container.addChild(pointer)
        container.addChild(label)

        if isInitiator {
            let scaleUp = SKAction.scale(to: 1.05, duration: 0.3)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
            let pulse = SKAction.sequence([scaleUp, scaleDown])
            container.run(SKAction.repeatForever(pulse))
        }

        return container
    }

    // MARK: - iOS Gesture Handlers

    #if os(iOS)
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let camera = cameraNode else { return }

        let translation = gesture.translation(in: view)
        let scale = camera.xScale

        camera.position.x -= translation.x * scale
        camera.position.y += translation.y * scale

        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let camera = cameraNode else { return }

        switch gesture.state {
        case .began:
            initialPinchScale = camera.xScale
        case .changed:
            let newScale = initialPinchScale / gesture.scale
            let clampedScale = max(0.5, min(4.0, newScale))
            camera.setScale(clampedScale)
        default:
            break
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = self.view else { return }
        let location = gesture.location(in: view)
        handleSelection(at: location)
    }
    #endif

    // MARK: - macOS Gesture Handlers

    #if os(macOS)
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        guard let camera = cameraNode, let view = self.view else { return }

        let translation = gesture.translation(in: view)
        let scale = camera.xScale

        camera.position.x -= translation.x * scale
        camera.position.y -= translation.y * scale

        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
        guard let camera = cameraNode else { return }

        switch gesture.state {
        case .began:
            initialMagnificationScale = camera.xScale
        case .changed:
            let newScale = initialMagnificationScale / (1.0 + gesture.magnification)
            let clampedScale = max(0.5, min(4.0, newScale))
            camera.setScale(clampedScale)
        default:
            break
        }
    }

    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard let view = self.view else { return }
        let location = gesture.location(in: view)
        handleSelection(at: location)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let camera = cameraNode else { return }

        let zoomDelta = event.deltaY * 0.05
        let newScale = camera.xScale + zoomDelta
        let clampedScale = max(0.5, min(4.0, newScale))
        camera.setScale(clampedScale)
    }
    #endif

    // MARK: - Selection Logic

    private func handleSelection(at viewLocation: CGPoint) {
        let sceneLocation = convertPoint(fromView: viewLocation)

        guard let snapshot = worldSnapshot else { return }

        let (gridX, gridY) = sceneToWorld(
            point: sceneLocation,
            worldHeight: snapshot.height,
            tileSize: tileSize
        )

        if let unit = snapshot.units.first(where: { $0.x == gridX && $0.y == gridY }) {
            onUnitSelected?(unit.id)
        } else {
            onUnitSelected?(nil)
        }
    }

    // MARK: - Camera Control

    func centerCamera(on x: Int, y: Int, worldHeight: Int) {
        let position = worldToScene(x: x, y: y, worldHeight: worldHeight, tileSize: tileSize)
        cameraNode?.position = position
    }

    func resetCamera() {
        guard let snapshot = worldSnapshot else { return }
        let centerX = snapshot.width / 2
        let centerY = snapshot.height / 2
        centerCamera(on: centerX, y: centerY, worldHeight: snapshot.height)
        cameraNode?.setScale(1.0)
    }
}

// MARK: - CGPoint Extension

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }
}
