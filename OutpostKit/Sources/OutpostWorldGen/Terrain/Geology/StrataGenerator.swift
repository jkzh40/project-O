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
            // Sediment field with new soft rocks near surface, fantasy at depth
            return [
                RockLayer(rockType: .chalk, thickness: 0.08),
                RockLayer(rockType: .sandstone, thickness: 0.14),
                RockLayer(rockType: .limestone, thickness: 0.14),
                RockLayer(rockType: .mudstone, thickness: 0.08),
                RockLayer(rockType: .shale, thickness: 0.10),
                RockLayer(rockType: .gneiss, thickness: 0.14),
                RockLayer(rockType: .livingrock, thickness: 0.04),
                RockLayer(rockType: .deepslate, thickness: 0.10),
                RockLayer(rockType: .runestone, thickness: 0.03),
                RockLayer(rockType: .aetherstone, thickness: 0.02),
                RockLayer(rockType: .granite, thickness: 0.13),
            ]

        case .continentalCollision:
            // High stress metamorphic with new metamorphic rocks
            return [
                RockLayer(rockType: .phyllite, thickness: 0.10),
                RockLayer(rockType: .slate, thickness: 0.14),
                RockLayer(rockType: .schist, thickness: 0.14),
                RockLayer(rockType: .serpentinite, thickness: 0.06),
                RockLayer(rockType: .marble, thickness: 0.14),
                RockLayer(rockType: .migmatite, thickness: 0.08),
                RockLayer(rockType: .moonstone, thickness: 0.04),
                RockLayer(rockType: .deepslate, thickness: 0.10),
                RockLayer(rockType: .voidrock, thickness: 0.03),
                RockLayer(rockType: .granite, thickness: 0.17),
            ]

        case .subductionZone:
            // Volcanic arc with new extrusive/intrusive rocks
            return [
                RockLayer(rockType: .tuff, thickness: 0.06),
                RockLayer(rockType: .basalt, thickness: 0.10),
                RockLayer(rockType: .rhyolite, thickness: 0.08),
                RockLayer(rockType: .andesite, thickness: 0.12),
                RockLayer(rockType: .diorite, thickness: 0.14),
                RockLayer(rockType: .pegmatite, thickness: 0.06),
                RockLayer(rockType: .sunrock, thickness: 0.04),
                RockLayer(rockType: .dragonrock, thickness: 0.03),
                RockLayer(rockType: .deepslate, thickness: 0.10),
                RockLayer(rockType: .schist, thickness: 0.12),
                RockLayer(rockType: .granite, thickness: 0.15),
            ]

        case .continentalRift:
            // Rift fill with siltstone and pumice, fantasy at depth
            return [
                RockLayer(rockType: .siltstone, thickness: 0.08),
                RockLayer(rockType: .sandstone, thickness: 0.16),
                RockLayer(rockType: .pumice, thickness: 0.06),
                RockLayer(rockType: .basalt, thickness: 0.20),
                RockLayer(rockType: .shadowrock, thickness: 0.04),
                RockLayer(rockType: .crystalrock, thickness: 0.04),
                RockLayer(rockType: .deepslate, thickness: 0.10),
                RockLayer(rockType: .granite, thickness: 0.20),
                RockLayer(rockType: .glowstone, thickness: 0.03),
                RockLayer(rockType: .bloodstone, thickness: 0.03),
                RockLayer(rockType: .deepslate, thickness: 0.06),
            ]

        case .oceanicSpread:
            // Mid-ocean ridge with tuff and soapstone
            return [
                RockLayer(rockType: .travertine, thickness: 0.06),
                RockLayer(rockType: .limestone, thickness: 0.12),
                RockLayer(rockType: .tuff, thickness: 0.06),
                RockLayer(rockType: .basalt, thickness: 0.26),
                RockLayer(rockType: .soapstone, thickness: 0.04),
                RockLayer(rockType: .gabbro, thickness: 0.26),
                RockLayer(rockType: .deepslate, thickness: 0.08),
                RockLayer(rockType: .aetherstone, thickness: 0.03),
                RockLayer(rockType: .livingrock, thickness: 0.03),
                RockLayer(rockType: .deepslate, thickness: 0.06),
            ]

        case .transformFault:
            // Sheared strata with phyllite and serpentinite
            return [
                RockLayer(rockType: .siltstone, thickness: 0.06),
                RockLayer(rockType: .sandstone, thickness: 0.12),
                RockLayer(rockType: .phyllite, thickness: 0.10),
                RockLayer(rockType: .serpentinite, thickness: 0.08),
                RockLayer(rockType: .slate, thickness: 0.14),
                RockLayer(rockType: .schist, thickness: 0.14),
                RockLayer(rockType: .runestone, thickness: 0.04),
                RockLayer(rockType: .deepslate, thickness: 0.10),
                RockLayer(rockType: .shadowrock, thickness: 0.03),
                RockLayer(rockType: .granite, thickness: 0.19),
            ]

        case .stableOceanic:
            // Ocean floor with mudstone
            return [
                RockLayer(rockType: .mudstone, thickness: 0.06),
                RockLayer(rockType: .limestone, thickness: 0.10),
                RockLayer(rockType: .basalt, thickness: 0.30),
                RockLayer(rockType: .gabbro, thickness: 0.26),
                RockLayer(rockType: .deepslate, thickness: 0.10),
                RockLayer(rockType: .moonstone, thickness: 0.03),
                RockLayer(rockType: .voidrock, thickness: 0.03),
                RockLayer(rockType: .deepslate, thickness: 0.12),
            ]
        }
    }
}
