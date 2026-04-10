# Tool Framework Architecture

## Overview

The Tool Framework is a centralized, data-driven system for managing Roblox Tool instances. It eliminates the need for individual scripts inside each tool by handling all logic through centralized services (server) and controllers (client), with per-tool source files for custom behavior.

---

## Core Principles

1. **Data-Driven Design** - Tools are defined as data entries in the registry
2. **Per-Tool Source Files** - Each tool has its own dedicated server and/or client module
3. **Server Authority** - All validation, damage, and state changes happen server-side
4. **Client Prediction** - Visual feedback plays immediately on client for responsiveness
5. **Component Architecture** - Modular components handle specific responsibilities
6. **Dynamic Module Loading** - Tool modules are loaded on-demand and cached
7. **Agnostic Module System** - Tools can have server-only, client-only, or both modules

---

## Agnostic Module System

The Tool Framework supports three operational modes based on which modules exist for each tool.

| Mode | Client Module | Server Module | Use Case |
|------|---------------|---------------|----------|
| **Full Mode** | ✅ Yes | ✅ Yes | Combat, complex abilities, multiplayer |
| **Server-Only** | ❌ No | ✅ Yes | Admin tools, simple utilities |
| **Client-Only** | ✅ Yes | ❌ No | Cosmetics, emotes, single-player effects |

**Key Points:**
- **Full Mode**: Client predicts visuals, server authorizes actions via RemoteFunction
- **Server-Only**: Native `Tool.Activated` replicates to server automatically
- **Client-Only**: No server communication, purely visual effects

> 📖 **For detailed flows, diagrams, and deduplication logic, see [AgnosticModuleSystem.md](./AgnosticModuleSystem.md)**

---

## Directory Structure

```
Tool Framework
│
├── src/ReplicatedStorage/SharedSource/Datas/ToolDefinitions/
│   ├── ToolRegistry/
│   │   ├── init.lua                    # Auto-loads all subcategory files
│   │   └── Categories/
│   │       ├── Weapons/
│   │       │   └── Swords.lua          # Sword tool definitions
│   │       ├── Consumables/
│   │       │   └── Food.lua            # Food tool definitions
│   │       └── Utilities/
│   │           └── Lights.lua          # Light tool definitions
│   ├── ToolConstants.lua               # Framework constants
│   └── Documentations/
│       └── Architecture.md             # This file
│
├── src/ReplicatedStorage/SharedSource/Utilities/
│   ├── ToolHelpers/
│   │   └── init.lua                    # Registry lookup utilities
│   └── ToolFactory/
│       └── init.lua                    # Tool instance creation
│
├── src/ServerScriptService/ServerSource/Server/ToolService/
│   ├── init.lua                        # Main service (Knit)
│   ├── Components/
│   │   ├── Get().lua                   # Read operations
│   │   ├── Set().lua                   # Write operations
│   │   └── Others/
│   │       ├── ValidationManager.lua   # Security & validation
│   │       ├── EquipManager.lua        # Equip/unequip logic
│   │       ├── CooldownManager.lua     # Cooldown tracking
│   │       ├── ActivationManager.lua   # Tool module loader & router
│   │       └── NativeToolHandler.lua   # Server-Only mode handler
│   └── Tools/
│       └── Categories/
│           ├── Weapons/
│           │   └── Swords/
│           │       └── sword_classic.lua
│           ├── Consumables/
│           │   └── Food/
│           │       └── cheeseburger_og.lua
│           └── Utilities/
│               └── Lights/d
│                   └── flashlight_standard.lua
│
└── src/ReplicatedStorage/ClientSource/Client/ToolController/
    ├── init.lua                        # Main controller (Knit)
    ├── Components/
    │   ├── Get().lua                   # Client state reads
    │   ├── Set().lua                   # Client state writes & server requests
    │   └── Others/
    │       ├── InputHandler.lua        # Mouse/touch input detection
    │       ├── AnimationManager.lua    # Animation loading & playback
    │       ├── VisualFeedback.lua      # Sound & VFX playback
    │       └── ToolModuleManager.lua   # Client tool module loader
    └── Tools/
        └── Categories/
            ├── Weapons/
            │   └── Swords/
            │       └── sword_classic.lua
            ├── Consumables/
            │   └── Food/
            │       └── cheeseburger_og.lua
            └── Utilities/
                └── Lights/
                    └── flashlight_standard.lua
```

