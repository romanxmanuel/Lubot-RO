# Click Activation Type

## Overview

**Click** is the default activation type for tools. It triggers a single activation when the user clicks (or taps on mobile).

---

## Behavior

- **Single activation per click** - One click = one activation
- **Debounce protection** - Prevents accidental double-clicks (0.1s default)
- **Cooldown support** - Server enforces cooldown between activations
- **Immediate feedback** - Client plays visual feedback instantly

---

## Flow Diagram

```
User Click
    │
    ▼
┌─────────────────┐
│  InputHandler   │  Debounce check (0.1s)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ ToolController  │  Is tool ready? (cooldown check)
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 Client     Server
 Module     Request
    │         │
    ▼         ▼
OnActivate  Activate
 (visual)   (logic)
```

---

## Module Requirements

### Server Module

```lua
--!strict
-- tool_id.lua (Server)
-- Click activation tool

local ToolModule = {}

--[=[
    REQUIRED: Called on each click activation
    @param player Player
    @param toolData table
    @param targetData table - { Target, Position, Direction }
    @return boolean - Success status
]=]
function ToolModule:Activate(player: Player, toolData: any, targetData: any): boolean
    -- Your click activation logic here
    -- Example: Deal damage, consume item, toggle state
    return true
end

-- OPTIONAL: Called when equipped
-- function ToolModule:OnEquip(player: Player, toolData: any)
-- end

-- OPTIONAL: Called when unequipped
-- function ToolModule:OnUnequip(player: Player, toolData: any)
-- end

function ToolModule.Init()
    -- Initialize references
end

return ToolModule
```

### Client Module

```lua
--!strict
-- tool_id.lua (Client)
-- Click activation tool

local ToolModule = {}

--[=[
    REQUIRED: Called on each click for visual feedback
    @param toolData table
    @param targetData table - { Target, Position, Direction }
]=]
function ToolModule:OnActivate(toolData: any, targetData: any)
    -- Play animation, sound, VFX
end

-- OPTIONAL: Called when equipped
-- function ToolModule:OnEquip(toolData: any)
-- end

-- OPTIONAL: Called when unequipped
-- function ToolModule:OnUnequip(toolData: any)
-- end

-- OPTIONAL: Called when server sends state update
-- function ToolModule:OnStateChanged(newState: any)
-- end

function ToolModule.Init()
    -- Initialize references
end

return ToolModule
```

---

## Tool Definition Example

```lua
sword_classic = {
    ToolId = "sword_classic",
    Category = "Weapons",
    Subcategory = "Swords",
    AssetName = "Classic Sword",
    
    Stats = {
        Cooldown = 0.5,
        Damage = 25,
        Range = 8,
    },
    
    BehaviorConfig = {
        ActivationType = "Click", -- Default, can be omitted
        MeleeData = {
            HitboxSize = Vector3.new(4, 4, 4),
        },
    },
},
```

---

## Use Cases

| Tool Type | Example | Why Click? |
|-----------|---------|------------|
| **Melee Weapons** | Sword, Axe | Single swing per click |
| **Throwables** | Grenade, Snowball | One throw per click |
| **Consumables** | Potion, Food | Consume on click |
| **Toggle Items** | Flashlight | Click to toggle on/off |
| **Utility Tools** | Teleporter | Activate ability on click |

---

## Toggle Pattern

For tools that toggle state (like flashlight), Click activation with server state tracking:

**Server:**
```lua
local _toggleStates = {} -- [player] = isOn

function ToolModule:Activate(player, toolData, targetData)
    -- Toggle state
    _toggleStates[player] = not _toggleStates[player]
    
    -- Notify client of state change
    ToolService.Client.ToolStateChanged:Fire(player, toolData.ToolId, {
        isOn = _toggleStates[player]
    })
    
    return true
end
```

**Client:**
```lua
function ToolModule:OnStateChanged(newState)
    if newState.isOn then
        -- Show "ON" state (light on, UI update, etc.)
    else
        -- Show "OFF" state
    end
end
```

---

## Notes

- Click is the **default** - if `ActivationType` is omitted, Click behavior is assumed
- The framework detects Click tools by the **absence** of `OnButtonDown` callback
- Cooldown is enforced server-side via `CooldownManager`
- Client-side debounce (0.1s) prevents UI/input lag from causing double-clicks
