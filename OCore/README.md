# OCore

An Orc Outpost simulation engine written in Swift. Watch autonomous orcs live their tiny lives with emergent behavior driven by needs, personalities, and social dynamics.

## Quick Start

```bash
# Build
swift build

# Run with defaults (50x20 world, 8 orcs)
swift run OutpostSim

# Run with world generation (creates history and lore)
swift run OutpostSim --worldgen

# Show current configuration
swift run OutpostSim --show-config
```

## CLI Options

### Simulation Options
| Flag | Description | Default |
|------|-------------|---------|
| `-w, --width <n>` | World width (20-100) | 50 |
| `-h, --height <n>` | World height (10-50) | 20 |
| `-u, --units <n>` | Starting orcs (1-20) | 8 |
| `-s, --speed <n>` | Ticks per second (0.1-10000, or "max"/"turbo") | 5.0 |

### Speed/Testing Options
| Flag | Description |
|------|-------------|
| `-T, --turbo` | Maximum speed mode (no delays) |
| `-r, --render-every <n>` | Only render every N ticks |
| `-t, --max-ticks <n>` | Stop after N ticks |
| `--headless` | No rendering (for benchmarks) |
| `--hard` | Hard mode: minimal starting resources |

### World Generation Options
| Flag | Description | Default |
|------|-------------|---------|
| `-g, --worldgen` | Enable world generation with history | off |
| `-y, --years <n>` | Years of history to simulate (50-1000) | 250 |
| `--gen-speed <n>` | Generation display speed (1-100) | 15 |

### Configuration
| Flag | Description |
|------|-------------|
| `--show-config` | Show config paths and loaded values |
| `--help` | Show help message |

### Examples
```bash
# Quick start with defaults
swift run OutpostSim

# Generate world history first
swift run OutpostSim --worldgen

# Turbo mode, stop at 5000 ticks
swift run OutpostSim -T -t 5000

# Max speed, render every 500 ticks, stop at 10k
swift run OutpostSim -s max -r 500 -t 10000

# Benchmark 50k ticks with no display
swift run OutpostSim --headless -t 50000

# 100 ticks/sec with 12 orcs
swift run OutpostSim -s 100 -u 12
```

---

## Major Systems Catalog

### 1. Simulation Engine (`Simulation.swift`)

**Purpose:** Core orchestrator that manages the game loop and coordinates all subsystems.

**Key Class:** `Simulation`
- `@MainActor` annotated for thread safety
- Manages tick-by-tick processing
- Coordinates: Jobs, Combat, Mood, Social, Construction, Crafting, Stockpiles

**How to Test:**
```bash
# Basic simulation test (runs 100 ticks)
swift run OutpostSim -t 100

# Stress test with max speed
swift run OutpostSim --headless -t 10000

# Longer test with rendering
swift run OutpostSim -T -r 100 -t 5000
```

**What to Verify:**
- Orcs spawn and move around
- Needs (hunger/thirst/sleep) increase over time
- Units transition between states (idle → moving → eating → sleeping)

---

### 2. Unit System (`Unit.swift`)

**Purpose:** Represents individual units (orcs, creatures) with personality, skills, and needs.

**Key Struct:** `Unit`
- Identity: ID, name, position
- State: idle, moving, eating, drinking, sleeping, working, fighting, fleeing, socializing
- Needs: hunger, thirst, drowsiness (0-100 scale)
- Personality: 30+ traits (bravery, gregariousness, cheerfulness, etc.)
- Skills: Mining, woodcutting, combat, cooking, brewing, etc.

**How to Test:**
```bash
# Watch units for ~500 ticks to see need cycles
swift run OutpostSim -t 500

# Test with more units
swift run OutpostSim -u 15 -t 300
```

**What to Verify:**
- Unit status panel shows changing needs
- Orcs seek food/drink when hungry/thirsty (hunger > 60)
- Orcs sleep when drowsy (drowsiness > 70)
- Different personality displays in behavior

---

### 3. Combat System (`Combat.swift`)

**Purpose:** Handles fighting mechanics, damage calculation, and combat resolution.

**Key Components:**
- `Health`: HP tracking, wounds, death
- `DamageType`: blunt, slash, pierce, bite, fire, cold
- `CombatManager`: Attack resolution

**Mechanics:**
- Hit chance = 60% + (skill × 2) - (target agility / 50)
- Critical hit = 5% + skill level
- Damage = 5 + (strength / 100) + skill bonuses ± 20% variance

**How to Test:**
```bash
# Run long enough for hostile spawns (default: every 500 ticks, 50% chance)
swift run OutpostSim -t 2000

# Increase hostile spawn rate via config file
# Or wait and watch for combat events in the log
```

