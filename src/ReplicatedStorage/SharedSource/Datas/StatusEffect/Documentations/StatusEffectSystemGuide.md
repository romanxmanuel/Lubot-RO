# Status Effect System Guide

## Overview

The **Status Effect System** is a dedicated, generic service for applying, removing, and querying timed status effects on any character (player or NPC). It decouples effect logic from individual combat components, making it easy to add new effects (stun, slow, freeze, burn, etc.) without code changes — only configuration.

### Architecture

| Component | Side | Location | Role |
|-----------|------|----------|------|
| **StatusEffectService** | Server | `ServerSource/Server/StatusEffectService/` | Authoritative effect management, BuffTimerUtil, client/server signals |
| **StatusEffectController** | Client | `ClientSource/Client/StatusEffectController/` | Visual feedback (animation, VFX, movement, sounds) |
| **StatusEffectSettings** | Shared | `SharedSource/Datas/StatusEffect/StatusEffectSettings.lua` | Per-effect configuration (duration, visuals, restrictions) |

---

## Signal Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        SERVER                                    │
│                                                                  │
│  Any Service (e.g., DamageHandler after parry)                   │
│    └─ StatusEffectService:ApplyEffect(character, "Stun")         │
│                                                                  │
│  StatusEffectService                                             │
│    ├─ BuffTimerUtil manages all effect timers                     │
│    ├─ :ApplyEffect(char, effectName, durationOverride?)           │
│    │   ├─ onApply: set CombatState, freeze movement, etc.        │
│    │   ├─ fires Client.EffectApplied → to player                 │
│    │   └─ fires OnEffectApplied → to server listeners            │
│    ├─ :RemoveEffect(char, effectName)                             │
│    ├─ :HasEffect(char, effectName) → boolean                      │
│    └─ :GetActiveEffects(char) → table                             │
│                                                                  │
│  Other Services (e.g., BlockParryHandler)                        │
│    └─ Listen to OnEffectApplied/OnEffectRemoved                   │
│       (e.g., force-end block when stunned)                        │
│                                                                  │
└──────────────────────────┬──────────────────────────────────────┘
                           │ Client Signals
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT                                    │
│                                                                  │
│  StatusEffectController                                          │
│    ├─ Listens to EffectApplied / EffectRemoved                   │
│    ├─ Per-effect visual handling (config-driven):                 │
│    │   ├─ Animation (play/stop looping track)                     │
│    │   ├─ VFX (clone → attach → rotate → destroy)                │
│    │   ├─ Movement (setWalkSpeed / restoreWalkSpeed)              │
│    │   ├─ CombatState attribute                                   │
│    │   └─ Sound (one-shot on apply)                               │
│    └─ :HasEffect(effectName) → boolean                            │
│                                                                  │
│  Other Controllers (e.g., BlockParryHandler client)              │
│    └─ StatusEffectController:HasEffect("Stun") for input gating  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## API Reference

### StatusEffectService (Server)

#### Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `:ApplyEffect(character, effectName, durationOverride?)` | `Model`, `string`, `number?` | `void` | Applies the named effect. Uses config duration if override is nil. |
| `:RemoveEffect(character, effectName)` | `Model`, `string` | `void` | Immediately removes the effect and restores state. |
| `:HasEffect(character, effectName)` | `Model`, `string` | `boolean` | Checks if an effect is currently active. |
| `:GetActiveEffects(character)` | `Model` | `{string: true}` | Returns table of all active effect names. |

#### Server-Side Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `OnEffectApplied` | `(character, effectName, duration)` | Fired when any effect is applied. Other services can listen. |
| `OnEffectRemoved` | `(character, effectName)` | Fired when any effect is removed or expires. |

#### Client Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `Client.EffectApplied` | `(effectName, duration)` | Fired to the affected player for visual feedback. |
| `Client.EffectRemoved` | `(effectName)` | Fired to the affected player when effect ends. |

### StatusEffectController (Client)

| Method | Returns | Description |
|--------|---------|-------------|
| `:HasEffect(effectName)` | `boolean` | Whether the local player has the named effect active. |
| `:GetActiveEffects()` | `table` | List of active effect names on the local player. |

---

## Configuration Reference (StatusEffectSettings.lua)

Each effect is a key in the settings table:

```lua
Stun = {
    DefaultDuration = 1.5,           -- seconds
    BuffMode = "refresh",            -- "refresh" | "extend" | "stack"
    MovementSpeedMultiplier = 0,     -- 0 = frozen
    CanAttack = false,
    CanBlock = false,
    CombatState = "Stunned",         -- attribute value (nil = don't set)
    Animation = {
        AssetId = "rbxassetid://97116917104177",
        Looped = true,
    },
    VFX = {
        Asset = "ReplicatedStorage.Assets.Effects.Combat.StunFX",
        AttachTo = "Head",
        RotateSpeed = 120,           -- degrees/sec
        Offset = { 0, 2, 0 },
    },
    Sound = nil,                     -- nil = no sound
},
```

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `DefaultDuration` | `number` | Effect duration in seconds |
| `BuffMode` | `string` | How re-application behaves: `"refresh"` resets timer, `"extend"` adds time, `"stack"` increments stacks |
| `MovementSpeedMultiplier` | `number?` | Multiplier for WalkSpeed (nil = don't modify) |
| `CanAttack` | `boolean` | Whether the character can attack (informational — systems must check) |
| `CanBlock` | `boolean` | Whether the character can block (informational — systems must check) |
| `CombatState` | `string?` | Value to set on `character:SetAttribute("CombatState", ...)` (nil = don't set) |
| `Animation` | `table?` | `{ AssetId: string, Looped: boolean }` — played on the character |
| `VFX` | `table?` | `{ Asset: string, AttachTo: string, RotateSpeed: number, Offset: {x,y,z} }` |
| `Sound` | `string?` | Sound asset ID played on apply (nil = none) |

---

## How to Add a New Status Effect

### Step 1: Add Configuration

Open `StatusEffectSettings.lua` and add a new entry:

```lua
Slow = {
    DefaultDuration = 3,
    BuffMode = "refresh",
    MovementSpeedMultiplier = 0.3,
    CanAttack = true,
    CanBlock = true,
    CombatState = nil,               -- doesn't change combat state
    Animation = nil,                  -- no animation
    VFX = {
        Asset = "ReplicatedStorage.Assets.Effects.Combat.SlowFX",
        AttachTo = "HumanoidRootPart",
        RotateSpeed = 0,
        Offset = { 0, 0, 0 },
    },
    Sound = "rbxassetid://0000000000",
},
```

### Step 2: Create VFX Asset (if applicable)

Place the VFX asset (Model or BasePart with ParticleEmitters) at the path specified in `VFX.Asset`.

### Step 3: Apply the Effect

From any server-side service or component:

```lua
local StatusEffectService = Superbullet.GetService("StatusEffectService")
StatusEffectService:ApplyEffect(character, "Slow")           -- uses DefaultDuration
StatusEffectService:ApplyEffect(character, "Slow", 5)        -- 5 second override
```

**That's it — no code changes required.** The system automatically handles:
- Server-side state management and timer
- Client visual feedback (animation, VFX, movement, sound)
- Cleanup on death/disconnect/respawn

---

## Integration Examples

### Parry → Stun (current implementation)

In `DamageHandler.lua` (DamageService component):
```lua
if defense.result == "parried" then
    local attackerChar = damageInfo.Attacker or user
    StatusEffectService:ApplyEffect(attackerChar, "Stun")
    return false, "Attack was parried"
end
```

### Checking for Active Effects

**Server (BlockParryHandler):**
```lua
if StatusEffectService:HasEffect(char, "Stun") then
    BlockRejectedSignal:Fire(player, "Stunned")
    return false
end
```

**Client (BlockParryHandler):**
```lua
if StatusEffectController and StatusEffectController:HasEffect("Stun") then
    return -- don't allow block input
end
```

### Reacting to Effects (Server-to-Server)

```lua
StatusEffectService.OnEffectApplied:Connect(function(character, effectName, _duration)
    if effectName == "Stun" then
        local player = Players:GetPlayerFromCharacter(character)
        if player and character:GetAttribute("CombatState") == "Blocking" then
            BlockParryHandler:EndBlock(player)
        end
    end
end)
```

---

## Cleanup Behavior

| Event | Action |
|-------|--------|
| Character dies | All active effects removed (server + client) |
| Player disconnects | All active effects removed (server) |
| Character respawns | Client clears all visual state |
| Effect expires naturally | BuffTimerUtil `onExpire` callback fires, state restored, signals sent |
| Effect manually removed | `RemoveEffect()` performs cleanup then clears timer |

---

## NPC Support

StatusEffectService works on **any character Model**, not just player characters:
- Server-side state management (CombatState attribute, WalkSpeed) works for NPCs
- Client signals (`EffectApplied`, `EffectRemoved`) are **only fired for player characters**
- Server signals (`OnEffectApplied`, `OnEffectRemoved`) fire for **all characters** including NPCs
- NPC AI can check `character:GetAttribute("CombatState")` to respect effects

---

## BuffTimerUtil Integration

The system uses `BuffTimerUtil.new(0.05)` (50ms tick) for precise timing:
- `buffTimer:apply(entity, name, duration, opts)` — creates/refreshes a buff
- `buffTimer:remove(entity, name)` — removes without triggering onExpire
- `buffTimer:has(entity, name)` — checks if active
- Each StatusEffectService has its own BuffTimerUtil instance, separate from block-specific timers in BlockParryHandler
