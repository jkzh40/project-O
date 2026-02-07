# Geological Terrain Generation

This document describes the real-world geology, algorithms, and mathematical models underpinning the procedural terrain generation pipeline. The system produces deterministic, geologically coherent worlds from a single 64-bit seed.

## Pipeline Overview

World generation runs as a **7-stage sequential pipeline**, where each stage enriches the same `WorldMap` grid of cells. A `WorldSeed` initializes a Xoshiro256\*\* PRNG, which forks deterministic child RNGs for each stage.

```
               WorldSeed (UInt64)
                     │
                     ▼
  ┌──────────────────────────────────┐
  │  Stage 1: Tectonic Simulation    │  Voronoi plates, drift, boundaries
  └──────────────┬───────────────────┘
                 ▼
  ┌──────────────────────────────────┐
  │  Stage 2: Heightmap Generation   │  Multi-octave noise + tectonic blend
  └──────────────┬───────────────────┘
                 ▼
  ┌──────────────────────────────────┐
  │  Stage 3: Erosion Simulation     │  Hydraulic droplets + thermal collapse
  └──────────────┬───────────────────┘
                 ▼
  ┌──────────────────────────────────┐
  │  Stage 3.5: Geological Strata    │  Tectonic context → rock columns
  └──────────────┬───────────────────┘
                 ▼
  ┌──────────────────────────────────┐
  │  Stage 4: Climate Simulation     │  Temperature, wind, orographic rain
  └──────────────┬───────────────────┘
                 ▼
  ┌──────────────────────────────────┐
  │  Stage 5: Hydrology Simulation   │  Flow routing, rivers, lakes
  └──────────────┬───────────────────┘
                 ▼
  ┌──────────────────────────────────┐
  │  Stage 6: Biome Classification   │  Extended Whittaker diagram
  └──────────────┬───────────────────┘
                 ▼
  ┌──────────────────────────────────┐
  │  Stage 7: Detail Pass            │  Vegetation, soil, ore deposits
  └──────────────────────────────────┘
```

---

## Stage 1: Tectonic Simulation

**Real-world basis:** Earth's lithosphere is divided into rigid tectonic plates that float on the asthenosphere. Plate interactions at boundaries drive mountain building (orogeny), volcanism, and earthquake activity.

### Voronoi Plate Assignment

The map is partitioned into plates using **Voronoi tessellation**. Seed points are placed randomly, and every cell is assigned to the nearest seed using wrap-aware Euclidean distance:

```
d(cell, seed) = sqrt( min(dx, mapSize - dx)² + min(dy, mapSize - dy)² )
```

Each plate is randomly classified as **oceanic** (40% probability) or **continental** (60%), mirroring the ~30/70 ocean-continent ratio on Earth (biased toward continents for gameplay). Plates receive random drift vectors representing tectonic motion.

### Boundary Classification

At plate boundaries, the **relative motion** between adjacent plates determines boundary type. Given two plates with drift vectors **v₁** and **v₂**, the relative velocity is **v_rel = v₁ - v₂**. The boundary normal **n** points from one plate center toward the other. Classification uses the dot product and cross product:

```
dot  = v_rel · n     (component along boundary normal — convergent/divergent)
cross = v_rel × n    (component along boundary — transform)

if dot > |cross|    → Convergent boundary  (plates colliding)
if dot < -|cross|   → Divergent boundary   (plates separating)
otherwise           → Transform boundary   (plates sliding past)
```

**Real-world analogy:**
- **Convergent:** Himalayas (continental-continental), Andes (oceanic-continental subduction)
- **Divergent:** Mid-Atlantic Ridge, East African Rift
- **Transform:** San Andreas Fault

### Boundary Stress & Elevation Contribution

Stress measures proximity to a plate boundary and the speed of relative motion:

```
stress = min( sqrt(v_rel_x² + v_rel_y²) / 2.0, 1.0 )
```

Stress decays radially from boundary cells with a Gaussian-like falloff over an **8-cell radius**:

```
influence = stress × max(0, 1 - distance / radius) × falloff_factor
```

Elevation contributions by boundary type:

| Boundary | Continental | Oceanic |
|----------|------------|---------|
| Convergent | +stress × 0.4 (mountain building) | +stress × 0.15 (volcanic arcs) |
| Divergent | -stress × 0.15 (rift valleys) | — |
| Transform | +stress × 0.05 (minor uplift) | — |

Base elevations: oceanic plates 0.1–0.3, continental plates 0.35–0.55.

