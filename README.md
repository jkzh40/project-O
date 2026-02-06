# Outpost

A Dwarf Fortress-inspired colony simulation where autonomous orcs build, fight, socialize, and survive — rendered via SpriteKit (macOS/iOS) or terminal (CLI).

## Project Structure

```
project-O/
├── OCore/          # Game engine & simulation library (Swift Package)
│   ├── Sources/
│   │   └── OCore/          # Core library
│   │       ├── Core/       # Data model (Unit, World, Tile, Item, Enums)
│   │       ├── Systems/    # Simulation systems (Combat, Jobs, Mood, Social, etc.)
│   │       ├── WorldGen/   # Procedural world & history generation
│   │       │   └── Terrain/  # 7-stage terrain pipeline
│   │       ├── Config/     # YAML configuration loading
│   │       └── Resources/  # Default YAML configs
│   └── Tests/
├── OutpostSim/     # Terminal-based CLI runner (Swift Package)
│   └── Sources/
│       └── OutpostSim/
├── Outpost/        # macOS/iOS SpriteKit app
│   ├── Outpost/
│   │   ├── SpriteKit/      # GameScene, TextureManager
│   │   ├── ViewModels/     # SimulationViewModel (bridges OCore → UI)
│   │   ├── Views/          # SwiftUI views
│   │   ├── Models/         # Render DTOs (WorldSnapshot)
│   │   └── Scripts/        # Asset generation
│   └── Outpost.xcodeproj/
└── docs/           # Design research & specifications
```

## Getting Started

### CLI (OutpostSim)

```bash
cd OutpostSim
swift build
swift run OutpostSim                    # Default: 50x20 world, 8 orcs
swift run OutpostSim --worldgen         # Full world generation with history
swift run OutpostSim -T -t 5000         # Turbo mode, stop at 5000 ticks
swift run OutpostSim --headless -t 50000  # Benchmark (no rendering)
```

See [OCore/README.md](OCore/README.md) for full CLI reference and system documentation.

### SpriteKit App (Outpost)

```bash
# Generate pixel art assets
swift Outpost/Scripts/GenerateAssets.swift

# Build
xcodebuild -scheme Outpost -destination 'platform=macOS' build
```

Or open `Outpost/Outpost.xcodeproj` in Xcode and run.

## Simulation Systems

| System | Description |
|--------|-------------|
| **Units** | Orcs with needs (hunger, thirst, sleep), personalities (30+ traits), and skills |
| **Combat** | Hit/crit/damage resolution, hostile spawns (goblins, wolves, bears, giants, undead) |
| **Jobs** | Autonomous work generation based on colony needs — mining, hunting, cooking, crafting |
| **Social** | Relationships, multi-turn conversations, marriages, births |
| **Mood** | Thoughts, stress accumulation, mental breaks (tantrum, berserk, catatonic) |
| **Construction** | 11 workshop types, quality tiers, recipe-based production |
| **Stockpiles** | Storage zones with configurable filters, auto-hauling |
| **World Gen** | 7-stage terrain pipeline (tectonics → erosion → climate → biomes) + civilization history |

## Tech Stack

- **Language:** Swift 6.2 (strict concurrency)
- **Platforms:** macOS 13+, iOS 17+
- **Rendering:** SpriteKit (app), ANSI terminal (CLI)
- **Dependencies:** [Yams](https://github.com/jpsim/Yams) (YAML, OCore), [swift-argument-parser](https://github.com/apple/swift-argument-parser) (CLI, OutpostSim)
