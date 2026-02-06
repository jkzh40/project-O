# TODO

> Items ordered by priority (bugs → core → features → polish) and tagged with complexity.
> Complexity: **Low** (< 1 day) · **Medium** (1–3 days) · **High** (3–7 days) · **Very High** (1–2 weeks)


## Bugs & Fixes

### 1. Fix WorldGen
**Complexity: Medium** · **Priority: Critical**

The world generation pipeline needs debugging. Investigate the 7-stage terrain pipeline (`WorldMapGenerator.swift` orchestrator) for issues with embark site selection, biome distribution, or heightmap quality. Verify that `LocalTerrainGenerator` correctly converts world-map regions into playable 3D tile grids. Run OutpostSim with world generation enabled (`--world-gen`) and compare output against expected biome/terrain distributions.

**Files:** `OCore/Sources/OCore/WorldGen/Terrain/WorldMapGenerator.swift`, `LocalTerrainGenerator.swift`, all pipeline stages

---

## Core Simulation

### 2. Needs-driven motivation system
**Complexity: High** · **Priority: High**

Units should autonomously decide to build/acquire things based on unmet needs. For example: "I'm tired and there's no bed → plan to build a bed → gather wood → craft at carpenter workshop." This requires a **goal planner** (GOAP or utility AI) that bridges the existing `NeedInstance` system to the `JobManager`. The `AutonomousWorkManager` handles colony-level resource jobs but there's no personal goal-planning for individual units.

**Approach:** Implement a utility-based AI where each unit evaluates available actions by scoring them against current needs, personality, and skills. Actions that satisfy critical needs score highest. Chain multi-step plans (e.g., need bed → need wood → chop tree → craft bed).

**Files:** New system in `OCore/Sources/OCore/Systems/`, integrates with `Unit.swift` (needs), `JobManager`, `ConstructionManager`, `CraftingManager`

### 3. Civilization-level progression ("tech tree")
**Complexity: Very High** · **Priority: High**

Certain buildings/workshops should unlock new capabilities. For example: building a forge enables metal tools, which enables better weapons, which enables fighting tougher invaders. This is a prerequisite for meaningful colony growth and the "colony building" item below.

**Approach:** Define a progression graph where nodes are milestones (buildings, population thresholds, resource stockpiles) and edges unlock new recipes, job types, building types, or events. The `ConstructionManager` already tracks workshops and buildings — extend it with an unlock/prerequisite system.

**Files:** New `ProgressionManager` in `OCore/Sources/OCore/Systems/`, extends `ConstructionManager`, `CraftingManager` (recipe unlocks), `StandardRecipes`

### 4. Colony building & overall objectives
**Complexity: Very High** · **Priority: High**

