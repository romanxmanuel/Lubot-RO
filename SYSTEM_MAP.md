# SYSTEM_MAP.md
> Lubot-RO — 5-Hit Combat Game  
> Last updated: 2026-04-15  
> Consult this document before adding any new feature or editing any script.

---

## 1. Script Directory

| Tag | Script Name | Studio Path | Type | Description |
|-----|-------------|-------------|------|-------------|
| AC  | AttackController | StarterPlayer.StarterCharacterScripts.AttackController | LocalScript | 5-hit combo engine; autolock; VFX; damage fire |
| CC  | CameraController | StarterPlayer.StarterCharacterScripts.CameraController | LocalScript | Lock-on camera + RMB free-look orbit |
| DC  | DashController | StarterPlayer.StarterCharacterScripts.DashController | LocalScript | Double-tap/Q+dir dash input; fires Step to server |
| APC | AirPhysicsController | StarterPlayer.StarterCharacterScripts.AirPhysicsController | LocalScript | Double-jump force + jump animation/sound |
| CS  | CombatSystem | ServerScriptService.CombatSystem | Script | HP, entity spawn/kill/respawn, damage server-side |
| DH  | DashHandler | ServerScriptService.DashHandler | Script | Server dash velocity + Y-lock + particle VFX |
| UI  | UIController | StarterPlayer.StarterPlayerScripts.UIController | LocalScript | HP bar, EXP bar, cash counter, level-up overlay, tutorial |
| BM  | BackgroundMusic | StarterPlayer.StarterPlayerScripts.BackgroundMusic | LocalScript | Cycles background music tracks |
| EC  | EntityConfig | ServerScriptService.EntityConfig | ModuleScript | Entity definition table (add rows to spawn new enemies) |
| MC  | MasterConfig | ReplicatedStorage.MasterConfig | ModuleScript | Single source of truth for all tunable gameplay values |

---

## 2. Dependency Graph

```
MasterConfig (MC)
  ├── read by AttackController  (attack timings, damages, radii, animations, sounds)
  ├── read by DashController    (speed, duration, cooldown, doublePressWindow, sound)
  ├── read by AirPhysicsController (jumpPower, jumpAnimationId, jumpSoundId)
  ├── read by CombatSystem      (playerMaxHP, hitDamages, hitRadii, HPRegen, regenDelay)
  ├── read by DashHandler       (speed, duration, cooldown)
  └── read by BackgroundMusic   (backgroundMusicIds, backgroundMusicVolume)

EntityConfig (EC)
  └── read by CombatSystem      (entity definitions: name, maxHp, respawn, cashType, offset...)

AttackController (AC)
  └── writes CameraLockTarget ObjectValue → read by CameraController (CC)

CombatSystem (CS)
  └── fires HUDEvent RemoteEvent → read by UIController (UI)
```

---

## 3. RemoteEvents Table

| Name | Lives In | Fires From | Listens In | Payload |
|------|----------|-----------|------------|---------|
| AttackHit | ReplicatedStorage | AC (client) | CS (server) | hitPos Vector3, hitRadius number, comboIndex number, primaryModel Model\|nil |
| DummyHit | ReplicatedStorage | CS (server) | AC (client) | hitPos Vector3, isDead bool |
| Step | ReplicatedStorage | DC (client) | DH (server) | direction Vector3 |
| HUDEvent | ReplicatedStorage | CS (server) | UI (client) | data table {hp, maxHp, regening, level, levelUp, expPct, cash, killCash} |
| KillEvent | ReplicatedStorage | CS (server, BindableEvent :Fire) | UI (client, listens) | player Player, cashType string |

> Note: KillEvent is a BindableEvent fired server-side by CombatSystem and listened to by the server-side economy/progression logic. UIController receives kill rewards via HUDEvent.

---

## 4. ObjectValues and Attributes

| Name | Type | Parent | Written By | Read By | Purpose |
|------|------|--------|-----------|---------|---------|
| CameraLockTarget | ObjectValue | character model | AttackController | CameraController | HRP of current autolock target; nil = no lock |

### Player Attributes (set server-side)

| Attribute | Type | Set By | Read By | Purpose |
|-----------|------|--------|---------|---------|
| Level | number | server progression | AC (max combo index) | Determines how many combo hits are unlocked |
| Cash | number | server economy | UI (cash counter display) | Player currency |
| EXP | number | server progression | UI (EXP bar display) | Experience points |

---

## 5. Key Data Flows

### Attack Combo Flow
```
[LMB / R key press]
  → AC: handleAttack()
      → autolock findLockTarget() → sets lockObj.Value (CameraLockTarget)
      → CC: RenderStepped sees lockObj.Value set → enterCameraLock()
      → AC: comboMove() physics, VFX, animation, sound
      → AC: AttackHit:FireServer(hitPos, radius, comboIndex, model)
          → CS: AttackHit.OnServerEvent
              → apply damage to entityHP / NPC humanoid
              → if dead: killEntity() → KillEvent:Fire() → respawn timer
              → DummyHit:FireClient(player, hitPos) → AC kill feedback
```

