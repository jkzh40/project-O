# Model Specifications

This document provides detailed specifications for all game models based on Dwarf Fortress research.

---

## 1. Core Enumerations

### Physical Attributes
```
enum PhysicalAttribute {
    STRENGTH = 0
    AGILITY = 1
    TOUGHNESS = 2
    ENDURANCE = 3
    RECUPERATION = 4
    DISEASE_RESISTANCE = 5
}
```

### Mental Attributes
```
enum MentalAttribute {
    ANALYTICAL_ABILITY = 0
    FOCUS = 1
    WILLPOWER = 2
    CREATIVITY = 3
    INTUITION = 4
    PATIENCE = 5
    MEMORY = 6
    LINGUISTIC_ABILITY = 7
    SPATIAL_SENSE = 8
    MUSICALITY = 9
    KINESTHETIC_SENSE = 10
    EMPATHY = 11
    SOCIAL_AWARENESS = 12
}
```

### Skill Types
```
enum SkillType {
    // Mining/Digging
    MINING = 0

    // Woodworking
    WOODCUTTING = 1
    CARPENTRY = 2
    BOWYER = 3

    // Stoneworking
    MASONRY = 4
    ENGRAVING = 5

    // Metalworking
    SMELTING = 6
    WEAPONSMITHING = 7
    ARMORSMITHING = 8
    BLACKSMITHING = 9
    METALCRAFTING = 10

    // Crafts
    LEATHERWORKING = 11
    WEAVING = 12
    CLOTHESMAKING = 13
    POTTERY = 14
    GLASSMAKING = 15
    GEMCUTTING = 16
    GEMSETTING = 17
    BONECARVING = 18
    STONECRAFTING = 19
    WOODCRAFTING = 20

    // Farming
    FARMING = 21
    BREWING = 22
    COOKING = 23
    HERBALISM = 24
    ANIMAL_TRAINING = 25
    ANIMAL_CARE = 26
    BUTCHERY = 27
    TANNING = 28
    MILLING = 29
    DYEING = 30

    // Medical
    DIAGNOSIS = 31
    SURGERY = 32
    BONE_SETTING = 33
    SUTURING = 34
    DRESSING_WOUNDS = 35

    // Military
    MELEE_COMBAT = 36
    RANGED_COMBAT = 37
    SHIELD_USER = 38
    ARMOR_USER = 39
    DODGING = 40
    WRESTLING = 41
    BITING = 42

    // Specific Weapons
    AXE = 43
    SWORD = 44
    MACE = 45
    HAMMER = 46
    SPEAR = 47
    CROSSBOW = 48
    BOW = 49

    // Social
    PERSUASION = 50
    NEGOTIATION = 51
    INTIMIDATION = 52
    CONSOLING = 53
    COMEDY = 54
    FLATTERY = 55
    CONVERSATION = 56

    // Leadership
    LEADERSHIP = 57
    TEACHING = 58

    // General
    SWIMMING = 59
    CLIMBING = 60
    CONCENTRATION = 61
    OBSERVER = 62
    ORGANIZER = 63
    RECORD_KEEPER = 64

    // Engineering
    MECHANICS = 65
    ARCHITECTURE = 66
    SIEGE_ENGINEERING = 67
    SIEGE_OPERATION = 68
    PUMP_OPERATION = 69
}
```