---

## Per-Tool Source File System

### Server Tool Module Structure

Each tool has a dedicated server module at:
`ToolService/Tools/Categories/[Category]/[Subcategory]/[tool_id].lua`

**See [Activation_Types/](./Activation_Types/) for Click vs Hold tool patterns.**

```lua
--!strict
-- tool_id.lua
-- Server-side logic for [Tool Name]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ToolModule = {}

---- Knit Services
local ToolService

--[=[
    Called when the tool is activated (REQUIRED for Click tools)
    @param player Player - The player activating the tool
    @param toolData table - Tool definition from ToolRegistry
    @param targetData table - { Target: Instance?, Position: Vector3?, Direction: Vector3? }
    @return boolean - Success status
]=]
function ToolModule:Activate(player: Player, toolData: any, targetData: any): boolean
    -- Your tool's activation logic here
    return true
end

--[=[
    OPTIONAL: Called when the tool is equipped
    @param player Player
    @param toolData table
]=]
-- function ToolModule:OnEquip(player: Player, toolData: any)
--     -- Custom equip logic
-- end

--[=[
    OPTIONAL: Called when the tool is unequipped
    @param player Player
    @param toolData table
]=]
-- function ToolModule:OnUnequip(player: Player, toolData: any)
--     -- Custom unequip logic
-- end

--[=[
    HOLD TOOLS ONLY: Called when button is pressed
    The presence of this callback marks this as a Hold tool
    @param player Player
    @param toolData table
]=]
-- function ToolModule:OnButtonDown(player: Player, toolData: any)
--     -- Start continuous action (fire loop, etc.)
-- end

--[=[
    HOLD TOOLS ONLY: Called when button is released
    @param player Player
    @param toolData table
]=]
-- function ToolModule:OnButtonUp(player: Player, toolData: any)
--     -- Stop continuous action
-- end

function ToolModule.Init()
    ToolService = Knit.GetService("ToolService")
end

return ToolModule
```

### Client Tool Module Structure

Each tool has a dedicated client module at:
`ToolController/Tools/Categories/[Category]/[Subcategory]/[tool_id].lua`

**See [Activation_Types/](./Activation_Types/) for Click vs Hold tool patterns.**

```lua
--!strict
-- tool_id.lua
-- Client-side visual feedback for [Tool Name]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ToolModule = {}

---- Knit Controllers
local ToolController

--[=[
    Called when the tool is activated - plays visual feedback (REQUIRED for Click tools)
    @param toolData table - Tool definition from ToolRegistry
    @param targetData table - { Target: Instance?, Position: Vector3?, Direction: Vector3? }
]=]
function ToolModule:OnActivate(toolData: any, targetData: any)
    -- Play animations, sounds, effects
end

--[=[
    OPTIONAL: Called when the tool is equipped
    @param toolData table
]=]
-- function ToolModule:OnEquip(toolData: any)
--     -- Load animations, setup UI
-- end

--[=[
    OPTIONAL: Called when the tool is unequipped
    @param toolData table
]=]
-- function ToolModule:OnUnequip(toolData: any)
--     -- Cleanup animations, UI
-- end

--[=[
    OPTIONAL: Called when tool state changes from server
    @param newState any
]=]
-- function ToolModule:OnStateChanged(newState: any)
--     -- Handle state changes (e.g., flashlight on/off)
-- end

--[=[
    HOLD TOOLS ONLY: Called when button is pressed
    The presence of this callback marks this as a Hold tool
    @param toolData table
    @param targetData table
]=]
-- function ToolModule:OnButtonDown(toolData: any, targetData: any)
--     -- Start visual effects (looping sound, particles, etc.)
-- end

--[=[
    HOLD TOOLS ONLY: Called when button is released
    @param toolData table
    @param targetData table
]=]
-- function ToolModule:OnButtonUp(toolData: any, targetData: any)
--     -- Stop visual effects
-- end

function ToolModule.Init()
    ToolController = Knit.GetController("ToolController")
end

return ToolModule
```

---

## Data Flow

