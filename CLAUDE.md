# CLAUDE

## Project Layout

- **OutpostKit/** — Game engine library (Swift Package, 3 targets)
  - `Sources/OutpostCore/` — Shared types, models, config (Layer 1 — depends on Yams only)
    - `Core/` — Data model: `Unit`, `World`, `Item`, `Enums`, `Models`
    - `Types/` — Shared types: `BiomeType`, `TerrainType`, `Tile`, `UnitName`/`NameGenerator`
    - `DataTypes/` — Data types for systems: Health, Job, Memory, Mood, Social, Construction, Crafting, Stockpile, Work, Simulation
    - `Config/` — YAML config loading (`ConfigurationLoader`, registries)
    - `Resources/` — Default YAML configs (`outpost.yaml`, `creatures.yaml`, `items.yaml`)
  - `Sources/OutpostWorldGen/` — World generation module (Layer 2 — depends on OutpostCore)
    - `Terrain/` — 7-stage procedural terrain pipeline (13 files)
    - `WorldGenerator.swift` — World generator with history simulation
    - `History.swift` — Historical events, figures, civilizations
  - `Sources/OutpostRuntime/` — Simulation engine and manager systems (Layer 3 — depends on OutpostCore + OutpostWorldGen)
    - `Simulation.swift` — Core simulation orchestrator
    - `Systems/` — Manager classes: Combat, Job, Mood, Social, Construction, Crafting, Stockpile, AutonomousWork
  - `Tests/` — Unit tests
- **OutpostSim/** — Terminal CLI app (Swift Package, depends on OutpostRuntime)
  - `Sources/OutpostSim/` — CLI runner, ANSI renderers
- **Outpost/** — macOS/iOS SpriteKit app (Xcode project, depends on OutpostRuntime)
  - `Outpost/SpriteKit/` — `GameScene` (rendering), `TextureManager` (sprite loading)
  - `Outpost/ViewModels/` — `SimulationViewModel` (bridges OutpostRuntime → SwiftUI)
  - `Outpost/Views/` — SwiftUI views including `UnitDetailPanel`
  - `Outpost/Models/` — `WorldSnapshot` DTOs for render layer
  - `Scripts/` — `GenerateAssets.swift` (pixel art generator)
- **docs/** — Design research and specifications

## Architecture

OutpostKit uses a 4-layer dependency architecture:

```
Layer 4: UI (Outpost app, OutpostSim)  →  import OutpostRuntime
Layer 3: OutpostRuntime (Simulation + Managers)  →  depends on OutpostCore + OutpostWorldGen
Layer 2: OutpostWorldGen (world generation pipeline)  →  depends on OutpostCore
Layer 1: OutpostCore (shared types, models, config)  →  depends on Yams only
```

- `Simulation` is the core orchestrator (`@MainActor`), processes each tick sequentially through all systems
- OutpostCore contains pure data types (structs/enums) with no simulation logic
- OutpostRuntime contains manager classes and the simulation engine
- OutpostRuntime re-exports OutpostCore and OutpostWorldGen via `@_exported import`
- Consumers import only `OutpostRuntime` to get all types
- Configuration is YAML-based, loaded at startup with fallback chain: `./outpost.yaml` → `~/.config/outpost/` → bundled defaults
- World generation is a 7-stage pipeline: Tectonics → Heightmap → Erosion → Climate → Hydrology → Biomes → Detail
- All randomness flows through `SeededRNG` (Xoshiro256**) for deterministic replay from a `WorldSeed`

## Build & Test

```bash
cd OutpostKit && swift build                 # Build OutpostKit
cd OutpostKit && swift test                  # Unit tests
cd OutpostSim && swift build                 # Build OutpostSim
cd OutpostSim && swift run OutpostSim -t 100 # Smoke test (100 ticks)
xcodebuild -scheme Outpost -destination 'platform=macOS' build  # Build Outpost
swift Outpost/Scripts/GenerateAssets.swift    # Asset generation
```

For full E2E testing, run OutpostSim. Use turbo + headless mode for long-running tests. For interactive/short tests, enable terminal rendering with the fastest tick rate.

## Conventions

### Swift

- Swift 6.2, strict concurrency
- Use `async`/`await` and structured concurrency (`TaskGroup`, `async let`) over callbacks, Combine, or GCD
- Default to `@MainActor`. For CPU-bound work, create a dedicated actor
- All types crossing concurrency boundaries must conform to `Sendable`
- Prefer the Observation framework (`@Observable`) over `ObservableObject`/`@Published`
- Enums use lowercase camelCase cases
- Configuration structs mirror YAML structure

### Game Domain

- Creature types: `.orc`, `.goblin`, `.wolf`, `.bear`, `.giant`, `.undead`
- Unit states: `.idle`, `.moving`, `.sleeping`, `.eating`, `.drinking`, `.working`, `.fighting`, `.fleeing`, `.socializing`, `.unconscious`, `.dead`
- Asset names: `category_name` (e.g., `creature_orc_walk_0`)
- Animation frames per creature: walk(4), attack(3), idle(2), death(3)
- GameScene z-layers: tile(0), ambient(1), item(2), shadow(9), unit(10), health(15), selection(20), speech(30), effects(40), overlay(500)

## Workflow

- Use subagents to parallelize independent tasks whenever possible
- Before writing new code, examine the existing codebase for reusable components
- Create or update tests for every new feature and bug fix
- When new files are created, update this CLAUDE.md (Project Layout section)

## Complex Workflows

For complex features (e.g., tasks requiring plan mode or touching multiple subsystems):

1. Create a git worktree with a descriptive branch name
2. Implement the feature in the worktree
3. Run builds and tests to verify
4. Audit: ensure all code follows Swift best practices, all code is used (no dead code), and no unused imports or stubs remain
5. Run full E2E testing via OutpostSim
6. Commit the changes
7. Push the branch to the remote
8. Open a PR against `main` — if the work addresses a GitHub issue, reference it in the PR body (e.g., `Closes #123`) so it is automatically linked and closed on merge