### Personality Facets
```
enum PersonalityFacet {
    LOVE_PROPENSITY = 0
    HATE_PROPENSITY = 1
    ENVY_PROPENSITY = 2
    CHEER_PROPENSITY = 3
    DEPRESSION_PROPENSITY = 4
    ANGER_PROPENSITY = 5
    ANXIETY_PROPENSITY = 6
    LUST_PROPENSITY = 7
    STRESS_VULNERABILITY = 8
    GREED = 9
    IMMODERATION = 10
    VIOLENT = 11
    PERSEVERANCE = 12
    WASTEFULNESS = 13
    DISCORD = 14
    FRIENDLINESS = 15
    POLITENESS = 16
    DISDAIN_ADVICE = 17
    BRAVERY = 18
    CONFIDENCE = 19
    VANITY = 20
    AMBITION = 21
    GRATITUDE = 22
    IMMODESTY = 23
    HUMOR = 24
    VENGEFUL = 25
    PRIDE = 26
    CRUELTY = 27
    SINGLEMINDED = 28
    HOPEFUL = 29
    CURIOUS = 30
    BASHFUL = 31
    PRIVACY = 32
    PERFECTIONIST = 33
    CLOSEMINDED = 34
    TOLERANT = 35
    EMOTIONALLY_OBSESSIVE = 36
    SWAYED_BY_EMOTIONS = 37
    ALTRUISM = 38
    DUTIFULNESS = 39
    THOUGHTLESSNESS = 40
    ORDERLINESS = 41
    TRUST = 42
    GREGARIOUSNESS = 43
    ASSERTIVENESS = 44
    ACTIVITY_LEVEL = 45
    EXCITEMENT_SEEKING = 46
    IMAGINATION = 47
    ABSTRACT_INCLINED = 48
    ART_INCLINED = 49
}
```

### Beliefs/Values
```
enum Belief {
    LAW = 0
    LOYALTY = 1
    FAMILY = 2
    FRIENDSHIP = 3
    POWER = 4
    TRUTH = 5
    CUNNING = 6
    ELOQUENCE = 7
    FAIRNESS = 8
    DECORUM = 9
    TRADITION = 10
    ARTWORK = 11
    COOPERATION = 12
    INDEPENDENCE = 13
    STOICISM = 14
    INTROSPECTION = 15
    SELF_CONTROL = 16
    TRANQUILITY = 17
    HARMONY = 18
    MERRIMENT = 19
    CRAFTMANSHIP = 20
    MARTIAL_PROWESS = 21
    SKILL = 22
    HARD_WORK = 23
    SACRIFICE = 24
    COMPETITION = 25
    PERSEVERANCE = 26
    LEISURE_TIME = 27
    COMMERCE = 28
    ROMANCE = 29
    NATURE = 30
    PEACE = 31
    KNOWLEDGE = 32
}
```

### Need Types
```
enum NeedType {
    DRINK_ALCOHOL = 0
    EAT = 1
    SLEEP = 2
    PRAY = 3
    SOCIALIZE = 4
    FAMILY = 5
    FRIENDSHIP = 6
    ROMANCE = 7
    CREATIVITY = 8
    EXCITEMENT = 9
    LEARNING = 10
    CRAFTSMANSHIP = 11
    MARTIAL_TRAINING = 12
    LEISURE = 13
    NATURE = 14
    ACQUISITION = 15
    HELPING = 16
    OCCUPATION = 17
    ABSTRACT_THINKING = 18
    ART_APPRECIATION = 19
}
```

### Wound Severity
```
enum WoundSeverity {
    NONE = 0
    MINOR = 1
    INHIBITED = 2
    FUNCTION_LOSS = 3
    BROKEN = 4
    MISSING = 5
}
```

### Item Quality
```
enum ItemQuality {
    STANDARD = 0        // 1.0x multiplier
    WELL_CRAFTED = 1    // 1.2x multiplier
    FINELY_CRAFTED = 2  // 1.4x multiplier
    SUPERIOR = 3        // 1.6x multiplier
    EXCEPTIONAL = 4     // 1.8x multiplier
    MASTERWORK = 5      // 2.0x multiplier
    ARTIFACT = 6        // 120x multiplier (unique)
}
```

### Job Priority
```
enum JobPriority {
    HIGHEST = 1
    HIGH = 2
    ABOVE_NORMAL = 3
    NORMAL = 4
    BELOW_NORMAL = 5
    LOW = 6
    LOWEST = 7
}
```

---

## 2. Core Data Structures

### Position/Coordinate
```
struct Position {
    x: i32          // X coordinate
    y: i32          // Y coordinate
    z: i32          // Z level (0 = surface)
}
```

### Attribute Value
```
struct AttributeValue {
    base: i32           // Base value (racial default)
    current: i32        // Current value (after modifiers)
    max: i32            // Maximum achievable
    modifier: i32       // Temporary modifier
}
```