### Tool Activation Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT SIDE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. User Input (Left-Click / Touch)                                         │
│         │                                                                   │
│         ▼                                                                   │
│  ┌──────────────────┐                                                       │
│  │   InputHandler   │  Detects input, checks debounce                       │
│  └────────┬─────────┘                                                       │
│           │                                                                 │
│           ▼                                                                 │
│  ┌──────────────────┐                                                       │
│  │  ToolController  │  Checks if tool equipped & ready                      │
│  └────────┬─────────┘                                                       │
│           │                                                                 │
│           ├─────────────────────────────────┐                               │
│           │                                 │                               │
│           ▼                                 ▼                               │
│  ┌──────────────────┐              ┌──────────────────┐                     │
│  │ToolModuleManager │              │  ToolService     │                     │
│  │  → tool_id.lua   │              │ :RequestActivate │                     │
│  │  :OnActivate()   │              └────────┬─────────┘                     │
│  └──────────────────┘                       │                               │
│   (Client Prediction)                       │                               │
│                                             │                               │
└─────────────────────────────────────────────┼───────────────────────────────┘
                                              │ RemoteFunction
┌─────────────────────────────────────────────┼───────────────────────────────┐
│                              SERVER SIDE    │                               │
├─────────────────────────────────────────────┼───────────────────────────────┤
│                                             ▼                               │
│                                    ┌──────────────────┐                     │
│  2. Server Receives Request        │   ToolService    │                     │
│                                    │   Set().lua      │                     │
│                                    └────────┬─────────┘                     │
│                                             │                               │
│           ┌─────────────────────────────────┼─────────────────────┐         │
│           ▼                                 ▼                     ▼         │
│  ┌──────────────────┐              ┌──────────────────┐  ┌──────────────┐   │
│  │ValidationManager │              │ CooldownManager  │  │EquipManager  │   │
│  │ - Player valid?  │              │ - On cooldown?   │  │ - Has tool?  │   │
│  │ - Rate limited?  │              └────────┬─────────┘  └──────────────┘   │
│  │ - Range check    │                       │                               │
│  └────────┬─────────┘                       │                               │
│           │                                 │                               │
│           └─────────────┬───────────────────┘                               │
│                         ▼                                                   │
│  3. Validation Pass    ┌──────────────────┐                                 │
│                        │ActivationManager │  Loads tool module              │
│                        └────────┬─────────┘                                 │
│                                 │                                           │
│                                 ▼                                           │
│                        ┌──────────────────┐                                 │
│                        │   tool_id.lua    │  Per-tool server logic          │
│                        │   :Activate()    │                                 │
│                        └──────────────────┘                                 │
│                                                                             │
│  4. Fire Client Signals (ToolActivated, ToolCooldownStart, ToolStateChanged)│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Module Loading Flow

```
┌─────────────────────┐
│  ActivationManager  │
│  (Server) or        │
│  ToolModuleManager  │
│  (Client)           │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────────────────────────┐
│  GetToolModule(toolId, toolData)        │
│  1. Check cache for existing module     │
│  2. Build path from Category/Subcategory│
│  3. Find ModuleScript                   │
│  4. require() the module                │
│  5. Call Init() if exists               │
│  6. Cache and return module             │
└─────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────┐
│  Tools/Categories/                      │
│    [Category]/                          │
│      [Subcategory]/                     │
│        [tool_id].lua                    │
└─────────────────────────────────────────┘
```

---

## Component Details

### ActivationManager (Server)

**Purpose:** Dynamically loads and calls per-tool server modules.

**Key Functions:**
- `GetToolModule(toolId, toolData)` - Load/cache tool module
- `Activate(player, toolId, targetData)` - Call tool's Activate function
- `OnToolEquipped(player, toolId)` - Notify tool of equip
- `OnToolUnequipped(player, toolId)` - Notify tool of unequip
- `ClearModuleCache(toolId)` - Clear cached module (for hot-reloading)

**Module Path Resolution:**
```
Tools/Categories/[toolData.Category]/[toolData.Subcategory]/[toolId].lua
```

### ToolModuleManager (Client)

**Purpose:** Dynamically loads and calls per-tool client modules.

**Key Functions:**
- `GetToolModule(toolId, toolData)` - Load/cache tool module
- `OnToolActivated(toolId, toolData, targetData)` - Call tool's OnActivate
- `OnToolEquipped(toolId, toolData)` - Call tool's OnEquip
- `OnToolUnequipped(toolId, toolData)` - Call tool's OnUnequip
- `OnToolStateChanged(toolId, toolData, newState)` - Call tool's OnStateChanged

---

## Tool Definition Schema

