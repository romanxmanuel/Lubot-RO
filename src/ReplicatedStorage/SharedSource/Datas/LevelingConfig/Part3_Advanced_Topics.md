# LevelingConfig Documentation - Part 3: Advanced Topics

## Table of Contents

- [Dynamic Level Types (Advanced)](#dynamic-level-types-advanced)
- [Best Practices](#best-practices)
- [FAQ](#faq)
- [Conclusion](#conclusion)

---

## Dynamic Level Types (Advanced)

For advanced use cases where you need to create level types programmatically at runtime (e.g., per-pet leveling systems, per-weapon leveling, etc.), you can dynamically add types to LevelingConfig using script operations.

### Use Case: Pet Leveling System

When you have multiple pets and each pet needs its own independent level progression, you can create dynamic level types using a naming pattern like `[pet_ID]_level`.

### How to Add Dynamic Level Types

**Step 1: Create External Config for Your Entities**

First, create a separate config file for your pets (or other entities):

```lua
-- In ReplicatedStorage/SharedSource/Datas/PetConfig.lua
local PetConfig = {
    dragon = {
        LevelName = "Dragon Level",
        ExpName = "Dragon EXP",
        MaxLevel = 100,
        MaxRebirth = nil,
        RebirthType = nil,
        Scaling = {
            Formula = "Exponential",
            Base = 100,
            Factor = 1.3,
        },
    },
    cat = {
        LevelName = "Cat Level",
        ExpName = "Cat EXP",
        MaxLevel = 50,
        MaxRebirth = nil,
        RebirthType = nil,
        Scaling = { Formula = "Linear" },
    },
    phoenix = {
        LevelName = "Phoenix Level",
        ExpName = "Phoenix EXP",
        MaxLevel = 75,
        MaxRebirth = 3,
        RebirthType = "rebirth",
        Scaling = {
            Formula = "Linear",
            Base = 150,
            Increment = 50,
        },
    },
}

return PetConfig
```

**Step 2: Use AddExternalTypes Helper in LevelingConfig**

In the `LevelingConfig/init.lua` file, after the main config definition:

```lua
local LevelingConfig = {
    Types = {
        -- Your static types
        levels = { ... },
        ranks = { ... },
    },
    Rebirths = { ... },
    Scaling = { ... },
}

-- Load the helper utility
local AddExternalTypes = require(script.Parent.Parent.Utilities.Levels.AddExternalTypes)

-- Load and add pet level types
local PetConfig = require(script.Parent.PetConfig)
AddExternalTypes.Add(LevelingConfig, PetConfig, "_level")

-- You can add more external configs:
-- local WeaponConfig = require(script.Parent.WeaponConfig)
-- AddExternalTypes.Add(LevelingConfig, WeaponConfig, "_mastery")

return LevelingConfig
```

**Example with Multiple External Configs:**

```lua
-- Load the helper
local AddExternalTypes = require(script.Parent.Parent.Utilities.Levels.AddExternalTypes)

-- Load multiple entity systems
local PetConfig = require(script.Parent.PetConfig)
local WeaponConfig = require(script.Parent.WeaponConfig)
local SkillConfig = require(script.Parent.SkillConfig)

-- Add them all using the helper
AddExternalTypes.Add(LevelingConfig, PetConfig, "_level")      -- Creates: dragon_level, cat_level, etc.
AddExternalTypes.Add(LevelingConfig, WeaponConfig, "_mastery") -- Creates: sword_mastery, bow_mastery, etc.
AddExternalTypes.Add(LevelingConfig, SkillConfig, "_skill")    -- Creates: fireball_skill, heal_skill, etc.

return LevelingConfig
```

**Helper Location & API:**

```
src/ReplicatedStorage/SharedSource/Utilities/Levels/AddExternalTypes.lua
```

**API:**

```lua
AddExternalTypes.Add(levelingConfig, externalConfig, typeSuffix)
```

**Parameters:**

- `levelingConfig` (table): The LevelingConfig table to modify
- `externalConfig` (table): External config with entity definitions
- `typeSuffix` (string, optional): Suffix for type keys (default: `"_level"`)

**Returns:** Nothing (modifies levelingConfig in-place)

**Benefits of Using This Helper:**

- ✅ **Clean Separation**: Keep entity configs separate from leveling logic
- ✅ **Reusable**: Use the same helper for pets, weapons, skills, etc.
- ✅ **Maintainable**: Easy to add/remove entities without touching LevelingConfig structure
- ✅ **Error Handling**: Built-in validation and warnings for invalid configs
- ✅ **Logging**: Prints count of added types for debugging

### Step 3: Ensure Profile Template Includes Dynamic Types

Since `BuildProfileTemplate_ForLevel` automatically generates profile data from LevelingConfig, your dynamic types will be included in the profile structure as long as they're added before `ProfileTemplate` is generated.

**Important**: Add dynamic types to LevelingConfig **before** `BuildProfileTemplate.GenerateLevelingData()` is called.

### Step 4: Access Dynamic Types Normally

Once added to `Types`, dynamic level types work exactly like static types:

```lua
-- Server
LevelService:AddExp(player, 100, "dragon_level")
LevelService:SetLevel(player, 25, "cat_level")

-- Client
local dragonLevel = LevelController:GetLevelData("dragon_level")
local catLevel = LevelController:GetLevelData("phoenix_level")

-- ProfileService :ChangeData() works normally
ProfileService:ChangeData(player, {"Leveling", "Types", "dragon_level", "Exp"}, 500)
```

### Alternative: Runtime Dynamic Creation

If you need to create level types **after** the profile template is already generated (e.g., when a player acquires a new pet), you'll need to handle profile data manually:

```lua
-- Example: Player acquires a new pet type
local function InitializePetLevel(player, petID)
    local typeKey = petID .. "_level"

    -- 1. Add to LevelingConfig if not already there
    if not LevelingConfig.Types[typeKey] then
        LevelingConfig.Types[typeKey] = {
            Name = "Pet Level",
            ExpName = "Pet EXP",
            MaxLevel = 50,
            MaxRebirth = nil,
            RebirthType = nil,
            Scaling = { Formula = "Linear" },
        }
    end

    -- 2. Initialize profile data for this player
    local _, data = ProfileService:GetProfile(player)
    if data and data.Leveling then
        -- Check if type already exists in player's data
        if not data.Leveling.Types[typeKey] then
            -- Calculate base MaxExp
            local GetBaseMaxExp = require(ReplicatedStorage.SharedSource.Utilities.Levels.GetBaseMaxExp)
            local baseMaxExp = GetBaseMaxExp.ForType(typeKey)

            -- Manually add to player's profile via :ChangeData()
            ProfileService:ChangeData(player, {"Leveling", "Types", typeKey}, {
                Exp = 0,
                Level = 1,
                MaxExp = baseMaxExp,
            })

            -- Initialize rebirth counter
            ProfileService:ChangeData(player, {"Leveling", "Rebirths", typeKey}, 0)
        end
    end
end

-- Usage
InitializePetLevel(player, "newPet_123")
```

### Benefits

✅ **Fully Compatible**: Dynamic types work seamlessly with all LevelService and LevelController functions

✅ **Auto-Save**: Data saves normally through ProfileService

✅ **No Code Changes**: No need to modify core level system code

✅ **Scalable**: Can support unlimited pets, weapons, or other entities

### Use Cases

- **Pet Systems**: `"dragon_level"`, `"cat_level"`, `"phoenix_level"`
- **Weapon Mastery**: `"sword_mastery"`, `"bow_mastery"`, `"staff_mastery"`
- **Skill Trees**: `"fire_magic"`, `"ice_magic"`, `"lightning_magic"`
- **Player-Generated Content**: `"custom_level_" .. userGeneratedID`

### Important Considerations

#### 1. Memory Usage

Each dynamic type adds data to every player's profile. Be mindful of scale:

- ✅ 10-50 dynamic types per player: Fine
- ⚠️ 100-500 dynamic types per player: Monitor performance
- ❌ 1000+ dynamic types per player: Consider alternative data structures

#### 2. Profile Template Timing

**For Pre-Known Types** (e.g., fixed set of pets):

```lua
-- Add to LevelingConfig before ProfileTemplate is created
-- This ensures all new players start with these types
```

**For Runtime Types** (e.g., user-acquired pets):

```lua
-- Add to player's profile manually when acquired
-- Use InitializePetLevel() pattern shown above
```

#### 3. Type Naming

Use consistent naming patterns to avoid collisions:

```lua
-- Good patterns
"pet_" .. petID .. "_level"     -- pet_dragon_level
"weapon_" .. weaponType          -- weapon_sword
"skill_" .. skillName            -- skill_fireball

-- Avoid
petID .. "_level"                -- Could collide with static types
```

#### 4. Cleanup

If a player releases a pet or removes a weapon, you may want to:

```lua
-- Option A: Keep the data (allows re-acquiring without losing progress)
-- Just stop updating it

-- Option B: Clear the data
ProfileService:ChangeData(player, {"Leveling", "Types", typeKey}, nil)
ProfileService:ChangeData(player, {"Leveling", "Rebirths", typeKey}, nil)
```

### Example: Complete Pet Leveling System

**Using Pre-Configured Types (Recommended):**

If your pets are defined in an external PetConfig (as shown in Step 1), they're already loaded into LevelingConfig. You just need to initialize them for players:

```lua
-- In PetService or similar
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelService = require(ReplicatedStorage.Server.LevelService)
local ProfileService = require(game.ServerScriptService.ServerSource.Server.ProfileService)
local GetBaseMaxExp = require(ReplicatedStorage.SharedSource.Utilities.Levels.GetBaseMaxExp)

local PetLevelingSystem = {}

function PetLevelingSystem:InitializePetForPlayer(player, petID)
    local typeKey = petID .. "_level"  -- e.g., "dragon_level"

    -- Check if pet type exists in LevelingConfig
    local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)
    if not LevelingConfig.Types[typeKey] then
        warn("Pet type not found in LevelingConfig:", typeKey)
        return nil
    end

    local _, data = ProfileService:GetProfile(player)
    if data and data.Leveling and not data.Leveling.Types[typeKey] then
        -- Calculate base MaxExp for this pet type
        local baseMaxExp = GetBaseMaxExp.ForType(typeKey)

        -- Initialize pet level data
        ProfileService:ChangeData(player, {"Leveling", "Types", typeKey}, {
            Exp = 0,
            Level = 1,
            MaxExp = baseMaxExp,
        })

        ProfileService:ChangeData(player, {"Leveling", "Rebirths", typeKey}, 0)
    end

    return typeKey
end

function PetLevelingSystem:AddPetExp(player, petID, amount)
    local typeKey = petID .. "_level"
    LevelService:AddExp(player, amount, typeKey)
end

function PetLevelingSystem:GetPetLevel(player, petID)
    local typeKey = petID .. "_level"
    local _, data = ProfileService:GetProfile(player)

    if data and data.Leveling and data.Leveling.Types[typeKey] then
        return data.Leveling.Types[typeKey].Level
    end

    return 0
end

-- Usage
local petID = "dragon"  -- Must match key in PetConfig
PetLevelingSystem:InitializePetForPlayer(player, petID)
PetLevelingSystem:AddPetExp(player, petID, 100)
local level = PetLevelingSystem:GetPetLevel(player, petID)
```

**Using Runtime Registration (For Dynamic Pets):**

If you need to create pet types at runtime based on rarity or other factors:

```lua
-- In PetService
local PetLevelingSystem = {}
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

-- Configuration: Define pet-specific scaling by rarity
local PET_RARITY_CONFIG = {
    common = { Base = 50, Increment = 15 },
    rare = { Base = 100, Increment = 30 },
    legendary = { Base = 200, Increment = 50 },
}

function PetLevelingSystem:RegisterDynamicPet(petID, rarity)
    local typeKey = "pet_" .. petID
    local scalingConfig = PET_RARITY_CONFIG[rarity] or PET_RARITY_CONFIG.common

    -- Add to LevelingConfig if not already there
    if not LevelingConfig.Types[typeKey] then
        LevelingConfig.Types[typeKey] = {
            Name = "Pet Level",
            ExpName = "Pet EXP",
            MaxLevel = 100,
            MaxRebirth = nil,
            RebirthType = nil,
            Scaling = {
                Formula = "Linear",
                Base = scalingConfig.Base,
                Increment = scalingConfig.Increment,
            },
        }
    end

    return typeKey
end

function PetLevelingSystem:InitializeDynamicPetForPlayer(player, petID, rarity)
    local typeKey = self:RegisterDynamicPet(petID, rarity)

    local _, data = ProfileService:GetProfile(player)
    if data and data.Leveling and not data.Leveling.Types[typeKey] then
        local GetBaseMaxExp = require(ReplicatedStorage.SharedSource.Utilities.Levels.GetBaseMaxExp)
        local baseMaxExp = GetBaseMaxExp.ForType(typeKey)

        ProfileService:ChangeData(player, {"Leveling", "Types", typeKey}, {
            Exp = 0,
            Level = 1,
            MaxExp = baseMaxExp,
        })

        ProfileService:ChangeData(player, {"Leveling", "Rebirths", typeKey}, 0)
    end

    return typeKey
end

-- Usage for runtime-generated pet
local petID = "unique_pet_12345"
PetLevelingSystem:InitializeDynamicPetForPlayer(player, petID, "legendary")
```

---

## Best Practices

### Naming Conventions

✅ **DO**: Use clear, descriptive names

```lua
Name = "Level"      -- Clear
ExpName = "EXP"     -- Standard
```

❌ **DON'T**: Use technical or cryptic names

```lua
Name = "lvl_sys_1"  -- Confusing for players
ExpName = "XP_PTS"  -- Unclear
```

### Type Identifiers

✅ **DO**: Use lowercase, plural, descriptive keys

```lua
Types = {
    levels = { ... },
    ranks = { ... },
    stages = { ... },
}
```

❌ **DON'T**: Use uppercase or unclear abbreviations

```lua
Types = {
    LVL = { ... },      -- Inconsistent
    type1 = { ... },    -- Not descriptive
}
```

### Scaling Configuration

✅ **DO**: Use global formulas for standard progression

```lua
levels = {
    Scaling = { Formula = "Linear" },  -- Simple, maintainable
}
```

✅ **DO**: Use inline params for unique progression

```lua
bossLevels = {
    Scaling = {
        Formula = "Exponential",
        Base = 500,      -- Boss-specific
        Factor = 2.0,    -- Very aggressive
    },
}
```

❌ **DON'T**: Override for minor tweaks

```lua
-- If this is close to a global formula, just adjust the global
myType = {
    Scaling = {
        Formula = "Linear",
        Base = 105,      -- Too similar to global (100)
        Increment = 26,  -- Just use global Linear
    },
}
```

### Rebirth Configuration

✅ **DO**: Set MaxLevel when using rebirth

```lua
levels = {
    MaxLevel = 100,
    RebirthType = "rebirth",
}
```

❌ **DON'T**: Forget MaxLevel with RebirthType

```lua
levels = {
    -- Missing MaxLevel!
    RebirthType = "rebirth",  -- Won't work
}
```

✅ **DO**: Use nil for unlimited rebirths explicitly

```lua
MaxRebirth = nil,  -- Clear intent: unlimited
```

✅ **DO**: Use specific numbers for limited rebirths

```lua
MaxRebirth = 10,  -- Clear: max 10 rebirths
```

### Testing New Types

When adding a new level type:

1. **Add to config** in `LevelingConfig/init.lua`
2. **Test in Studio** using `LevelSystemTesters.server.lua`
3. **Verify profile generation** by checking `ProfileTemplate.Leveling`
4. **Test rebirth eligibility** if applicable
5. **Check UI updates** if using LevelController UI system

### Performance Considerations

- ✅ Config is loaded once at startup
- ✅ Formula resolution is cached per operation
- ✅ Adding new types has minimal performance impact
- ⚠️ Avoid extremely large MaxLevel values (>10,000) with exponential formulas

### Version Control

When modifying LevelingConfig in production:

1. **Backup current config** before major changes
2. **Test in development** environment first
3. **Use ProfileService:Reconcile()** to add new types to existing players
4. **Avoid removing types** that existing players have data for
5. **Scaling changes** don't affect existing player MaxExp until they level up

---

## FAQ

### Q: Can I change scaling parameters for an existing level type?

**A**: Yes, but it only affects future level-ups. Existing players' current MaxExp won't retroactively change. Use `LevelService:SetLevel()` or rebirth to recalculate MaxExp.

### Q: What happens if I remove a level type?

**A**: The profile data will still exist for players who had it. If you want to properly remove a type:

1. Set `RebirthType = nil` to disable rebirth
2. Mark as deprecated in config comments
3. Eventually remove after data migration

### Q: Can I have different MaxLevel for different rebirth counts?

**A**: Not directly in config. MaxLevel is static per type. For dynamic requirements, implement custom logic in `CanRebirth()`.

### Q: How do I create a "prestige" system that's faster each time?

**A**: Create a custom formula or use rebirth bonuses outside of LevelingConfig (e.g., multiply EXP gains based on rebirth count in `AddExp()`).

### Q: Can I use decimal levels?

**A**: No, the system uses integer levels only. Use sub-systems for decimal progression (e.g., "Level 5.7" could be Level=5, Exp=70/100).

### Q: What's the maximum MaxLevel I can set?

**A**: Technically unlimited, but exponential formulas can overflow Lua numbers around level 300-500 depending on Factor. Linear formulas can go much higher (10,000+).

---

## Conclusion

The LevelingConfig system provides a flexible, scalable way to manage multiple progression systems in your game. By centralizing configuration, you can:

- Add new progression types without code changes
- Balance systems by adjusting formulas
- Create varied player experiences with different rebirth mechanics
- Maintain clean, readable configuration

For implementation details, see the related files listed in Part 2 or check the main `LevelSystem_Plan.md` documentation.

---

**Previous:** [Part 2: Implementation Guide](Part2_Implementation_Guide.md)  
**Return to:** [Part 1: Getting Started](Part1_Getting_Started.md)