---

## Stage 2: Heightmap Generation

**Real-world basis:** Terrain elevation results from tectonic uplift modified by erosion, sedimentation, and volcanic activity at multiple spatial scales.

### Multi-Octave Noise Composition

The heightmap blends four noise layers with physically-motivated weights:

```
elevation = tectonic_base     × 0.50    ← large-scale plate structure
          + continental_noise × 0.25    ← regional variation (hills, basins)
          + mountain_ridges   × 0.15    ← sharp peaks at plate boundaries
          + organic_detail    × 0.10    ← small-scale terrain texture
```

**Fractal Brownian Motion (fBm)** produces the continental noise — self-similar patterns at decreasing scales, modeling how terrain exhibits statistical similarity across scales (coastlines, mountain ranges). Each octave doubles in frequency and halves in amplitude:

```
fBm(x, y) = Σᵢ (persistenceⁱ × noise(x × lacunarityⁱ, y × lacunarityⁱ))
           / Σᵢ persistenceⁱ

Parameters: 6 octaves, lacunarity = 2.0, persistence = 0.5
```

**Ridged multifractal noise** generates mountain ridges by inverting the absolute value of each noise sample — this creates sharp ridges (like real mountain ranges) where the noise crosses zero:

```
signal = 1.0 - |noise(x, y)|     ← fold noise into sharp ridges
signal = signal²                   ← sharpen peaks further
signal = signal × weight           ← suppress detail in valleys
weight = clamp(signal × gain)      ← feedback: ridges amplify detail

Parameters: 5 octaves, lacunarity = 2.2, gain = 2.0
```

This ridge noise is modulated by boundary stress — ridges only form where tectonic activity is high.

**Domain warping** adds organic irregularity by using noise to offset the input coordinates themselves:

```
warp_x = noise(x, y)
warp_y = noise(x + 5.2, y + 1.3)
warped = noise(x + strength × warp_x, y + strength × warp_y)

Parameters: strength = 0.3, 3 octaves
```

### Edge Falloff

A **smoothstep** falloff over the outer 10% of the map forces edges to ocean level, creating a natural island or continental boundary:

```
smoothstep(t) = t² × (3 - 2t)     for t ∈ [0, 1]
```

### Post-Processing

Two smoothing passes blend each cell 60/40 with its 8-neighbor average, simulating broad-scale isostatic adjustment.

---

## Stage 3: Erosion Simulation

**Real-world basis:** Hydraulic erosion carves valleys, deposits sediment in floodplains, and shapes the concave profiles of real river channels. Thermal erosion breaks down steep cliff faces through freeze-thaw weathering.

### Hydraulic Erosion (Particle-Based)

The algorithm simulates **500,000 rain droplets** as Lagrangian particles flowing downhill, each carrying water and dissolved sediment. This is a GPU-friendly variant of the method described by Hans Theobald Beyer (2015).

**Droplet lifecycle:**

```
For each droplet (max 60 steps):
  1. Compute bilinear gradient from 4 corner cell heights
  2. Update direction:  dir = dir × inertia + gradient × (1 - inertia)
  3. Move along direction (1 cell step)
  4. Compute height difference: Δh = h_new - h_old
  5. Compute sediment capacity:
       capacity = max(-Δh, min_slope) × speed × water × capacity_factor
  6. If carrying too much sediment (sediment > capacity):
       deposit (sediment - capacity) × deposition_rate
  7. Else (capacity available):
       erode min(capacity - sediment, -Δh) × erosion_rate
       (spread erosion over 3-cell radius with distance weighting)
  8. Update speed:  speed = sqrt(speed² + Δh × gravity)
  9. Evaporate water: water = water × (1 - evaporation_rate)
  10. Stop if water < 0.001 or droplet exits map
```

**Key parameters (physically motivated):**

| Parameter | Value | Geological meaning |
|-----------|-------|--------------------|
| Inertia | 0.05 | Water strongly follows gravity (low momentum retention) |
| Capacity | 4.0 | Sediment carrying capacity of flowing water |
| Deposition rate | 0.3 | Speed of sediment settling |
| Erosion rate | 0.3 | Rock dissolving/abrasion rate |
| Evaporation | 0.01 | Water loss per step |
| Gravity | 4.0 | Acceleration on slopes |
| Min slope | 0.01 | Prevents capacity collapse on flat terrain |
| Erosion radius | 3 | Area of effect for erosive action |

