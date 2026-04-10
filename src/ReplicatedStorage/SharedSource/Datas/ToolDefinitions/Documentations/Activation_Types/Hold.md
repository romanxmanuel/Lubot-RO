# Hold Activation Type

## Overview

**Hold** activation type enables continuous or duration-based tool behavior. The tool activates while the user holds down the mouse button (or touch) and deactivates when released.

---

## Behavior

- **Button state tracking** - Framework tracks when button is pressed/released
- **Continuous mouse position** - Server receives mouse position updates while held
- **Duration-based logic** - Server can implement max fire duration, overheating, etc.
- **Clean release handling** - Framework notifies both client and server on button release

---

## How Hold Tools Are Detected

**IMPORTANT:** The framework detects Hold tools by checking if the module has an `OnButtonDown` callback, **not** by reading the `ActivationType` field.

```lua
-- From ToolModuleManager.lua
function ToolModuleManager:IsHoldTool(toolId, toolData)
    local toolModule = self:GetToolModule(toolId, toolData)
    if toolModule and toolModule.OnButtonDown then
        return true
    end
    return false
end
```

**This means:**
- ✅ If your module has `OnButtonDown` → Hold behavior is enabled
- ❌ If your module lacks `OnButtonDown` → Click behavior (default)
- The `ActivationType = "Hold"` in tool definition is **documentation only** (for clarity)

---

## Flow Diagram

```
User Press (Button Down)
    │
    ▼
┌─────────────────┐
│  InputHandler   │  Detects hold tool (has OnButtonDown?)
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
 Client     Server
 Module     Signal
    │         │
    ▼         ▼
OnButtonDown  OnButtonDown
 (start VFX)  (start loop)
    │         │
    ▼         ▼
[Mouse position tracking starts]
    │         │
    ▼         ▼
[Continuous fire/effect loop]
    │         │
    ▼         ▼
User Release (Button Up)
    │
    ▼
OnButtonUp   OnButtonUp
 (stop VFX)  (stop loop)
```

---

## Module Requirements

### Server Module (Hold Tool)

```lua
--!strict
-- tool_id.lua (Server)
-- Hold activation tool

local ToolModule = {}

---- Knit Services
local ToolService

---- State tracking
local _playerStates = {} -- Per-player firing state

--[=[
    REQUIRED FOR HOLD TOOLS: Called when button is pressed
    @param player Player
    @param toolData table
]=]
function ToolModule:OnButtonDown(player: Player, toolData: any)
    local state = _playerStates[player]
    if not state then return end
    
    state.isFiring = true
    
    -- Start fire loop in separate thread
    task.spawn(function()
        while state.isFiring do
            -- Get mouse position from framework
            local mousePos = ToolService:GetHoldToolMousePosition(player)
            
            if mousePos then
                -- Do continuous action (spawn projectiles, deal damage, etc.)
                self:FireProjectile(player, mousePos)
            end
            
            task.wait(toolData.Stats.FireRate or 0.1)
        end
    end)
end

--[=[
    REQUIRED FOR HOLD TOOLS: Called when button is released
    @param player Player
    @param toolData table
]=]
function ToolModule:OnButtonUp(player: Player, toolData: any)
    local state = _playerStates[player]
    if state then
        state.isFiring = false
    end
end

--[=[
    Called on single-click activation (usually empty for hold tools)
]=]
function ToolModule:Activate(player: Player, toolData: any, targetData: any): boolean
    -- Hold tools use OnButtonDown/OnButtonUp instead
    return true
end

--[=[
    Called when equipped - setup state
]=]
function ToolModule:OnEquip(player: Player, toolData: any)
    _playerStates[player] = {
        isFiring = false,
        -- Add other state as needed
    }
end

--[=[
    Called when unequipped - cleanup state
]=]
function ToolModule:OnUnequip(player: Player, toolData: any)
    if _playerStates[player] then
        _playerStates[player].isFiring = false
    end
    _playerStates[player] = nil
    
    -- Clear mouse position tracking
    ToolService:ClearHoldToolMousePosition(player)
end

function ToolModule.Init()
    ToolService = Knit.GetService("ToolService")
end

return ToolModule
```

### Client Module (Hold Tool)