**What to Verify:**
- Hostiles spawn (goblins, wolves, etc.)
- Orcs engage in combat (red "fight" state)
- Combat log shows attacks, damage, deaths
- Wounded orcs flee when low HP

---

### 4. World System (`World.swift`, `WorldGenerator.swift`)

**Purpose:** Manages 3D tile grid with terrain, units, items, and pathfinding.

**Key Features:**
- Tile types: grass, stone, water, trees, walls, floors, stairs
- A* pathfinding with z-level support
- Terrain modification (mining, carving)

**World Generation (5 phases):**
1. Creation → 2. Terrain → 3. Regions → 4. Civilizations → 5. History

**How to Test:**
```bash
# Basic world (no history)
swift run OutpostSim -w 60 -h 25 -t 100

# Full world generation with history
swift run OutpostSim --worldgen -y 250

# Quick world gen
swift run OutpostSim --worldgen -y 50 --gen-speed 50
```

**What to Verify:**
- Map renders with varied terrain (grass, trees, water, stone)
- Units pathfind around obstacles
- World gen shows civilizations, heroes, events
- Generated history appears in summary

---

### 5. Social System (`Social.swift`)

**Purpose:** Manages relationships, conversations, and social interactions.

**Key Types:**
- `RelationshipType`: stranger → friend → close friend → lover → spouse
- `Relationship`: tracks strength (-100 to +100)
- 13 conversation topics with personality weighting

**How to Test:**
```bash
# Run long enough for social interactions
swift run OutpostSim -t 3000

# More orcs = more social activity
swift run OutpostSim -u 12 -t 2000
```

**What to Verify:**
- Orcs enter "social" state (magenta)
- Event log shows "seeking friend", conversations
- Marriages occur over time
- Births happen after marriages (every 5000 ticks, 5% chance)

---

### 6. Mood System (`Mood.swift`)

**Purpose:** Tracks emotional state, thoughts, stress, and mental breaks.

**Key Components:**
- `Thought`: mood modifier with expiration
- `ThoughtType`: 20+ types (ate good food +10, friend died -50, etc.)
- `MentalBreakType`: tantrum, berserk, catatonic, wandering

**Mental Break Thresholds:**
- Stress 70%: Minor break chance
- Stress 80%: Tantrum
- Stress 90%: Catatonic
- Stress 95%: Berserk

**How to Test:**
```bash
# Hard mode creates more stress conditions
swift run OutpostSim --hard -t 3000

# Long run to see mood changes
swift run OutpostSim -t 5000
```

**What to Verify:**
- Mood indicator in unit status (☺ bar)
- High stress from lack of needs met
- Mental breaks trigger under extreme stress
- Positive thoughts from eating, socializing

---

### 7. Job System (`Job.swift`, `AutonomousWork.swift`)

**Purpose:** Manages work assignments and auto-generates jobs based on colony needs.

**Job Types:**
- mine, chopTree, haul, cook, brew, craft
- hunt, fish, harvest, build, demolish, clean

**Autonomous Generation:**
- Assesses colony needs (food/drink/materials per orc)
- Auto-creates: hunting, fishing, gathering, chopping, mining, cooking

**How to Test:**
```bash
# Watch job creation and completion
swift run OutpostSim -t 1000

# More units = more job activity
swift run OutpostSim -u 12 -t 1500
```

**What to Verify:**
- Orcs enter "working" state
- Job counter in header changes
- Resources appear (food, drink items)
- Autonomous jobs created based on needs

---

### 8. Construction & Crafting (`Construction.swift`, `Crafting.swift`)

**Purpose:** Workshop management and item production.

**Workshop Types:**
- carpenter, mason, forge, kitchen, brewery
- craftsorc, jeweler, clothier, tannery, butcher, smelter

**Quality Levels:**
- Standard (1.0x), Fine (1.1x), Superior (1.3x), Excellent (1.5x)

**How to Test:**
```bash
# Long run to see crafting cycles
swift run OutpostSim -t 2000

# Check items via --show-config
swift run OutpostSim --show-config
```

**What to Verify:**
- Food and drink items appear on map
- Item count increases over time
- Different item types created

---

### 9. Stockpile System (`Stockpile.swift`)

**Purpose:** Storage zone management and item hauling.

**Features:**
- Configurable acceptance filters
- Presets: all, food only, drinks only, furniture, materials
- Auto-generates haul tasks for loose items

**How to Test:**
```bash
# Items should be organized
swift run OutpostSim -t 1000
```

**What to Verify:**
- Items (!) appear on map
- Orcs haul items (moving state toward items)

---

### 10. Configuration System (`Configuration.swift`, `ConfigurationLoader.swift`)

**Purpose:** YAML-based configuration for simulation parameters.

**Config Files:**
- `outpost.yaml` - simulation settings, events
- `creatures.yaml` - creature definitions
- `items.yaml` - item definitions