Range: 0-5000, with 1000 being human average.

### Skill Entry
```
struct SkillEntry {
    skill_type: SkillType
    rating: u8              // 0-20 (0=Not, 15=Legendary)
    experience: u32         // Current XP
    rust_counter: u32       // Ticks since last use
    natural_level: u8       // Cannot degrade below this
}
```

**Skill Level Names:**
| Rating | Name |
|--------|------|
| 0 | Not |
| 1 | Dabbling |
| 2 | Novice |
| 3 | Adequate |
| 4 | Competent |
| 5 | Skilled |
| 6 | Proficient |
| 7 | Talented |
| 8 | Adept |
| 9 | Expert |
| 10 | Professional |
| 11 | Accomplished |
| 12 | Great |
| 13 | Master |
| 14 | High Master |
| 15 | Grand Master |
| 16+ | Legendary |

**XP Formula:** `XP_for_level(n) = 400 + 100 * n`

---

## 3. Unit Models

### Unit (Main Entity)
```
struct Unit {
    id: u64
    name: Name
    race: RaceId
    caste: CasteId
    sex: Sex

    // Position & Movement
    position: Position
    facing: Direction
    current_path: Option<Path>

    // Components
    body: Body
    soul: Soul
    inventory: Inventory

    // State
    flags: UnitFlags
    current_job: Option<JobId>
    military_data: Option<MilitaryData>

    // Relationships
    relationships: Vec<Relationship>
    civilization_id: Option<EntityId>
    site_id: Option<SiteId>

    // Timing
    birth_year: i32
    birth_tick: u32
}
```

### Name
```
struct Name {
    first_name: String
    nickname: Option<String>
    last_name: Option<String>
    translated_name: Option<String>  // For artifacts/titles
}
```

### Body
```
struct Body {
    body_plan: BodyPlanId
    parts: Vec<BodyPartInstance>
    wounds: Vec<Wound>

    physical_attributes: [AttributeValue; 6]

    // Vitals
    blood_current: i32
    blood_max: i32

    // Status
    temperature: i32
    infection_level: i32

    // Syndromes/Effects
    active_syndromes: Vec<SyndromeInstance>
}
```

### BodyPartInstance
```
struct BodyPartInstance {
    part_id: BodyPartId
    parent_id: Option<BodyPartId>

    tissue_layers: Vec<TissueLayerInstance>

    // State
    status: BodyPartStatus
    motor_function: f32     // 0.0-1.0
    sensory_function: f32   // 0.0-1.0

    // Worn items
    worn_items: Vec<ItemId>
}
```

### TissueLayerInstance
```
struct TissueLayerInstance {
    tissue_type: TissueType
    material: MaterialId

    thickness_current: i32
    thickness_max: i32

    damage: TissueDamage
}
```

### TissueDamage
```
struct TissueDamage {
    strain: i32
    effect_fraction: i32    // Damage percentage
    bleeding: i32           // Blood loss rate
    pain: i32
    paralysis: bool
    numbness: bool
    severed: bool
}
```

### Wound
```
struct Wound {
    id: u64
    body_part_id: BodyPartId

    severity: WoundSeverity
    contact_area: i32

    // Effects
    strain: i32
    bleeding_rate: i32
    pain_level: i32
    paralysis: bool

    // Healing
    treatment_status: TreatmentStatus
    infection: bool
    healing_progress: f32

    created_tick: u32
}
```

### Soul
```
struct Soul {
    // Identity
    name: Name

    // Mental Attributes
    mental_attributes: [AttributeValue; 13]

    // Skills
    skills: Vec<SkillEntry>

    // Personality
    personality: Personality

    // Preferences
    preferences: Vec<Preference>

    // Psychological State
    stress: i32             // -1,000,000 to +1,000,000
    focus: f32              // 0.6 to 1.4+

    // Memory
    short_term_memories: [Option<Memory>; 8]
    long_term_memories: [Option<Memory>; 8]

    // Needs
    needs: Vec<NeedInstance>
}
```

### Personality
```
struct Personality {
    facets: [u8; 50]        // 0-100 for each facet
    beliefs: [i8; 33]       // -3 to +3 for each belief
    goals: Vec<Goal>
}
```

