# ⚔️ Combat System Implementation Registry

## 📋 Overview

The Combat System manages the interaction between **Weapon Definitions** and **Combat Logic Types**. This registry ensures that weapon stats are correctly linked to hit detection and server-side damage validation.

---

## 🛠️ Functional Combat Types

### Slash System

**ID:** `[b0219013-d009-4cd4-9cf3-6d907705a26f]`

**Description:** A 5-hit combo engine that uses **ClientCast** for raycast-based hit detection.

* **Configurable Logic**: Uses `SlashSettings` to control combo windows and attack speeds.
* **Task Parameters**:
* `Damage`: The amount of health removed per hit.
* `Cooldown`: The delay between attack sequences.
* `EnableSlash`: Toggle that activates the melee handler.


* **Workspace Dependency**: Requires weapon models to have parts containing **Attachments** named `DmgPoint`.

---

## 📊 Technical Comparison & Configuration

| Combat Type | Logic ID | Required Config | Detection Method |
| --- | --- | --- | --- |
| **Melee** | `SlashHandler` | `SlashSettings` | Raycast (ClientCast) |
| **Ranged** | `Projectile` | `BulletConfig` | FastCast / Physics |

---

## ⚙️ Core Integration Rules

### 📍 Weapon Registration

Metadata must be added to:
`src/ReplicatedStorage/SharedSource/Datas/ToolDefinitions/ToolRegistry/Subcategory/Weapons/Swords.lua`

```lua
sword_katana = {
    ToolId = "sword_katana",
    Stats = { Damage = 15, Cooldown = 0.8 },
    BehaviorConfig = { EnableSlash = true }
}

```

### ⚠️ Dependency Guardrails

* **Hitbox Points**: If `DmgPoint` attachments are missing from the weapon model, no damage will be registered.
* **Logic Files**: Do not move `SlashHandler.lua` from its folder, as the **Knit** controllers expect them in specific paths for combat initiation.
* **Validation**: The server checks `Stats.Range` to prevent distance-based exploits.

---

## ⚡ Developer Commands

**Check Combo State:**

```lua
local Slash = require(game.ReplicatedStorage.ClientSource.Client.CombatController.Components.Others.SlashHandler)
print(Slash._comboIndex)

```
* **Task Parameters**:
  * `DamageReduction`: Percentage of damage negated while blocking (default: 50%)
  * `ParryWindow`: Timing window in seconds for parry (default: 0.2s)
  * `StunDuration`: How long attacker is stunned on parry (default: 1.5s)
  * `CanParry` / `CanBlock`: Per-weapon configurability in BehaviorConfig

* **Integration Point**: `DamageHandler.ApplyDamage()` — block/parry check runs before `TakeDamage()`
* **Full Documentation**: See `ParryBlockGuide.md` in this folder

---

## 📊 Technical Comparison & Configuration (Updated)

| Combat Type | Logic ID | Required Config | Detection Method | Defense Interaction |
| --- | --- | --- | --- | --- |
| **Melee (Punch)** | `NormalAttack` | `PunchSettings` | ClientCast / Hitbox | Can be **blocked** (not parried) |
| **Melee (Slash)** | `SlashHandler` | `SlashSettings` | Raycast (ClientCast) | Can be **blocked** and **parried** |
| **Ranged** | `Projectile` | `BulletConfig` | FastCast / Physics | Cannot be blocked or parried |
| **Block/Parry** | `BlockParryHandler` | `ParryBlockSettings` | Attribute-based state | Defensive — reduces/negates incoming damage |