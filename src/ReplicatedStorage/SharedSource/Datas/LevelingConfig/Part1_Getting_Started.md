# LevelingConfig Documentation - Part 1: Getting Started

## Table of Contents

- [Overview](#overview)
- [Configuration Structure](#configuration-structure)
- [Level Types](#level-types)
- [Rebirth System](#rebirth-system)
- [Scaling Formulas](#scaling-formulas)
- [Examples](#examples)

---

## Overview

The **LevelingConfig** is a centralized configuration system that defines all level types, their scaling formulas, and rebirth behaviors for the game. It enables you to create multiple independent progression systems (e.g., Levels, Ranks, Stages) with different growth rates and rebirth mechanics.

### Key Features

- **Multiple Level Types**: Define unlimited progression systems (levels, ranks, stages, etc.)
- **Flexible Scaling**: Use global formula templates or custom per-type parameters
- **Rebirth Support**: Configurable rebirth systems with multiple rebirth families
- **Auto-Profile Generation**: Automatically generates profile data structure from config
- **Type-Safe**: Config-driven design reduces hardcoding and errors

### Location

```
src/ReplicatedStorage/SharedSource/Datas/LevelingConfig/init.lua
```

---

## Configuration Structure

The LevelingConfig table has three main sections:

```lua
LevelingConfig = {
    Types = { ... },      -- Level type definitions
    Rebirths = { ... },   -- Rebirth system configuration
    Scaling = { ... },    -- Global scaling formula templates
}
```

---

## Level Types

Level types are defined in the `Types` table. Each type represents an independent progression system.

### Type Properties

| Property      | Type       | Required      | Description                                                               |
| ------------- | ---------- | ------------- | ------------------------------------------------------------------------- |
| `Name`        | string     | Yes           | Display name shown to players (e.g., "Level", "Rank")                     |
| `ExpName`     | string     | Yes           | Display name for experience points (e.g., "EXP", "Honor")                 |
| `MaxLevel`    | number     | Conditional\* | Maximum level before rebirth becomes available                            |
| `MaxRebirth`  | number/nil | No            | Max rebirth count (`nil` = unlimited)                                     |
| `RebirthType` | string/nil | No            | Rebirth family to use (`nil` = no rebirth for this type)                  |
| `Scaling`     | table      | Yes           | Scaling formula configuration (see [Scaling Formulas](#scaling-formulas)) |

**Note**: `MaxLevel` is required if `RebirthType` is set (used to determine rebirth eligibility).

### Example Type Definition

```lua
levels = {
    Name = "Level",
    ExpName = "EXP",
    MaxLevel = 100,
    MaxRebirth = 10,
    RebirthType = "rebirth",
    Scaling = { Formula = "Linear" },
}
```

### Type Keys

The key used in the `Types` table (e.g., `levels`, `ranks`) is the **type identifier** used throughout the codebase:

```lua
-- In LevelingConfig
Types = {
    levels = { ... },    -- type identifier = "levels"
    ranks = { ... },     -- type identifier = "ranks"
}

-- In code
LevelService:AddExp(player, 100, "levels")  -- Use the type identifier
LevelController:GetLevelData("ranks")
```

---

## Rebirth System

The rebirth system allows players to reset their level for permanent bonuses. Multiple rebirth "families" can be defined with different names and behaviors.

### Rebirth Configuration

```lua
Rebirths = {
    enabled = true,  -- Global rebirth toggle
    Types = {
        rebirth = {
            Name = "Rebirths",        -- Plural display name
            ShortName = "R",          -- Short prefix (e.g., "R1", "R2")
            ActionName = "Rebirth"    -- Verb shown in UI buttons
        },
        ascension = {
            Name = "Ascensions",
            ShortName = "A",
            ActionName = "Ascend"
        },
    },
}
```

### Rebirth Properties

| Property  | Type    | Description                      |
| --------- | ------- | -------------------------------- |
| `enabled` | boolean | Global toggle for rebirth system |
| `Types`   | table   | Dictionary of rebirth families   |

#### Rebirth Type Properties

| Property     | Type   | Description                                            |
| ------------ | ------ | ------------------------------------------------------ |
| `Name`       | string | Plural display name (e.g., "Rebirths", "Ascensions")   |
| `ShortName`  | string | Short prefix for display (e.g., "R", "A")              |
| `ActionName` | string | Action verb for UI buttons (e.g., "Rebirth", "Ascend") |

### Rebirth Eligibility

A player can rebirth when:

1. Global `Rebirths.enabled` is `true`
2. Level type has a valid `RebirthType` set
3. Player's level ≥ type's `MaxLevel`
4. Player's rebirth count < type's `MaxRebirth` (if set)

### Disabling Rebirths

**For specific level type:**

```lua
tiers = {
    Name = "Tier",
    ExpName = "TP",
    MaxLevel = 60,
    RebirthType = nil,  -- No rebirth for this type
    Scaling = { Formula = "Exponential" },
}
```

**Globally:**

```lua
Rebirths = {
    enabled = false,  -- Disables all rebirths
    Types = { ... },
}
```

---

## Scaling Formulas

Scaling formulas determine how much EXP is required to reach each level. The system supports two formula types and a flexible parameter resolution system.

### Formula Types

#### Linear Formula

Experience grows linearly with level.

**Formula**: `MaxExp(Level) = Base + Increment × (Level - 1)`

**Example**:

- Base = 100
- Increment = 25
- Level 1: 100 EXP
- Level 2: 125 EXP
- Level 3: 150 EXP
- Level 10: 325 EXP

**Use Cases**: Steady, predictable progression. Good for main level systems.

#### Exponential Formula

Experience grows exponentially with level.

**Formula**: `MaxExp(Level) = floor(Base × Factor^(Level - 1))`

**Example**:

- Base = 50
- Factor = 1.25
- Level 1: 50 EXP
- Level 2: 62 EXP
- Level 3: 78 EXP
- Level 10: 372 EXP

**Use Cases**: Increasingly difficult progression. Good for prestige/rank systems.

### Parameter Resolution (Fallback Hierarchy)

The system resolves formula parameters using a priority system:

1. **Inline Custom Parameters** (Highest Priority)

   - Parameters defined directly in the type's `Scaling` table
   - Overrides global formulas

2. **Global Formula Library** (Fallback)

   - Looks up formula by name in `Scaling.Formulas`
   - Uses template parameters

3. **Default Linear** (Ultimate Fallback)
   - Base = 100, Increment = 25
   - Used if no config found

### Global Formula Library

Define reusable formula templates in `Scaling.Formulas`:

```lua
Scaling = {
    Formulas = {
        Linear = { Base = 100, Increment = 25 },
        Exponential = { Base = 50, Factor = 1.25 },
        FastLinear = { Base = 50, Increment = 50 },
        SlowExponential = { Base = 100, Factor = 1.1 },
    },
}
```

### Scaling Configuration Patterns

#### Pattern 1: Reference Global Formula

Uses parameters from the global template.

```lua
-- In Types
levels = {
    Name = "Level",
    ExpName = "EXP",
    Scaling = { Formula = "Linear" },  -- Uses global Linear: Base=100, Increment=25
}
```

#### Pattern 2: Inline Custom Parameters

Overrides global parameters for this type only.

```lua
stages = {
    Name = "Stage",
    ExpName = "SP",
    Scaling = {
        Formula = "Linear",   -- Calculation logic
        Base = 200,           -- Custom override
        Increment = 75,       -- Custom override
    },
}
```

### Formula Parameters

#### Linear Formula Parameters

| Parameter   | Type   | Description                            |
| ----------- | ------ | -------------------------------------- |
| `Formula`   | string | Must be "Linear" for calculation logic |
| `Base`      | number | Starting EXP requirement at level 1    |
| `Increment` | number | EXP increase per level                 |

#### Exponential Formula Parameters

| Parameter | Type   | Description                                                 |
| --------- | ------ | ----------------------------------------------------------- |
| `Formula` | string | Must be "Exponential" for calculation logic                 |
| `Base`    | number | Starting EXP requirement at level 1                         |
| `Factor`  | number | Multiplier applied each level (e.g., 1.25 = +25% per level) |

---

## Examples

### Example 1: Standard Level System

Uses global Linear formula with rebirth support.

```lua
levels = {
    Name = "Level",
    ExpName = "EXP",
    MaxLevel = 100,
    MaxRebirth = 10,
    RebirthType = "rebirth",
    Scaling = { Formula = "Linear" },  -- Uses global: Base=100, Increment=25
}
```

**Progression**:

- Level 1→2: 100 EXP
- Level 2→3: 125 EXP
- Level 100→101: Rebirth required
- Max 10 rebirths allowed

### Example 2: Prestige Rank System

Uses global Exponential formula with different rebirth family.

```lua
ranks = {
    Name = "Rank",
    ExpName = "Honor",
    MaxLevel = 50,
    MaxRebirth = 5,
    RebirthType = "ascension",  -- Different rebirth family
    Scaling = { Formula = "Exponential" },  -- Uses global: Base=50, Factor=1.25
}
```

**Progression**:

- Level 1→2: 50 EXP
- Level 2→3: 62 EXP
- Level 10→11: 372 EXP
- Can "Ascend" (not "Rebirth") at level 50
- Max 5 ascensions allowed

### Example 3: Custom Fast-Growth System

Inline parameters override global formula.

```lua
stages = {
    Name = "Stage",
    ExpName = "SP",
    MaxLevel = 75,
    MaxRebirth = nil,  -- Unlimited
    RebirthType = "rebirth",
    Scaling = {
        Formula = "Linear",
        Base = 200,      -- Higher starting requirement
        Increment = 75,  -- Larger jumps per level
    },
}
```

**Progression**:

- Level 1→2: 200 EXP
- Level 2→3: 275 EXP
- Level 10→11: 875 EXP
- Unlimited rebirths

### Example 4: Progression Without Rebirth

No rebirth system for this type.

```lua
tiers = {
    Name = "Tier",
    ExpName = "TP",
    MaxLevel = 60,      -- Not used (no rebirth)
    RebirthType = nil,  -- Rebirth disabled
    Scaling = {
        Formula = "Exponential",
        Base = 100,
        Factor = 1.5,   -- Aggressive growth
    },
}
```

**Progression**:

- Level 1→2: 100 EXP
- Level 2→3: 150 EXP
- Level 10→11: 5766 EXP
- No rebirth available

---

**Next:** [Part 2: Implementation Guide](Part2_Implementation_Guide.md)
