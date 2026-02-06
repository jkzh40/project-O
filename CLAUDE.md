# CLAUDE.md

## Build & Test

```bash
# OCore (Swift Package)
cd OCore && swift build
swift test                              # Unit tests
swift run OutpostSim -t 100             # Smoke test (100 ticks)

# Outpost (Xcode)
xcodebuild -scheme Outpost -destination 'platform=macOS' build

# Asset generation
swift Outpost/Scripts/GenerateAssets.swift
```

## Project Layout

- **OCore/** — Game engine library + CLI runner (Swift Package)
  - `Sources/OCore/Core/` — Data model: `Unit`, `World`, `Tile`, `Item`, `Enums`
  - `Sources/OCore/Systems/` — Simulation systems: Combat, Job, Mood, Social, Construction, Crafting, Stockpile, AutonomousWork, Memory
  - `Sources/OCore/WorldGen/` — World generation + history (`WorldGenerator.swift`, `History.swift`)
  - `Sources/OCore/WorldGen/Terrain/` — 7-stage procedural terrain pipeline (13 files)
  - `Sources/OCore/Config/` — YAML config loading (`ConfigurationLoader`, registries)
  - `Sources/OCore/Resources/` — Default YAML configs (`outpost.yaml`, `creatures.yaml`, `items.yaml`)
  - `Sources/OutpostSim/` — Terminal CLI app
- **Outpost/** — macOS/iOS SpriteKit app (Xcode project)
  - `Outpost/SpriteKit/` — `GameScene` (rendering), `TextureManager` (sprite loading)
  - `Outpost/ViewModels/` — `SimulationViewModel` (bridges OCore → SwiftUI)
  - `Outpost/Views/` — SwiftUI views including `UnitDetailPanel`
  - `Outpost/Models/` — `WorldSnapshot` DTOs for render layer
  - `Scripts/` — `GenerateAssets.swift` (pixel art generator)
- **docs/** — Design research and specifications

## Architecture

- `Simulation` is the core orchestrator (`@MainActor`), processes each tick sequentially through all systems
- OCore is a pure Swift library with no UI dependencies — consumed by both OutpostSim (terminal) and Outpost (SpriteKit)
- Configuration is YAML-based, loaded at startup with fallback chain: `./outpost.yaml` → `~/.config/outpost/` → bundled defaults
- World generation is a 7-stage pipeline: Tectonics → Heightmap → Erosion → Climate → Hydrology → Biomes → Detail
- All randomness flows through `SeededRNG` (Xoshiro256**) for deterministic replay from a `WorldSeed`

## Conventions

- Swift 6.2, strict concurrency — `@MainActor` on simulation + rendering, `Sendable` conformance required
- Asset names: `category_name` (e.g., `creature_orc_walk_0`)
- GameScene z-layers: tile(0), ambient(1), item(2), shadow(9), unit(10), health(15), selection(20), speech(30), effects(40), overlay(500)
- Animation frames per creature: walk(4), attack(3), idle(2), death(3)
- Enums use lowercase camelCase cases
- Configuration structs mirror YAML structure
- Creature types: `.orc`, `.goblin`, `.wolf`, `.bear`, `.giant`, `.undead`
- Unit states: `.idle`, `.moving`, `.sleeping`, `.eating`, `.drinking`, `.working`, `.fighting`, `.fleeing`, `.socializing`, `.unconscious`, `.dead`