The **bilinear gradient** at fractional coordinates (x, y) with integer corners (i, j):

```
offset_x = x - i,  offset_y = y - j
grad_x = (h₁₀ - h₀₀)(1 - offset_y) + (h₁₁ - h₀₁)(offset_y)
grad_y = (h₀₁ - h₀₀)(1 - offset_x) + (h₁₁ - h₁₀)(offset_x)
```

### Thermal Erosion

Models **talus slope failure** — material slides downhill when slope exceeds a critical angle. Runs 5 iterations:

```
For each cell with steepest neighbor:
  Δh = height - neighbor_height
  if Δh > talus_angle (0.02):
    transfer = (Δh - talus_angle) × 0.5
    cell loses `transfer`, neighbor gains `transfer`
```

This produces the scree slopes and talus fans seen at the base of real cliffs.

---

## Stage 3.5: Geological Strata Generation

**Real-world basis:** The subsurface is composed of layered rock strata whose composition depends on the geological history of the region — sedimentary basins accumulate limestone and shale, volcanic arcs produce basalt and andesite, collision zones create metamorphic schist and marble.

### Tectonic Context Classification

Each cell's plate boundary data is classified into one of 7 tectonic contexts, mirroring real plate tectonic settings:

```
┌─────────────────────┬───────────────────────────────────────────────────┐
│ Context             │ Real-world analogue                               │
├─────────────────────┼───────────────────────────────────────────────────┤
│ Stable Continental  │ Interior cratons (Canadian Shield, Russian Plat.) │
│ Continental Collis. │ Himalayas, Alps                                   │
│ Subduction Zone     │ Andes, Japanese arc, Cascades                     │
│ Continental Rift    │ East African Rift, Rio Grande Rift                │
│ Oceanic Spread      │ Mid-Atlantic Ridge, East Pacific Rise             │
│ Transform Fault     │ San Andreas Fault, Alpine Fault (NZ)              │
│ Stable Oceanic      │ Abyssal plains, deep ocean floor                  │
└─────────────────────┴───────────────────────────────────────────────────┘
```

Classification logic:
- No boundary → stable continental or oceanic (based on plate type)
- Convergent + mixed plate types → subduction zone
- Convergent + same plate types → continental collision
- Divergent + both oceanic → oceanic spread
- Divergent + continental → continental rift
- Transform → transform fault

### Rock Column Generation

Each context defines a **layer sequence** ordered from surface to depth, with normalized thickness proportions. For example, the stable continental sequence:

```
Surface  ┌──────────────┐
         │   Chalk 8%   │  ← Young, soft sedimentary cap
         │ Sandstone 14%│  ← Consolidated sand deposits
         │ Limestone 14%│  ← Marine carbonate platform
         │ Mudstone  8% │  ← Fine-grained sediment
         │   Shale  10% │  ← Compacted clay
         │  Gneiss  14% │  ← High-grade metamorphic basement
         │ Livingrock 4%│  ← Fantasy: magical deep rock
         │ Deepslate 10%│  ← Fantasy: ultra-hard deep crust
         │ Runestone  3%│  ← Fantasy: rune-inscribed
         │Aetherstone 2%│  ← Fantasy: magical, rare
         │ Granite  13% │  ← Intrusive igneous basement
Depth    └──────────────┘
```

**Thickness perturbation** adds natural variation using simplex noise:

```
perturbation = noise(x × 0.05 + 1000, y × 0.05 + 1000)    ∈ [-1, 1]
factor = 1.0 + perturbation × 0.15                          ∈ [0.85, 1.15]
perturbed_thickness = max(0.02, base_thickness × factor)

Renormalize: thickness_i = perturbed_i / Σ perturbed_j
```

This ±15% variation ensures adjacent cells have slightly different layer boundaries, as in real geology where strata undulate, thin, and thicken.

### Geological Column Lookup

To determine the rock type at a given depth within a column, normalized depth is mapped through cumulative layer thicknesses:

```
Given z-level z and total depth D:
  normalized_depth = z / D          ∈ [0, 1]
  cumulative = 0
  for each layer (top → bottom):
    cumulative += layer.thickness
    if normalized_depth < cumulative:
      return layer.rockType
```

---

## Stage 4: Climate Simulation

**Real-world basis:** Global temperature follows a latitudinal gradient (hot at equator, cold at poles). Wind patterns are driven by the Coriolis effect creating trade winds, westerlies, and polar easterlies. Mountains force air upward, cooling it and causing orographic precipitation on windward slopes.

