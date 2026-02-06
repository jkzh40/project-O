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
    private let shadowLayer = SKNode()       // z: 9
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
    private var shadowSprites: [UInt64: SKSpriteNode] = [:]
    private var selectionSprite: SKSpriteNode?

    // MARK: - Animation Tracking

    private var unitAnimationStates: [UInt64: UnitState] = [:]
    private var unitCreatureTypes: [UInt64: CreatureType] = [:]
    private var previousUnitHealth: [UInt64: Int] = [:]
    private var waterAnimated: Set<Int> = [] // track which tile indices have water anim
    private var treeSwayApplied: Set<Int> = []
    private var currentRenderedSeason: Season?

    /// Tile variation map (deterministic per-tile variant index)
    private var tileVariantMap: [[Int]] = []

    /// Movement tracking for footstep particles
    private var unitWasMoving: [UInt64: Bool] = [:]

    /// Seasonal particle emitter
    private var currentSeasonalEmitter: SKEmitterNode?
    private var currentParticleSeason: Season?

    /// Whether enhanced rendering is enabled
    private var enhancedAnimations: Bool = true
    private var previousEnhancedAnimations: Bool = true

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
        shadowLayer.zPosition = 9
        unitLayer.zPosition = 10
        healthBarLayer.zPosition = 15
        selectionLayer.zPosition = 20
        speechBubbleLayer.zPosition = 30
        effectsLayer.zPosition = 40

        addChild(tileLayer)
        addChild(ambientLayer)
        addChild(itemLayer)
        addChild(shadowLayer)
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

    func updateWorld(with snapshot: WorldSnapshot, selectedUnitId: UInt64?, enhancedAnimations: Bool) {
        self.worldSnapshot = snapshot
        self.selectedUnitId = selectedUnitId
        self.enhancedAnimations = enhancedAnimations

        // Detect enhanced animations toggle transitions
        let transitionedOff = previousEnhancedAnimations && !enhancedAnimations
        let transitionedOn = !previousEnhancedAnimations && enhancedAnimations

        if transitionedOff {
            handleEnhancedOff()
        } else if transitionedOn {
            handleEnhancedOn(snapshot: snapshot)
        }
        previousEnhancedAnimations = enhancedAnimations

        updateTiles(snapshot)
        updateItems(snapshot)
        updateUnits(snapshot)
        updateHealthBars(snapshot)
        updateSelection()
        updateSpeechBubbles(snapshot)
        updateDayNightOverlay(snapshot)

        // Keep ambient particles centered on camera
        ambientLayer.position = cameraNode?.position ?? .zero

        // Seasonal ambient particles
        let cal = WorldCalendar(tick: snapshot.tick)
        updateSeasonalParticles(season: snapshot.season, hour: cal.hour)
    }

    // MARK: - Enhanced Animation Transitions

    private func handleEnhancedOff() {
        // Hide shadows
        shadowLayer.isHidden = true

        // Remove seasonal emitter
        currentSeasonalEmitter?.removeFromParent()
        currentSeasonalEmitter = nil
        currentParticleSeason = nil

        // Strip item bob actions and glow children
        for (_, sprite) in itemSprites {
            sprite.removeAction(forKey: "itemBob")
            for child in sprite.children {
                if let spriteChild = child as? SKSpriteNode, spriteChild.blendMode == .add {
                    spriteChild.removeFromParent()
                }
            }
        }

        // Re-apply all unit state animations with basic versions
        for (id, state) in unitAnimationStates {
            if let sprite = unitSprites[id], let creatureType = unitCreatureTypes[id] {
                applyStateAnimation(sprite: sprite, state: state, creatureType: creatureType)
            }
        }

        // Snap all unit positions to current target (cancel smooth moves)
        for (_, sprite) in unitSprites {
            sprite.removeAction(forKey: "unitMove")
        }
        for (_, shadow) in shadowSprites {
            shadow.removeAction(forKey: "shadowMove")
        }
    }

    private func handleEnhancedOn(snapshot: WorldSnapshot) {
        // Show shadows
        shadowLayer.isHidden = false

        // Re-apply all unit state animations with enhanced versions
        for (id, state) in unitAnimationStates {
            if let sprite = unitSprites[id], let creatureType = unitCreatureTypes[id] {
                applyStateAnimation(sprite: sprite, state: state, creatureType: creatureType)
            }
        }

        // Force seasonal particles to re-create
        currentParticleSeason = nil
    }

    // MARK: - Tile Rendering

    private func updateTiles(_ snapshot: WorldSnapshot) {
        // Initialize tile grid if needed
        if tileSprites.isEmpty || tileSprites.count != snapshot.height {
            tileLayer.removeAllChildren()
            tileSprites.removeAll()
            waterAnimated.removeAll()
            treeSwayApplied.removeAll()

            // Initialize tile variant map
            tileVariantMap = (0..<snapshot.height).map { y in
                (0..<snapshot.width).map { x in (x * 7919 + y * 104729) % 3 }
            }

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

                if (tile.terrain == .water || tile.terrain == .deepWater) && !waterFrames.isEmpty {
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
                    if enhancedAnimations {
                        let variant = (y < tileVariantMap.count && x < tileVariantMap[y].count) ? tileVariantMap[y][x] : 0
                        sprite.texture = textureManager.terrainTexture(for: tile.terrain, season: snapshot.season, variant: variant)
                    } else {
                        sprite.texture = textureManager.texture(for: tile.terrain, season: snapshot.season)
                    }
                }

                // Tree/shrub sway (includes new tree types)
                if tile.terrain == .tree || tile.terrain == .shrub
                    || tile.terrain == .coniferTree || tile.terrain == .palmTree
                    || tile.terrain == .deadTree || tile.terrain == .reeds
                    || tile.terrain == .tallGrass {
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

                if enhancedAnimations {
                    // Hover bob animation with random phase offset
                    let phaseDelay = Double(item.id % 100) / 100.0 * 0.8
                    let bobUp = SKAction.moveBy(x: 0, y: 2, duration: 0.4)
                    let bobDown = SKAction.moveBy(x: 0, y: -2, duration: 0.4)
                    bobUp.timingMode = .easeInEaseOut
                    bobDown.timingMode = .easeInEaseOut
                    let bob = SKAction.sequence([bobUp, bobDown])
                    let delay = SKAction.wait(forDuration: phaseDelay)
                    sprite.run(SKAction.sequence([delay, SKAction.repeatForever(bob)]), withKey: "itemBob")

                    // Glow child sprite
                    let glow = SKSpriteNode(color: SKColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 0.25), size: CGSize(width: tileSize * 0.3, height: tileSize * 0.15))
                    glow.position = CGPoint(x: 0, y: -tileSize * 0.15)
                    glow.blendMode = .add
                    glow.zPosition = -1
                    let pulseUp = SKAction.fadeAlpha(to: 0.35, duration: 0.6)
                    let pulseDown = SKAction.fadeAlpha(to: 0.15, duration: 0.6)
                    pulseUp.timingMode = .easeInEaseOut
                    pulseDown.timingMode = .easeInEaseOut
                    glow.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])))
                    sprite.addChild(glow)
                }
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

            let isMoving = unit.state == .moving || unit.state == .fleeing

            if let sprite = unitSprites[unit.id] {
                // Movement
                if sprite.position.distance(to: newPosition) > 1 {
                    if enhancedAnimations {
                        let moveAction = SKAction.move(to: newPosition, duration: 0.3)
                        moveAction.timingMode = .easeInEaseOut
                        sprite.run(moveAction, withKey: "unitMove")
                    } else {
                        sprite.removeAction(forKey: "unitMove")
                        sprite.position = newPosition
                    }
                }

                // Only set base texture when not playing frame animation
                if unitAnimationStates[unit.id] == nil || unitAnimationStates[unit.id] == .idle {
                    sprite.texture = textureManager.texture(for: unit.creatureType)
                }

                // Facing direction
                applyFacing(sprite: sprite, facing: unit.facing)

                // State-driven animation (with creature type for frame-based anims)
                let previousState = unitAnimationStates[unit.id]
                if previousState != unit.state {
                    unitAnimationStates[unit.id] = unit.state
                    unitCreatureTypes[unit.id] = unit.creatureType
                    applyStateAnimation(sprite: sprite, state: unit.state, creatureType: unit.creatureType)
                }

                // Shadow tracking
                if enhancedAnimations, let shadow = shadowSprites[unit.id] {
                    let shadowPos = CGPoint(x: newPosition.x, y: newPosition.y - tileSize * 0.3)
                    if shadow.position.distance(to: shadowPos) > 1 {
                        let moveShadow = SKAction.move(to: shadowPos, duration: 0.3)
                        moveShadow.timingMode = .easeInEaseOut
                        shadow.run(moveShadow, withKey: "shadowMove")
                    }
                    // Fade shadow on death
                    if unit.state == .dead {
                        shadow.alpha = 0.1
                    }
                }

                // Footstep particles
                if enhancedAnimations {
                    let wasMoving = unitWasMoving[unit.id] ?? false
                    if isMoving && !wasMoving {
                        spawnFootstepDust(at: sprite.position, count: 3)
                    } else if !isMoving && wasMoving {
                        spawnFootstepDust(at: sprite.position, count: 2)
                    }
                }
                unitWasMoving[unit.id] = isMoving

                // Combat FX: damage detection
                let prevHP = previousUnitHealth[unit.id] ?? unit.healthCurrent
                if unit.healthCurrent < prevHP {
                    let damage = prevHP - unit.healthCurrent
                    let maxHP = max(unit.healthMax, 1)
                    spawnDamageNumber(damage: damage, at: newPosition)
                    applyHitFlash(sprite: sprite)
                    spawnImpactParticles(at: newPosition, facing: unit.facing)
                    // Camera shake for big hits (>20% HP) — only when enhanced
                    if enhancedAnimations && damage * 100 / maxHP > 20 {
                        applyCameraShake()
                    }
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

                // Create shadow (only when enhanced)
                if enhancedAnimations {
                    let shadow = SKSpriteNode(texture: textureManager.unitShadowTexture())
                    shadow.size = CGSize(width: tileSize * 0.65, height: tileSize * 0.2)
                    shadow.position = CGPoint(x: newPosition.x, y: newPosition.y - tileSize * 0.3)
                    shadow.alpha = 0.3
                    shadow.zPosition = 0
                    shadowLayer.addChild(shadow)
                    shadowSprites[unit.id] = shadow
                }

                applyFacing(sprite: sprite, facing: unit.facing)
                unitAnimationStates[unit.id] = unit.state
                unitCreatureTypes[unit.id] = unit.creatureType
                applyStateAnimation(sprite: sprite, state: unit.state, creatureType: unit.creatureType)
                previousUnitHealth[unit.id] = unit.healthCurrent
                unitWasMoving[unit.id] = isMoving
            }
        }

        // Remove sprites for units that no longer exist
        for (id, sprite) in unitSprites {
            if !presentUnitIds.contains(id) {
                sprite.removeFromParent()
                unitSprites.removeValue(forKey: id)
                unitAnimationStates.removeValue(forKey: id)
                unitCreatureTypes.removeValue(forKey: id)
                previousUnitHealth.removeValue(forKey: id)
                unitWasMoving.removeValue(forKey: id)
                // Remove shadow
                if let shadow = shadowSprites.removeValue(forKey: id) {
                    shadow.removeFromParent()
                }
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

    private func applyStateAnimation(sprite: SKSpriteNode, state: UnitState, creatureType: CreatureType) {
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
            if enhancedAnimations {
                // Multi-frame idle breathing
                let idleFrames = textureManager.idleTextures(for: creatureType)
                if idleFrames.count >= 2 {
                    let anim = SKAction.animate(with: [idleFrames[0], idleFrames[1], idleFrames[0]], timePerFrame: 0.5)
                    sprite.run(SKAction.repeatForever(anim), withKey: "stateAnim")
                } else {
                    let up = SKAction.moveBy(x: 0, y: 1, duration: 0.6)
                    let down = SKAction.moveBy(x: 0, y: -1, duration: 0.6)
                    up.timingMode = .easeInEaseOut
                    down.timingMode = .easeInEaseOut
                    sprite.run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "stateAnim")
                }
            } else {
                // Basic: gentle Y bob
                let up = SKAction.moveBy(x: 0, y: 1, duration: 0.6)
                let down = SKAction.moveBy(x: 0, y: -1, duration: 0.6)
                up.timingMode = .easeInEaseOut
                down.timingMode = .easeInEaseOut
                sprite.run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "stateAnim")
            }

        case .moving:
            if enhancedAnimations {
                // Multi-frame walk cycle
                let walkFrames = textureManager.walkTextures(for: creatureType)
                if walkFrames.count >= 4 {
                    let anim = SKAction.animate(with: walkFrames, timePerFrame: 0.075)
                    sprite.run(SKAction.repeatForever(anim), withKey: "stateAnim")
                } else {
                    let up = SKAction.moveBy(x: 0, y: 2, duration: 0.15)
                    let down = SKAction.moveBy(x: 0, y: -2, duration: 0.15)
                    up.timingMode = .easeOut
                    down.timingMode = .easeIn
                    sprite.run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "stateAnim")
                }
            } else {
                // Basic: bounce
                let up = SKAction.moveBy(x: 0, y: 2, duration: 0.15)
                let down = SKAction.moveBy(x: 0, y: -2, duration: 0.15)
                up.timingMode = .easeOut
                down.timingMode = .easeIn
                sprite.run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "stateAnim")
            }

        case .sleeping:
            sprite.alpha = 0.6
            let spawnZ = SKAction.run { [weak self, weak sprite] in
                guard let self, let sprite else { return }
                self.spawnSleepZ(at: sprite.position)
            }
            let wait = SKAction.wait(forDuration: 1.5)
            sprite.run(SKAction.repeatForever(SKAction.sequence([spawnZ, wait])), withKey: "sleepZzz")

        case .eating:
            let scaleUp = SKAction.scaleX(to: spriteXSign * baseScale * 1.05, y: baseScale * 1.05, duration: 0.2)
            let scaleDown = SKAction.scaleX(to: spriteXSign * baseScale, y: baseScale, duration: 0.2)
            sprite.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])), withKey: "stateAnim")

        case .drinking:
            let scaleUp = SKAction.scaleX(to: spriteXSign * baseScale * 1.05, y: baseScale * 1.05, duration: 0.2)
            let scaleDown = SKAction.scaleX(to: spriteXSign * baseScale, y: baseScale, duration: 0.2)
            let tintOn = SKAction.colorize(with: SKColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1), colorBlendFactor: 0.3, duration: 0.1)
            let tintOff = SKAction.colorize(withColorBlendFactor: 0, duration: 0.3)
            let pulse = SKAction.sequence([scaleUp, scaleDown])
            let tint = SKAction.sequence([tintOn, tintOff])
            sprite.run(SKAction.repeatForever(SKAction.group([pulse, tint])), withKey: "stateAnim")

        case .working:
            let angle: CGFloat = 3.0 * .pi / 180.0
            let left = SKAction.rotate(toAngle: -angle, duration: 0.15)
            let right = SKAction.rotate(toAngle: angle, duration: 0.15)
            sprite.run(SKAction.repeatForever(SKAction.sequence([left, right])), withKey: "stateAnim")

        case .fighting:
            if enhancedAnimations {
                // Multi-frame attack animation
                let attackFrames = textureManager.attackTextures(for: creatureType)
                if attackFrames.count >= 3 {
                    let anim = SKAction.animate(with: attackFrames, timePerFrame: 0.1)
                    let tintOn = SKAction.colorize(with: .red, colorBlendFactor: 0.3, duration: 0.05)
                    let tintOff = SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
                    let pause = SKAction.wait(forDuration: 0.15)
                    let cycle = SKAction.sequence([anim, tintOn, pause, tintOff])
                    sprite.run(SKAction.repeatForever(cycle), withKey: "stateAnim")
                } else {
                    sprite.color = .red
                    let tintOn = SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.075)
                    let tintOff = SKAction.colorize(withColorBlendFactor: 0, duration: 0.075)
                    let shakeL = SKAction.moveBy(x: -1, y: 0, duration: 0.05)
                    let shakeR = SKAction.moveBy(x: 2, y: 0, duration: 0.05)
                    let shakeBack = SKAction.moveBy(x: -1, y: 0, duration: 0.05)
                    let flash = SKAction.sequence([tintOn, tintOff])
                    let shake = SKAction.sequence([shakeL, shakeR, shakeBack])
                    sprite.run(SKAction.repeatForever(SKAction.group([flash, shake])), withKey: "stateAnim")
                }
            } else {
                // Basic: red flash + shake
                sprite.color = .red
                let tintOn = SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.075)
                let tintOff = SKAction.colorize(withColorBlendFactor: 0, duration: 0.075)
                let shakeL = SKAction.moveBy(x: -1, y: 0, duration: 0.05)
                let shakeR = SKAction.moveBy(x: 2, y: 0, duration: 0.05)
                let shakeBack = SKAction.moveBy(x: -1, y: 0, duration: 0.05)
                let flash = SKAction.sequence([tintOn, tintOff])
                let shake = SKAction.sequence([shakeL, shakeR, shakeBack])
                sprite.run(SKAction.repeatForever(SKAction.group([flash, shake])), withKey: "stateAnim")
            }

        case .fleeing:
            sprite.xScale = spriteXSign * baseScale * 1.1
            let up = SKAction.moveBy(x: 0, y: 2, duration: 0.075)
            let down = SKAction.moveBy(x: 0, y: -2, duration: 0.075)
            up.timingMode = .easeOut
            down.timingMode = .easeIn
            sprite.run(SKAction.repeatForever(SKAction.sequence([up, down])), withKey: "stateAnim")

        case .socializing:
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
            if enhancedAnimations {
                // Multi-frame death animation
                let deathFrames = textureManager.deathTextures(for: creatureType)
                if deathFrames.count >= 3 {
                    let anim = SKAction.animate(with: deathFrames, timePerFrame: 0.2)
                    let holdCorpse = SKAction.setTexture(deathFrames[2])
                    let fadeToCorpse = SKAction.fadeAlpha(to: 0.5, duration: 0.3)
                    let lowerZ = SKAction.run { sprite.zPosition = 3 }
                    let deathSequence = SKAction.sequence([anim, holdCorpse, SKAction.group([fadeToCorpse, lowerZ])])
                    sprite.run(deathSequence, withKey: "stateAnim")

                    // Corpse fade-out after 30 seconds
                    let waitThenFade = SKAction.sequence([
                        SKAction.wait(forDuration: 30.0),
                        SKAction.fadeOut(withDuration: 2.0)
                    ])
                    sprite.run(waitThenFade, withKey: "corpseFade")
                } else {
                    sprite.zRotation = .pi / 2
                    sprite.alpha = 0.3
                    sprite.color = .gray
                    sprite.colorBlendFactor = 0.5
                }
            } else {
                // Basic: instant corpse
                sprite.zRotation = .pi / 2
                sprite.alpha = 0.3
                sprite.color = .gray
                sprite.colorBlendFactor = 0.5
            }
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

    private func spawnImpactParticles(at position: CGPoint, facing: Direction = .east) {
        if enhancedAnimations {
            // Directional bias based on facing
            let dirBias: CGFloat
            switch facing {
            case .east, .northeast, .southeast: dirBias = 1.0
            case .west, .northwest, .southwest: dirBias = -1.0
            default: dirBias = 0.0
            }

            // White additive spark
            let spark = SKSpriteNode(color: .white, size: CGSize(width: 4, height: 4))
            spark.position = position
            spark.zPosition = 42
            spark.blendMode = .add
            let sparkGrow = SKAction.scale(to: 2.0, duration: 0.04)
            let sparkFade = SKAction.group([SKAction.scale(to: 0.1, duration: 0.04), SKAction.fadeOut(withDuration: 0.04)])
            effectsLayer.addChild(spark)
            spark.run(SKAction.sequence([sparkGrow, sparkFade, SKAction.removeFromParent()]))

            // Red particles with directional velocity
            let count = Int.random(in: 4...7)
            for _ in 0..<count {
                let particle = SKSpriteNode(color: .red, size: CGSize(width: 2, height: 2))
                particle.position = position
                particle.zPosition = 41

                let dx = CGFloat.random(in: -8...8) + dirBias * 6
                let dy = CGFloat.random(in: 2...14)
                let gravity = CGFloat.random(in: -6...(-2))
                let movePath = CGMutablePath()
                movePath.move(to: .zero)
                movePath.addQuadCurve(to: CGPoint(x: dx, y: dy + gravity), control: CGPoint(x: dx * 0.5, y: dy))
                let followPath = SKAction.follow(movePath, asOffset: true, orientToPath: false, duration: 0.3)
                let fade = SKAction.fadeOut(withDuration: 0.3)
                let group = SKAction.group([followPath, fade])

                effectsLayer.addChild(particle)
                particle.run(SKAction.sequence([group, SKAction.removeFromParent()]))
            }
        } else {
            // Basic: simple random particles
            let count = Int.random(in: 3...5)
            for _ in 0..<count {
                let particle = SKSpriteNode(color: .red, size: CGSize(width: 2, height: 2))
                particle.position = position
                particle.zPosition = 41

                let dx = CGFloat.random(in: -8...8)
                let dy = CGFloat.random(in: 2...10)
                let moveUp = SKAction.moveBy(x: dx, y: dy, duration: 0.3)
                let fade = SKAction.fadeOut(withDuration: 0.3)
                let group = SKAction.group([moveUp, fade])

                effectsLayer.addChild(particle)
                particle.run(SKAction.sequence([group, SKAction.removeFromParent()]))
            }
        }
    }

    private func applyCameraShake() {
        guard let cam = cameraNode else { return }
        cam.removeAction(forKey: "cameraShake")
        let step: CGFloat = 2.0
        let dur: TimeInterval = 0.03
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -step, y: step, duration: dur),
            SKAction.moveBy(x: step * 2, y: -step, duration: dur),
            SKAction.moveBy(x: -step, y: 0, duration: dur),
        ])
        cam.run(shake, withKey: "cameraShake")
    }

    // MARK: - Footstep Dust

    private func spawnFootstepDust(at position: CGPoint, count: Int) {
        for _ in 0..<count {
            let dust = SKSpriteNode(color: SKColor(white: 0.7, alpha: 0.6), size: CGSize(width: 2, height: 2))
            dust.position = CGPoint(
                x: position.x + CGFloat.random(in: -4...4),
                y: position.y - tileSize * 0.25
            )
            dust.zPosition = 11
            let floatUp = SKAction.moveBy(x: CGFloat.random(in: -2...2), y: 6, duration: 0.4)
            let fade = SKAction.fadeOut(withDuration: 0.4)
            let scale = SKAction.scale(to: 0.3, duration: 0.4)
            effectsLayer.addChild(dust)
            dust.run(SKAction.sequence([SKAction.group([floatUp, fade, scale]), SKAction.removeFromParent()]))
        }
    }

    // MARK: - Seasonal Ambient Particles

    private func updateSeasonalParticles(season: Season, hour: Int) {
        if !enhancedAnimations {
            // Remove emitter and skip
            currentSeasonalEmitter?.removeFromParent()
            currentSeasonalEmitter = nil
            currentParticleSeason = nil
            return
        }

        // Only update if season changed
        if currentParticleSeason == season { return }
        currentParticleSeason = season

        // Remove existing seasonal emitter
        currentSeasonalEmitter?.removeFromParent()
        currentSeasonalEmitter = nil

        let emitter = SKEmitterNode()
        emitter.particlePositionRange = CGVector(dx: 2000, dy: 2000)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleSize = CGSize(width: 3, height: 3)
        emitter.targetNode = self

        switch season {
        case .spring:
            // Pink/white pollen dots drifting diagonally
            emitter.particleBirthRate = 3
            emitter.particleLifetime = 6
            emitter.particleLifetimeRange = 2
            emitter.particleSpeed = 8
            emitter.particleSpeedRange = 4
            emitter.emissionAngle = .pi * 0.75
            emitter.emissionAngleRange = .pi * 0.25
            emitter.particleAlpha = 0.4
            emitter.particleAlphaSpeed = -0.05
            emitter.particleScale = 0.4
            emitter.particleScaleRange = 0.2
            emitter.particleColor = SKColor(red: 1.0, green: 0.85, blue: 0.9, alpha: 1)
            emitter.particleColorRedRange = 0.1
            emitter.particleColorBlueRange = 0.1

        case .summer:
            // Fireflies at night (we'll check hour in updateWorld — for now always create but low rate)
            emitter.particleBirthRate = 2
            emitter.particleLifetime = 4
            emitter.particleLifetimeRange = 2
            emitter.particleSpeed = 3
            emitter.particleSpeedRange = 2
            emitter.emissionAngle = .pi / 2
            emitter.emissionAngleRange = .pi * 2
            emitter.particleAlpha = 0.5
            emitter.particleAlphaRange = 0.3
            emitter.particleAlphaSpeed = -0.1
            emitter.particleScale = 0.3
            emitter.particleColor = SKColor(red: 0.9, green: 1.0, blue: 0.4, alpha: 1)

        case .autumn:
            // Orange-brown falling leaves
            emitter.particleBirthRate = 2
            emitter.particleLifetime = 8
            emitter.particleLifetimeRange = 3
            emitter.particleSpeed = 6
            emitter.particleSpeedRange = 3
            emitter.emissionAngle = -.pi / 2 // down
            emitter.emissionAngleRange = .pi * 0.3
            emitter.particleAlpha = 0.6
            emitter.particleAlphaSpeed = -0.06
            emitter.particleScale = 0.5
            emitter.particleScaleRange = 0.2
            emitter.particleColor = SKColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1)
            emitter.particleColorRedRange = 0.2
            emitter.particleColorGreenRange = 0.2
            emitter.particleRotation = 0
            emitter.particleRotationRange = .pi
            emitter.particleRotationSpeed = 1.5
            emitter.particleSize = CGSize(width: 4, height: 4)

        case .winter:
            // White snowflakes
            emitter.particleBirthRate = 6
            emitter.particleLifetime = 10
            emitter.particleLifetimeRange = 4
            emitter.particleSpeed = 10
            emitter.particleSpeedRange = 5
            emitter.emissionAngle = -.pi / 2 - 0.2
            emitter.emissionAngleRange = .pi * 0.2
            emitter.particleAlpha = 0.6
            emitter.particleAlphaRange = 0.2
            emitter.particleAlphaSpeed = -0.04
            emitter.particleScale = 0.4
            emitter.particleScaleRange = 0.3
            emitter.particleColor = .white
        }

        let tex = SKTexture(imageNamed: "UI/ui_selection") // reuse small texture
        emitter.particleTexture = tex
        emitter.zPosition = 45
        ambientLayer.addChild(emitter)
        currentSeasonalEmitter = emitter
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
            // Render bubbles for each participant with a non-empty line
            for participant in conversation.participants {
                guard !participant.line.isEmpty,
                      let unit = snapshot.units.first(where: { $0.id == participant.unitId }) else {
                    continue
                }

                let bubble = createSpeechBubble(
                    text: participant.line,
                    isSuccess: conversation.isSuccess,
                    isInitiator: participant.isSpeaking
                )
                bubble.position = worldToScene(
                    x: unit.x, y: unit.y,
                    worldHeight: snapshot.height,
                    tileSize: tileSize
                )
                bubble.position.y += tileSize * 0.8
                if !participant.isSpeaking {
                    bubble.alpha = 0.6
                }
                speechBubbleLayer.addChild(bubble)
            }

            // Render small dim "..." bubbles for eavesdroppers
            for eavesdropperId in conversation.eavesdropperIds {
                guard let unit = snapshot.units.first(where: { $0.id == eavesdropperId }) else {
                    continue
                }

                let bubble = createSpeechBubble(
                    text: "...",
                    isSuccess: conversation.isSuccess,
                    isInitiator: false
                )
                bubble.position = worldToScene(
                    x: unit.x, y: unit.y,
                    worldHeight: snapshot.height,
                    tileSize: tileSize
                )
                bubble.position.y += tileSize * 0.8
                bubble.alpha = 0.35
                bubble.setScale(0.7)
                speechBubbleLayer.addChild(bubble)
            }
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

        switch gesture.state {
        case .began:
            camera.removeAction(forKey: "cameraMomentum")
        case .changed:
            let translation = gesture.translation(in: view)
            let scale = camera.xScale
            camera.position.x -= translation.x * scale
            camera.position.y += translation.y * scale
            gesture.setTranslation(.zero, in: view)
        case .ended:
            if enhancedAnimations {
                let velocity = gesture.velocity(in: view)
                let scale = camera.xScale
                let momentumDuration: TimeInterval = 0.5
                let dx = -velocity.x * scale * CGFloat(momentumDuration) * 0.15
                let dy = velocity.y * scale * CGFloat(momentumDuration) * 0.15
                let momentum = SKAction.moveBy(x: dx, y: dy, duration: momentumDuration)
                momentum.timingMode = .easeOut
                camera.run(momentum, withKey: "cameraMomentum")
            }
        default: break
        }
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

        switch gesture.state {
        case .began:
            camera.removeAction(forKey: "cameraMomentum")
        case .changed:
            let translation = gesture.translation(in: view)
            let scale = camera.xScale
            camera.position.x -= translation.x * scale
            camera.position.y -= translation.y * scale
            gesture.setTranslation(.zero, in: view)
        case .ended:
            if enhancedAnimations {
                let velocity = gesture.velocity(in: view)
                let scale = camera.xScale
                let momentumDuration: TimeInterval = 0.5
                let dx = -velocity.x * scale * CGFloat(momentumDuration) * 0.15
                let dy = -velocity.y * scale * CGFloat(momentumDuration) * 0.15
                let momentum = SKAction.moveBy(x: dx, y: dy, duration: momentumDuration)
                momentum.timingMode = .easeOut
                camera.run(momentum, withKey: "cameraMomentum")
            }
        default: break
        }
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
