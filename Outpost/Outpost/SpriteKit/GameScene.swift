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

    // MARK: - Layers

    private let tileLayer = SKNode()
    private let itemLayer = SKNode()
    private let unitLayer = SKNode()
    private let selectionLayer = SKNode()

    // MARK: - Sprite Pools

    private var tileSprites: [[SKSpriteNode]] = []
    private var unitSprites: [UInt64: SKSpriteNode] = [:]
    private var itemSprites: [UInt64: SKSpriteNode] = [:]
    private var selectionSprite: SKSpriteNode?

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
        addChild(tileLayer)
        addChild(itemLayer)
        addChild(unitLayer)
        addChild(selectionLayer)

        // Setup gesture recognizers
        setupGestureRecognizers()
    }

    private func setupGestureRecognizers() {
        guard let view = self.view else { return }

        #if os(iOS)
        // Pan gesture for camera movement
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)

        // Pinch gesture for zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        // Tap gesture for selection
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)

        #elseif os(macOS)
        // Pan gesture for camera movement
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panGesture)

        // Magnification gesture for zoom
        let magnifyGesture = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        view.addGestureRecognizer(magnifyGesture)

        // Click gesture for selection
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
        updateSelection()
    }

    // MARK: - Tile Rendering

    private func updateTiles(_ snapshot: WorldSnapshot) {
        // Initialize tile grid if needed
        if tileSprites.isEmpty || tileSprites.count != snapshot.height {
            // Clear existing tiles
            tileLayer.removeAllChildren()
            tileSprites.removeAll()

            // Create tile sprites
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

        // Update textures
        for y in 0..<snapshot.height {
            for x in 0..<snapshot.width {
                let tile = snapshot.tiles[y][x]
                let sprite = tileSprites[y][x]
                sprite.texture = textureManager.texture(for: tile.terrain)
            }
        }
    }

    // MARK: - Item Rendering

    private func updateItems(_ snapshot: WorldSnapshot) {
        // Track which items are still present
        var presentItemIds = Set<UInt64>()

        for item in snapshot.items {
            presentItemIds.insert(item.id)

            if let sprite = itemSprites[item.id] {
                // Update existing sprite
                sprite.position = worldToScene(
                    x: item.x, y: item.y,
                    worldHeight: snapshot.height,
                    tileSize: tileSize
                )
            } else {
                // Create new sprite
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

        // Remove sprites for items that no longer exist
        for (id, sprite) in itemSprites {
            if !presentItemIds.contains(id) {
                sprite.removeFromParent()
                itemSprites.removeValue(forKey: id)
            }
        }
    }

    // MARK: - Unit Rendering

    private func updateUnits(_ snapshot: WorldSnapshot) {
        // Track which units are still present
        var presentUnitIds = Set<UInt64>()

        for unit in snapshot.units {
            presentUnitIds.insert(unit.id)

            if let sprite = unitSprites[unit.id] {
                // Update existing sprite position with smooth animation
                let newPosition = worldToScene(
                    x: unit.x, y: unit.y,
                    worldHeight: snapshot.height,
                    tileSize: tileSize
                )

                // Only animate if position actually changed
                if sprite.position.distance(to: newPosition) > 1 {
                    sprite.run(SKAction.move(to: newPosition, duration: 0.08))
                }

                // Update texture if creature type changed (shouldn't happen normally)
                sprite.texture = textureManager.texture(for: unit.creatureType)

                // Update state indicator
                updateUnitStateIndicator(sprite: sprite, state: unit.state)
            } else {
                // Create new sprite
                let sprite = SKSpriteNode(texture: textureManager.texture(for: unit.creatureType))
                sprite.size = CGSize(width: tileSize * 0.8, height: tileSize * 0.8)
                sprite.position = worldToScene(
                    x: unit.x, y: unit.y,
                    worldHeight: snapshot.height,
                    tileSize: tileSize
                )
                sprite.zPosition = 10
                sprite.name = "unit_\(unit.id)"
                unitLayer.addChild(sprite)
                unitSprites[unit.id] = sprite

                updateUnitStateIndicator(sprite: sprite, state: unit.state)
            }
        }

        // Remove sprites for units that no longer exist
        for (id, sprite) in unitSprites {
            if !presentUnitIds.contains(id) {
                sprite.removeFromParent()
                unitSprites.removeValue(forKey: id)
            }
        }
    }

    private func updateUnitStateIndicator(sprite: SKSpriteNode, state: UnitState) {
        // Remove existing indicator
        sprite.childNode(withName: "stateIndicator")?.removeFromParent()

        // Add state color overlay if not idle
        let stateColor = textureManager.stateColor(for: state)
        if stateColor != .clear {
            let indicator = SKShapeNode(circleOfRadius: tileSize * 0.5)
            indicator.fillColor = stateColor
            indicator.strokeColor = .clear
            indicator.zPosition = -1
            indicator.name = "stateIndicator"
            sprite.addChild(indicator)
        }
    }

    // MARK: - Selection Rendering

    private func updateSelection() {
        // Remove existing selection
        selectionLayer.removeAllChildren()

        guard let selectedId = selectedUnitId,
              let unitSprite = unitSprites[selectedId] else { return }

        // Create selection ring
        let selection = SKSpriteNode(texture: textureManager.selectionRingTexture())
        selection.size = CGSize(width: tileSize, height: tileSize)
        selection.position = unitSprite.position
        selection.zPosition = 5

        // Add pulsing animation
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.5)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.5)
        let pulse = SKAction.sequence([scaleUp, scaleDown])
        selection.run(SKAction.repeatForever(pulse))

        selectionLayer.addChild(selection)
        selectionSprite = selection
    }

    // MARK: - iOS Gesture Handlers

    #if os(iOS)
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let camera = cameraNode else { return }

        let translation = gesture.translation(in: view)
        let scale = camera.xScale

        // Move camera opposite to pan direction, scaled by zoom level
        camera.position.x -= translation.x * scale
        camera.position.y += translation.y * scale  // Inverted for SpriteKit coordinates

        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let camera = cameraNode else { return }

        switch gesture.state {
        case .began:
            initialPinchScale = camera.xScale
        case .changed:
            let newScale = initialPinchScale / gesture.scale
            // Clamp zoom level
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

        // Move camera opposite to pan direction, scaled by zoom level
        camera.position.x -= translation.x * scale
        camera.position.y -= translation.y * scale  // macOS Y is already correct direction

        gesture.setTranslation(.zero, in: view)
    }

    @objc private func handleMagnify(_ gesture: NSMagnificationGestureRecognizer) {
        guard let camera = cameraNode else { return }

        switch gesture.state {
        case .began:
            initialMagnificationScale = camera.xScale
        case .changed:
            let newScale = initialMagnificationScale / (1.0 + gesture.magnification)
            // Clamp zoom level
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

    // Handle scroll wheel for zooming on macOS
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

        // Convert to grid coordinates
        let (gridX, gridY) = sceneToWorld(
            point: sceneLocation,
            worldHeight: snapshot.height,
            tileSize: tileSize
        )

        // Find unit at this position
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
