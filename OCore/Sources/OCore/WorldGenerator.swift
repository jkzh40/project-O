// MARK: - World Generator
// Generates world history, civilizations, and lore over simulated years

import Foundation

/// Callback for world generation progress
public typealias WorldGenCallback = @MainActor (WorldGenPhase, String, WorldHistory) -> Void

/// Phases of world generation
public enum WorldGenPhase: String, Sendable {
    case creation = "Creating World"
    case terrain = "Shaping Terrain"
    case regions = "Defining Regions"
    case civilizations = "Founding Civilizations"
    case history = "Simulating History"
    case complete = "Generation Complete"
}

/// Generates a world with history
@MainActor
public final class WorldGenerator: Sendable {
    /// The world being generated
    public private(set) var world: World

    /// Historical data
    public private(set) var history: WorldHistory

    /// Current generation phase
    public private(set) var currentPhase: WorldGenPhase = .creation

    /// Years of history to simulate
    public let historyYears: Int

    /// Callback for progress updates
    public var onProgress: WorldGenCallback?

    /// Speed of generation display (events per second)
    public var generationSpeed: Double = 20.0

    /// ID counters
    private var nextEventId: UInt64 = 1
    private var nextFigureId: UInt64 = 1
    private var nextCivId: UInt64 = 1

    /// Creates a new world generator
    public init(
        worldWidth: Int = 50,
        worldHeight: Int = 25,
        historyYears: Int = 250
    ) {
        self.world = World(width: worldWidth, height: worldHeight)
        self.history = WorldHistory(worldName: WorldNameGenerator.generate())
        self.historyYears = historyYears
    }

    // MARK: - Generation

    /// Generates the complete world with history
    public func generate() async {
        // Phase 1: World Creation
        await phaseCreation()

        // Phase 2: Terrain Shaping
        await phaseTerrain()

        // Phase 3: Region Definition
        await phaseRegions()

        // Phase 4: Civilization Founding
        await phaseCivilizations()

        // Phase 5: History Simulation
        await phaseHistory()

        // Complete
        currentPhase = .complete
        emitProgress("World generation complete! \(history.events.count) events recorded.")
    }

    // MARK: - Generation Phases

    private func phaseCreation() async {
        currentPhase = .creation
        emitProgress("In the beginning, there was nothing...")
        await delay()

        emitProgress("The void stirred, and \(history.worldName) began to form...")
        await delay()

        addEvent(year: 0, type: .worldCreated,
                 description: "\(history.worldName) was created from the primordial void")
        await delay()
    }

    private func phaseTerrain() async {
        currentPhase = .terrain

        // Mountains
        let mountainCount = Int.random(in: 3...6)
        for i in 1...mountainCount {
            emitProgress("Great mountains rise from the earth... (\(i)/\(mountainCount))")
            let mountainName = ["The Spine of the World", "Mount Eternal", "The Iron Peaks",
                               "Thunder Summit", "The Frozen Crown", "Dragonspire"].randomElement()!
            addEvent(year: 0, type: .mountainRaised,
                    description: "\(mountainName) rose from the depths")
            await delay(short: true)
        }

        // Rivers
        let riverCount = Int.random(in: 2...4)
        for i in 1...riverCount {
            emitProgress("Rivers carve their paths... (\(i)/\(riverCount))")
            let riverName = ["The Great River", "Silverflow", "The Serpent's Path",
                            "Mistwater", "The Roaring Current"].randomElement()!
            addEvent(year: 0, type: .riverCarved,
                    description: "\(riverName) carved its path across the land")
            await delay(short: true)
        }

        // Forests
        let forestCount = Int.random(in: 2...5)
        for i in 1...forestCount {
            emitProgress("Forests spread across the land... (\(i)/\(forestCount))")
            let forestName = ["The Ancient Wood", "Shadowgrove", "The Emerald Forest",
                             "Whisperwood", "The Tangled Thicket"].randomElement()!
            addEvent(year: 1, type: .forestGrew,
                    description: "\(forestName) spread across the valleys")
            await delay(short: true)
        }
    }

    private func phaseRegions() async {
        currentPhase = .regions

        let regionCount = Int.random(in: 6...10)
        for i in 1...regionCount {
            let regionName = RegionNameGenerator.generate()
            history.regions.append(regionName)
            emitProgress("Defining \(regionName)... (\(i)/\(regionCount))")
            await delay(short: true)
        }

        emitProgress("\(regionCount) regions defined across \(history.worldName)")
        await delay()
    }