```lua
{
    -- === REQUIRED ===
    ToolId = "unique_id",           -- Unique identifier (matches filename)
    Category = "Weapons",            -- Top-level category (folder name)
    Subcategory = "Swords",          -- Subcategory (folder name)
    AssetName = "Tool Name",         -- Exact name of Tool instance in Assets folder

    Stats = {
        -- Common stats
        Cooldown = 0.8,              -- Seconds between activations

        -- Type-specific stats (read by tool module)
        Damage = 25,                 -- For weapons
        Range = 8,                   -- For melee/ranged
        HealAmount = 30,             -- For consumables
        BatteryLife = 300,           -- For utilities
    },

    BehaviorConfig = {
        ActivationType = "Click",    -- "Click" (default) or "Hold"
                                     -- See Documentations/Activation_Types/ for details

        -- Animation/Sound/VFX (used by tool modules)
        ActivateAnimation = "rbxassetid://...",
        ActivateSound = "rbxassetid://...",
        ActivateEffect = "rbxassetid://...",

        -- Tool-specific config (read by tool module)
        MeleeData = { ... },
        ConsumableData = { ... },
        UtilityData = { ... },
    },

    -- === OPTIONAL METADATA (uncomment if needed) ===
    -- RequiredLevel = 1,
    -- Rarity = "Common",
    -- Description = "Tool description",
}
```

### AssetName Resolution

The `AssetName` field specifies the **exact name** of the Tool instance in the Assets folder:

```
ReplicatedStorage.Assets.Tools.[Category].[Subcategory].[AssetName]
```

**Why AssetName is required:**
- Tool instance names often contain spaces (e.g., "Grapple Hook", "Fire Sword")
- Tool IDs use underscores for code compatibility (e.g., `grapple_hook`, `fire_sword`)
- Without `AssetName`, the framework falls back to removing underscores from ToolId (e.g., `grapplehook`)
- This fallback rarely matches the actual tool name in Studio

**Examples:**

| ToolId | AssetName | Tool Instance Name |
|--------|-----------|--------------------|
| `grapple_hook` | `"Grapple Hook"` | "Grapple Hook" |
| `fire_sword` | `"Fire Sword"` | "Fire Sword" |
| `battleaxe_iron` | `"Iron Battleaxe"` | "Iron Battleaxe" |
| `flashlight_standard` | `"Flashlight"` | "Flashlight" |


---

## Adding New Tools

### Step 1: Create Tool Definition

Add to appropriate subcategory file in `ToolDefinitions/ToolRegistry/Categories/`:

```lua
-- Categories/Weapons/Axes.lua
return {
    battleaxe_iron = {
        ToolId = "battleaxe_iron",
        Category = "Weapons",
        Subcategory = "Axes",
        AssetName = "Iron Battleaxe", -- REQUIRED: Exact name of Tool in Assets folder
        Stats = { Damage = 40, Range = 6, Cooldown = 1.2 },
        BehaviorConfig = {
            ActivationType = "Click",
            MeleeData = { HitboxSize = Vector3.new(5, 5, 5) },
        },
    },
}
```

### Step 2: Create Server Tool Module

Create: `ToolService/Tools/Categories/Weapons/Axes/battleaxe_iron.lua`

```lua
local BattleaxeIron = {}

function BattleaxeIron:Activate(player, toolData, targetData)
    -- Implement axe attack logic
    -- Can copy from sword_classic and modify
    return true
end

function BattleaxeIron.Init()
    -- Initialize references
end

return BattleaxeIron
```

### Step 3: Create Client Tool Module

Create: `ToolController/Tools/Categories/Weapons/Axes/battleaxe_iron.lua`

```lua
local BattleaxeIron = {}

function BattleaxeIron:OnActivate(toolData, targetData)
    -- Play attack animation and sound
end

function BattleaxeIron.Init()
    -- Initialize references
end

return BattleaxeIron
```

### Step 4: Create Tool Asset

1. Create folder: `ReplicatedStorage.Assets.Tools.Weapons.Axes`
2. Insert Tool instance with the **exact name specified in `AssetName`** (e.g., "Iron Battleaxe")
3. Add Handle part with visuals
4. Configure Tool properties

**Important:** The Tool instance name must **exactly match** the `AssetName` in the registry definition, including spaces and capitalization.

### Step 5: Test

```lua
local ToolService = Knit.GetService("ToolService")
ToolService:EquipTool(player, "battleaxe_iron")
```

---

