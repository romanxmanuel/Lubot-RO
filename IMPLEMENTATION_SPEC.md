# IMPLEMENTATION_SPEC.md
## Source of truth for the Roblox AAA 5-hit combo combat system

---

## OBJECTIVE

Build a **5-hit AAA combat combo system** in Roblox that feels:
- Heavy and crunchy (not floaty, not spammy)
- Cinematic and premium
- Inspired by Crimson Desert / Black Myth: Wukong / God of War

This system must use:
- `AnimationTrack` `KeyframeMarker` events for exact impact timing
- Config tables for all gameplay values
- Modular scripts (one file per system)

---

## COMBO OVERVIEW

### Hit 1 — Blink Strike
- Blink to nearest auto-locked target (almost instant: 0.04s)
- Single-target strike
- Green lightning erupts **inside** target body — fires 0.03s AFTER hit stop
- Secondary micro-burst: 0.03s HitStop, no slow motion
- **Role:** sharp, precise, surgical opener

### Hit 2 — Push + Meteor (TWO sub-impacts)

#### Hit 2A — Pushback Strike
- Push target slightly forward (5.5 studs)
- Player launches backward (9 studs) and upward (6 studs) in a giant leap
- Duration: 0.18s

#### Hit 2B — Meteor Impact (fires 0.18s after Hit 2A)
- Meteor explodes at enemy location
- Enemy gets ground compression (0.04s) before knockback
- **Role:** space creation + first true heavy impact

### Hit 3 — Air Meteor Drop
- Only available while player is **Suspended** (airborne after Hit 2)
- Next click drops a rasengan-like meteor on enemy from above
- Shockwave ring expands outward on impact
- Shock blast launches player even higher (10 studs upward)
- Enemy compresses DOWN before being blasted
- **Role:** vertical dominance spike

### Hit 4 — Re-engage Blink Strike
- Teleport back to target immediately
- Forceful strike + green lightning burst (stronger than Hit 1)
- Secondary burst: 0.04s HitStop delay
- **Role:** snap return, re-control

### Hit 5 — Final Nuke
- Giant frontal blast (Graves ult style)
- Target gets blasted hard (Knockback 40)
- Player gets pushed back **to their combo start position** (ReturnDuration 0.22s)
- Longest recovery drag (0.7x speed, 0.30s)
- **Role:** full payoff, disengage, reset

---

## COMBAT FLOW HIERARCHY

| Hit | Feel |
|-----|------|
| Hit 1 | instant + sharp → precision |
| Hit 2 | separation → tension builds |
| Hit 3 | vertical dominance → power spike |
| Hit 4 | snap return → control regained |
| Hit 5 | explosion → release + reset |

---

## REQUIRED FILE STRUCTURE

```
ReplicatedStorage/
  Combat/
    CombatConfig.lua        ← all hit values
    CameraShaker.lua        ← dual-layer noise shake module
    AssetRegistry.lua       ← VFX/SFX/Animation ID references
    ComboUtils.lua          ← target locking, blink, knockback utilities
    VFXService.lua          ← clone + spawn VFX from VFX Drops
    SFXService.lua          ← sound playback
    HitStopService.lua      ← hit stop + slow-mo coordination
    CombatRemotes/
      ComboInput            (RemoteEvent)
      PlayImpactFX          (RemoteEvent)

ServerScriptService/
  ComboController.server.lua  ← server state machine

StarterPlayerScripts/
  HitFXController.client.lua  ← camera shake, FOV, blur
  AbilityClient.client.lua    ← input → server
```

---

## ANIMATION MARKERS (REQUIRED)

These markers must exist in the animation tracks:

| Hit | Markers |
|-----|---------|
| Hit 1 | `HIT1_CONTACT`, `HIT1_LIGHTNING_BURST` |
| Hit 2 | `HIT2_PUSH`, `HIT2_METEOR_IMPACT` |
| Hit 3 | `HIT3_DROP_IMPACT` |
| Hit 4 | `HIT4_CONTACT`, `HIT4_LIGHTNING_BURST` |
| Hit 5 | `HIT5_FIRE`, `HIT5_BLAST`, `HIT5_RETURN` |

---

## VFX MAPPING (CRITICAL)