    private func phaseCivilizations() async {
        currentPhase = .civilizations

        let civCount = Int.random(in: 3...6)
        let foundingYears = (1...civCount).map { _ in Int.random(in: 5...50) }.sorted()

        for year in foundingYears {
            let civName = CivilizationNameGenerator.generate()
            var civ = Civilization(id: nextCivId, name: civName, foundingYear: year)
            nextCivId += 1

            // Assign traits
            let traitCount = Int.random(in: 1...3)
            civ.traits = Array(CivilizationTrait.allCases.shuffled().prefix(traitCount))

            // Assign initial territory
            if let territory = history.regions.randomElement() {
                civ.territories.append(territory)
            }

            // Create founding leader
            let leaderName = NameGenerator.generate()
            var leader = HistoricalFigure(
                id: nextFigureId,
                name: leaderName,
                birthYear: year - Int.random(in: 20...40),
                civilizationId: civ.id
            )
            leader.title = ["King", "Queen", "Chief", "High Lord", "Warlord", "Elder"].randomElement()!
            nextFigureId += 1

            civ.leader = leader.id
            history.figures[leader.id] = leader
            history.civilizations[civ.id] = civ

            emitProgress("Year \(year): \(civName) founded by \(leader.title!) \(leaderName.firstName)")
            addEvent(year: year, type: .civFounded,
                    description: "\(civName) was founded in the \(civ.territories.first ?? "wilderness")",
                    involvedCivs: [civ.id])
            addEvent(year: year, type: .leaderRose,
                    description: "\(leader.title!) \(leaderName.firstName) rose to lead \(civName)",
                    involvedFigures: [leader.id], involvedCivs: [civ.id])
            await delay()
        }

        // Establish initial relations
        let civIds = Array(history.civilizations.keys)
        for i in 0..<civIds.count {
            for j in (i+1)..<civIds.count {
                let relation: CivRelation = [.neutral, .friendly, .tense].randomElement()!
                history.civilizations[civIds[i]]?.relations[civIds[j]] = relation
                history.civilizations[civIds[j]]?.relations[civIds[i]] = relation
            }
        }
    }

    private func phaseHistory() async {
        currentPhase = .history

        let startYear = (history.civilizations.values.map { $0.foundingYear }.max() ?? 0) + 1
        history.currentYear = startYear

        for year in startYear...historyYears {
            history.currentYear = year

            // Generate events for this year
            let eventCount = Int.random(in: 0...3)
            for _ in 0..<eventCount {
                await generateYearlyEvent(year: year)
            }

            // Decade summary
            if year % 10 == 0 {
                let activeCivs = history.activeCivilizations.count
                let livingFigures = history.livingFigures.count
                emitProgress("Year \(year): \(activeCivs) civilizations, \(livingFigures) notable figures")
                await delay(short: true)
            }

            // Century milestone
            if year % 100 == 0 && year > 0 {
                emitProgress("═══ Century \(year / 100) passes... ═══")
                await delay()
            }
        }

        emitProgress("Year \(historyYears): History simulation complete")
    }

    // MARK: - Event Generation

    private func generateYearlyEvent(year: Int) async {
        let activeCivs = history.activeCivilizations
        guard !activeCivs.isEmpty else { return }

        let eventType = weightedRandomEvent()

        switch eventType {
        case .warDeclared:
            await generateWar(year: year, civs: activeCivs)
        case .allianceFormed:
            await generateAlliance(year: year, civs: activeCivs)
        case .leaderDied:
            await generateLeaderDeath(year: year, civs: activeCivs)
        case .heroicDeed:
            await generateHeroicDeed(year: year, civs: activeCivs)
        case .artifactCreated:
            await generateArtifact(year: year, civs: activeCivs)
        case .civExpanded:
            await generateExpansion(year: year, civs: activeCivs)
        case .plague, .famine:
            await generateDisaster(year: year, civs: activeCivs, type: eventType)
        case .figureBorn:
            await generateNotableBirth(year: year, civs: activeCivs)
        default:
            break
        }
    }

    private func weightedRandomEvent() -> HistoricalEventType {
        let weights: [(HistoricalEventType, Int)] = [
            (.figureBorn, 25),
            (.heroicDeed, 15),
            (.civExpanded, 15),
            (.leaderDied, 10),
            (.warDeclared, 10),
            (.allianceFormed, 8),
            (.artifactCreated, 7),
            (.plague, 5),
            (.famine, 5),
        ]

        let total = weights.reduce(0) { $0 + $1.1 }
        var roll = Int.random(in: 1...total)

        for (event, weight) in weights {
            roll -= weight
            if roll <= 0 {
                return event
            }
        }
        return .heroicDeed
    }

