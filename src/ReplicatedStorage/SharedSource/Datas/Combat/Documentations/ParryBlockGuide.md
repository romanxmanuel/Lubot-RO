# ⚔️ Parry and Block System Guide

## 📋 Overview

The Parry and Block system provides **client-predicted** defensive mechanics integrated into the existing CombatService → DamageService damage pipeline. Players can block incoming damage and, with precise timing, parry attacks to negate damage and stun the attacker.

### Key Features
- **Instant client-side blocking**: Press `F` (PC) or tap mobile button — visual feedback starts immediately, no server round-trip wait
- **Server validation**: Server confirms/rejects block state; final authority on damage calculations
- **Parrying**: Timing-based mechanic — block within a tight window to negate damage and stun the attacker
- **Per-weapon configurability**: Each weapon can independently enable/disable parry and block
- **Per-attack-type configurability**: Attack sub-types (punch, slash, etc.) define whether they can be parried or blocked
- **BuffTimerUtil integration**: Block cooldown and block timeout managed via timed buffs
- **StatusEffectService integration**: Stun (and future effects) managed by the dedicated StatusEffectService

---

## 🏗️ Architecture

### File Locations

| File | Location | Purpose |
|------|----------|---------|
| `ParryBlockSettings.lua` | `SharedSource/Datas/Combat/` | Central configuration (all tunable values) |
| `BlockParryHandler.lua` (Server) | `CombatService/Components/Others/` | Server validation, state management, parry evaluation |
| `BlockParryHandler.lua` (Client) | `CombatController/Components/Others/` | Input handling, client prediction, VFX/SFX |
| `StatusEffectService` | `ServerSource/Server/StatusEffectService/` | Manages stun (and all status effects) |
| `StatusEffectController` | `ClientSource/Client/StatusEffectController/` | Stun visual feedback (animation, VFX) |
| `StatusEffectSettings.lua` | `SharedSource/Datas/StatusEffect/` | Stun configuration (duration, visuals) |
| `BlockInputUI` (ScreenGui) | `StarterGui` | PC "F" key prompt + mobile block button |
| `DamageHandler.lua` (Modified) | `DamageService/Components/Others/` | Block/parry check inserted before TakeDamage |
| `DamageUtils.lua` (Modified) | `CombatService/Components/Others/` | Extended to pass AttackSubType and Attacker |

### Damage Pipeline Integration

```
Attack Input (Client)
  ↓
CombatService:PerformAttack / CombatService:PerformSlash (Server)
  ↓
NormalAttack / SlashHandler → DamageUtils.ApplyDamageToTargets
  ↓  (now passes AttackSubType + Attacker)
DamageService:ApplyDamage(attacker, target, damageInfo)
  ↓
DamageHandler.ApplyDamage
  ├─ Existing validations (invincibility, self-damage, team check)
  ├─ NEW: BlockParryHandler:EvaluateDefense() ← ── checks block/parry
  │   ├─ "parried" → negate damage + StatusEffectService:ApplyEffect(attacker, "Stun") → return
  │   ├─ "blocked" → reduce damage → continue
  │   └─ "none" → no change → continue
  └─ humanoid:TakeDamage(finalDamage)
```

---

## ⚙️ Configuration Reference

All configuration lives in `ParryBlockSettings.lua`. No code changes needed to tune values.

### Block Settings

| Field | Default | Description |
|-------|---------|-------------|
| `DamageReduction` | `0.5` | 50% damage negated while blocking |
| `MovementSpeedMultiplier` | `0.4` | WalkSpeed reduced to 40% while blocking |
| `MaxBlockDuration` | `5` | Max seconds block can be held before auto-release |
| `BlockCooldown` | `0.3` | Cooldown after releasing block before re-blocking |
| `AllowBareHanded` | `true` | Whether players can block without a weapon |
| `BareHandedReduction` | `0.25` | 25% damage reduction when blocking bare-handed |

### Parry Settings

| Field | Default | Description |
|-------|---------|-------------|
| `ParryWindow` | `0.2` | 200ms timing window at the start of a block |
| `DamageNegation` | `1.0` | 100% damage negated on successful parry |
| `MaxTimestampDrift` | `0.5` | Anti-cheat: max client timestamp drift (seconds) |

### Stun Settings

> **Note**: Stun configuration has been moved to `StatusEffectSettings.lua` as part of the dedicated Status Effect System. See [StatusEffectSystemGuide.md](StatusEffectSystemGuide.md) for details.
>
> Key stun values: `DefaultDuration = 1.5`, `MovementSpeedMultiplier = 0`, `CanAttack = false`, `CanBlock = false`

### Attack Type Rules

Controls which attacks can be blocked/parried:

| AttackSubType | CanBeParried | CanBeBlocked |
|---------------|:------------:|:------------:|
| `punch` | ❌ | ✅ |
| `slash` | ✅ | ✅ |
| `ranged` | ❌ | ❌ |
| `ability` | ❌ | ✅ |
| `area` | ❌ | ❌ |
| `environment` | ❌ | ❌ |

---

## 🗡️ Per-Weapon Configuration

Add `CanParry` and `CanBlock` to any weapon's `BehaviorConfig`:

```lua
sword_katana = {
    BehaviorConfig = {
        ActivationType = "Click",
        EnableSlash = true,
        CanParry = true,   -- This weapon can parry
        CanBlock = true,   -- This weapon can block
        -- ...
    },
}
```