**Do NOT use InsertService or asset IDs for these VFX.**
**Clone from the existing folder:**

```
workspace > VFX Drops
```

| Hit | VFX Object |
|-----|-----------|
| Hit 1 & 4 | `Hakari Aura` |
| Hit 2 & 3 | `Meteor` |
| Hit 5 | `Portal` |

VFXService must:
1. Find object in VFX Drops by name
2. Clone it to hit position
3. Fire particle emitters / trails
4. Debris cleanup after short lifetime

---

## EXACT COMBAT VALUES (CombatConfig)

### Hit 1 — Blink Strike
```lua
Name = "BlinkStrike"
HitStop = 0.085
SlowMoScale = 0.62,       SlowMoDuration = 0.08
ShakeCrackAmplitude = 0.16, ShakeCrackRotation = 0.8,  ShakeCrackFrequency = 32, ShakeCrackDuration = 0.05
ShakeMassAmplitude = 0.38,  ShakeMassRotation = 1.6,   ShakeMassFrequency = 14,  ShakeMassDuration = 0.14
FOVPunch = 3,             BlurPulse = 0
Stun = 0.18,              Knockback = 8
BlinkDuration = 0.04
SecondaryBurstDelay = 0.03, SecondaryBurstHitStop = 0.03
```

### Hit 2A — Pushback Strike
```lua
Name = "PushbackLaunch"
HitStop = 0.075
SlowMoScale = 0.70,       SlowMoDuration = 0.06
ShakeCrackAmplitude = 0.14, ShakeCrackRotation = 0.7,  ShakeCrackFrequency = 30, ShakeCrackDuration = 0.05
ShakeMassAmplitude = 0.32,  ShakeMassRotation = 1.3,   ShakeMassFrequency = 15,  ShakeMassDuration = 0.12
FOVPunch = 2,             BlurPulse = 0
Stun = 0.14,              Knockback = 6
EnemyForwardPush = 5.5
PlayerBackwardLaunch = 9, PlayerVerticalLift = 6, LaunchDuration = 0.18
```

### Hit 2B — Meteor Impact
```lua
Name = "MeteorOne"
HitStop = 0.125
SlowMoScale = 0.42,       SlowMoDuration = 0.13
ShakeCrackAmplitude = 0.22, ShakeCrackRotation = 1.2,  ShakeCrackFrequency = 26, ShakeCrackDuration = 0.07
ShakeMassAmplitude = 0.85,  ShakeMassRotation = 3.2,   ShakeMassFrequency = 10,  ShakeMassDuration = 0.24
FOVPunch = 5,             BlurPulse = 4, BlurDuration = 0.06
Stun = 0.32,              Knockback = 18
GroundCompression = 0.04
```

### Hit 3 — Air Meteor Drop
```lua
Name = "AirMeteorDrop"
HitStop = 0.135
SlowMoScale = 0.36,       SlowMoDuration = 0.15
ShakeCrackAmplitude = 0.26, ShakeCrackRotation = 1.4,  ShakeCrackFrequency = 24, ShakeCrackDuration = 0.08
ShakeMassAmplitude = 1.10,  ShakeMassRotation = 3.8,   ShakeMassFrequency = 9,   ShakeMassDuration = 0.28
FOVPunch = 6,             BlurPulse = 5, BlurDuration = 0.08
Stun = 0.38,              Knockback = 24
SelfLaunchUpward = 10,    SelfLaunchDuration = 0.14
```

### Hit 4 — Re-engage Blink Strike
```lua
Name = "ReengageBlink"
HitStop = 0.095
SlowMoScale = 0.55,       SlowMoDuration = 0.09
ShakeCrackAmplitude = 0.18, ShakeCrackRotation = 0.9,  ShakeCrackFrequency = 30, ShakeCrackDuration = 0.06
ShakeMassAmplitude = 0.45,  ShakeMassRotation = 1.9,   ShakeMassFrequency = 13,  ShakeMassDuration = 0.16
FOVPunch = 4,             BlurPulse = 0
Stun = 0.24,              Knockback = 12
SecondaryBurstDelay = 0.04, SecondaryBurstHitStop = 0.04
```

