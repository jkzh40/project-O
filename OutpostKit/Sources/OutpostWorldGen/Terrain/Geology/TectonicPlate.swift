// MARK: - Tectonic Plate

/// A tectonic plate with drift vector and type
struct TectonicPlate: Sendable {
    let id: Int
    let centerX: Double
    let centerY: Double
    let driftX: Double
    let driftY: Double
    let isOceanic: Bool

    init(id: Int, centerX: Double, centerY: Double, driftX: Double, driftY: Double, isOceanic: Bool) {
        self.id = id
        self.centerX = centerX
        self.centerY = centerY
        self.driftX = driftX
        self.driftY = driftY
        self.isOceanic = isOceanic
    }
}
