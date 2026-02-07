// MARK: - Ore Type

/// Types of mineable ore deposits
enum OreType: String, CaseIterable, Sendable {
    // Original ores
    case iron
    case copper
    case tin
    case gold
    case silver
    case coal
    case gemstone

    // Real geology ores
    case lead
    case zinc
    case nickel
    case platinum
    case chromium
    case tungsten
    case cobalt
    case mercury
    case sulfur
    case saltpeter
    case bauxite
    case bismuth

    // Fantasy ores
    case mithril
    case adamantine
    case orichalcum
    case starmetal
    case moonsilver
    case sunstone
    case darksteel
    case bloodiron
    case etherealite
    case runegold
    case voidstone
    case dragonite
}