### NeedInstance
```
struct NeedInstance {
    need_type: NeedType
    focus_level: i32        // Current satisfaction (0-400)
    strength: u8            // How strongly this need affects unit (from personality)
    deity_id: Option<DeityId>  // For prayer needs
}
```

### Memory
```
struct Memory {
    event_type: EventType
    subject_id: Option<u64>
    emotional_strength: i32     // Absolute value of emotion
    emotion_type: EmotionType   // Positive or negative
    year: i32
    tick: u32
    times_recalled: u32
}
```

### Preference
```
struct Preference {
    preference_type: PreferenceType
    target_type: PreferenceTarget   // Material, creature, item type, etc.
    target_id: u32
    strength: i8                    // How much they like/dislike
}
```

---

## 4. Item Models

### Item (Base)
```
struct Item {
    id: u64
    item_type: ItemType
    subtype_id: Option<u32>

    material: MaterialId
    quality: ItemQuality

    position: Option<Position>
    container_id: Option<ItemId>
    owner_id: Option<UnitId>

    // State
    flags: ItemFlags
    wear_level: u8          // 0-3 (0=new, 3=tattered)
    temperature: i32

    // For stackable items
    stack_size: u32

    // For crafted items
    maker_id: Option<UnitId>
    artifact_name: Option<Name>
}
```

### ItemType Categories
```
enum ItemType {
    // Tools
    PICK,
    AXE,

    // Weapons
    WEAPON,
    AMMO,

    // Armor
    ARMOR,
    SHIELD,
    HELM,
    GLOVES,
    SHOES,
    PANTS,

    // Furniture
    BED,
    TABLE,
    CHAIR,
    DOOR,
    STATUE,
    COFFIN,
    CABINET,
    BIN,
    BARREL,

    // Food/Drink
    FOOD,
    DRINK,
    MEAT,
    FISH,
    PLANT,
    SEED,

    // Materials
    BAR,
    BLOCK,
    LOG,
    BOULDER,
    GEM,
    ROUGH_GEM,

    // Crafts
    CRAFT,
    TOY,
    INSTRUMENT,

    // Containers
    BAG,
    BOX,

    // Medical
    SPLINT,
    CRUTCH,
    THREAD,
    CLOTH,
}
```

### WeaponData
```
struct WeaponData {
    attack_type: AttackType     // SLASH, PIERCE, BLUNT
    contact_area: i32
    penetration: i32
    velocity_modifier: i32
    skill_type: SkillType
    size: i32
    two_handed_size: i32
}
```

### ArmorData
```
struct ArmorData {
    coverage: Vec<BodyPartCategory>
    protection: i32
    layer: ArmorLayer           // UNDER, ARMOR, COVER
    permit_layer: ArmorLayer
}
```

---

## 5. Material System

### Material
```
struct Material {
    id: MaterialId
    name: String

    // Physical properties
    solid_density: i32
    liquid_density: i32

    // Mechanical properties
    impact_yield: i32
    impact_fracture: i32
    impact_elasticity: i32
    shear_yield: i32
    shear_fracture: i32
    shear_elasticity: i32
    torsion_yield: i32
    torsion_fracture: i32
    bending_yield: i32
    bending_fracture: i32

    // Thermal
    melting_point: i32
    boiling_point: i32
    ignite_point: i32
    specific_heat: i32

    // Value
    base_value: i32

    // State
    state: MaterialState

    // Flags
    flags: MaterialFlags
}
```

### Inorganic Material (Stone/Metal/Gem)
```
struct InorganicMaterial {
    material: Material

    // Where it spawns
    environment_type: EnvironmentType
    environment_inclusion_type: InclusionType

    // For metals
    is_metal: bool
    ore_products: Vec<(MaterialId, f32)>  // What can be smelted from this

    // For gems
    is_gem: bool
    gem_rarity: GemRarity

    // For stone
    stone_type: StoneType
}
```

---

## 6. Building Models

