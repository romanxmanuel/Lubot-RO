# LevelingConfig Documentation - Part 2: Implementation Guide

## Table of Contents

- [Adding New Level Types](#adding-new-level-types)
- [Profile Integration](#profile-integration)
- [Related Files](#related-files)

---

## Adding New Level Types

### Step 1: Define the Type in LevelingConfig

```lua
-- In LevelingConfig.Types
myCustomType = {
    Name = "Power",
    ExpName = "Energy",
    MaxLevel = 200,
    MaxRebirth = nil,  -- Unlimited rebirths
    RebirthType = "rebirth",
    Scaling = { Formula = "Exponential" },
}
```

### Step 2: (Optional) Add Custom Rebirth Family

If you want a unique rebirth name:

```lua
-- In LevelingConfig.Rebirths.Types
transcendence = {
    Name = "Transcendences",
    ShortName = "T",
    ActionName = "Transcend"
}

-- Then in your level type
myCustomType = {
    -- ...
    RebirthType = "transcendence",
    -- ...
}
```

### Step 3: That's It!

The system automatically:

- Generates profile data structure via `BuildProfileTemplate_ForLevel`
- Creates level tracking with correct starting MaxExp
- Creates rebirth counter
- Enables all level system functions for this type

### Using the New Type in Code

```lua
-- Server (LevelService)
LevelService:AddExp(player, 500, "myCustomType")
LevelService:SetLevel(player, 50, "myCustomType")
LevelService:CanRebirth(player, "myCustomType")
LevelService:PerformRebirth(player, "myCustomType")

-- Client (LevelController)
local data = LevelController:GetLevelData("myCustomType")
local eligible = LevelController:GetRebirthEligibility("myCustomType")
```

---

## Profile Integration

The LevelingConfig automatically generates the profile data structure through `BuildProfileTemplate_ForLevel`.

### Profile Structure Generated

```lua
ProfileTemplate.Leveling = {
    Types = {
        levels = {
            Exp = 0,
            Level = 1,
            MaxExp = 100,  -- Calculated from Scaling config
        },
        ranks = {
            Exp = 0,
            Level = 1,
            MaxExp = 50,   -- Calculated from Scaling config
        },
        -- ... all configured types
    },
    Rebirths = {
        levels = 0,
        ranks = 0,
        -- ... counters for all types
    },
}
```

### How MaxExp is Calculated

1. System reads type's `Scaling` config
2. Resolves formula parameters using fallback hierarchy
3. Calculates Level 1 MaxExp:
   - Linear: `Base + Increment × 0 = Base`
   - Exponential: `Base × Factor^0 = Base`
4. Stores in profile template

### Accessing Profile Data

```lua
-- Server
local profile, data = ProfileService:GetProfile(player)
local currentLevel = data.Leveling.Types.levels.Level
local currentExp = data.Leveling.Types.levels.Exp
local rebirthCount = data.Leveling.Rebirths.levels

-- Client (via DataController)
local data = DataController.Data
if data and data.Leveling then
    local levelData = data.Leveling.Types.levels
    local rebirthData = data.Leveling.Rebirths.levels
end
```

---

## Related Files

| File                                                                                    | Purpose                                               |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `ReplicatedStorage/SharedSource/Datas/LevelingConfig/init.lua`                          | Main configuration file                               |
| `ReplicatedStorage/SharedSource/Datas/ProfileTemplate.lua`                              | Uses config to generate profile structure             |
| `ReplicatedStorage/SharedSource/Utilities/Levels/BuildProfileTemplate_ForLevel.lua`     | Auto-generates profile data from config               |
| `ReplicatedStorage/SharedSource/Utilities/Levels/GetBaseMaxExp.lua`                     | Calculates starting MaxExp values                     |
| `ReplicatedStorage/SharedSource/Utilities/Levels/AddExternalTypes.lua`                  | Helper for adding dynamic types from external configs |
| `ServerScriptService/ServerSource/Server/LevelService/Components/Others/Calculator.lua` | Implements formula calculations                       |
| `ServerScriptService/ServerSource/Server/LevelService/init.lua`                         | Server-side level management                          |
| `ReplicatedStorage/ClientSource/Client/LevelController/init.lua`                        | Client-side level data access                         |

---

**Previous:** [Part 1: Getting Started](Part1_Getting_Started.md)  
**Next:** [Part 3: Advanced Topics](Part3_Advanced_Topics.md)
