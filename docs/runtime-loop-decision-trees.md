# Runtime Loop & Decision Trees

This document details the primary runtime loop for each dwarf during each tick and the decision trees governing behavior, based on Dwarf Fortress mechanics research.

**Sources:**
- [DF Wiki - Time](https://dwarffortresswiki.org/index.php/DF2014:Time)
- [DF Wiki - Speed](https://dwarffortresswiki.org/index.php/v0.34:Speed)
- [DF Wiki - Thirst](https://dwarffortresswiki.org/index.php/DF2014:Thirst)
- [DF Wiki - Sleep](https://dwarffortresswiki.org/index.php/DF2014:Sleep)
- [DF Wiki - Labor](https://dwarffortresswiki.org/index.php/DF2014:Labor)

---

## Table of Contents

1. [Game Tick Architecture](#1-game-tick-architecture)
2. [Unit Update Loop](#2-unit-update-loop)
3. [Action Counter System](#3-action-counter-system)
4. [Need Thresholds & Counters](#4-need-thresholds--counters)
5. [Dwarf State Machine](#5-dwarf-state-machine)
6. [Decision Trees](#6-decision-trees)
7. [Job Assignment System](#7-job-assignment-system)
8. [Special Behaviors](#8-special-behaviors)

---

## 1. Game Tick Architecture

### Time Units

| Mode | 1 Tick = | Notes |
|------|----------|-------|
| Fortress Mode | 72 in-game seconds | 144x compression |
| Adventurer Mode | 0.5 in-game seconds | Real-time feel |

### Calendar Conversions (Fortress Mode)

```
1 tick    = 72 seconds
1 hour    = 50 ticks
1 day     = 1,200 ticks
1 month   = 33,600 ticks (28 days)
1 season  = 100,800 ticks (3 months)
1 year    = 403,200 ticks (12 months)
```

### Update Frequencies

```mermaid
flowchart TD
    subgraph EveryTick["Every Tick (1)"]
        T1["Unit Movement"]
        T2["Fluid Simulation"]
        T3["Temperature Transfer"]
        T4["Combat Resolution"]
        T5["Action Counter Decrement"]
        T6["Vegetation Growth"]
        T7["Vermin Updates"]
        T8["Building States"]
    end

    subgraph Every10["Every 10 Ticks"]
        E10["Season Advancement"]
        E10b["Weather Updates"]
        E10c["Map Changes"]
    end

    subgraph Every50["Every 50 Ticks"]
        E50["Tavern/Temple Updates"]
        E50b["Library Updates"]
        E50c["Item Deletion Checks"]
    end

    subgraph Every100["Every 100 Ticks"]
        E100["Job Assignment Auction"]
        E100b["Strange Mood Checks"]
        E100c["Item Rotting"]
        E100d["Job Applications"]
    end

    subgraph Every1000["Every 1000 Ticks"]
        E1000["Object Cleanup"]
        E1000b["Memory Management"]
    end
```

### Main Game Loop

```
MAIN_LOOP:
    for each tick:
        # Phase 1: World Updates
        update_fluids()
        update_temperature()
        update_weather()
        update_vegetation()

        # Phase 2: Unit Updates
        for each unit in active_units:
            unit.tick_update()

        # Phase 3: Building/Job Updates
        update_buildings()

        # Phase 4: Periodic Checks (staggered)
        if tick % 10 == 0:
            check_seasons()
        if tick % 50 == 0:
            update_social_locations()
        if tick % 100 == 0:
            run_job_auction()
            check_strange_moods()
        if tick % 1000 == 0:
            cleanup_objects()

        # Phase 5: Combat Resolution
        resolve_pending_combats()

        # Phase 6: Pathfinding Queue
        process_pathfinding_requests()
```

---

## 2. Unit Update Loop

### Per-Tick Unit Update

```mermaid
flowchart TD
    Start["Unit.tick_update()"] --> CheckAlive{"Is Alive?"}

    CheckAlive -->|No| ProcessDeath["Process Death"]
    CheckAlive -->|Yes| UpdateCounters["Update Internal Counters"]

    UpdateCounters --> IncrementNeeds["Increment Need Counters\n(hunger++, thirst++, drowsiness++)"]
    IncrementNeeds --> DecrementAction["Decrement Action Counter"]

    DecrementAction --> CheckAction{"Action Counter == 0?"}

    CheckAction -->|No| End["End Tick"]
    CheckAction -->|Yes| CanAct["Can Take Action"]

    CanAct --> CheckState{"Current State?"}

    CheckState -->|IDLE| IdleDecision["Run Idle Decision Tree"]
    CheckState -->|WORKING| WorkDecision["Continue Work / Check Interrupt"]
    CheckState -->|MOVING| MoveDecision["Continue Move / Arrive"]
    CheckState -->|FIGHTING| CombatDecision["Combat Decision Tree"]
    CheckState -->|SLEEPING| SleepDecision["Check Wake Condition"]
    CheckState -->|EATING| EatDecision["Continue Eating"]
    CheckState -->|DRINKING| DrinkDecision["Continue Drinking"]

    IdleDecision --> SetAction["Set New Action Counter"]
    WorkDecision --> SetAction
    MoveDecision --> SetAction
    CombatDecision --> SetAction
    SleepDecision --> SetAction
    EatDecision --> SetAction
    DrinkDecision --> SetAction

    SetAction --> End
```

### Pseudocode: Unit Tick Update

```python
class Unit:
    def tick_update(self):
        if not self.is_alive:
            self.process_death()
            return

        # 1. Update internal counters
        self.hunger += 1
        self.thirst += 1
        self.drowsiness += 1

        # 2. Decrement action counter
        self.action_counter -= 1

        # 3. Check if can act this tick
        if self.action_counter > 0:
            return  # Still waiting

        # 4. Process current state
        match self.state:
            case State.IDLE:
                self.idle_decision_tree()
            case State.WORKING:
                self.work_update()
            case State.MOVING:
                self.movement_update()
            case State.FIGHTING:
                self.combat_update()
            case State.SLEEPING:
                self.sleep_update()
            case State.EATING:
                self.eat_update()
            case State.DRINKING:
                self.drink_update()

        # 5. Set next action counter based on speed
        self.action_counter = self.calculate_action_delay()
```

---

## 3. Action Counter System

### Speed Calculation

The speed system determines how many ticks pass between a unit's actions.

```
Base Speed: 900 (default for most creatures)
Higher number = SLOWER actions
```

### Action Delay Formula

```python
def calculate_action_delay(self) -> int:
    """
    Speed value determines delay between actions.
    - Hundreds digit: full turns to skip
    - Tens/ones: probability of extra turn

    Example: Speed 975
    - Skip 9 turns guaranteed
    - 75% chance to skip 10th turn
    """
    base_speed = self.race.base_speed  # e.g., 900

    # Apply modifiers
    effective_speed = base_speed
    effective_speed = self.apply_agility_modifier(effective_speed)
    effective_speed = self.apply_encumbrance_modifier(effective_speed)
    effective_speed = self.apply_status_modifiers(effective_speed)

    # Convert to delay
    full_turns = effective_speed // 100
    remainder = effective_speed % 100

    # Probabilistic extra delay
    if random.randint(1, 100) <= remainder:
        full_turns += 1

    return full_turns
```

### Speed Modifiers

| Modifier | Effect | Notes |
|----------|--------|-------|
| Agility | Multiplier on base speed | Higher = faster |
| Strength | Affects fast gaits | Running, sprinting |
| Encumbrance | Slows movement | Based on carry weight |
| Lying Down | ~50% slower | Knocked down |
| Stunned | ~50% slower | After heavy hit |
| Drowsiness | Progressive slowdown | Based on counter |
| Hunger | Progressive slowdown | After threshold |
| Thirst | Progressive slowdown | After threshold |
| Armor | Adds delay | Mitigated by skill |
| Sneaking | Adds delay | Mitigated by Ambusher |
| Swimming | Different speed | Mitigated by Swimmer |

### Movement Action Counter

```python
def start_movement(self, destination: Position):
    """Initialize movement to adjacent tile."""
    self.movement_target = destination
    self.state = State.MOVING

    # Base movement: 8 ticks per tile
    base_ticks = 8

    # Apply terrain modifiers
    terrain = self.world.get_terrain(destination)
    base_ticks *= terrain.movement_cost

    # Apply unit speed
    base_ticks = self.apply_speed_modifiers(base_ticks)

    self.action_counter = base_ticks
```

---

## 4. Need Thresholds & Counters

### Counter Increment Rate

All need counters increment by **1 per tick**.

```
Per day:    +1,200
Per month:  +33,600
Per year:   +403,200
```

### Thirst Thresholds

```mermaid
flowchart LR
    subgraph Thirst["Thirst Counter Thresholds"]
        T0["0"] --> T20["20,000\nConsider drinking\n(1/120 chance if idle)"]
        T20 --> T22["22,000\nDecide to drink\n(if idle)"]
        T22 --> T25["25,000\n'Thirsty' indicator"]
        T25 --> T35["35,000\nUnhappy thought\nCANCEL current job"]
        T35 --> T50["50,000\n'Dehydrated' indicator"]
        T50 --> T60["60,000\nDehydration thought"]
        T60 --> T75["75,000\nDEATH"]
    end
```

### Hunger Thresholds

```mermaid
flowchart LR
    subgraph Hunger["Hunger Counter Thresholds"]
        H0["0"] --> H40["40,000\nConsider eating\n(1/120 chance if idle)"]
        H40 --> H45["45,000\nDecide to eat\n(if idle)"]
        H45 --> H50["50,000\n'Hungry' indicator"]
        H50 --> H65["65,000\nUnhappy thought\nCANCEL current job"]
        H65 --> H75["75,000\n'Starving' indicator"]
        H75 --> H100["~100,000\nDEATH"]
    end
```

### Drowsiness Thresholds

```mermaid
flowchart LR
    subgraph Drowsiness["Drowsiness Counter Thresholds"]
        D0["0"] --> D50["50,000\nConsider sleeping\n(1/120 chance if idle)"]
        D50 --> D54["54,000\nDecide to sleep\n(if idle)"]
        D54 --> D576["57,600\n'Drowsy' indicator"]
        D576 --> D65["65,000\nTiredness thought"]
        D65 --> D150["150,000\n'Very Drowsy'"]
        D150 --> D160["160,000\nExhaustion thought"]
        D160 --> D200["200,000\nGo INSANE"]
    end
```

### Need Satisfaction

```python
NEED_SATISFACTION = {
    'thirst': -50_000,    # Completing drink
    'hunger': -50_000,    # Completing eat
    'drowsiness': -19,    # Per tick while sleeping
}

# Sleep recovery: ~2,650-2,900 ticks to fully recover
# (~5% of time spent sleeping)
```

### Need Check Decision

```python
def check_need_interrupt(self) -> Optional[NeedType]:
    """
    Check if a need is urgent enough to interrupt current activity.
    Returns the most urgent need or None.
    """
    # Critical thresholds that force job cancellation
    CRITICAL_THIRST = 35_000
    CRITICAL_HUNGER = 65_000
    CRITICAL_DROWSINESS = 150_000

    if self.thirst >= CRITICAL_THIRST:
        return NeedType.DRINK
    if self.hunger >= CRITICAL_HUNGER:
        return NeedType.EAT
    if self.drowsiness >= CRITICAL_DROWSINESS:
        return NeedType.SLEEP

    return None

def check_need_consideration(self) -> Optional[NeedType]:
    """
    Check if unit should consider satisfying a need (when idle).
    Uses probabilistic check for soft thresholds.
    """
    CONSIDER_THIRST = 20_000
    CONSIDER_HUNGER = 40_000
    CONSIDER_DROWSINESS = 50_000

    DECIDE_THIRST = 22_000
    DECIDE_HUNGER = 45_000
    DECIDE_DROWSINESS = 54_000

    # Hard decision thresholds
    if self.thirst >= DECIDE_THIRST:
        return NeedType.DRINK
    if self.hunger >= DECIDE_HUNGER:
        return NeedType.EAT
    if self.drowsiness >= DECIDE_DROWSINESS:
        return NeedType.SLEEP

    # Soft consideration (1/120 chance per tick)
    if random.randint(1, 120) == 1:
        if self.thirst >= CONSIDER_THIRST:
            return NeedType.DRINK
        if self.hunger >= CONSIDER_HUNGER:
            return NeedType.EAT
        if self.drowsiness >= CONSIDER_DROWSINESS:
            return NeedType.SLEEP

    return None
```

---

## 5. Dwarf State Machine

### Primary States

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Moving: path_to_destination
    Idle --> Working: job_assigned
    Idle --> Socializing: social_need
    Idle --> Praying: prayer_need
    Idle --> Eating: hunger_threshold
    Idle --> Drinking: thirst_threshold
    Idle --> Sleeping: drowsiness_threshold

    Moving --> Idle: arrived
    Moving --> Working: arrived_at_job
    Moving --> Fighting: threat_encountered
    Moving --> Eating: critical_hunger
    Moving --> Drinking: critical_thirst

    Working --> Idle: job_complete
    Working --> Moving: need_materials
    Working --> Fighting: attacked
    Working --> Eating: critical_hunger
    Working --> Drinking: critical_thirst
    Working --> Sleeping: critical_drowsiness

    Socializing --> Idle: social_complete
    Socializing --> Moving: move_to_new_target
    Socializing --> Fighting: threat
    Socializing --> Eating: hunger
    Socializing --> Drinking: thirst

    Fighting --> Idle: combat_ended
    Fighting --> Fleeing: morale_break
    Fighting --> Unconscious: pain_threshold
    Fighting --> Dead: fatal_wound

    Fleeing --> Idle: safe
    Fleeing --> Fighting: cornered

    Eating --> Idle: finished_eating
    Drinking --> Idle: finished_drinking
    Sleeping --> Idle: fully_rested

    Unconscious --> Idle: recovered
    Unconscious --> Dead: bleed_out

    Praying --> Idle: prayer_complete
```

### State Priorities (Highest to Lowest)

```
1. DEAD / UNCONSCIOUS (terminal states)
2. FIGHTING (threat response)
3. FLEEING (survival)
4. CRITICAL_NEEDS (thirst > hunger > sleep)
5. MILITARY_ORDERS (if soldier on duty)
6. WORKING (assigned job)
7. SOFT_NEEDS (consider eating/drinking/sleeping)
8. SOCIALIZING / IDLE_ACTIVITIES
9. IDLE (no activity)
```

### State Transition Logic

```python
class UnitStateMachine:
    def evaluate_state_transition(self):
        """
        Evaluate if unit should transition to a new state.
        Called when action counter reaches 0.
        """
        # Priority 1: Check death/unconscious
        if self.health.is_dead:
            return State.DEAD
        if self.health.is_unconscious:
            return State.UNCONSCIOUS

        # Priority 2: Combat threat
        if self.has_hostile_in_range():
            return State.FIGHTING

        # Priority 3: Flee check (personality-based)
        if self.should_flee():
            return State.FLEEING

        # Priority 4: Critical needs (interrupt anything)
        critical_need = self.check_need_interrupt()
        if critical_need:
            return self.get_need_state(critical_need)

        # Priority 5: Military orders (if on duty)
        if self.is_military_on_duty():
            return self.evaluate_military_orders()

        # Priority 6: Continue current job
        if self.current_job and not self.current_job.is_complete:
            return State.WORKING

        # Priority 7: Soft needs (if idle)
        soft_need = self.check_need_consideration()
        if soft_need:
            return self.get_need_state(soft_need)

        # Priority 8: Social activities
        if self.should_socialize():
            return State.SOCIALIZING

        # Priority 9: Find new job or idle
        return State.IDLE
```

---

## 6. Decision Trees

### Master Idle Decision Tree

```mermaid
flowchart TD
    Start["IDLE State"] --> CheckThreat{"Hostile\nNearby?"}

    CheckThreat -->|Yes| Fight["Enter FIGHTING"]
    CheckThreat -->|No| CheckCritical{"Critical\nNeed?"}

    CheckCritical -->|Thirst ≥ 35k| Drink["Find Drink"]
    CheckCritical -->|Hunger ≥ 65k| Eat["Find Food"]
    CheckCritical -->|Drowsy ≥ 150k| Sleep["Find Bed"]
    CheckCritical -->|None| CheckMilitary{"On Military\nDuty?"}

    CheckMilitary -->|Yes| MilOrders["Follow Orders"]
    CheckMilitary -->|No| CheckJob{"Has Assigned\nJob?"}

    CheckJob -->|Yes| GoToJob["Move to Job Site"]
    CheckJob -->|No| CheckSoftNeeds{"Soft Need\nThreshold?"}

    CheckSoftNeeds -->|Thirst 20-35k| MaybeDrink{"1/120\nChance?"}
    CheckSoftNeeds -->|Hunger 40-65k| MaybeEat{"1/120\nChance?"}
    CheckSoftNeeds -->|Drowsy 50-150k| MaybeSleep{"1/120\nChance?"}
    CheckSoftNeeds -->|Below All| CheckJobAvail{"Job\nAvailable?"}

    MaybeDrink -->|Yes| Drink
    MaybeDrink -->|No| CheckJobAvail
    MaybeEat -->|Yes| Eat
    MaybeEat -->|No| CheckJobAvail
    MaybeSleep -->|Yes| Sleep
    MaybeSleep -->|No| CheckJobAvail

    CheckJobAvail -->|Yes| ClaimJob["Claim Job"]
    CheckJobAvail -->|No| IdleActivity["Idle Activity"]

    IdleActivity --> WhatActivity{"Personality\nCheck"}
    WhatActivity -->|Social| Socialize["Go to Meeting Area"]
    WhatActivity -->|Religious| Pray["Go to Temple"]
    WhatActivity -->|Martial| Train["Self-Training"]
    WhatActivity -->|None| Wander["Wander"]
```

### Job Selection Decision Tree

```mermaid
flowchart TD
    Start["Find Job"] --> GetJobs["Get Available Jobs"]
    GetJobs --> FilterLabor["Filter by\nEnabled Labors"]

    FilterLabor --> HasJobs{"Any Jobs?"}
    HasJobs -->|No| NoJob["Return: No Job"]

    HasJobs -->|Yes| ScoreJobs["Score Each Job"]

    ScoreJobs --> CalcScore["For Each Job:\nscore = base_priority\n+ skill_bonus\n- distance_penalty\n+ need_satisfaction"]

    CalcScore --> SortJobs["Sort by Score\n(Descending)"]
    SortJobs --> TryBest["Try Best Job"]

    TryBest --> CanReach{"Can Path\nTo Job?"}
    CanReach -->|No| TryNext["Try Next Job"]
    TryNext --> MoreJobs{"More Jobs?"}
    MoreJobs -->|Yes| TryBest
    MoreJobs -->|No| NoJob

    CanReach -->|Yes| ClaimJob["Claim Job"]
    ClaimJob --> Return["Return: Job Assigned"]
```

### Combat Decision Tree

```mermaid
flowchart TD
    Start["FIGHTING State"] --> CheckMorale{"Morale\nCheck"}

    CheckMorale -->|Break| Flee["Enter FLEEING"]
    CheckMorale -->|Hold| EvalSituation["Evaluate Situation"]

    EvalSituation --> HasWeapon{"Has\nWeapon?"}
    HasWeapon -->|No| Wrestling["Wrestling Attack"]
    HasWeapon -->|Yes| WeaponType{"Weapon\nType?"}

    WeaponType -->|Ranged| RangedCheck{"In Range?"}
    WeaponType -->|Melee| MeleeCheck{"Adjacent?"}

    RangedCheck -->|No| MoveCloser["Move to Range"]
    RangedCheck -->|Yes| RangedAttack["Ranged Attack"]

    MeleeCheck -->|No| Charge["Charge Target"]
    MeleeCheck -->|Yes| MeleeDecision{"Attack\nType?"}

    MeleeDecision --> AttackStyle["Choose Based On:\n- Weapon type\n- Target armor\n- Skill level\n- Target body part"]

    AttackStyle --> Heavy["Heavy Attack\n(slower, more damage)"]
    AttackStyle --> Quick["Quick Attack\n(faster, less damage)"]
    AttackStyle --> Precise["Precise Attack\n(slower, accurate)"]
    AttackStyle --> Wild["Wild Attack\n(fast, inaccurate)"]

    Wrestling --> WrestleType["Choose:\n- Grab\n- Push\n- Joint Lock\n- Strangle"]
```

### Need Satisfaction Decision Tree

```mermaid
flowchart TD
    subgraph Drinking["Drinking Decision"]
        D1["Need: DRINK"] --> D2{"Alcohol\nAvailable?"}
        D2 -->|Yes| D3["Path to Alcohol"]
        D2 -->|No| D4{"Well\nAvailable?"}
        D4 -->|Yes| D5["Path to Well"]
        D4 -->|No| D6{"Water Source?"}
        D6 -->|Yes| D7["Path to Water"]
        D6 -->|No| D8["Cancel: No Drink"]
    end

    subgraph Eating["Eating Decision"]
        E1["Need: EAT"] --> E2{"Prepared Food?"}
        E2 -->|Yes| E3["Path to Food"]
        E2 -->|No| E4{"Raw Food?"}
        E4 -->|Yes| E5["Path to Raw Food"]
        E4 -->|No| E6["Cancel: No Food"]
    end

    subgraph Sleeping["Sleeping Decision"]
        S1["Need: SLEEP"] --> S2{"Owned Bed?"}
        S2 -->|Yes| S3["Path to Own Bed"]
        S2 -->|No| S4{"Any Free Bed?"}
        S4 -->|Yes| S5["Path to Nearest Bed"]
        S4 -->|No| S6["Sleep on Ground"]
    end
```

---

## 7. Job Assignment System

### Job Auction (Every 100 Ticks)

```mermaid
sequenceDiagram
    participant G as Game
    participant J as Job Queue
    participant U as Units

    G->>J: Get Unassigned Jobs

    loop For Each Job
        J->>U: Broadcast Job Available

        loop For Each Eligible Unit
            U->>U: Calculate Bid Score
            Note over U: Score = Priority<br/>+ Skill Bonus<br/>- Distance Penalty
            U->>J: Submit Bid
        end

        J->>J: Select Highest Bidder
        J->>U: Assign Job to Winner
    end
```

### Job Scoring Formula

```python
def calculate_job_score(self, job: Job) -> float:
    """
    Calculate a score for job assignment priority.
    Higher score = more likely to be assigned.
    """
    score = 0.0

    # Base priority (1-7, inverted so 1 is best)
    score += (8 - job.priority) * 100

    # Skill bonus
    if job.required_skill:
        skill_level = self.get_skill_level(job.required_skill)
        score += skill_level * 10

    # Distance penalty
    distance = self.position.distance_to(job.position)
    score -= distance * 2

    # Workshop assignment bonus
    if job.workshop and job.workshop.is_assigned_to(self):
        score += 50

    # Need satisfaction bonus
    if job.satisfies_need:
        need_level = self.get_need_level(job.satisfies_need)
        score += need_level / 1000

    return score
```

### Job Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Pending: Job Created

    Pending --> Claimed: Unit Claims Job
    Pending --> Cancelled: Requirements Invalid

    Claimed --> InProgress: Unit Arrives
    Claimed --> Pending: Unit Interrupted

    InProgress --> Complete: Work Finished
    InProgress --> Suspended: Missing Materials
    InProgress --> Pending: Unit Interrupted

    Suspended --> InProgress: Materials Available
    Suspended --> Cancelled: Timeout

    Complete --> [*]
    Cancelled --> [*]
```

---

## 8. Special Behaviors

### Strange Mood Trigger

```mermaid
flowchart TD
    Start["Every 100 Ticks"] --> CheckPop{"Population\n≥ 20?"}
    CheckPop -->|No| End["No Mood"]
    CheckPop -->|Yes| RollChance["Roll Mood Chance"]

    RollChance --> Triggered{"Mood\nTriggered?"}
    Triggered -->|No| End
    Triggered -->|Yes| SelectUnit["Select Eligible Unit"]

    SelectUnit --> Eligible{"Unit Criteria:\n- Has STRANGE_MOODS\n- Permanent resident\n- Not military profession\n- Not already mooded"}

    Eligible -->|None| End
    Eligible -->|Found| SelectMood["Select Mood Type"]

    SelectMood --> MoodType{"Random:\n- Fey\n- Secretive\n- Possessed\n- Fell\n- Macabre"}

    MoodType --> ClaimWorkshop["Claim Workshop"]
    ClaimWorkshop --> GatherMaterials["Gather Materials\n(ignores all needs)"]
    GatherMaterials --> CreateArtifact["Create Artifact"]
    CreateArtifact --> Success{"Success?"}

    Success -->|Yes| Legendary["Gain Legendary Skill"]
    Success -->|No| Insane["Go Insane"]
```

### Military Schedule State

```mermaid
stateDiagram-v2
    [*] --> Civilian: Not in Squad

    Civilian --> OffDuty: Assigned to Squad

    OffDuty --> Training: Schedule = Train
    OffDuty --> Stationed: Schedule = Station
    OffDuty --> Patrolling: Schedule = Patrol
    OffDuty --> Defending: Alert + Enemies

    Training --> OffDuty: Schedule Ends
    Training --> Defending: Alert + Enemies

    Stationed --> OffDuty: Schedule Ends
    Stationed --> Fighting: Enemy Spotted

    Patrolling --> OffDuty: Schedule Ends
    Patrolling --> Fighting: Enemy Spotted

    Defending --> OffDuty: Threat Cleared
    Defending --> Fighting: Enemy in Range

    Fighting --> Stationed: Enemy Killed
    Fighting --> Patrolling: Enemy Killed
    Fighting --> Fleeing: Morale Break
```

### Break/Idle Activity Selection

```python
def select_idle_activity(self) -> IdleActivity:
    """
    Select an idle activity based on personality and needs.
    """
    activities = []

    # Check social need
    if self.needs.gregariousness > 0:
        activities.append((
            IdleActivity.SOCIALIZE,
            self.personality.get_facet(Facet.GREGARIOUSNESS)
        ))

    # Check religious need
    for deity in self.worshipped_deities:
        if self.needs.prayer[deity] > 0:
            activities.append((
                IdleActivity.PRAY,
                self.personality.get_belief_strength(Belief.TRADITION)
            ))

    # Check martial training (if disciplined soldier)
    if self.is_military and self.personality.get_facet(Facet.DUTIFULNESS) > 60:
        activities.append((
            IdleActivity.SELF_TRAIN,
            self.personality.get_facet(Facet.PERSEVERANCE)
        ))

    # Check art appreciation
    if self.personality.get_facet(Facet.ART_INCLINED) > 50:
        activities.append((
            IdleActivity.APPRECIATE_ART,
            self.personality.get_facet(Facet.ART_INCLINED)
        ))

    # Check nature need
    if self.personality.get_belief_strength(Belief.NATURE) > 0:
        activities.append((
            IdleActivity.WANDER_OUTSIDE,
            self.personality.get_belief_strength(Belief.NATURE)
        ))

    # Default: wander
    if not activities:
        return IdleActivity.WANDER

    # Weighted random selection
    total = sum(weight for _, weight in activities)
    roll = random.randint(1, total)

    cumulative = 0
    for activity, weight in activities:
        cumulative += weight
        if roll <= cumulative:
            return activity

    return IdleActivity.WANDER
```

---

## Summary: Complete Tick Processing

```python
def process_unit_tick(unit: Unit):
    """
    Complete tick processing for a single unit.
    """
    # 1. Skip if dead
    if unit.is_dead:
        return

    # 2. Increment need counters
    unit.hunger += 1
    unit.thirst += 1
    unit.drowsiness += 1

    # 3. Process any active syndromes/effects
    for syndrome in unit.active_syndromes:
        syndrome.tick(unit)

    # 4. Decrement action counter
    unit.action_counter -= 1

    # 5. If can't act yet, return
    if unit.action_counter > 0:
        return

    # 6. State-specific update
    match unit.state:
        case State.IDLE:
            # Run full decision tree
            new_state = unit.idle_decision_tree()
            unit.transition_to(new_state)

        case State.MOVING:
            if unit.has_arrived():
                unit.arrive_at_destination()
            else:
                unit.continue_movement()

        case State.WORKING:
            # Check for interrupts
            interrupt = unit.check_need_interrupt()
            if interrupt:
                unit.suspend_job()
                unit.transition_to(interrupt.get_state())
            elif unit.has_hostile_nearby():
                unit.suspend_job()
                unit.transition_to(State.FIGHTING)
            else:
                unit.continue_work()

        case State.FIGHTING:
            unit.combat_decision_tree()

        case State.SLEEPING:
            unit.drowsiness -= 19  # Recovery rate
            if unit.drowsiness <= 0:
                unit.drowsiness = 0
                unit.transition_to(State.IDLE)

        case State.EATING:
            if unit.eating_progress >= 100:
                unit.hunger -= 50_000
                unit.hunger = max(0, unit.hunger)
                unit.transition_to(State.IDLE)
            else:
                unit.eating_progress += unit.get_eating_speed()

        case State.DRINKING:
            if unit.drinking_progress >= 100:
                unit.thirst -= 50_000
                unit.thirst = max(0, unit.thirst)
                unit.transition_to(State.IDLE)
            else:
                unit.drinking_progress += unit.get_drinking_speed()

    # 7. Set next action delay
    unit.action_counter = unit.calculate_action_delay()
```

---

## Constants Reference

### Need Thresholds

```python
class NeedThresholds:
    # Thirst
    THIRST_CONSIDER = 20_000
    THIRST_DECIDE = 22_000
    THIRST_INDICATOR = 25_000
    THIRST_CRITICAL = 35_000
    THIRST_DEHYDRATED = 50_000
    THIRST_DEATH = 75_000

    # Hunger
    HUNGER_CONSIDER = 40_000
    HUNGER_DECIDE = 45_000
    HUNGER_INDICATOR = 50_000
    HUNGER_CRITICAL = 65_000
    HUNGER_STARVING = 75_000
    HUNGER_DEATH = 100_000

    # Drowsiness
    DROWSY_CONSIDER = 50_000
    DROWSY_DECIDE = 54_000
    DROWSY_INDICATOR = 57_600
    DROWSY_TIRED_THOUGHT = 65_000
    DROWSY_VERY = 150_000
    DROWSY_EXHAUSTED = 160_000
    DROWSY_INSANE = 200_000

    # Satisfaction amounts
    DRINK_SATISFACTION = 50_000
    EAT_SATISFACTION = 50_000
    SLEEP_RECOVERY_PER_TICK = 19
```

### Speed Constants

```python
class SpeedConstants:
    DEFAULT_SPEED = 900
    MOVEMENT_BASE_TICKS = 8
    CONSIDERATION_CHANCE = 120  # 1 in 120 per tick

    # Terrain costs
    TERRAIN_FLOOR = 1.0
    TERRAIN_STAIRS = 2.0
    TERRAIN_WATER = 5.0
    TERRAIN_DIFFICULT = 3.0
```

### Update Frequencies

```python
class UpdateFrequency:
    EVERY_TICK = 1
    WEATHER = 10
    SOCIAL_ZONES = 50
    JOB_AUCTION = 100
    STRANGE_MOOD_CHECK = 100
    OBJECT_CLEANUP = 1000
```