### Building
```
struct Building {
    id: u64
    building_type: BuildingType
    subtype_id: Option<u32>

    position: Position
    dimensions: (u8, u8)    // Width, Height

    // Construction
    construction_stage: ConstructionStage
    materials_used: Vec<ItemId>

    // Jobs
    job_queue: Vec<JobId>
    max_jobs: u8

    // For workshops
    profile: Option<WorkshopProfile>

    // Ownership
    owner_id: Option<UnitId>
    room_id: Option<RoomId>
}
```

### BuildingType
```
enum BuildingType {
    // Workshops
    CRAFTSDWARFS_WORKSHOP,
    CARPENTERS_WORKSHOP,
    MASONS_WORKSHOP,
    METALSMITH_FORGE,
    SMELTER,
    JEWELERS_WORKSHOP,
    MECHANICS_WORKSHOP,
    KITCHEN,
    BREWERY,
    FARMERS_WORKSHOP,
    LOOM,
    CLOTHIERS_WORKSHOP,
    LEATHERWORKS,
    BUTCHERS_SHOP,
    TANNERS_SHOP,
    FISHERY,
    QUERN,
    MILLSTONE,
    SIEGE_WORKSHOP,
    BOWYERS_WORKSHOP,

    // Furniture
    BED,
    TABLE,
    CHAIR,
    DOOR,
    STATUE,
    COFFIN,
    CABINET,
    WEAPON_RACK,
    ARMOR_STAND,

    // Infrastructure
    WALL,
    FLOOR,
    RAMP,
    STAIRS_UP,
    STAIRS_DOWN,
    STAIRS_UPDOWN,
    FORTIFICATION,
    BRIDGE,
    WELL,
    LEVER,
    HATCH,
    WINDOW,

    // Traps
    STONE_FALL_TRAP,
    WEAPON_TRAP,
    CAGE_TRAP,
    UPRIGHT_SPEAR,

    // Farm
    FARM_PLOT,
    NEST_BOX,
    HIVE,
}
```

### Room
```
struct Room {
    id: u64
    room_type: RoomType

    center: Position
    tiles: Vec<Position>

    // Value calculation
    smoothed_tiles: u32
    engraved_tiles: u32
    furniture_value: i32
    total_value: i32

    // Ownership
    owner_id: Option<UnitId>

    // For meeting areas
    meeting_area: bool
}
```

### RoomType
```
enum RoomType {
    BEDROOM,
    DINING_ROOM,
    OFFICE,
    TOMB,
    TEMPLE,
    TAVERN,
    LIBRARY,
    BARRACKS,
    ARCHERY_RANGE,
    HOSPITAL,
}
```

---

## 7. Job System

### Job
```
struct Job {
    id: u64
    job_type: JobType

    // Location
    position: Position
    building_id: Option<BuildingId>

    // Assignment
    assigned_unit: Option<UnitId>
    required_skill: Option<SkillType>
    minimum_skill_level: u8

    // Materials
    required_items: Vec<JobItemRef>

    // Priority & State
    priority: JobPriority
    state: JobState

    // Progress
    work_remaining: u32
    work_total: u32

    // Result
    result_item_type: Option<ItemType>
    result_building_type: Option<BuildingType>
}
```

### JobType
```
enum JobType {
    // Mining
    DIG,
    CHANNEL,
    RAMP,
    STAIRS_DOWN,
    STAIRS_UP,
    STAIRS_UPDOWN,

    // Gathering
    FELL_TREE,
    GATHER_PLANTS,
    COLLECT_WEBS,

    // Hauling
    STORE_ITEM,
    HAUL_ITEM,
    HAUL_REFUSE,
    HAUL_FURNITURE,

    // Construction
    CONSTRUCT_BUILDING,
    DECONSTRUCT_BUILDING,
    CONSTRUCT_WALL,
    CONSTRUCT_FLOOR,

    // Crafting (by workshop)
    CRAFT_ITEM,
    FORGE_WEAPON,
    FORGE_ARMOR,
    SMELT_ORE,
    MAKE_FURNITURE,
    CUT_GEM,
    ENCRUST_GEM,

    // Food/Drink
    BREW,
    COOK,
    BUTCHER,
    TAN_HIDE,
    MILL_PLANT,

    // Farming
    PLANT_SEED,
    HARVEST,

    // Medical
    DIAGNOSE,
    SURGERY,
    SET_BONE,
    SUTURE,
    DRESS_WOUND,
    FEED_PATIENT,
    GIVE_WATER,

    // Military
    TRAIN,
    SPAR,
    PATROL,
    GUARD,
    ATTACK,

    // Service
    CLEAN,
    PULL_LEVER,
    OPERATE_PUMP,

    // Social/Personal
    EAT,
    DRINK,
    SLEEP,
    PRAY,
    PARTY,
    READ,
    WRITE,
}
```