**Search Order:**
1. `./outpost.yaml`
2. `~/.config/outpost/outpost.yaml`
3. Bundled defaults

**How to Test:**
```bash
# Show loaded configuration
swift run OutpostSim --show-config

# Create custom config
cp Sources/OCore/Resources/outpost.yaml ./outpost.yaml
# Edit values, then run
swift run OutpostSim --show-config
```

**What to Verify:**
- `--show-config` displays all values
- Custom config overrides defaults
- Invalid values are clamped to valid ranges

---

### 11. History System (`History.swift`)

**Purpose:** Generates historical figures, civilizations, and events for world narrative.

**Generated Content:**
- 3-6 civilizations over 250 years
- Leaders, heroes, villains
- Wars, alliances, disasters
- Artifacts and legendary deeds

**How to Test:**
```bash
# Full world generation
swift run OutpostSim --worldgen -y 250

# Quick history
swift run OutpostSim --worldgen -y 100 --gen-speed 30
```

**What to Verify:**
- Multiple civilizations founded
- Historical figures born and die
- Events recorded (wars, plagues, discoveries)
- Summary shows world history statistics

---

### 12. Rendering System (`Renderer.swift`, `WorldGenRenderer.swift`)

**Purpose:** Terminal-based visualization using ANSI codes.

**Display Elements:**
- Header: tick count, population, kills/deaths
- Map: terrain + units + items
- Unit status panel with need bars
- Event log (8 most recent)
- Legend

**Symbols:**
| Symbol | Meaning |
|--------|---------|
| `@` | Orc |
| `g` | Goblin |
| `w` | Wolf |
| `!` | Item |
| `.` | Grass |
| `T` | Tree |
| `~` | Water |
| `_` | Stone |
| `#` | Wall |

**State Colors:**
- White: idle
- Cyan: moving
- Green: eating/drinking
- Blue: sleeping
- Magenta: socializing
- Red: fighting
- Yellow: fleeing

**How to Test:**
```bash
# Watch rendering at different speeds
swift run OutpostSim -s 2
swift run OutpostSim -s 20
swift run OutpostSim -T -r 50 -t 500
```

---

## Configuration Reference

### outpost.yaml
```yaml
simulation:
  world:
    width: 50
    height: 20
  units:
    initial_count: 8
    max_population: 50
  resources:
    food_count: 15
    drink_count: 15
    bed_count: 5
  speed:
    ticks_per_second: 5.0
  difficulty:
    hard_mode: false

events:
  hostile_spawn:
    interval_ticks: 500
    chance_percent: 50
  migrant_wave:
    interval_ticks: 10000
  birth_check:
    interval_ticks: 5000
    chance_percent: 5

hostile_spawn_pool:
  - goblin
  - wolf
```

### creatures.yaml
```yaml
creatures:
  goblin:
    display_char: "g"
    base_hp: 60
    base_damage: 8
    hostile_to_orcs: true
    weapon: "crude sword"
    damage_type: "slash"
    loot_on_death:
      - item: "goblin_ear"
        quantity_min: 1
        quantity_max: 2
```

### items.yaml
```yaml
items:
  food:
    category: "consumable"
    base_value: 5
    stackable: true
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Simulation                                │
│  (Main loop - coordinates all systems each tick)                │
└─────────────────────────────────────────────────────────────────┘
        │
        ├──► World (3D tile grid, pathfinding, terrain)
        │
        ├──► Units (orcs, creatures with needs/personality)
        │       │
        │       ├──► MoodManager (thoughts, stress, breaks)
        │       ├──► SocialManager (relationships, conversations)
        │       └──► CombatManager (attacks, damage, death)
        │
        ├──► JobManager (work orders, task assignment)
        │       │
        │       └──► AutonomousWorkManager (auto-generate jobs)
        │
        ├──► StockpileManager (storage, hauling)
        │
        ├──► ConstructionManager (workshops, buildings)
        │       │
        │       └──► CraftingManager (recipes, production)
        │
        └──► Registries
                ├──► CreatureRegistry (creature definitions)
                └──► ItemRegistry (item definitions)

Configuration loaded from:
  ConfigurationLoader → OutpostConfig → Registries
```

---

## Testing Checklist

### Quick Smoke Test
```bash
swift build && swift run OutpostSim -t 100
```

### Full System Test
```bash
# 1. Config loading
swift run OutpostSim --show-config

# 2. Basic simulation
swift run OutpostSim -t 500

# 3. World generation
swift run OutpostSim --worldgen -y 100

# 4. Stress test
swift run OutpostSim --headless -t 50000

# 5. Hard mode
swift run OutpostSim --hard -t 1000
```

### Performance Benchmark
```bash
time swift run OutpostSim --headless -t 100000
```

---