## Server Tool Module Functions

### Click Tools (Default)

| Function | Required | Parameters | Description |
|----------|----------|------------|-------------|
| `Activate` | Yes | `player, toolData, targetData` | Main tool logic, returns boolean |
| `OnEquip` | No | `player, toolData` | Called when equipped |
| `OnUnequip` | No | `player, toolData` | Called when unequipped |
| `Init` | No | none | Called once when module loads |

### Hold Tools

| Function | Required | Parameters | Description |
|----------|----------|------------|-------------|
| `OnButtonDown` | **Yes** | `player, toolData` | Called when button pressed - **marks tool as Hold type** |
| `OnButtonUp` | **Yes** | `player, toolData` | Called when button released |
| `Activate` | No | `player, toolData, targetData` | Usually empty for Hold tools |
| `OnEquip` | Recommended | `player, toolData` | Setup per-player state |
| `OnUnequip` | Recommended | `player, toolData` | Cleanup state, stop firing |
| `Init` | No | none | Called once when module loads |

**See [Activation_Types/Hold.md](./Activation_Types/Hold.md) for detailed Hold tool implementation.**

## Client Tool Module Functions

### Click Tools (Default)

| Function | Required | Parameters | Description |
|----------|----------|------------|-------------|
| `OnActivate` | Yes | `toolData, targetData` | Visual feedback on activation |
| `OnEquip` | No | `toolData` | Called when equipped |
| `OnUnequip` | No | `toolData` | Called when unequipped |
| `OnStateChanged` | No | `newState` | Called when server sends state change |
| `Init` | No | none | Called once when module loads |

### Hold Tools

| Function | Required | Parameters | Description |
|----------|----------|------------|-------------|
| `OnButtonDown` | **Yes** | `toolData, targetData` | Called when button pressed - **marks tool as Hold type** |
| `OnButtonUp` | **Yes** | `toolData, targetData` | Called when button released |
| `OnActivate` | No | `toolData, targetData` | Usually empty for Hold tools |
| `OnEquip` | No | `toolData` | Called when equipped |
| `OnUnequip` | No | `toolData` | Called when unequipped |
| `Init` | No | none | Called once when module loads |

**See [Activation_Types/Hold.md](./Activation_Types/Hold.md) for detailed Hold tool implementation.**

---

## State Changes (Server to Client)

For tools that have state (like flashlight on/off):

**Server (in tool module):**
```lua
function FlashlightStandard:Activate(player, toolData, targetData)
    -- Toggle state
    _toggleStates[player] = not _toggleStates[player]

    -- Notify client
    ToolService.Client.ToolStateChanged:Fire(player, toolData.ToolId, {
        isOn = _toggleStates[player]
    })

    return true
end
```

**Client (in tool module):**
```lua
function FlashlightStandard:OnStateChanged(newState)
    if newState.isOn then
        -- Update UI to show "ON"
    else
        -- Update UI to show "OFF"
    end
end
```

---

## ToolStateManager (Automatic Cleanup)

For tools with persistent state (physics connections, ongoing effects, etc.), use `ToolStateManager` for automatic cleanup when the player's character ancestry changes (respawn/leave).

**Location:** `SharedSource/Utilities/ToolStateManager`

### Why Use ToolStateManager?

- **Automatic cleanup** via AncestryChanged - detects character/model removal (respawn, player leaving, NPC destruction)
- **No manual PlayerRemoving listener needed** - character ancestry detection handles player leave cleanup
- **Character validity checks** - verify character is spawned before operations
- **Works on both server and client** - same API, shared utility

### API Reference

| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `RegisterState` | `toolUser, toolId, state, cleanupCallback?` | `state` | Registers state with auto-cleanup for both Players and NPCs |
| `GetState` | `toolUser, toolId` | `any?` | Gets registered state (nil if not found) |
| `CleanupState` | `toolUser, toolId` | `void` | Manual cleanup (triggers callback) |
| `CleanupToolUser` | `toolUser` | `void` | Cleanup all states for tool user (Player or NPC Model) |
| `CleanupPlayer` | `player` | `void` | Cleanup all states for player (deprecated, use CleanupToolUser) |
| `IsPlayer` | `toolUser` | `boolean` | Checks if tool user is a Player |
| `IsNPC` | `toolUser` | `boolean` | Checks if tool user is an NPC Model |
| `IsToolUserValid` | `toolUser` | `boolean` | Checks if tool user (Player or NPC) is valid |
| `IsNPCValid` | `npcModel` | `boolean` | NPC validation against NPC_Service.ActiveNPCs |
| `IsCharacterValid` | `player` | `boolean` | Character exists, has parent, humanoid alive |
| `HasCharacter` | `player` | `boolean` | Character exists with parent (less strict) |
| `GetValidCharacter` | `player` | `Model?` | Returns character if valid, else nil |