### WorkOrder
```
struct WorkOrder {
    id: u64

    job_type: JobType
    item_type: ItemType
    subtype_id: Option<u32>
    material: Option<MaterialId>

    // Quantity
    amount_total: u32
    amount_completed: u32

    // Conditions
    conditions: Vec<WorkOrderCondition>

    // Frequency
    frequency: WorkOrderFrequency

    // State
    is_active: bool
    is_validated: bool
}
```

---

## 8. World/Map Models

### WorldMap
```
struct WorldMap {
    width: u32
    height: u32

    regions: Vec<Vec<Region>>

    // Global data
    civilizations: Vec<Civilization>
    historical_events: Vec<HistoricalEvent>
    historical_figures: Vec<HistoricalFigure>
}
```

### Region
```
struct Region {
    position: (u32, u32)

    // Terrain
    elevation: i32
    rainfall: i32
    temperature: i32
    drainage: i32
    volcanism: i32
    savagery: i32
    evil_alignment: i32

    biome: BiomeType

    // Rivers/water
    rivers: Vec<RiverId>

    // Sites
    sites: Vec<SiteId>

    // Vegetation/wildlife
    flora: Vec<PlantSpeciesId>
    fauna: Vec<CreatureSpeciesId>
}
```

### LocalMap (Embark Site)
```
struct LocalMap {
    width: u32
    height: u32
    depth: u32

    tiles: Vec<Vec<Vec<Tile>>>

    // Entities on map
    units: Vec<UnitId>
    items: Vec<ItemId>
    buildings: Vec<BuildingId>

    // Fluids
    water_levels: Vec<Vec<Vec<u8>>>     // 0-7 per tile
    magma_levels: Vec<Vec<Vec<u8>>>
}
```

### Tile
```
struct Tile {
    terrain_type: TerrainType
    material: MaterialId

    // Designation
    designation: TileDesignation
    traffic: TrafficDesignation

    // State
    temperature: i32
    occupancy: TileOccupancy

    // Features
    feature_type: Option<FeatureType>
}
```

### TerrainType
```
enum TerrainType {
    // Natural
    EMPTY_AIR,
    SOIL_FLOOR,
    STONE_FLOOR,
    SOIL_WALL,
    STONE_WALL,
    ORE_WALL,
    GEM_WALL,
    GRASS,
    TREE,
    SHRUB,
    WATER,
    MAGMA,
    RAMP,

    // Constructed
    CONSTRUCTED_FLOOR,
    CONSTRUCTED_WALL,
    CONSTRUCTED_RAMP,
    CONSTRUCTED_STAIRS_UP,
    CONSTRUCTED_STAIRS_DOWN,
    CONSTRUCTED_STAIRS_UPDOWN,
    FORTIFICATION,
}
```

---

## 9. Entity/Civilization Models

### Civilization
```
struct Civilization {
    id: u64
    name: Name

    race: RaceId
    government_type: GovernmentType

    // Territory
    sites: Vec<SiteId>

    // Population
    population: u32
    notable_figures: Vec<HistoricalFigureId>

    // Positions
    positions: Vec<Position>

    // Relations
    wars: Vec<WarId>
    alliances: Vec<AllianceId>

    // Culture
    beliefs: Vec<BeliefId>
    ethics: CivEthics
}
```

### Site
```
struct Site {
    id: u64
    name: Name

    site_type: SiteType
    position: (u32, u32)        // World map position

    owner_civ_id: Option<CivilizationId>
    government: SiteGovernment

    population: u32
    structures: Vec<StructureId>
}
```