    private func generateWar(year: Int, civs: [Civilization]) async {
        guard civs.count >= 2 else { return }
        let shuffled = civs.shuffled()
        let civ1 = shuffled[0]
        let civ2 = shuffled[1]

        // Check if already at war
        if civ1.relations[civ2.id] == .atWar { return }

        history.civilizations[civ1.id]?.relations[civ2.id] = .atWar
        history.civilizations[civ2.id]?.relations[civ1.id] = .atWar

        let warName = ["The War of", "The Conflict of", "The Struggle for", "The Battle of"].randomElement()!
        let warSubject = ["Honor", "Territory", "Succession", "Revenge", "Resources", "the Crown"].randomElement()!

        emitProgress("Year \(year): WAR! \(civ1.name) declares war on \(civ2.name)!")
        addEvent(year: year, type: .warDeclared,
                description: "\(warName) \(warSubject) began between \(civ1.name) and \(civ2.name)",
                involvedCivs: [civ1.id, civ2.id])
        await delay()
    }

    private func generateAlliance(year: Int, civs: [Civilization]) async {
        guard civs.count >= 2 else { return }
        let shuffled = civs.shuffled()
        let civ1 = shuffled[0]
        let civ2 = shuffled[1]

        // Can't ally if at war
        if civ1.relations[civ2.id] == .atWar { return }

        history.civilizations[civ1.id]?.relations[civ2.id] = .allied
        history.civilizations[civ2.id]?.relations[civ1.id] = .allied

        emitProgress("Year \(year): \(civ1.name) and \(civ2.name) form an alliance")
        addEvent(year: year, type: .allianceFormed,
                description: "\(civ1.name) and \(civ2.name) signed a treaty of alliance",
                involvedCivs: [civ1.id, civ2.id])
        await delay(short: true)
    }

    private func generateLeaderDeath(year: Int, civs: [Civilization]) async {
        guard let civ = civs.randomElement(),
              let leaderId = civ.leader,
              var leader = history.figures[leaderId],
              leader.isAlive else { return }

        leader.deathYear = year
        history.figures[leaderId] = leader

        let cause = ["old age", "battle", "illness", "assassination", "accident"].randomElement()!
        emitProgress("Year \(year): \(leader.title ?? "") \(leader.name.firstName) of \(civ.name) died of \(cause)")
        addEvent(year: year, type: .leaderDied,
                description: "\(leader.title ?? "Leader") \(leader.name.firstName) of \(civ.name) died of \(cause)",
                involvedFigures: [leaderId], involvedCivs: [civ.id])

        // Generate new leader
        let newLeaderName = NameGenerator.generate()
        var newLeader = HistoricalFigure(
            id: nextFigureId,
            name: newLeaderName,
            birthYear: year - Int.random(in: 25...50),
            civilizationId: civ.id
        )
        newLeader.title = leader.title
        nextFigureId += 1

        history.figures[newLeader.id] = newLeader
        history.civilizations[civ.id]?.leader = newLeader.id

        addEvent(year: year, type: .leaderRose,
                description: "\(newLeader.title ?? "") \(newLeaderName.firstName) rose to lead \(civ.name)",
                involvedFigures: [newLeader.id], involvedCivs: [civ.id])
        await delay()
    }

    private func generateHeroicDeed(year: Int, civs: [Civilization]) async {
        guard let civ = civs.randomElement() else { return }

        let heroName = NameGenerator.generate()
        var hero = HistoricalFigure(
            id: nextFigureId,
            name: heroName,
            birthYear: year - Int.random(in: 20...40),
            civilizationId: civ.id
        )
        nextFigureId += 1

        let deed = [
            "slew a great beast terrorizing the land",
            "discovered a lost ancient ruin",
            "saved a village from raiders",
            "won a great tournament",
            "negotiated peace between warring factions",
            "led a daring expedition into unknown lands",
            "defended the realm against invaders"
        ].randomElement()!

        hero.notableDeeds.append(deed)
        hero.title = ["Hero", "Champion", "Defender", "Knight", "Wanderer"].randomElement()!
        history.figures[hero.id] = hero

        emitProgress("Year \(year): \(heroName.firstName) of \(civ.name) \(deed)")
        addEvent(year: year, type: .heroicDeed,
                description: "\(heroName.firstName) of \(civ.name) \(deed)",
                involvedFigures: [hero.id], involvedCivs: [civ.id])
        await delay(short: true)
    }