### Server Usage Example

```lua
local ToolStateManager = require(SharedSource.Utilities.ToolStateManager)

local TOOL_ID = "grapple_hook"

-- Define cleanup callback
local function onStateCleanup(player, state)
    if state.connection then state.connection:Disconnect() end
    if state.pullForce then state.pullForce:Destroy() end
end

-- In OnEquip or Activate:
local function getOrCreateState(player, toolData)
    local existing = ToolStateManager:GetState(player, TOOL_ID)
    if existing then return existing end
    
    local newState = { connection = nil, pullForce = nil, toolData = toolData }
    return ToolStateManager:RegisterState(player, TOOL_ID, newState, onStateCleanup)
end

-- In Activate:
function ToolModule:Activate(player, toolData, targetData)
    if not ToolStateManager:IsCharacterValid(player) then
        return false
    end
    
    local state = getOrCreateState(player, toolData)
    -- ... tool logic
end

-- In OnUnequip:
function ToolModule:OnUnequip(player, toolData)
    ToolStateManager:CleanupState(player, TOOL_ID)
end
```

### Client Usage Example

```lua
local ToolStateManager = require(SharedSource.Utilities.ToolStateManager)
local player = Players.LocalPlayer

local TOOL_ID = "grapple_hook"

-- Define cleanup callback
local function onStateCleanup(_player, state)
    if state.inputConnection then state.inputConnection:Disconnect() end
    -- Reset visuals...
end

-- In OnEquip:
function ToolModule:OnEquip(toolData)
    if not ToolStateManager:HasCharacter(player) then return end
    
    local state = getOrCreateState() -- similar pattern as server
    state.inputConnection = UserInputService.InputBegan:Connect(...)
end

-- In OnUnequip:
function ToolModule:OnUnequip(toolData)
    ToolStateManager:CleanupState(player, TOOL_ID)
end
```

### Cleanup Triggers

| Event | Cleanup Triggered? |
|-------|--------------------|
| Character parent → nil (respawn) | ✅ Yes (automatic) |
| Player leaves game | ✅ Yes (automatic) |
| Tool unequipped | Manual via `CleanupState()` |
| Character dies | No (use `IsCharacterValid` checks) |

### Best Practices

1. **Always validate character** before operations:
   ```lua
   if not ToolStateManager:IsCharacterValid(player) then return end
   ```

2. **Store toolData in state** for cleanup callback:
   ```lua
   state.toolData = toolData -- Available in cleanup callback
   ```

3. **Use unique TOOL_ID constants** to avoid conflicts:
   ```lua
   local TOOL_ID = "grapple_hook" -- Match tool registry ID
   ```

4. **Cleanup on unequip** for immediate state reset:
   ```lua
   function ToolModule:OnUnequip(player, toolData)
       ToolStateManager:CleanupState(player, TOOL_ID)
   end
   ```

---

## Security Model

1. **Server Authority** - Tool modules on server handle all game logic
2. **Client Prediction** - Client modules only handle visual feedback
3. **Validation** - ValidationManager checks all requests before activation
4. **Rate Limiting** - 20 activations/second max per player

---

## NPC Tool Support

The Tool Framework supports NPC tool users in addition to Players. NPCs are identified by their Model instance and tracked via `NPC_Service.ActiveNPCs[npcModel]`.

**Marketplace ID for NPC System:** `07473040-45dc-4afa-bb24-462e187d10ee`

> **For detailed NPC integration, API reference, and examples, see [NPC-Tool-Support.md](./NPC-Tool-Support.md)**

---

## Performance

1. **Lazy Loading** - Tool modules loaded on first use
2. **Module Caching** - Loaded modules cached in memory
3. **Hot-Reload Support** - `ClearModuleCache()` for development

---

## Debugging

Console prefixes:
- `[ActivationManager]` - Server module loading
- `[ToolModuleManager]` - Client module loading
- `[tool_id]` - Per-tool debug messages