### SiteType
```
enum SiteType {
    FORTRESS,
    TOWN,
    HAMLET,
    DARK_FORTRESS,
    CAVE,
    HILLOCKS,
    MOUNTAIN_HALL,
    FOREST_RETREAT,
    CAMP,
    VAULT,
    TOMB,
    TOWER,
    SHRINE,
    LABYRINTH,
}
```

### NoblePosition
```
struct NoblePosition {
    position_type: PositionType
    holder_id: Option<UnitId>

    // Requirements
    responsibilities: Vec<Responsibility>
    demands: Vec<Demand>

    // For elected positions
    is_elected: bool
    term_length: Option<u32>
    election_year: Option<i32>
}
```

### PositionType
```
enum PositionType {
    // Civilization-level
    MONARCH,
    GENERAL,
    DIPLOMAT,

    // Site-level
    MAYOR,
    MANAGER,
    BROKER,
    SHERIFF,
    CAPTAIN_OF_GUARD,
    CHIEF_MEDICAL_DWARF,
    BOOKKEEPER,

    // Nobility
    BARON,
    COUNT,
    DUKE,
}
```

---

## 10. Combat Models

### Attack
```
struct Attack {
    attacker_id: UnitId
    defender_id: UnitId

    attack_type: AttackType
    weapon_id: Option<ItemId>
    body_part_used: Option<BodyPartId>

    target_body_part: BodyPartId

    velocity: i32
    contact_area: i32

    // Results (calculated)
    hit: bool
    damage: Option<WoundResult>
}
```

### AttackType
```
enum AttackType {
    // Weapon attacks
    SLASH,
    STAB,
    BASH,

    // Natural attacks
    BITE,
    SCRATCH,
    KICK,
    PUNCH,

    // Wrestling
    PUSH,
    PULL,
    GRAB,
    THROW,
    STRANGLE,
    JOINT_LOCK,
}
```

### DefenseAction
```
struct DefenseAction {
    defender_id: UnitId
    defense_type: DefenseType

    shield_id: Option<ItemId>
    weapon_id: Option<ItemId>     // For parry

    success: bool
}
```

### DefenseType
```
enum DefenseType {
    DODGE,
    BLOCK,          // With shield
    PARRY,          // With weapon
    ARMOR,          // Passive
}
```

---

## Appendix: Constants

### Attribute Ranges (for Dwarves)
```
STRENGTH:     [450, 950, 1150, 1250, 1350, 1550, 2250]
AGILITY:      [150, 600,  800,  900, 1000, 1100, 1500]
TOUGHNESS:    [450, 950, 1150, 1250, 1350, 1550, 2250]
ENDURANCE:    [200, 700,  900, 1000, 1100, 1300, 1900]
RECUPERATION: [200, 700,  900, 1000, 1100, 1300, 1900]
DISEASE_RES:  [200, 700,  900, 1000, 1100, 1300, 1900]
```

### Stress Thresholds
```
CONTENT:      < 0
NORMAL:       0 - 10,000
STRESSED:     10,000 - 25,000
VERY_STRESSED: 25,000 - 50,000
BREAKING:     > 50,000
```

### Focus Ranges
```
BADLY_DISTRACTED: < 60%   (-50% skill)
DISTRACTED:       60-80%  (-25% skill)
UNFOCUSED:        80-100% (-10% skill)
NORMAL:           100%    (baseline)
FOCUSED:          100-120% (+10% skill)
VERY_FOCUSED:     120-140% (+25% skill)
HYPER_FOCUSED:    > 140%  (+50% skill)
```

### Traffic Costs
```
HIGH_TRAFFIC:  1
NORMAL:        2
LOW_TRAFFIC:   5
RESTRICTED:    25
```

### Quality Multipliers
```
STANDARD:      1.0x
WELL_CRAFTED:  1.2x
FINELY_CRAFTED: 1.4x
SUPERIOR:      1.6x
EXCEPTIONAL:   1.8x
MASTERWORK:    2.0x  (accuracy/deflection: 2x)
ARTIFACT:      120x  (accuracy/deflection: 3x)
```