### Hit 5 — Final Nuke
```lua
Name = "FinalNukeDisengage"
HitStop = 0.18
SlowMoScale = 0.28,       SlowMoDuration = 0.18
ShakeCrackAmplitude = 0.32, ShakeCrackRotation = 1.8,  ShakeCrackFrequency = 24, ShakeCrackDuration = 0.09
ShakeMassAmplitude = 1.4,   ShakeMassRotation = 4.8,   ShakeMassFrequency = 8,   ShakeMassDuration = 0.32
FOVPunch = 8,             BlurPulse = 6, BlurDuration = 0.08
Stun = 0.55,              Knockback = 40
PlayerBackwardBlast = 12, ReturnDuration = 0.22
RecoveryDragSpeed = 0.7,  RecoveryDragDuration = 0.30
```

---

## HIT STOP RULES

- Hit stop pauses: attacker animation, victim animation, camera motion, weapon trail progression
- Does NOT fully pause: some particles, environment motion, lingering VFX glow (contrast = filmic)
- Victim HitStop = same or slightly stronger than attacker
- Freeze contrast is what makes it feel expensive

---

## SLOW MOTION RULES

- Slow mo applies AFTER hit stop — never before
- Fake it by reducing: animation playback speed, particle speeds, trail speeds, camera spring speed
- Keep it short — deeper scale is better than longer duration
- Roblox has no true global time scale — fake at the component level

---

## CAMERA RULES

- Two shake layers run simultaneously on impact:
  - **Crack layer:** high frequency (24–32), short duration (0.05–0.09s), sells violent collision
  - **Mass layer:** low frequency (8–15), long duration (0.14–0.32s), sells weapon weight
- Shake starts ON the hit stop frame
- FOV punch: increase at impact, tween back via TweenService (Quad, Out)
- Use `BindToRenderStep` at Camera priority for shake

---

## SOUND RULES

Every big hit = 3 layers:
1. **Transient crack** — exact contact frame
2. **Body weight** — same frame or +0.01s
3. **Tail texture** — +0.02–0.05s after (scrape, spark, rattle, etc.)

Before Hit 3 and Hit 5: add **0.02–0.04s sound drop** (brief silence) — massively increases perceived impact.

---

## COMBO SYSTEM RULES

Server state per player:
```lua
{
  Step = 0,              -- current combo step (0 = idle, 1–5 = active)
  Suspended = false,     -- true when airborne (enables Hit 3)
  StartPosition = Vector3, -- recorded at combo start (for Hit 5 return)
  LastTarget = Model,    -- locked target model
}
```

- Combo resets if timing window expires
- Hit 3 only available when `Suspended = true`
- Anti-double-fire: debounce per marker event
- Input: MouseButton1 fires `ComboInput` RemoteEvent to server

---

## CRITICAL IMPLEMENTATION RULES

- Damage fires from animation markers only — no `task.delay()` for hit timing
- Server validates all hits before applying damage
- VFX is **client-side only** — server fires `PlayImpactFX` RemoteEvent to trigger client visuals
- Old combat system is disposable — inspect only for animation/sound/VFX references
- Do not preserve old architecture — build new system clean

---

## FINAL REQUIREMENTS

After implementation, output:
1. Summary of all files created and their Studio paths
2. List of assumptions made
3. List of potential bugs or timing risks
4. Roblox Studio testing checklist
5. Tuning guide: which values to adjust if combo feels too floaty

---

## INITIAL CLAUDE CODE PROMPT (use this to start)

```
Read CLAUDE.md and IMPLEMENTATION_SPEC.md first.
Then inspect the current project.

Important context:
- Existing VFX are in workspace > VFX Drops
- Use: "Hakari Aura" for Hit 1 and Hit 4
- Use: "Meteor" for Hit 2 and Hit 3
- Use: "Portal" for Hit 5
- There is an older prototype combat system which can be replaced

Task:
Build the new modular combat system described in IMPLEMENTATION_SPEC.md.
Clone VFX from workspace > VFX Drops using the exact names above.
Do not preserve old messy combat logic — inspect it only for animation/sound/VFX references.

After implementation:
- Summarize files created
- List assumptions
- List potential bugs
- Give a Roblox Studio testing checklist
```
