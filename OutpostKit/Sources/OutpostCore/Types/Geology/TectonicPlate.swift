// MARK: - Tectonic Plate

/// A tectonic plate with drift vector and type
public struct TectonicPlate: Sendable {
    public let id: Int
    public let centerX: Double
    public let centerY: Double
    public let driftX: Double
    public let driftY: Double
    public let isOceanic: Bool

    public init(id: Int, centerX: Double, centerY: Double, driftX: Double, driftY: Double, isOceanic: Bool) {
        self.id = id
        self.centerX = centerX
        self.centerY = centerY
        self.driftX = driftX
        self.driftY = driftY
        self.isOceanic = isOceanic
    }
}
