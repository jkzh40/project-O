// MARK: - Geological Column
// Vertical strata profile for a world map cell

/// A single rock layer within a geological column
public struct RockLayer: Sendable {
    /// The type of rock in this layer
    public let rockType: RockType
    /// Normalized thickness (0-1 fraction of total column depth)
    public let thickness: Float

    public init(rockType: RockType, thickness: Float) {
        self.rockType = rockType
        self.thickness = thickness
    }
}

/// Vertical sequence of rock layers at a world map cell
public struct GeologicalColumn: Sendable {
    /// Rock layers ordered from top (surface) to bottom (deep crust)
    public let layers: [RockLayer]

    public init(layers: [RockLayer]) {
        self.layers = layers
    }

    /// Returns the rock type at a given z-level
    /// - Parameters:
    ///   - z: The z-level (0 = surface, increasing downward)
    ///   - totalDepth: Total number of underground z-levels
    /// - Returns: The rock type at that depth
    public func rockType(atZLevel z: Int, totalDepth: Int) -> RockType {
        guard !layers.isEmpty, totalDepth > 0 else { return .granite }

        let normalizedDepth = Float(z) / Float(totalDepth)
        var cumulative: Float = 0

        for layer in layers {
            cumulative += layer.thickness
            if normalizedDepth < cumulative {
                return layer.rockType
            }
        }

        // Return deepest layer if we somehow exceed 1.0
        return layers.last?.rockType ?? .granite
    }
}