    private func generateArtifact(year: Int, civs: [Civilization]) async {
        guard let civ = civs.randomElement() else { return }

        let artifactName = ArtifactNameGenerator.generate()
        history.artifacts.append(artifactName)

        let creatorName = NameGenerator.generate()
        var creator = HistoricalFigure(
            id: nextFigureId,
            name: creatorName,
            birthYear: year - Int.random(in: 30...60),
            civilizationId: civ.id
        )
        creator.title = ["Master", "Artisan", "Sage", "Wizard", "Smith"].randomElement()!
        creator.notableDeeds.append("created \(artifactName)")
        nextFigureId += 1
        history.figures[creator.id] = creator

        emitProgress("Year \(year): \(creator.title!) \(creatorName.firstName) created \(artifactName)")
        addEvent(year: year, type: .artifactCreated,
                description: "\(artifactName) was created by \(creator.title!) \(creatorName.firstName) of \(civ.name)",
                involvedFigures: [creator.id], involvedCivs: [civ.id])
        await delay()
    }

    private func generateExpansion(year: Int, civs: [Civilization]) async {
        guard let civ = civs.randomElement() else { return }

        // Find unclaimed region or create new one
        let claimedRegions = Set(civs.flatMap { $0.territories })
        let unclaimedRegions = history.regions.filter { !claimedRegions.contains($0) }

        let region: String
        if let unclaimed = unclaimedRegions.randomElement() {
            region = unclaimed
        } else {
            region = RegionNameGenerator.generate()
            history.regions.append(region)
        }

        history.civilizations[civ.id]?.territories.append(region)
        history.civilizations[civ.id]?.population += Int.random(in: 50...200)

        emitProgress("Year \(year): \(civ.name) expanded into the \(region)")
        addEvent(year: year, type: .civExpanded,
                description: "\(civ.name) claimed the \(region)",
                involvedCivs: [civ.id])
        await delay(short: true)
    }

    private func generateDisaster(year: Int, civs: [Civilization], type: HistoricalEventType) async {
        guard let civ = civs.randomElement() else { return }

        let disasterName = type == .plague
            ? ["The Red Death", "The Wasting Sickness", "The Grey Plague", "The Fever"].randomElement()!
            : ["The Great Famine", "The Withering", "The Hungry Years", "The Blight"].randomElement()!

        let casualties = Int.random(in: 10...50)
        let currentPopulation = history.civilizations[civ.id]?.population ?? 100
        history.civilizations[civ.id]?.population = max(10, currentPopulation - casualties)

        emitProgress("Year \(year): \(disasterName) struck \(civ.name)! (\(casualties) perished)")
        addEvent(year: year, type: type,
                description: "\(disasterName) struck \(civ.name), claiming many lives",
                involvedCivs: [civ.id])
        await delay()
    }

    private func generateNotableBirth(year: Int, civs: [Civilization]) async {
        guard let civ = civs.randomElement() else { return }

        let name = NameGenerator.generate()
        let figure = HistoricalFigure(
            id: nextFigureId,
            name: name,
            birthYear: year,
            civilizationId: civ.id
        )
        nextFigureId += 1
        history.figures[figure.id] = figure

        // Only announce some births
        if Int.random(in: 1...5) == 1 {
            emitProgress("Year \(year): \(name.firstName) was born in \(civ.name)")
            addEvent(year: year, type: .figureBorn,
                    description: "\(name.firstName) was born in \(civ.name)",
                    involvedFigures: [figure.id], involvedCivs: [civ.id])
        }
    }

    // MARK: - Helpers

    private func addEvent(
        year: Int,
        type: HistoricalEventType,
        description: String,
        involvedFigures: [UInt64] = [],
        involvedCivs: [UInt64] = []
    ) {
        let event = HistoricalEvent(
            id: nextEventId,
            year: year,
            eventType: type,
            description: description,
            involvedFigures: involvedFigures,
            involvedCivs: involvedCivs
        )
        nextEventId += 1
        history.events.append(event)
    }

    private func emitProgress(_ message: String) {
        onProgress?(currentPhase, message, history)
    }

    private func delay(short: Bool = false) async {
        let interval = short ? 0.5 / generationSpeed : 1.0 / generationSpeed
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }
}
