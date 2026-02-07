// MARK: - Plate Boundary

/// Classification of plate boundary types
public enum PlateBoundaryType: Sendable {
    case convergent   // Plates moving toward each other → mountains
    case divergent    // Plates moving apart → rifts/valleys
    case transform    // Plates sliding past → moderate elevation
    case none         // Interior of plate
}
