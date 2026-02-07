// MARK: - Strata Generator
// Builds geological columns from tectonic context

/// Tectonic setting classification for strata generation
enum TectonicContext: Sendable {
    case stableContinental
    case continentalCollision
    case subductionZone
    case continentalRift
    case oceanicSpread
    case transformFault
    case stableOceanic
}

/// Generates geological columns based on tectonic context
struct StrataGenerator: Sendable {

    /// Classifies the tectonic context of a cell from plate data
    static func classifyContext(
        cell: WorldMapCell,
        plates: [TectonicPlate]
    ) -> TectonicContext {
        let myPlate = plates[cell.plateId]

        // Interior cells with no boundary
        guard cell.boundaryType != .none else {
            return myPlate.isOceanic ? .stableOceanic : .stableContinental
        }

        // Boundary cells — classify by boundary type and plate types
        let neighborIsOceanic: Bool
        if let neighborId = cell.neighborPlateId, neighborId < plates.count {
            neighborIsOceanic = plates[neighborId].isOceanic
        } else {
            neighborIsOceanic = myPlate.isOceanic
        }

        switch cell.boundaryType {
        case .convergent:
            if myPlate.isOceanic != neighborIsOceanic {
                return .subductionZone
            }
            return .continentalCollision

        case .divergent:
            if myPlate.isOceanic && neighborIsOceanic {
                return .oceanicSpread
            }
            return .continentalRift

        case .transform:
            return .transformFault

        case .none:
            return myPlate.isOceanic ? .stableOceanic : .stableContinental
        }
    }

    /// Generates a geological column for the given tectonic context
    static func generateColumn(
        context: TectonicContext,
        cell: WorldMapCell,
        noise: SimplexNoise,
        x: Int,
        y: Int,
        rng: inout SeededRNG
    ) -> GeologicalColumn {
        let baseLayers = layerSequence(for: context)

        // Perturb thicknesses with noise (±15%)
        let nx = Double(x) * 0.01
        let ny = Double(y) * 0.01
        let perturbation = Float(noise.noise2D(x: nx * 5.0 + 1000, y: ny * 5.0 + 1000))

        var layers = baseLayers.map { layer in
            let factor = 1.0 + perturbation * 0.15
            return RockLayer(
                rockType: layer.rockType,
                thickness: max(0.02, layer.thickness * factor)
            )
        }

        // Renormalize so thicknesses sum to 1.0
        let total = layers.reduce(Float(0)) { $0 + $1.thickness }
        if total > 0 {
            layers = layers.map {
                RockLayer(rockType: $0.rockType, thickness: $0.thickness / total)
            }
        }

        return GeologicalColumn(layers: layers)
    }

    // MARK: - Layer Sequences

    /// Base layer sequence for each tectonic context (top to bottom)
    private static func layerSequence(for context: TectonicContext) -> [RockLayer] {
        switch context {
        case .stableContinental:
            // Sediment field: sandstone → limestone → shale → gneiss → granite
            return [
                RockLayer(rockType: .sandstone, thickness: 0.20),
                RockLayer(rockType: .limestone, thickness: 0.20),
                RockLayer(rockType: .shale, thickness: 0.15),
                RockLayer(rockType: .gneiss, thickness: 0.20),
                RockLayer(rockType: .granite, thickness: 0.25),
            ]

        case .continentalCollision:
            // High stress metamorphic: slate → schist → marble → granite
            return [
                RockLayer(rockType: .slate, thickness: 0.20),
                RockLayer(rockType: .schist, thickness: 0.25),
                RockLayer(rockType: .marble, thickness: 0.25),
                RockLayer(rockType: .granite, thickness: 0.30),
            ]

        case .subductionZone:
            // Volcanic arc: basalt → andesite → diorite → granite → schist
            return [
                RockLayer(rockType: .basalt, thickness: 0.15),
                RockLayer(rockType: .andesite, thickness: 0.20),
                RockLayer(rockType: .diorite, thickness: 0.20),
                RockLayer(rockType: .granite, thickness: 0.25),
                RockLayer(rockType: .schist, thickness: 0.20),
            ]

        case .continentalRift:
            // Rift fill: sandstone → basalt → granite
            return [
                RockLayer(rockType: .sandstone, thickness: 0.30),
                RockLayer(rockType: .basalt, thickness: 0.35),
                RockLayer(rockType: .granite, thickness: 0.35),
            ]

        case .oceanicSpread:
            // Mid-ocean ridge: limestone → basalt → gabbro
            return [
                RockLayer(rockType: .limestone, thickness: 0.20),
                RockLayer(rockType: .basalt, thickness: 0.40),
                RockLayer(rockType: .gabbro, thickness: 0.40),
            ]

        case .transformFault:
            // Sheared strata: sandstone → slate → schist → granite
            return [
                RockLayer(rockType: .sandstone, thickness: 0.20),
                RockLayer(rockType: .slate, thickness: 0.25),
                RockLayer(rockType: .schist, thickness: 0.25),
                RockLayer(rockType: .granite, thickness: 0.30),
            ]

        case .stableOceanic:
            // Ocean floor: limestone → basalt → gabbro
            return [
                RockLayer(rockType: .limestone, thickness: 0.15),
                RockLayer(rockType: .basalt, thickness: 0.45),
                RockLayer(rockType: .gabbro, thickness: 0.40),
            ]
        }
    }
}