### Temperature Model

```
T_latitude  = 1.0 - 2.0 × |y_normalized - 0.5|        ← equator hot, poles cold
T_elevation = max(0, elevation - 0.3) × 1.5             ← lapse rate cooling
T_ocean     = 0.3 × (if elevation < 0.3)                ← maritime moderation
T_noise     = noise(x × 4.0, y × 4.0 + 200) × 0.1      ← local variation

temperature = clamp(T_latitude - T_elevation - T_ocean + T_noise, 0, 1)
```

The **environmental lapse rate** of ~6.5°C/km is approximated by the elevation cooling term. Ocean cells receive temperature moderation (maritime climate effect).

### Wind Bands

Latitude-based bands model the three-cell atmospheric circulation:

```
        90°N ┌──────────────┐
  Polar      │ ← Easterlies │  lat > 0.7: windX = -0.5
  Easterlies │              │
        60°N ├──────────────┤
  Prevailing │ Westerlies → │  0.2 < lat < 0.7: windX = +0.8
  Westerlies │              │
        30°N ├──────────────┤
  Trade      │ ← Trades     │  lat < 0.2: windX = -0.6
  Winds      │              │
         0°  └──────────────┘
```

Mountains reduce wind speed: `wind × (1 - (elevation - 0.5) × 2.0 × 0.5)` for elevation > 0.5.

### Moisture Advection & Orographic Rainfall

Moisture transport is simulated with **20 advection iterations** along wind direction:

```
For each ocean cell: moisture = 1.0 (evaporation source)

Repeat 20×:
  For each cell:
    next_cell = cell + wind_direction
    next.moisture += cell.moisture × transport_decay (0.85)

    if elevation > 0.4:    ← orographic lift
      rain = (elevation - 0.4) × 0.8 × moisture
      moisture -= rain      ← rain shadow effect
      cell.rainfall += rain

Final rainfall = moisture × (0.5 + temperature × 0.5) + noise × 0.1
```

This produces realistic rain shadows (e.g., dry eastern slopes of the Cascades) and wet windward coasts.

---

## Stage 5: Hydrology Simulation

**Real-world basis:** Water flows downhill following the steepest gradient, accumulating into streams and rivers. Lakes form in topographic depressions where water cannot drain.

### Sink Filling (Planchon-Darboux Algorithm)

Before routing flow, closed depressions must be filled to prevent flow from getting stuck. The **Planchon-Darboux (2001)** algorithm iteratively raises depression cells to the level of their lowest outlet:

```
Initialize: all land cells to ∞, border cells to actual elevation
Repeat (max 200 iterations):
  For each cell with height = ∞:
    For each neighbor with height < current:
      new_height = max(neighbor_height + ε, actual_elevation)
      if new_height < current: update
  Until no changes (convergence)

ε = 0.0001 (ensures strict downhill gradient)
Sea level = 0.3 (cells below are ocean)
```

### Flow Direction (D8 Method)

Each cell's flow direction points to the steepest downhill neighbor among 8 directions. Diagonal neighbors use a distance factor of √2:

```
For each of 8 neighbors:
  slope = (my_height - neighbor_height) / distance
  distance = 1.0 (cardinal) or 1.414 (diagonal)

flow_direction = neighbor with maximum slope
```

### Flow Accumulation (Topological Sort)

A BFS-based topological sort propagates accumulation downstream:

```
Compute in-degree for each cell (how many cells flow into it)
Queue all cells with in-degree = 0 (headwater cells)

While queue not empty:
  cell = dequeue
  downstream = cell pointed to by flow_direction
  downstream.accumulation += cell.accumulation + 1
  downstream.in_degree -= 1
  if downstream.in_degree == 0: enqueue
```

### River Tracing

Rivers are traced from high-accumulation cells downstream:

```
threshold = mapSize × 2    (cells must drain this many upstream cells)
max_rivers = 20
min_length = 5 cells

Starting from cells where accumulation > threshold:
  Follow flow_direction downstream
  Mark each cell as river
  Record path and volume = accumulation / mapSize²
```

### Lake Identification

Lakes form where:
- Elevation is 0.3–0.4 (just above sea level)
- Flow accumulation > mapSize AND moisture > 0.6
- Surrounded by ≥5 higher neighbors (topographic depression)

Lake water depth: `0.3 + moisture × 0.4`. Neighboring cells within 0.02 elevation are included in the lake body.

---

