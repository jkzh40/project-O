# Dwarf Fortress Domain Research

## Overview

This document contains comprehensive research on Dwarf Fortress game mechanics, models, entities, world generation, logic, and behavior systems. This research serves as the foundation for building a Dwarf Fortress-inspired simulation game.

**Sources:**
- [Dwarf Fortress Wiki](https://dwarffortresswiki.org/)
- [DFHack df-structures Repository](https://github.com/DFHack/df-structures)
- [Stack Overflow - How Dwarf Fortress is Built](https://stackoverflow.blog/2021/12/31/700000-lines-of-code-20-years-and-one-developer-how-dwarf-fortress-is-built/)
- [Bay 12 Games Official Site](https://www.bay12games.com/dwarves/)

---

## Table of Contents

1. [Core Architecture](#1-core-architecture)
2. [World Generation](#2-world-generation)
3. [Unit/Creature System](#3-unitcreature-system)
4. [Attributes System](#4-attributes-system)
5. [Skills & Labor System](#5-skills--labor-system)
6. [Personality & Psychology System](#6-personality--psychology-system)
7. [Needs & Happiness System](#7-needs--happiness-system)
8. [Combat & Anatomy System](#8-combat--anatomy-system)
9. [Item & Material System](#9-item--material-system)
10. [Building & Construction System](#10-building--construction-system)
11. [Job & Task System](#11-job--task-system)
12. [Entity & Civilization System](#12-entity--civilization-system)
13. [Pathfinding System](#13-pathfinding-system)

---

## 1. Core Architecture

### High-Level System Diagram

```mermaid
flowchart TB
    subgraph GameCore["Game Core"]
        WorldGen["World Generation"]
        Simulation["Simulation Engine"]
        UI["User Interface"]
    end

    subgraph DataLayer["Data Layer"]
        Units["Units/Creatures"]
        Items["Items"]
        Buildings["Buildings"]
        Map["Map/Terrain"]
        History["History/Events"]
    end

    subgraph Systems["Game Systems"]
        JobSystem["Job System"]
        CombatSystem["Combat System"]
        NeedsSystem["Needs System"]
        PathfindingSystem["Pathfinding"]
        AISystem["AI/Behavior"]
    end

    WorldGen --> Map
    WorldGen --> History
    WorldGen --> Units

    Simulation --> Systems
    Systems --> DataLayer

    UI --> Simulation
    UI --> DataLayer
```

### Key Data Structures (from DFHack)

The game uses several core XML-defined structures:
- `df.unit.xml` - Unit/creature data
- `df.soul.xml` - Personality/soul data
- `df.item.xml` - Item definitions
- `df.job.xml` - Job system
- `df.building.xml` - Building structures
- `df.creature.xml` - Creature definitions
- `df.material.xml` - Material properties

---

## 2. World Generation

### Generation Pipeline

```mermaid
flowchart TD
    subgraph Phase1["Phase 1: Topography"]
        A1["Seed Basic Values"] --> A2["Fractal Elevation Fill"]
        A2 --> A3["Temperature Mapping"]
        A3 --> A4["Rainfall Distribution"]
        A4 --> A5["Drainage Calculation"]
    end

    subgraph Phase2["Phase 2: Geography"]
        B1["Place Mountain Peaks"] --> B2["Erosion Simulation"]
        B2 --> B3["River Generation"]
        B3 --> B4["Lake Formation"]
        B4 --> B5["Biome Assignment"]
    end

    subgraph Phase3["Phase 3: Geology"]
        C1["Rock Layer Placement"] --> C2["Mineral Distribution"]
        C2 --> C3["Gem Clusters"]
        C3 --> C4["Metal Veins"]
    end

    subgraph Phase4["Phase 4: History"]
        D1["Civilization Placement"] --> D2["Site Generation"]
        D2 --> D3["Population Simulation"]
        D3 --> D4["Event Simulation"]
        D4 --> D5["War/Politics"]
    end

    Phase1 --> Phase2
    Phase2 --> Phase3
    Phase3 --> Phase4
```

### World Generation Parameters

| Parameter | Options | Description |
|-----------|---------|-------------|
| World Size | 17×17 to 257×257 | Region tile dimensions |
| History Length | 5-1050 years | Simulated history duration |
| Civilizations | Very Low to Very High | Number of civilizations |
| Maximum Sites | Very Low to Very High | Town/hamlet count |
| Number of Beasts | Very Low to Very High | Megabeasts/titans |
| Natural Savagery | Low to High | Aggressive biome frequency |
| Mineral Occurrence | Sparse to Frequent | Resource density |

### Terrain Field Values

```mermaid
erDiagram
    TILE {
        int x
        int y
        int z
        int elevation
        int rainfall
        int temperature
        int drainage
        int volcanism
        int savagery
        int evil_good_alignment
        enum biome_type
    }

    BIOME {
        string name
        enum savagery_level
        enum alignment
        list flora
        list fauna
    }

    GEOLOGY_LAYER {
        int depth
        enum rock_type
        list minerals
        list gems
    }

    TILE ||--o{ BIOME : "has"
    TILE ||--o{ GEOLOGY_LAYER : "contains"
```

---

## 3. Unit/Creature System

### Unit Data Model

```mermaid
classDiagram
    class Unit {
        +int id
        +string name
        +Race race
        +Caste caste
        +Sex sex
        +Position position
        +Body body
        +Soul soul
        +Inventory inventory
        +UnitFlags flags
        +list~Job~ current_jobs
    }

    class Body {
        +list~BodyPart~ parts
        +list~Wound~ wounds
        +PhysicalAttributes physical_attrs
        +int blood_count
        +int blood_max
        +list~Syndrome~ syndromes
    }

    class Soul {
        +string name
        +MentalAttributes mental_attrs
        +list~Skill~ skills
        +list~Preference~ preferences
        +Personality personality
        +list~Need~ needs
        +list~Memory~ memories
    }

    class BodyPart {
        +string name
        +BodyPartCategory category
        +BodyPart parent
        +list~TissueLayer~ tissues
        +list~BodyPartFlags~ flags
        +int size
    }

    class TissueLayer {
        +TissueType type
        +int thickness
        +Material material
        +int pain_receptors
        +bool functional
    }

    Unit "1" *-- "1" Body
    Unit "1" *-- "1" Soul
    Body "1" *-- "*" BodyPart
    BodyPart "1" *-- "*" TissueLayer
```

### Unit Action System

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Moving: path_found
    Idle --> Working: job_assigned
    Idle --> Fighting: threat_detected
    Idle --> Sleeping: exhausted
    Idle --> Eating: hungry
    Idle --> Drinking: thirsty

    Moving --> Idle: destination_reached
    Moving --> Fighting: attacked

    Working --> Idle: job_complete
    Working --> Fighting: interrupted

    Fighting --> Idle: combat_ended
    Fighting --> Wounded: hit
    Fighting --> Dead: fatal_wound

    Wounded --> Idle: recovered
    Wounded --> Dead: bleed_out

    Sleeping --> Idle: rested
    Eating --> Idle: fed
    Drinking --> Idle: hydrated
```

---

## 4. Attributes System

### Physical Attributes

| Attribute | Median | Effects |
|-----------|--------|---------|
| **Strength** | 1250 | Melee damage, carry capacity, muscle mass, running speed |
| **Agility** | 900 | Fast gait speeds, dodge capability |
| **Toughness** | 1250 | Reduces all physical damage, bleeding, suffocation |
| **Endurance** | 1000 | Reduces exhaustion rate, increases pain tolerance |
| **Recuperation** | 1000 | Wound healing speed, fat reduction |
| **Disease Resistance** | 1000 | Syndrome resistance and effect mitigation |

### Mental Attributes

| Attribute | Median | Effects |
|-----------|--------|---------|
| **Analytical Ability** | 1250 | Learning speed for analytical skills |
| **Focus** | 1500 | Task concentration |
| **Willpower** | 1000 | Resistance to exhaustion |
| **Creativity** | 1250 | Artifact creation, artistic quality |
| **Intuition** | 1000 | Instinctive decisions |
| **Patience** | 1250 | Task persistence |
| **Memory** | 1250 | Skill retention |
| **Linguistic Ability** | 1000 | Language learning |
| **Spatial Sense** | 1000 | Navigation, construction |
| **Musicality** | 1000 | Musical performance |
| **Kinesthetic Sense** | 1000 | Physical coordination |
| **Empathy** | 1000 | Social understanding |
| **Social Awareness** | 1000 | Social skill learning |

### Attribute Value Ranges

```mermaid
gantt
    title Attribute Value Distribution (0-5000)
    dateFormat X
    axisFormat %s

    section Levels
    Very Low (0-199)    :a, 0, 200
    Low (200-449)       :b, 200, 450
    Below Avg (450-649) :c, 450, 650
    Average (650-1099)  :d, 650, 1100
    Above Avg (1100-1349) :e, 1100, 1350
    High (1350-1549)    :f, 1350, 1550
    Very High (1550-1999) :g, 1550, 2000
    Superior (2000-2999) :h, 2000, 3000
    Extreme (3000-5000) :i, 3000, 5000
```

---

## 5. Skills & Labor System

### Skill Progression

```mermaid
flowchart LR
    subgraph SkillLevels["Skill Levels (0-15+)"]
        L0["0: Not"] --> L1["1: Dabbling"]
        L1 --> L2["2: Novice"]
        L2 --> L3["3: Adequate"]
        L3 --> L4["4: Competent"]
        L4 --> L5["5: Skilled"]
        L5 --> L6["6: Proficient"]
        L6 --> L7["7: Talented"]
        L7 --> L8["8: Adept"]
        L8 --> L9["9: Expert"]
        L9 --> L10["10: Professional"]
        L10 --> L11["11: Accomplished"]
        L11 --> L12["12: Great"]
        L12 --> L13["13: Master"]
        L13 --> L14["14: High Master"]
        L14 --> L15["15: Grand Master"]
        L15 --> L16["16+: Legendary"]
    end
```

**Experience Formula:** `400 + 100 * new_level` XP per level

### Skill Categories

```mermaid
mindmap
    root((Skills))
        Labor
            Mining
            Woodcutting
            Carpentry
            Masonry
            Brewing
            Cooking
            Farming
            Metalsmithing
            Jewelcrafting
        Combat
            Melee Weapons
                Axe
                Sword
                Hammer
                Spear
                Mace
            Ranged
                Archery
                Crossbow
            Defense
                Shield
                Armor User
                Dodging
            Wrestling
        Social
            Persuasion
            Negotiation
            Intimidation
            Consoling
            Comedy
            Flattery
        Other
            Swimming
            Climbing
            Observer
            Tracker
            Reader
            Writer
```

### Labor-Skill-Job Relationship

```mermaid
erDiagram
    LABOR {
        string name
        bool enabled
        enum category
    }

    SKILL {
        enum type
        int rating
        int experience
        int rust_counter
        int natural_level
    }

    JOB {
        enum job_type
        int priority
        Position location
        list items_needed
        Unit assigned_unit
        bool suspended
    }

    WORKSHOP {
        enum workshop_type
        Position position
        list jobs_queue
        list assigned_workers
    }

    LABOR ||--o{ SKILL : "trains"
    LABOR ||--o{ JOB : "enables"
    WORKSHOP ||--o{ JOB : "generates"
    JOB ||--o| UNIT : "assigned_to"
```

---

## 6. Personality & Psychology System

### Personality Structure

```mermaid
classDiagram
    class Personality {
        +list~Facet~ facets
        +list~Belief~ beliefs
        +list~Goal~ goals
        +int stress_level
    }

    class Facet {
        +FacetType type
        +int value
        +string get_description()
    }

    class Belief {
        +BeliefType type
        +int strength
    }

    class Goal {
        +GoalType type
        +bool achieved
        +int priority
    }

    Personality "1" *-- "*" Facet
    Personality "1" *-- "*" Belief
    Personality "1" *-- "*" Goal
```

### Personality Facets (Complete List)

#### Emotional Facets
| Facet | Range | Low Description | High Description |
|-------|-------|-----------------|------------------|
| LOVE_PROPENSITY | 0-100 | Never falls in love | Always in love |
| HATE_PROPENSITY | 0-100 | Never feels hatred | Easily develops hatred |
| ENVY_PROPENSITY | 0-100 | Never envies others | Consumed by jealousy |
| CHEER_PROPENSITY | 0-100 | Never cheerful | Often filled with joy |
| DEPRESSION_PROPENSITY | 0-100 | Rarely sad | Prone to depression |
| ANGER_PROPENSITY | 0-100 | Never angry | Constant internal rage |
| ANXIETY_PROPENSITY | 0-100 | Calm and collected | Nervous wreck |

#### Behavioral Facets
| Facet | Range | Low Description | High Description |
|-------|-------|-----------------|------------------|
| STRESS_VULNERABILITY | 0-100 | Stress resistant | Easily overwhelmed |
| GREED | 0-100 | Neglects wealth | Obsessed with wealth |
| IMMODERATION | 0-100 | Never overindulges | Ruled by cravings |
| VIOLENT | 0-100 | Peaceful | Enjoys fighting |
| PERSEVERANCE | 0-100 | Gives up easily | Unbelievably stubborn |
| BRAVERY | 0-100 | Coward | Utterly fearless |
| CONFIDENCE | 0-100 | No confidence | Blind overconfidence |
| AMBITION | 0-100 | No ambition | Relentless drive |

#### Social Facets
| Facet | Range | Low Description | High Description |
|-------|-------|-----------------|------------------|
| FRIENDLINESS | 0-100 | Quarreler | Bold flatterer |
| POLITENESS | 0-100 | Vulgar | Refined politeness |
| GREGARIOUSNESS | 0-100 | Prefers alone time | Treasures company |
| ASSERTIVENESS | 0-100 | Passive | Very assertive |
| TRUST | 0-100 | Sees others as conniving | Naturally trustful |

### Beliefs/Values

```
LAW, LOYALTY, FAMILY, FRIENDSHIP, POWER, TRUTH, CUNNING,
ELOQUENCE, FAIRNESS, DECORUM, TRADITION, ARTWORK,
COOPERATION, INDEPENDENCE, STOICISM, INTROSPECTION,
SELF_CONTROL, TRANQUILITY, HARMONY, MERRIMENT,
CRAFTMANSHIP, MARTIAL_PROWESS, SKILL, HARD_WORK,
SACRIFICE, COMPETITION, PERSEVERANCE, LEISURE_TIME,
COMMERCE, ROMANCE, NATURE, PEACE, KNOWLEDGE
```

---

## 7. Needs & Happiness System

### Needs-Focus-Stress Relationship

```mermaid
flowchart TD
    subgraph Needs["Needs System"]
        N1["Unmet Need"] --> N2["Decreased Focus"]
        N2 --> N3["Negative Thought"]
        N3 --> N4["Stress Increase"]

        N5["Met Need"] --> N6["Increased Focus"]
        N6 --> N7["Positive Thought"]
        N7 --> N8["Stress Decrease"]
    end

    subgraph Stress["Stress Levels"]
        S1["< 0: Content"] --> S2["0-10k: Normal"]
        S2 --> S3["10k-25k: Stressed"]
        S3 --> S4["25k-50k: Very Stressed"]
        S4 --> S5["50k+: Breaking Point"]
    end

    N4 --> Stress
    N8 --> Stress
```

### Complete Needs List

| Need | Satisfaction Method | Related Trait |
|------|---------------------|---------------|
| Gregariousness | Socialize/speak | GREGARIOUSNESS |
| Drinking | Consume alcohol | IMMODERATION |
| Prayer/Meditation | Pray at temple | Religious beliefs |
| Occupation | Perform tasks | HARD_WORK |
| Creativity | Create art | ARTWORK |
| Excitement | Danger/performances | EXCITEMENT_SEEKING |
| Learning | Gain skill/read | KNOWLEDGE |
| Family | Socialize with family | FAMILY |
| Friendship | Socialize with friends | FRIENDSHIP |
| Martial Arts | Combat/sparring | MARTIAL_PROWESS |
| Romance | Interact with spouse | ROMANCE |
| Acquisition | Obtain items | GREED, COMMERCE |
| Good Meals | Eat preferred food | IMMODERATION |
| Fighting | Engage combat | VIOLENT |
| Helping | Aid others | ALTRUISM |

### Focus System

```mermaid
gantt
    title Focus Level Effects
    dateFormat X
    axisFormat %s

    section Performance
    Badly Distracted (-50% skill) :a, 0, 60
    Distracted (-25% skill)       :b, 60, 80
    Unfocused (-10% skill)        :c, 80, 100
    Normal (baseline)             :d, 100, 120
    Focused (+10% skill)          :e, 120, 140
    Very Focused (+50% skill)     :f, 140, 200
```

### Memory System

```mermaid
flowchart LR
    subgraph ShortTerm["Short-Term Memory (8 slots)"]
        ST1["Recent Event 1"]
        ST2["Recent Event 2"]
        ST3["..."]
        ST8["Recent Event 8"]
    end

    subgraph LongTerm["Long-Term Memory (8 slots)"]
        LT1["Strongest Memory 1"]
        LT2["Strongest Memory 2"]
        LT3["..."]
        LT8["Strongest Memory 8"]
    end

    Event["New Event"] --> ShortTerm
    ShortTerm -->|"Strongest emotions"| LongTerm
    LongTerm -->|"Periodic recall"| StressChange["Stress Change"]
```

---

## 8. Combat & Anatomy System

### Body Part Hierarchy

```mermaid
graph TD
    Body["Body (Root)"]

    Body --> Head
    Body --> Torso
    Body --> LeftArm["Left Arm"]
    Body --> RightArm["Right Arm"]
    Body --> LeftLeg["Left Leg"]
    Body --> RightLeg["Right Leg"]

    Head --> Brain
    Head --> Eyes
    Head --> Ears
    Head --> Nose
    Head --> Mouth
    Head --> Teeth

    Torso --> Heart
    Torso --> Lungs
    Torso --> Liver
    Torso --> Stomach
    Torso --> Guts
    Torso --> Spine

    LeftArm --> LeftHand["Left Hand"]
    LeftHand --> LeftFingers["Fingers"]

    RightArm --> RightHand["Right Hand"]
    RightHand --> RightFingers["Fingers"]

    LeftLeg --> LeftFoot["Left Foot"]
    LeftFoot --> LeftToes["Toes"]

    RightLeg --> RightFoot["Right Foot"]
    RightFoot --> RightToes["Toes"]
```

### Tissue Layer System

```mermaid
flowchart LR
    subgraph Layers["Tissue Layers (Outside to Inside)"]
        L1["Skin"] --> L2["Fat"]
        L2 --> L3["Muscle"]
        L3 --> L4["Bone"]
        L4 --> L5["Internal Organs"]
    end

    subgraph Properties["Layer Properties"]
        P1["Pain Receptors"]
        P2["Blood Vessels"]
        P3["Structural Integrity"]
        P4["Healing Rate"]
    end
```

### Wound Severity Levels

| Level | Name | Description |
|-------|------|-------------|
| 0 | NONE | No active wounds |
| 1 | MINOR | Damage without functional consequences |
| 2 | INHIBITED | Partial loss of function |
| 3 | FUNCTION_LOSS | Complete function loss, structure intact |
| 4 | BROKEN | Lost structural integrity |
| 5 | MISSING | Part completely gone |

### Combat Flow

```mermaid
sequenceDiagram
    participant A as Attacker
    participant D as Defender
    participant W as Wound System

    A->>D: Attack (weapon, body part target)
    D->>D: Calculate defense (dodge/block/parry)

    alt Defense Success
        D->>A: Attack deflected
    else Defense Failure
        D->>W: Apply damage
        W->>W: Calculate penetration
        W->>W: Determine tissue damage
        W->>W: Apply effects (pain, bleeding)
        W->>D: Update body state

        alt Fatal Wound
            D->>D: Death
        else Severe Wound
            D->>D: Incapacitated
        else Minor Wound
            D->>D: Continue fighting
        end
    end
```

### Pain System

| Tissue Type | Pain Receptors | Effect |
|-------------|----------------|--------|
| Skin | 5 | Light pain |
| Fat | 5 | Light pain |
| Muscle | 5 | Light pain |
| Bone | 50 | Heavy pain |
| Organs | Variable | Heavy pain + effects |

**Pain Threshold:** 150+ points = unconsciousness

---

## 9. Item & Material System

### Item Quality Levels

```mermaid
flowchart LR
    Q1["Standard (1x)"] --> Q2["-Well-crafted- (1.2x)"]
    Q2 --> Q3["+Finely-crafted+ (1.4x)"]
    Q3 --> Q4["*Superior* (1.6x)"]
    Q4 --> Q5["≡Exceptional≡ (1.8x)"]
    Q5 --> Q6["☼Masterwork☼ (2x)"]
    Q6 --> Q7["Artifact (120x)"]
```

### Item Hierarchy

```mermaid
classDiagram
    class Item {
        +int id
        +ItemType type
        +Material material
        +Quality quality
        +Position position
        +list~ItemFlags~ flags
        +int wear_level
    }

    class Weapon {
        +int attack_velocity
        +int contact_area
        +AttackType attack_type
        +int penetration
    }

    class Armor {
        +int coverage
        +int protection
        +BodyPartCategory covered_parts
    }

    class Tool {
        +ToolType tool_type
        +list~JobType~ enabled_jobs
    }

    class Food {
        +int nutrition
        +bool prepared
        +list~Ingredient~ ingredients
    }

    Item <|-- Weapon
    Item <|-- Armor
    Item <|-- Tool
    Item <|-- Food
```

### Material Categories

```mermaid
mindmap
    root((Materials))
        Inorganic
            Stone
                Ignite
                Sedimentary
                Metamorphic
            Metal
                Iron
                Copper
                Silver
                Gold
                Steel
                Adamantine
            Gem
                Ornamental
                Semi-precious
                Precious
                Rare
        Organic
            Wood
            Bone
            Leather
            Cloth
            Plant
            Shell
```

### Material Properties

| Property | Description |
|----------|-------------|
| SOLID_DENSITY | Weight per unit volume |
| IMPACT_YIELD | Blunt damage resistance |
| IMPACT_FRACTURE | Breaking point |
| SHEAR_YIELD | Cutting damage resistance |
| SHEAR_FRACTURE | Cutting breaking point |
| MELTING_POINT | Temperature to melt |
| VALUE | Base trade value |

---

## 10. Building & Construction System

### Building Types

```mermaid
mindmap
    root((Buildings))
        Workshops
            Craftsdwarf's
            Carpenter's
            Mason's
            Metalsmith's
            Jeweler's
            Mechanic's
            Kitchen
            Brewery
            Farmer's
        Furniture
            Bed
            Table
            Chair
            Door
            Cabinet
            Coffer
            Statue
            Coffin
        Infrastructure
            Well
            Lever
            Bridge
            Road
            Wall
            Floor
            Stairs
            Fortification
        Military
            Barracks
            Archery Target
            Armor Stand
            Weapon Rack
        Traps
            Stone-fall
            Weapon
            Cage
            Upright Spear
```

### Room System

```mermaid
erDiagram
    ROOM {
        int id
        enum room_type
        Position center
        int size
        Unit owner
        int value
    }

    FURNITURE {
        int id
        enum furniture_type
        Position position
        Quality quality
        Material material
    }

    ZONE {
        int id
        enum zone_type
        list positions
        list settings
    }

    STOCKPILE {
        int id
        list positions
        StockpileSettings settings
        int priority
    }

    ROOM ||--o{ FURNITURE : "contains"
    ZONE ||--o{ FURNITURE : "encompasses"
```

### Room Types & Requirements

| Room Type | Required Furniture | Max Size |
|-----------|-------------------|----------|
| Bedroom | Bed | 60×60 |
| Dining Room | Table + Chair | 60×60 |
| Office | Chair | 60×60 |
| Tomb | Coffin | 60×60 |
| Temple | None (zone) | 60×60 |
| Tavern | Table + Chair | 60×60 |
| Library | Bookcase | 60×60 |

---

## 11. Job & Task System

### Job Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Created: job_generated
    Created --> Queued: added_to_queue
    Queued --> Assigned: dwarf_available
    Assigned --> InProgress: work_started
    InProgress --> Suspended: interrupted
    Suspended --> Queued: resumed
    InProgress --> Completed: work_done
    InProgress --> Failed: cannot_complete
    Completed --> [*]
    Failed --> [*]
```

### Job Priority System

| Priority | Value | Description |
|----------|-------|-------------|
| Highest | 1 | Do immediately |
| High | 2 | High priority |
| Above Normal | 3 | Above average |
| Normal | 4 | Default |
| Below Normal | 5 | Below average |
| Low | 6 | Low priority |
| Lowest | 7 | Do when idle |

### Work Order System

```mermaid
flowchart TD
    WO["Work Order Created"] --> Conditions{"Check Conditions"}

    Conditions -->|"Conditions Met"| Generate["Generate Jobs"]
    Conditions -->|"Conditions Not Met"| Wait["Wait for Conditions"]
    Wait --> Conditions

    Generate --> Assign["Assign to Workshop"]
    Assign --> Queue["Add to Job Queue"]
    Queue --> Execute["Execute Job"]
    Execute --> Complete["Job Complete"]
    Complete --> Check{"More Items Needed?"}
    Check -->|"Yes"| Generate
    Check -->|"No"| Done["Work Order Complete"]
```

---

## 12. Entity & Civilization System

### Entity Hierarchy

```mermaid
classDiagram
    class Entity {
        +int id
        +string name
        +EntityType type
        +list~Position~ positions
        +list~Unit~ members
        +list~Site~ sites
    }

    class Civilization {
        +Race race
        +Government government_type
        +list~Entity~ sub_entities
        +list~War~ wars
        +list~Treaty~ treaties
    }

    class SiteGovernment {
        +Site site
        +Entity parent_civ
        +list~Noble~ nobles
    }

    class Position {
        +string title
        +PositionLevel level
        +Unit holder
        +list~Responsibility~ responsibilities
        +list~Demand~ demands
    }

    Entity <|-- Civilization
    Entity <|-- SiteGovernment
    Entity "1" *-- "*" Position
```

### Noble Positions

#### Civilization-Level
- Monarch (King/Queen)
- General
- Diplomat
- Outpost Liaison

#### Site-Level
- Mayor (elected)
- Manager
- Broker
- Sheriff/Captain of the Guard
- Chief Medical Dwarf
- Bookkeeper

### Position Responsibilities

```mermaid
flowchart LR
    subgraph Utility["Utility Nobles"]
        Manager["Manager: Work Orders"]
        Broker["Broker: Trading"]
        Sheriff["Sheriff: Justice"]
        CMO["Chief Medical: Healthcare"]
        Bookkeeper["Bookkeeper: Stocks"]
    end

    subgraph Ceremonial["Ceremonial Nobles"]
        Mayor["Mayor: Morale"]
        Baron["Baron: Prestige"]
        Duke["Duke: Higher Prestige"]
    end
```

---

## 13. Pathfinding System

### A* Algorithm Implementation

```mermaid
flowchart TD
    Start["Start Position"] --> Open["Add to Open Set"]
    Open --> Eval{"Evaluate Lowest F-cost"}

    Eval --> Goal{"Is Goal?"}
    Goal -->|"Yes"| Path["Reconstruct Path"]
    Goal -->|"No"| Expand["Expand Neighbors"]

    Expand --> Check{"Check Each Neighbor"}
    Check --> Passable{"Is Passable?"}
    Passable -->|"No"| Check
    Passable -->|"Yes"| Calculate["Calculate G, H, F costs"]
    Calculate --> Update["Update Open/Closed Sets"]
    Update --> Eval

    Path --> Done["Return Path"]
```

### Traffic Designations

| Designation | Cost | Use Case |
|-------------|------|----------|
| High Traffic | 1 | Main hallways |
| Normal | 2 | Default |
| Low Traffic | 5 | Less preferred |
| Restricted | 25 | Emergencies only |

### Movement Costs

```mermaid
graph LR
    subgraph Terrain["Terrain Costs"]
        Floor["Floor: 1"] --> Stairs["Stairs: 2"]
        Stairs --> Ramp["Ramp: 2"]
        Ramp --> Water["Water: 5"]
        Water --> Magma["Magma: ∞"]
    end

    subgraph Modifiers["Cost Modifiers"]
        Door["Door: +1"]
        Furniture["Furniture: +1"]
        Traffic["Traffic Designation"]
    end
```

---

## Summary of Core Models

### Entity Summary

| Model | Key Properties | Relationships |
|-------|---------------|---------------|
| **Unit** | id, race, position, body, soul | Has body, soul, inventory, jobs |
| **Body** | parts, wounds, physical_attrs | Has body parts, wounds |
| **Soul** | mental_attrs, skills, personality | Has skills, needs, memories |
| **Item** | type, material, quality | Owned by unit, in position |
| **Building** | type, position, jobs | Contains items, generates jobs |
| **Job** | type, priority, assigned_unit | Assigned to unit, linked to building |
| **Entity** | type, members, positions | Has units, noble positions |
| **Tile** | position, terrain, temperature | Part of map |

### System Interactions

```mermaid
flowchart TB
    subgraph Core["Core Game Loop"]
        Update["Update Tick"]
    end

    subgraph Systems["System Updates"]
        Update --> Pathfinding
        Update --> Jobs
        Update --> Needs
        Update --> Combat
        Update --> Physics
    end

    subgraph Data["Data Changes"]
        Pathfinding --> UnitPosition["Unit Positions"]
        Jobs --> ItemState["Item States"]
        Needs --> UnitMood["Unit Moods"]
        Combat --> Wounds["Wounds/Deaths"]
        Physics --> FluidLevels["Fluid Levels"]
    end
```

---

## References

1. [Dwarf Fortress Wiki - Main](https://dwarffortresswiki.org/)
2. [DFHack df-structures](https://github.com/DFHack/df-structures)
3. [700,000 Lines of Code Article](https://stackoverflow.blog/2021/12/31/700000-lines-of-code-20-years-and-one-developer-how-dwarf-fortress-is-built/)
4. [Bay 12 Games](https://www.bay12games.com/dwarves/)
5. [DF Wiki - Attribute](https://dwarffortresswiki.org/index.php/DF2014:Attribute)
6. [DF Wiki - Personality Facet](https://dwarffortresswiki.org/index.php/DF2014:Personality_facet)
7. [DF Wiki - Need](https://dwarffortresswiki.org/index.php/DF2014:Need)
8. [DF Wiki - Stress](https://dwarffortresswiki.org/index.php/DF2014:Stress)
9. [DF Wiki - Combat](https://dwarffortresswiki.org/index.php/DF2014:Combat)
10. [DF Wiki - World Generation](https://dwarffortresswiki.org/index.php/DF2014:World_generation)