```lua
--!strict
-- tool_id.lua (Client)
-- Hold activation tool

local ToolModule = {}

---- State
local _isFiring = false

--[=[
    REQUIRED FOR HOLD TOOLS: Called when button is pressed
    Framework handles server communication automatically
    @param toolData table
    @param targetData table
]=]
function ToolModule:OnButtonDown(toolData: any, targetData: any)
    _isFiring = true
    -- Start visual effects (looping sound, particle emitter, etc.)
end

--[=[
    REQUIRED FOR HOLD TOOLS: Called when button is released
    @param toolData table
    @param targetData table
]=]
function ToolModule:OnButtonUp(toolData: any, targetData: any)
    _isFiring = false
    -- Stop visual effects
end

--[=[
    Called on single-click (usually empty for hold tools)
]=]
function ToolModule:OnActivate(toolData: any, targetData: any)
    -- Hold tools use OnButtonDown/OnButtonUp instead
end

-- OPTIONAL: Called when equipped
-- function ToolModule:OnEquip(toolData: any)
-- end

-- OPTIONAL: Called when unequipped
-- function ToolModule:OnUnequip(toolData: any)
-- end

function ToolModule.Init()
    -- Initialize references
end

return ToolModule
```

---

## Tool Definition Example

```lua
blow_dryer = {
    ToolId = "blow_dryer",
    Category = "Miscs",
    Subcategory = "General",
    AssetName = "Blow Dryer",
    
    Stats = {
        Cooldown = 1,            -- Cooldown after max fire duration
        MaxFireDuration = 2,     -- Maximum time holding fire
        FireRate = 1 / 60,       -- Projectile spawn rate
        BubbleSpeed = 120,
        BubbleForce = 40,
    },
    
    BehaviorConfig = {
        ActivationType = "Hold", -- Documentation: indicates hold-to-fire
        
        -- Visual config
        BubbleColors = {"White", "Light blue"},
        MouseIcon = "rbxassetid://textures/GunCursor.png",
    },
},
```

---

## Framework Infrastructure

The framework provides built-in support for Hold tools:

### Client Side (InputHandler)
- Tracks `_isButtonDown` state
- Starts mouse position tracking via `RenderStepped`
- Sends `HoldToolButtonState` signal (true on press, false on release)
- Sends `HoldToolMousePosition` signal continuously while held

### Server Side (ActivationManager)
- Listens to `HoldToolButtonState` signal
- Routes to `OnButtonDown` / `OnButtonUp` callbacks
- Provides `ToolService:GetHoldToolMousePosition(player)` for position data
- Provides `ToolService:ClearHoldToolMousePosition(player)` for cleanup

---

## Use Cases

| Tool Type | Example | Why Hold? |
|-----------|---------|-----------|
| **Spray Tools** | Blow Dryer, Fire Hose | Continuous projectile stream |
| **Beam Weapons** | Laser, Flamethrower | Sustained damage over time |
| **Charge Tools** | Bow, Charge Cannon | Hold to charge, release to fire |
| **Mining Tools** | Drill, Pickaxe | Hold to mine continuously |

---

## Max Duration & Cooldown Pattern

Many Hold tools implement a maximum fire duration followed by cooldown:

```lua
-- Server module
local MAX_FIRE_DURATION = 2  -- seconds
local COOLDOWN = 1           -- seconds

function ToolModule:OnButtonDown(player, toolData)
    local startTime = tick()
    state.isFiring = true
    
    while state.isFiring and (tick() - startTime) < MAX_FIRE_DURATION do
        -- Fire logic
        task.wait(FIRE_RATE)
    end
    
    -- Cooldown
    toolInstance.Enabled = false
    task.wait(COOLDOWN)
    toolInstance.Enabled = true
end
```

---

## Key Differences from Click

| Aspect | Click | Hold |
|--------|-------|------|
| **Detection** | No `OnButtonDown` callback | Has `OnButtonDown` callback |
| **Activation** | Single `Activate()` call | `OnButtonDown` → loop → `OnButtonUp` |
| **Mouse Tracking** | Single position snapshot | Continuous position updates |
| **Server State** | Stateless (mostly) | Requires per-player state |
| **Use Case** | Discrete actions | Continuous/duration actions |

---

## Notes

- The `ActivationType = "Hold"` field is **documentation only** - actual detection uses callback presence
- Always implement both `OnButtonDown` AND `OnButtonUp` for proper cleanup
- Use `ToolService:GetHoldToolMousePosition(player)` for server-side targeting
- Clean up state in `OnUnequip` and when player leaves
- Consider implementing max duration to prevent infinite firing