## Stage 6: Biome Classification

**Real-world basis:** The **Whittaker biome diagram** classifies biomes by mean annual temperature and precipitation. This implementation extends the scheme to ~30 biome types.

### Extended Whittaker Diagram

Classification proceeds by elevation tier, then temperature, then moisture:

```
Elevation Tiers:
  > 0.8     → Snow Peak / Alpine
  0.65-0.8  → Mountain / Alpine Meadow
  0.33-0.65 → Land biomes (temperature × moisture matrix)
  0.3-0.33  → Beach / River Bank
  0.2-0.3   → Ocean
  < 0.2     → Deep Ocean

Temperature × Moisture matrix (land tier):
          │  Dry (<0.15) │  Semi-arid  │  Moderate  │  Moist   │  Wet (>0.7)
──────────┼──────────────┼─────────────┼────────────┼──────────┼────────────
Very Cold │  Tundra      │  Tundra     │  Tundra    │  Tundra  │  Ice Cap
Cold      │  Cold Desert │  Scrubland  │  Boreal F. │  Boreal  │  Boreal F.
Cool      │  Scrubland   │  Temp. Gras.│  Temp. F.  │  Temp. F.│  Temp. Rain.
Warm Temp │  Desert      │  Savanna    │  Temp. F.  │  Temp. F.│  Temp. Rain.
Warm      │  Hot Desert  │  Savanna    │  Trop. F.  │  Trop. F.│  Trop. Rain.
Hot       │  Hot Desert  │  Desert     │  Savanna   │  Trop. F.│  Mangrove
```

River adjacency and high moisture override some biome assignments (e.g., river banks, marshes, swamps).

---

## Stage 7: Detail Pass

**Real-world basis:** Vegetation density correlates with moisture and temperature; soil depth depends on erosion, sedimentation, and parent rock weathering; ore deposits form in specific host rocks based on geological processes (hydrothermal veins, magmatic segregation, sedimentary concentration).

### Ore Deposit Placement

Ore veins are generated using simplex noise to create spatially coherent deposits:

```
ore_noise = noise(x × 12.0 + 500, y × 12.0 + 500)

if elevation > 0.35 AND ore_noise > 0.5:
  richness = (ore_noise - 0.5) × 2.0          ∈ [0, 1]
  rock = geological_column.rockType(mid_depth)
  ore = random_choice(rock.compatibleOres)

  if ore == .gemstone:
    gemstone = random_choice(rock.compatibleGemstones)
```

Each rock type defines geologically appropriate ore compatibility — e.g., pegmatites host platinum and bismuth (as in real pegmatite intrusions), serpentinite hosts chromium and nickel (as in real ophiolite complexes).

### Gemstone Selection

When an ore deposit is classified as `.gemstone`, a specific gemstone variety is chosen from the host rock's compatibility list. This models how real gemstones form in specific geological environments:

- **Intrusive igneous** (pegmatite, granite): Diamond, emerald, ruby, sapphire — high-pressure crystallization
- **Metamorphic** (marble, schist, serpentinite): Ruby, sapphire, jade, lapis — recrystallization under heat/pressure
- **Sedimentary**: Amethyst, garnet, onyx — secondary mineralization in cavities
- **Volcanic**: Opal, garnet, topaz — hydrothermal deposition

---

## Noise Functions

### OpenSimplex2 (2D/3D)