### Default Behavior (when fields are missing)
- `CanBlock`: defaults to `true` for all weapons
- `CanParry`: defaults to `true` if `EnableSlash = true`, `false` otherwise

### Example: Weapon That Can Block But Not Parry
```lua
heavy_shield = {
    BehaviorConfig = {
        CanParry = false,  -- Too slow to parry
        CanBlock = true,   -- Excellent at blocking
    },
}
```

---

## 🔄 Combat State Machine

Characters have a `CombatState` attribute (string) on their character model:

```
Idle ──(block input)──→ Blocking  [CLIENT sets immediately, SERVER validates]
Blocking ──(release / timeout)──→ Idle
Blocking ──(hit within parry window)──→ Parry → Idle
Blocking ──(server rejects)──→ Idle  [CLIENT rolls back]
Idle ──(parried by target)──→ Stunned
Stunned ──(stun duration expires)──→ Idle
```

### Character Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `CombatState` | string | `"Idle"`, `"Blocking"`, or `"Stunned"` |
| `BlockStartTime` | number | `workspace:GetServerTimeNow()` when block started |
| `BlockingWeaponId` | string | ToolId of weapon used to block |

---

## 🎯 Parry vs Block Decision Flow

When damage hits a blocking target:

1. Is target `CombatState == "Blocking"`? → No: normal damage
2. Can this attack type be blocked? (`AttackTypeRules`) → No: normal damage
3. Is the target within parry window? (`ServerTime - BlockStartTime < ParryWindow`)
4. Can this attack type be parried? (`AttackTypeRules.CanBeParried`) → No: BLOCK (reduced damage)
5. Does the defender's weapon have `CanParry = true`? → No: BLOCK (reduced damage)
6. **PARRY**: negate all damage, stun attacker

---

## 🕐 Client Prediction Flow

```
CLIENT                                    SERVER
  │                                          │
  ├─ Player presses F                        │
  ├─ IMMEDIATELY:                            │
  │   ├─ Enter block stance (animation)      │
  │   ├─ Apply movement slow                 │
  │   ├─ Record BlockStartTime               │
  │                                          │
  ├─ Send RequestBlock(true, blockStartTime) │
  │ ─────────────────────────────────────►   │
  │                                          ├─ Validate (not stunned, not on cooldown)
  │                                          ├─ If VALID → BlockConfirmed
  │   ◄───────────────────────────────────── │  (no action needed, already blocking)
  │                                          ├─ If INVALID → BlockRejected
  │   ◄───────────────────────────────────── │
  ├─ Roll back to Idle                       │
```

---

## 🔧 How to Add New Attack Types

1. Add the new `AttackSubType` to `ParryBlockSettings.AttackTypeRules`:
```lua
AttackTypeRules = {
    -- existing entries ...
    my_new_attack = { CanBeParried = true, CanBeBlocked = true },
}
```

2. When calling `DamageUtils.ApplyDamageToTargets()`, pass the sub-type:
```lua
DamageUtils.ApplyDamageToTargets(targets, damage, char, {
    AttackSubType = "my_new_attack",
    Attacker = char,
})
```

---

## 🎨 Replacing Placeholder Assets

### Animations
Update IDs in `ParryBlockSettings.Animations`:
- `BlockIdle`: Looping block stance animation
- `ParrySuccess`: One-shot parry flash animation

> **Stunned animation** is now in `StatusEffectSettings.Stun.Animation.AssetId`

### Sounds
Update IDs in `ParryBlockSettings.Sounds`:
- `BlockStart`: Played when entering block stance
- `BlockHit`: Played when an attack is blocked
- `ParrySuccess`: Played on successful parry

### VFX
Create VFX assets at the paths specified in `ParryBlockSettings.VFX`:
- `ReplicatedStorage.Assets.Effects.Combat.Parry` — Particle effect cloned to HumanoidRootPart on parry

> **StunFX** is now in `StatusEffectSettings.Stun.VFX.Asset`

---

## 📡 Client Extension API

### Signals (Server → Client)
| Signal | Args | Description |
|--------|------|-------------|
| `BlockConfirmed` | — | Server accepted the block |
| `BlockRejected` | reason: string | Server rejected; client should roll back |
| `BlockHit` | attackerChar: Model | An attack was blocked |
| `ParrySuccess` | otherChar: Model | A parry succeeded (sent to both parties) |

> **Note**: `StunApplied` and `StunEnded` signals have been moved to `StatusEffectService` as `EffectApplied` and `EffectRemoved`. See [StatusEffectSystemGuide.md](StatusEffectSystemGuide.md).

### Methods (Client → Server)
| Method | Args | Returns | Description |
|--------|------|---------|-------------|
| `RequestBlock` | isBlocking: bool, blockStartTime: number? | bool | Start/stop blocking |

---

## ⚠️ Anti-Cheat Measures

- **Timestamp sanity**: Client `BlockStartTime` is clamped to ±`MaxTimestampDrift` (0.5s) from server time
- **State validation**: Server verifies player isn't stunned, on cooldown, or dead before accepting block
- **Weapon verification**: Server checks ToolRegistry to confirm weapon's CanBlock/CanParry capability
- **Input rate**: Knit RemoteFunction has built-in rate limiting; additional checks in ValidateAndStartBlock
