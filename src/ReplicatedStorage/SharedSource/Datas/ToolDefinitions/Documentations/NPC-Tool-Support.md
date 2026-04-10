# NPC Tool Support

The Tool Framework supports NPC tool users in addition to Players. NPCs are identified by their Model instance and tracked via the NPC system.

---

## NPC System Integration

**Marketplace ID:** `07473040-45dc-4afa-bb24-462e187d10ee`

The NPC system tracks active NPCs in:
```lua
NPC_Service.ActiveNPCs[npcModel] -- Key is the NPC Model instance
```

---

## ToolUser Type

Tools can be used by either Players or NPC Models:

```lua
type ToolUser = Player | Model
```

- **Player**: Standard Roblox Player instance with a character
- **Model**: NPC Model instance tracked by `NPC_Service.ActiveNPCs`

---

## ValidationManager NPC Support

```lua
-- Check if tool user is a Player or NPC
ValidationManager:IsPlayer(toolUser)   --> boolean
ValidationManager:IsNPC(toolUser)      --> boolean

-- Validate NPC Model
ValidationManager:ValidateNPC(npcModel) --> boolean
```

**TODO: Implement NPC validation in `ValidateNPC`:**
- Verify `NPC_Service.ActiveNPCs[npcModel]` exists
- Check if NPC is alive (Humanoid health > 0)
- Validate NPC permissions for specific tools

---

## ToolStateManager NPC Support

```lua
-- Check if tool user (Player or NPC) is valid
ToolStateManager:IsToolUserValid(toolUser) --> boolean

-- NPC-specific validation
ToolStateManager:IsNPCValid(npcModel)      --> boolean

-- Register state for NPC (automatic cleanup on model destruction)
ToolStateManager:RegisterState(npcModel, toolId, state, cleanupCallback)

-- Get/cleanup state for NPC
ToolStateManager:GetState(npcModel, toolId)
ToolStateManager:CleanupState(npcModel, toolId)
ToolStateManager:CleanupToolUser(npcModel)
```

**TODO: Implement NPC validation in `IsNPCValid`:**
- Verify `NPC_Service.ActiveNPCs[npcModel]` exists
- Check NPC health via Humanoid

---

## Automatic Cleanup

Both Players and NPCs have automatic cleanup:

| Tool User | Automatic Cleanup Trigger |
|-----------|---------------------------|
| Player | Character respawn, player leaving |
| NPC | Model destruction/removal (AncestryChanged) |

The framework watches NPC Model ancestry changes and automatically cleans up tool state when the model is destroyed or removed from workspace.

---

## Example: NPC Using a Tool

```lua
-- Server-side NPC tool usage
local ValidationManager = require(...)
local ToolStateManager = require(...)

-- Get NPC model from NPC system
local npcModel = workspace.NPCs.Guard001

-- Validate NPC can equip
local canEquip, err = ValidationManager:ValidateEquip(npcModel, "sword_basic")
if not canEquip then
    warn("NPC cannot equip:", err)
    return
end

-- Register state for NPC (auto-cleanup when model is destroyed)
local state = { isAttacking = false }
ToolStateManager:RegisterState(npcModel, "sword_basic", state, function(user, s)
    -- Cleanup logic when NPC tool state is removed
    s.isAttacking = false
end)

-- Check validity before operations
if ToolStateManager:IsToolUserValid(npcModel) then
    -- Perform tool action
end

-- Manual cleanup (optional - automatic cleanup happens on model destruction)
ToolStateManager:CleanupToolUser(npcModel)
```

---

## Implementing NPC Validation

To fully integrate with the NPC system, implement the TODO validators:

### ValidationManager.lua

```lua
function ValidationManager:ValidateNPC(npcModel: Model): boolean
    -- Check NPC_Service.ActiveNPCs
    if not NPC_Service or not NPC_Service.ActiveNPCs[npcModel] then
        return false
    end

    -- Check model exists
    if not npcModel or not npcModel.Parent then
        return false
    end

    -- Check humanoid health
    local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    return true
end
```

### ToolStateManager/init.lua

```lua
function ToolStateManager:IsNPCValid(npcModel: Model): boolean
    -- Check NPC_Service.ActiveNPCs
    if not NPC_Service or not NPC_Service.ActiveNPCs[npcModel] then
        return false
    end

    -- Check model exists
    if not npcModel or not npcModel.Parent then
        return false
    end

    -- Check humanoid health
    local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    return true
end
```