The core noise function is a pure Swift implementation of **OpenSimplex2** (Ken Perlin's improved simplex noise). It maps input coordinates to gradient-based noise in the range [-1, 1].

**Key constants:**
- Skew factor (2D): `F₂ = (√3 - 1) / 2 ≈ 0.366`
- Unskew factor (2D): `G₂ = (3 - √3) / 6 ≈ 0.211`
- 24 gradient vectors (2D), 16 gradient vectors (3D)
- Contribution radius: 0.5 (2D), 0.6 (3D)
- Output scale: 70.0 (2D), 32.0 (3D)

### Fractal Brownian Motion (fBm)

Self-similar noise at multiple scales, modeling the fractal nature of terrain:

```
fBm(x, y) = Σᵢ₌₀ⁿ⁻¹ persistenceⁱ × noise(x × freq × lacunarityⁱ, y × freq × lacunarityⁱ)
           / Σᵢ₌₀ⁿ⁻¹ persistenceⁱ

Default: 6 octaves, frequency 1.0, lacunarity 2.0, persistence 0.5
```

### Ridged Multifractal

Creates sharp ridge features by folding noise around zero:

```
signal = (1.0 - |noise(x, y)|)²
weight = clamp(signal × gain, 0, 1)

Each octave: value += signal × persistenceⁱ × weight
```

This produces the sharp, interconnected ridge patterns seen in real mountain ranges.

### Domain Warping

Adds organic distortion by using noise to offset sampling coordinates:

```
warp_x = noise(x, y) × strength
warp_y = noise(x + 5.2, y + 1.3) × strength
result = noise(x + warp_x, y + warp_y)
```

---

## Deterministic Seeding

All randomness flows through **Xoshiro256\*\***, a fast, high-quality 256-bit state PRNG. The seed expansion uses SplitMix64:

```
SplitMix64 step:
  z = (state += 0x9e3779b97f4a7c15)
  z = (z ^ (z >> 30)) × 0xbf58476d1ce4e5b9
  z = (z ^ (z >> 27)) × 0x94d049bb133111eb
  return z ^ (z >> 31)

Xoshiro256** output:
  result = rotl(state[1] × 5, 7) × 9
```

Each pipeline stage **forks** a child RNG using FNV-1a hash of a label string (e.g., "tectonic", "erosion"), ensuring that adding/removing stages doesn't alter the randomness of other stages.

---

## Rock Classification

Rocks are classified into geological groups following standard petrology:

```
                    ┌─────────────────────┐
                    │    39 Rock Types     │
                    └──────────┬──────────┘
          ┌────────────────────┼────────────────────┐
    Sedimentary (8)      Igneous (8)         Metamorphic (9)
    ├─ Chalk             ├─ Basalt (ext.)    ├─ Slate
    ├─ Sandstone         ├─ Andesite (ext.)  ├─ Phyllite
    ├─ Siltstone         ├─ Rhyolite (ext.)  ├─ Schist
    ├─ Mudstone          ├─ Tuff (ext.)      ├─ Marble
    ├─ Limestone         ├─ Pumice (ext.)    ├─ Quartzite
    ├─ Shale             ├─ Granite (int.)   ├─ Gneiss
    ├─ Travertine        ├─ Diorite (int.)   ├─ Serpentinite
    └─ Conglomerate      ├─ Gabbro (int.)    ├─ Soapstone
                         └─ Pegmatite (int.) └─ Migmatite

    Volcanic Glass (1)        Fantasy (13)
    └─ Obsidian               ├─ Deepslate      (deep crust)
                              ├─ Glowstone      (magical)
                              ├─ Shadowrock      ...
                              ├─ Crystalrock
                              ├─ Bloodstone
                              ├─ Voidrock
                              ├─ Moonstone
                              ├─ Sunrock
                              ├─ Dragonrock
                              ├─ Runestone
                              ├─ Aetherstone
                              └─ Livingrock
```

**Hardness** (0–1) follows real Mohs-scale ordering: chalk (0.15) < shale (0.20) < sandstone (0.30) < basalt (0.65) < granite (0.80) < quartzite (0.85) < obsidian (0.90).

**Ore compatibility** reflects real mineralization processes:
- Sedimentary: coal (organic accumulation), iron/tin (banded iron formations), lead/zinc (Mississippi Valley-type deposits)
- Igneous intrusive: gold, silver, gemstones (hydrothermal veins in cooling plutons), chromium (chromite in mafic magma)
- Metamorphic: gold (orogenic lode deposits), tungsten (contact metamorphism skarns)
- Pegmatite: platinum, bismuth, gemstones (coarse-grained late-stage crystallization)

---

## References

The algorithms draw from established techniques in procedural generation and computational geology:

- **Simplex noise:** Ken Perlin, "Improving Noise" (2002); OpenSimplex2 variant
- **Hydraulic erosion:** Hans Theobald Beyer, "Implementation of a method for Hydraulic Erosion" (2015)
- **Planchon-Darboux sink filling:** Planchon & Darboux, "A fast, simple and versatile algorithm to fill the depressions of digital elevation models" (2001)
- **Whittaker biome diagram:** Robert Whittaker, "Communities and Ecosystems" (1975)
- **Xoshiro256\*\*:** Blackman & Vigna, "Scrambled Linear Pseudorandom Number Generators" (2021)
- **Voronoi tessellation:** Georgy Voronoy (1908); Fortune's algorithm variant
- **Ridged multifractal:** Ken Musgrave, "Texturing and Modeling: A Procedural Approach" (1994)
