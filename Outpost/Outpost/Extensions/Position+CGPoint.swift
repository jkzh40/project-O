import CoreGraphics
import OutpostRuntime

// MARK: - Coordinate Conversion

extension Position {
    /// Converts to CGPoint using a tile size
    func toCGPoint(tileSize: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(x) * tileSize + tileSize / 2,
            y: CGFloat(y) * tileSize + tileSize / 2
        )
    }
}

extension CGPoint {
    /// Converts from scene coordinates to grid position
    func toGridPosition(tileSize: CGFloat) -> (x: Int, y: Int) {
        let gridX = Int(floor(x / tileSize))
        let gridY = Int(floor(y / tileSize))
        return (gridX, gridY)
    }
}

// MARK: - SpriteKit Helpers

/// Converts world coordinates to SpriteKit scene coordinates
/// SpriteKit has (0,0) at bottom-left, world has (0,0) at top-left
func worldToScene(x: Int, y: Int, worldHeight: Int, tileSize: CGFloat) -> CGPoint {
    CGPoint(
        x: CGFloat(x) * tileSize + tileSize / 2,
        y: CGFloat(worldHeight - 1 - y) * tileSize + tileSize / 2
    )
}

/// Converts SpriteKit scene coordinates to world grid coordinates
func sceneToWorld(point: CGPoint, worldHeight: Int, tileSize: CGFloat) -> (x: Int, y: Int) {
    let gridX = Int(floor(point.x / tileSize))
    let gridY = worldHeight - 1 - Int(floor(point.y / tileSize))
    return (gridX, gridY)
}