### Dash Flow
```
[Double-tap WASD or Q+dir]
  → DC: tryDash()
      → DC: client VFX (transparency fade, particle aura, sound)
      → DC: Step:FireServer(direction)
          → DH: Step.OnServerEvent
              → LinearVelocity + YLock applied to HRP
              → ParticleFlash cloned to HRP
              → cleanup after Duration, debounce cleared after Cooldown
```

### Kill Economy Flow
```
CS: killEntity()
  → KillEvent:Fire(player, cashType)
      → server economy script: award Cash + EXP, check level-up
          → HUDEvent:FireClient(player, {cash, killCash, level, levelUp, expPct})
              → UI: animateCash(), setEXP(), doLevelUp() if applicable
```

---

## 6. MasterConfig Key Values Reference

| Key | Default | Used By | Notes |
|-----|---------|---------|-------|
| PlayerMaxHP | 150 | CS, UI | Base HP; scales with LevelHPScale |
| PlayerHPRegen | 2 | CS | HP/s during regen |
| PlayerRegenDelay | 5 | CS | Seconds after last damage before regen |
| AttackChainWindow | 1.5 | AC | Seconds to keep combo alive |
| AttackCooldown | 0.8 | AC | Min seconds between hits |
| AutolockReleaseDelay | 4.0 | AC | Seconds of inactivity before lock drops |
| HitDamages | {100,140,180,220,600} | AC, CS | Per-hit damage [1..5] |
| HitRadii | {8,20,26,13,32} | AC, CS | Per-hit AoE radius [1..5] |
| Speed | 120 | DC, DH | Dash studs/s |
| Duration | 0.3 | DC, DH | Dash active seconds |
| Cooldown | 0.0 | DC, DH | Post-dash cooldown seconds |
| DoublePressWindow | 0.3 | DC | Max seconds between double-tap |
| JumpPower | 150 | APC | Double-jump Y velocity |
| BackgroundMusicVolume | 0.45 | BM | Music volume |

---

## 7. EntityConfig Entry Types

| Name | maxHp | respawn | cashType | Notes |
|------|-------|---------|----------|-------|
| WoodenPost | 100 | 1s | Dummy | x3 small wooden dummies |
| PracticeDummy | 500 | 10s | Dummy | Standard scale dummy |
| MiniBoss | 3000 | 20s | Soldier | 1.5x scale dummy |
| BossDummy | 10000 | 45s | Soldier | 2.1x scale dummy |
| Army Soldier (Standard Mob) | 100 | 1s | Dummy | Cloned model, count=3 |
| RPG Soldier (Elite Boss) | 3000 | 20s | Soldier | Cloned model |
| Killer Boss | 10000 | 45s | Soldier | Cloned model |

> To add a new entity: add one row to EntityConfig. CombatSystem handles spawn, HP, kill, and respawn automatically. If using `modelName`, ensure the model exists in `ServerStorage.EntityTemplates`.

---

## 8. Edit Rules

### Before editing AttackController (AC)
- Check: CameraController (CC) — reads CameraLockTarget ObjectValue written by AC
- Check: CombatSystem (CS) — receives AttackHit payload (hitPos, radius, comboIndex, primaryModel)
- Check: MasterConfig (MC) — all timing/damage/radius values must stay here

**After editing AC, verify:**
- [ ] Combo chains 1→2→3→4→5 without reset inside AttackChainWindow
- [ ] CameraLockTarget ObjectValue created in character at script start
- [ ] AttackHit fires correct signature: (hitPos Vector3, hitRadius number, comboIndex number, primaryModel Model|nil)
- [ ] lastClickTime resets on each attack input
- [ ] Camera lock persists across the full combo chain

---

### Before editing CameraController (CC)
- Check: AttackController (AC) — CC depends on CameraLockTarget being created by AC on spawn

**After editing CC, verify:**
- [ ] Camera enters Scriptable mode when lockObj.Value is set
- [ ] Camera returns to Custom mode when lockObj.Value is nil
- [ ] RMB held = free-look orbit (does NOT clear lockObj.Value)
- [ ] RMB released = smoothly returns to lock-on framing
- [ ] exitedThisFrame guard prevents same-frame lock re-entry

---

### Before editing DashController (DC)
- Check: DashHandler (DH) — must match Step RemoteEvent signature
- Check: MasterConfig (MC) — dash values must stay there

**After editing DC, verify:**
- [ ] Double-tap WASD triggers dash within DoublePressWindow
- [ ] Q + direction key triggers dash immediately
- [ ] Dash sound plays on every dash
- [ ] Step:FireServer(direction) fires with a unit Vector3

---