Define what "success" looks like for a colony. Combine the progression system (#3) with colony-wide goals: attract migrants, defend against raids, accumulate wealth, build specific structures. The `AutonomousWorkManager` already tracks colony needs — extend it with strategic goals and milestones that give the player (or AI) direction.

**Approach:** Implement a `ColonyManager` that tracks overall colony state (wealth tier already exists in OutpostSim stats), population milestones, defense readiness, and triggers events (migration waves, trade caravans, noble demands) based on progress.

**Files:** New `ColonyManager` in `OCore/Sources/OCore/Systems/`, integrates with `AutonomousWorkManager`, `ConstructionManager`

### 5. Inventory system & unit equipment
**Complexity: Medium** · **Priority: High**

Units currently interact with world items but don't carry anything. Implement per-unit inventory with equipment slots (weapon, armor, clothing) and a carried-items bag. Items in inventory should affect combat stats, movement speed, and mood. Random starting items for new units/migrants.

**Approach:** Add an `Inventory` struct to `Unit` with slot-based equipment + general bag (weight-limited using item weight/volume, which `Item` currently lacks). Integrate with `CombatManager` (weapon damage, armor reduction) and `MoodTracker` (nice clothes → happy thought).

**Files:** `Unit.swift`, `Item.swift` (add weight/volume), `Combat.swift`, `Mood.swift`

### 6. Health, wounding & body parts
**Complexity: High** · **Priority: Medium**

The current `Health` struct is HP-only. Implement a DF-inspired body part system: head, torso, arms, legs, hands, feet — each with its own HP. Wounds affect capabilities (broken leg → slow movement, lost hand → can't craft). Healing over time, scarring, infection risk based on `diseaseResistance` attribute.

**Approach:** Replace or extend `Health` with a `Body` struct containing `BodyPart` entries. `CombatManager.resolveAttack()` targets specific parts. Wounds create status effects that modify unit capabilities. Recovery happens during sleep/rest ticks.

**Files:** `Combat.swift` (new `Body`/`BodyPart` types), `Unit.swift`, potentially new `MedicalSystem`

### 7. Invaders & hostile factions (humans, etc.)
**Complexity: High** · **Priority: Medium**

Add new hostile creature types (humans, raiders) that arrive in organized groups. Raid events should scale with colony wealth/population (ties into #4). Currently only 6 creature types exist with basic hostility flags. Needs raid scheduling, group AI (formation, retreat conditions), and loot mechanics.

**Approach:** Extend `CreatureType` with new factions. Add a `RaidManager` that schedules invasions based on colony progress, spawns groups at map edges, and gives them objectives (steal items, destroy buildings, kidnap units). Integrate with `CombatManager` and `History.swift` for event logging.

**Files:** `Enums.swift` (new creature types), new `RaidManager`, `Combat.swift`, `History.swift`

### 8. Seasonal dangers (temperature)
**Complexity: Medium** · **Priority: Medium**

Climate data exists from `ClimateSimulator` but doesn't affect gameplay at runtime. Extreme cold/heat should drain health, increase need rates, require shelter/clothing. Winter should slow movement, freeze water tiles, reduce food availability. Summer heat should increase thirst rate.

**Approach:** Add a `TemperatureSystem` that reads the current season + biome climate data and applies modifiers to unit need rates, movement costs, and tile passability. Integrate with `MoodTracker` (cold/hot thoughts) and the wounding system (#6) for frostbite/heatstroke.

**Files:** New system in `OCore/Sources/OCore/Systems/`, integrates with `ClimateSimulator` output, `Unit.swift` (need rates), `Tile.swift` (passability)

### 9. Persistent world state (save/load)
**Complexity: High** · **Priority: Medium**

No save/load system exists. The entire simulation state (`World`, all `Unit`s, `Item`s, job queues, relationships, memories, buildings, stockpiles) needs serialization. Use `Codable` throughout — most types are already structs.

**Approach:** Make all core types conform to `Codable`. Create a `SaveManager` that serializes the full `Simulation` state to JSON or a binary format. Support auto-save at configurable intervals. Load restores full state including RNG position for determinism.

**Files:** All model/system files (add `Codable` conformance), new `SaveManager`

### 10. Social structure & hierarchy
**Complexity: Medium** · **Priority: Medium**

No leadership, roles, or social hierarchy exists beyond relationship strength. Implement ranks (leader, elder, warrior, worker), role assignment based on skills/personality, and social effects (leader's mood affects colony morale, disputes over rank).

**Approach:** Add a `Role` enum and assignment logic. Leader election based on social standing (relationship strengths + skills + personality). Roles affect job priority, mood modifiers, and social interaction outcomes. Ties into civilization progression (#3).

**Files:** `Unit.swift` (role field), new `HierarchyManager`, integrates with `SocialManager`, `MoodTracker`

---

## World & Environment

### 11. Weather system
**Complexity: High** · **Priority: Medium**

No runtime weather exists beyond seasonal particles. Implement rain, snow, fog, storms, drought as discrete weather events that affect gameplay (rain fills water, snow slows movement, storms damage buildings, fog reduces vision). Weather should be driven by biome + season + randomness.

**Approach:** Add a `WeatherManager` that generates weather events based on `ClimateSimulator` data and season. Weather modifies tile properties temporarily, affects unit mood, and triggers visual effects in GameScene. Severe weather (storms, blizzards) can cause damage.

**Files:** New `WeatherManager` in `OCore/Sources/OCore/Systems/`, GameScene (weather rendering), `ClimateSimulator` (weather probabilities per biome/season)

### 12. Ecology & biology (vegetation growth, animal behavior)
**Complexity: Very High** · **Priority: Medium**

Terrain is currently static post-generation. Implement plant growth/death cycles (seasonal), animal migration patterns, predator-prey dynamics, and natural resource regeneration. Trees should regrow, berries should ripen seasonally, animals should breed and form herds.

**Approach:** Add a `EcologyManager` with tick-based updates: plant growth stages, seasonal die-back, animal population dynamics (birth rate, carrying capacity per biome), resource respawn timers. Animals get basic AI (graze, flee, hunt) using the existing pathfinding + combat systems.

**Files:** New `EcologyManager`, extends `Tile.swift` (growth stage), `World.swift` (resource regeneration), creature AI behaviors

### 13. Natural disasters
**Complexity: Medium** · **Priority: Low**

Earthquakes, floods, wildfires, volcanic eruptions (near tectonic boundaries). These are dramatic events that test colony resilience. Should be rare, biome-appropriate, and tie into the tectonic/climate data from world gen.

**Approach:** Add a `DisasterManager` that rolls for events based on biome, season, and tectonic data. Each disaster type modifies terrain (fire burns trees, flood fills tiles, earthquake collapses caves), damages buildings, and injures units. Creates memorable historical events.

**Files:** New `DisasterManager`, integrates with `World.swift`, `ConstructionManager`, `History.swift`

### 14. Caves & underground
**Complexity: High** · **Priority: Low**

The 3D tile grid and multi-z pathfinding already exist, but caves aren't generated. Implement cave systems during world gen (or local terrain gen) with ore veins, underground water, cave creatures, and exploration mechanics.

**Approach:** Extend `LocalTerrainGenerator` with cave carving algorithms (cellular automata or drunkard's walk). Place ore deposits, underground lakes, and hostile creatures. Mining operations (`mineTile()` already works) expose cave systems. Requires z-level rendering improvements in GameScene.

**Files:** `LocalTerrainGenerator.swift`, `DetailPass.swift` (ore placement in caves), GameScene (z-level rendering)

---

## Unit Systems

### 15. Age, maturity & lifecycle
**Complexity: Medium** · **Priority: Medium**

No birth dates, aging, or generational mechanics exist. Units should have age, grow from child to adult (affects capabilities), age into elderly (reduced physical stats), and eventually die of old age. Children born from relationships.

**Approach:** Add `birthTick` to `Unit`, calculate age from `WorldCalendar`. Define life stages (child, adolescent, adult, elder) with attribute modifiers. Children can't work dangerous jobs, elders have wisdom bonuses but physical penalties. Reproduction requires spouse relationship + housing.

**Files:** `Unit.swift`, `Models.swift` (life stages), new `PopulationManager`

### 16. Education & training model
**Complexity: Medium** · **Priority: Low**

Units should be able to learn from each other and through dedicated training. Apprenticeship (work alongside skilled unit → faster XP), classroom learning (if library/school building exists), and mentorship relationships.

**Approach:** Extend the skill XP system with learning modifiers: working near a master grants bonus XP, dedicated training jobs at appropriate buildings (training grounds for combat, library for mental skills). Integrate with the progression system (#3) — advanced buildings unlock advanced training.

**Files:** `Unit.swift` (skill XP modifiers), `JobManager` (training job type), `ConstructionManager` (training buildings)

### 17. Unit memory — persistent across sessions
**Complexity: Low** · **Priority: Medium**

The `MemoryStore` is comprehensive (episodic, semantic, emotional) but exists only in-memory. Memories should survive save/load (#9). This is largely solved by making `MemoryStore` and its contents `Codable`.

**Approach:** Ensure `EpisodicMemory`, `SemanticMemory`, `EmotionalAssociation`, and `MemoryStore` all conform to `Codable`. Include in the save/load system. Consider memory persistence across generations (elders pass down semantic memories to children).

**Files:** `Memory.swift` (add `Codable`), ties into #9

### 18. Migration & population growth
**Complexity: Medium** · **Priority: Medium**

Colony attractiveness should drive migration. More wealth, better defenses, higher happiness → more migrants arrive. Migrants should bring random skills, items, and personalities. Population should also grow through births (#15).

**Approach:** Add a `MigrationManager` that evaluates colony attractiveness each season (wealth, population, happiness average, military strength, available housing). Spawn migrants at map edges with randomized stats. Scale migrant quality with colony tier. Ties into #4 (colony building).

**Files:** New `MigrationManager`, integrates with `ColonyManager` (#4), `Unit.swift` (random generation)

---

## Infrastructure & Technical

### 19. Universal logging system
**Complexity: Low** · **Priority: High**

No structured logging exists. Add a unified logging system using `os.Logger` (or Swift `Logger`) with categories (simulation, combat, worldgen, social, jobs, AI) and configurable verbosity levels. Essential for debugging complex simulation behavior.

**Approach:** Create a `GameLogger` with category-based loggers. Replace ad-hoc print statements. Support log levels (debug, info, warning, error). In OutpostSim, optionally write logs to file for post-run analysis.

**Files:** New `GameLogger` in `OCore/Sources/OCore/Core/`, update all systems to use it

### 20. Code cleanup & organization
**Complexity: Medium** · **Priority: High**

Review and refactor across the codebase. Key areas: ensure the skill `rust` counter is actually integrated into skill checks (it's tracked but unused), verify personality facets modulate mood updates (shallow integration currently), clean up unused imports, and ensure consistent error handling patterns.

**Files:** All system files — audit for dead code, unused fields, incomplete integrations

### 21. Refactor rendering & main run loop
**Complexity: Medium** · **Priority: Medium**

GameScene is large and handles many concerns (animations, particles, camera, UI overlays). Extract subsystems into dedicated managers (e.g., `ParticleManager`, `AnimationManager`, `CameraController`). The simulation tick loop in `SimulationViewModel` could benefit from a more explicit pipeline pattern.

**Files:** `GameScene.swift`, `SimulationViewModel.swift`

### 22. Configuration consolidation
**Complexity: Medium** · **Priority: Medium**

Multiple items overlap: terrain type config, plant type config, entity config, SpriteKit image config. Currently creature/item stats are hardcoded in registries with YAML stubs. Consolidate into a single configuration pipeline: YAML defines all entity types, terrain properties, plant growth rules, and texture mappings. Consider whether a database backend makes more sense long-term.

**Approach:** Expand `ConfigurationLoader` to parse creature definitions, terrain properties, plant types, and texture mappings from YAML. Registries (`CreatureRegistry`, `ItemRegistry`) should load from config rather than hardcoding defaults. Add a texture mapping config that GameScene's `TextureManager` reads.

**Files:** `ConfigurationLoader.swift`, `CreatureRegistry.swift`, `ItemRegistry.swift`, `TextureManager.swift`, YAML resource files

### 23. Expose API surface for external interactions
**Complexity: Medium** · **Priority: Low**

Allow external tools (editors, mods, debug UIs) to interact with the simulation. Define a public API on `Simulation` for querying state, issuing commands (designate area, assign jobs, control units), and subscribing to events.

**Files:** `Simulation` public interface, possibly a new `SimulationAPI` facade

### 24. Background simulation updating
**Complexity: Low** · **Priority: Low**

Ensure the simulation can tick in the background when the app is not in the foreground (macOS) or handle suspension gracefully (iOS). The current `@MainActor` architecture may need a dedicated simulation actor for background processing.

**Files:** `SimulationViewModel.swift`, potentially extract simulation tick loop to a dedicated actor

---

## Long-term / Ambitious

### 25. LLM integration
**Complexity: Very High** · **Priority: Low**

Use an LLM to drive unit behavior at reduced tick rates (e.g., every 100 ticks). Units could "think" via LLM about their situation, relationships, and goals — producing richer dialogue, creative problem-solving, and emergent narrative. The existing memory system (episodic, semantic, emotional) provides excellent context for LLM prompts.

**Approach:** At configurable intervals, serialize a unit's state (needs, memories, relationships, surroundings) into a prompt. LLM responds with an action plan or dialogue. Parse the response into game actions. Rate-limit to control cost/latency. Consider local models (llama.cpp) for offline play.

**Files:** New `LLMManager` in `OCore/Sources/OCore/Systems/`, integrates with `Memory.swift`, `SocialManager`, `Unit.swift`

### 26. Simulate agentic/prompt engineering
**Complexity: Very High** · **Priority: Low**

Meta-feature: treat unit AI as an "agentic" system where personality, memories, and goals form a "system prompt" and environmental observations form "user messages." This is a design philosophy for how the AI decision-making works — could be implemented with or without actual LLMs using structured decision trees that mirror prompt engineering patterns.

**Files:** Design document first, then implementation in AI/decision systems

### 27. Time-based decay
**Complexity: Low** · **Priority: Low**

Items should degrade over time. Food spoils, tools wear out, buildings need maintenance. Adds resource pressure and recurring crafting demand. Simple to implement: add a `durability` or `freshness` field to `Item`, decrement per tick, remove/downgrade when depleted.

**Files:** `Item.swift` (add decay field), tick update logic in `Simulation`

### 28. Multiplayer
**Complexity: Very High** · **Priority: Low**

Networked multiplayer for shared world simulation. Extremely complex — requires deterministic lockstep or client-server architecture, conflict resolution, and significant networking infrastructure. Consider as a very long-term goal after single-player is polished.

**Files:** Architectural redesign required

### 29. World gen integration with runtime
**Complexity: Medium** · **Priority: Low**

The world map (macro scale) and local terrain (micro scale) are loosely connected. Tighten integration so that world-map features (rivers, trade routes, neighboring civilizations) directly affect the local simulation — e.g., river on world map → water source on local map, neighboring hostile civ → increased raid frequency.

**Files:** `WorldMapGenerator.swift`, `LocalTerrainGenerator.swift`, `RaidManager` (#7), colony event triggers