### Before editing DashHandler (DH)
- Check: DashController (DC) — must match Step RemoteEvent payload
- Check: ReplicatedStorage — ParticleFlash object must exist

**After editing DH, verify:**
- [ ] Step RemoteEvent exists in ReplicatedStorage
- [ ] Debounce[Player] prevents cooldown spam per player
- [ ] LinearVelocity and YLock cleaned up after Duration seconds
- [ ] ParticleFlash cloned correctly and cleaned up

---

### Before editing CombatSystem (CS)
- Check: AttackController (AC) — AttackHit payload format
- Check: EntityConfig (EC) — entity tier table structure
- Check: MasterConfig (MC) — all damage/HP numbers must stay there
- Check: UIController (UI) — HUDEvent payload format

**After editing CS, verify:**
- [ ] Registry[model] entry is created by Reg_new() and fully cleared by Reg_clear() in killEntity() atomically
- [ ] killEntity() fires KillEvent then instantly hides model before Debris cleanup
- [ ] spawnEntity() correctly branches on tier.modelName (template clone vs wooden dummy)
- [ ] HP regen fires after PlayerRegenDelay seconds with no incoming damage
- [ ] Hit 4 applies applyFlinch to nearby non-primary models at 30% damage

---

### Before editing UIController (UI)
- Check: CombatSystem (CS) — HUDEvent payload structure

**After editing UI, verify:**
- [ ] HP bar updates on HUDEvent with hpUpdate flag
- [ ] Cash counter animates on kill (data.killCash > 0)
- [ ] Level-up flash fires when data.levelUp == true
- [ ] HUDEvent RemoteEvent exists in ReplicatedStorage

---

### Before editing EntityConfig (EC)
- Check: CombatSystem (CS) — ensure new fields are handled or optional

**After editing EC, verify:**
- [ ] Every entry has: name, maxHp, respawn, cashType, offset
- [ ] Any entry with modelName has a matching model in ServerStorage.EntityTemplates
- [ ] count field works correctly with the X-spread spacing (5 studs per copy)

---

### Before editing MasterConfig (MC)
- Check all consumers: AC, DC, APC, CS, DH, BM — any key rename must be updated everywhere

**After editing MC, verify:**
- [ ] No gameplay constant is hardcoded in any other script
- [ ] HitDamages and HitRadii remain parallel arrays of length 5
- [ ] AttackAnimations has exactly 5 entries

---

### Before editing AirPhysicsController (APC)
- Check: MasterConfig (MC) — JumpPower, JumpAnimationId, JumpSoundId

**After editing APC, verify:**
- [ ] First jump (StateChanged → Jumping) plays sound and animation
- [ ] Space while airborne gives double-jump upward velocity (JumpPower)
- [ ] Jump animation loads at Action2 priority (overrides default Animate script)
- [ ] jumpCount resets on Landed / Running state

---

### Before editing BackgroundMusic (BM)
- Check: MasterConfig (MC) — BackgroundMusicIds, BackgroundMusicVolume
- Note: Script currently has a duplicate dead-code block starting at line 34. The first `while true` loop exits via its own infinite loop before the second block runs.

**After editing BM, verify:**
- [ ] Music cycles through all BackgroundMusicIds in order
- [ ] Script handles empty ids table gracefully (early return)

---

## 9. Integration Checklists (Quick Reference)

| Script | Key Invariants |
|--------|---------------|
| AC | CameraLockTarget in character; AttackHit(hitPos,radius,comboIndex,model); chain 1→5 |
| CC | Scriptable when locked, Custom when not; RMB = orbit only, no lock clear |
| DC | Step(direction) fires on double-tap WASD or Q+dir; canDash debounce active |
| APC | Action2 anim priority; jumpCount resets on land; double-jump applies JumpPower |
| CS | entityHP/Tier/Spawn all cleared atomically; killEntity hides instantly; regen after delay |
| DH | Debounce[Player] gate; LV + YLock cleaned after Duration; ParticleFlash in RS |
| UI | HUDEvent drives all UI; HP ghost-drain; level-up flash on levelUp flag |
| BM | Cycles all ids; early-return if empty |
| EC | Every row: name+maxHp+respawn+cashType+offset; modelName needs EntityTemplates entry |
| MC | All gameplay numbers here; HitDamages and HitRadii are length-5 parallel arrays |

---

## 10. Known Issues / Tech Debt

| Issue | Location | Severity |
|-------|----------|----------|
| Duplicate dead-code music block | BackgroundMusic (line 34+) | Low — second block never runs but wastes lines |
| CameraController config not in MasterConfig | CC local constants | Low — LOCK_CAM_DIST/HEIGHT/SPEED/SENS are hardcoded |
| `wait()` (legacy) used in DashHandler | DH lines 60, 70 | Low — should be `task.wait()` |
| `repeat wait()` at top of DashController | DC line 1 | Low — should be CharacterAdded pattern |
