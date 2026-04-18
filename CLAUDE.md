# CLAUDE.md
## Project: Roblox AAA Combat System

This project implements a premium, cinematic 5-hit combo combat system inspired by high-end action
games like Crimson Desert, Black Myth, and God of War.

---

## CORE PRINCIPLES

- All values live in config tables — never hardcode numbers in scripts
- Server is authoritative for damage, hit validation, and combo state
- Client handles all visual presentation (camera shake, FOV, blur, VFX, sound)
- Damage and FX must fire from animation `KeyframeMarker` events — not `task.delay()`
- Every hit in the combo has a distinct role and distinct values
- Hierarchy is everything — not all hits should feel the same

---

## ARCHITECTURE RULES

### Separation of Responsibilities

**Server (ComboController.server.lua):**
- Hit detection and validation
- Damage application
- Knockback and stun application
- Combo state tracking (Step, Suspended, StartPosition, LastTarget)
- Target auto-locking

**Client (HitFXController.client.lua + AbilityClient.client.lua):**
- Camera shake (dual-layer: crack + mass)
- FOV punch
- Blur pulse
- VFX spawning (clone from VFX Drops)
- Animation playback
- Sound playback

---

## TIMING RULES

- Hit stop occurs **FIRST**, then slow motion **AFTER** — never before
- Camera shake starts **on the hit stop frame** — not before, not after
- Victim reaction must occur **on the same frame** as the hit stop
- The hit must visually land before damage feeling happens — not early, not late

---

## COMBAT FEEL RULES

- Every major hit must feel like it has **mass and consequence**
- Recovery drag is mandatory on heavy hits — no weightless snapping back
- Contrast hierarchy: `light = snap`, `medium = punch`, `heavy = crunch`, `finisher = rupture`
- Too much intensity on every hit = nothing feels big — scale appropriately
- Bigger attacks need a **brief silence** before impact — pre-impact vacuum makes hits feel stronger

---

## IMPACT STACK ORDER

Every major hit must follow this exact order:
1. Pre-impact anticipation
2. 1–3 frame contact snap
3. Hard hit stop
4. Deep localized slow motion
5. Double-layer camera shake (crack layer + mass layer simultaneously)
6. Violent victim reaction (same frame as hit stop)
7. Draggy attacker recovery
8. Bass + crack sound at exact contact frame

If even one of these is weak, the whole hit loses weight.

---

## ASSET USAGE RULE

Existing VFX assets are located in:
```
workspace > VFX Drops
```

Use these exact mappings — **do NOT require renaming**:
- Hit 1 & 4 → `workspace["VFX Drops"]["Hakari Aura"]`
- Hit 2 & 3 → `workspace["VFX Drops"]["Meteor"]`
- Hit 5     → `workspace["VFX Drops"]["Portal"]`

VFXService must:
- Clone from VFX Drops (not InsertService / asset IDs)
- Move the clone to the hit position
- Trigger particle emitters / trails
- Destroy clone after a short lifetime via Debris

---

## OLD SYSTEM RULE

There is an older prototype combat system in the project.
- You **MAY** inspect it for animation, sound, and VFX references
- You **MAY NOT** preserve its architecture or patch it
- Treat old combat logic as **disposable** — replace it entirely with the new modular system
- Move old scripts to `OldCombatBackup/` folder, do not delete them

---

## CODE QUALITY RULES

- All gameplay values in `CombatConfig` module — zero magic numbers in script bodies
- One file per system — no spaghetti
- Comments explain WHY, not what
- Anti-double-fire protection on all animation markers
- Cooldown / debounce safety on all inputs
- Separate gameplay state completely from visual presentation

---

## FINAL PRIORITY

If there is ever a conflict between clean code and combat feel:

> **Choose: combat feel**

---

## STUDIO WORKFLOW (Claude Code Operational — Required Reading)

All game scripts live in **Roblox Studio**. This repo has **NO local .lua files**.

### Session Start (mandatory before any code work)
1. Read `SYSTEM_MAP.md` fully
2. Verify Studio MCP: `mcp__Roblox_Studio__list_roblox_studios` — confirm not in play mode
3. Check git status — only `.md` files should ever appear

### Script Operations
| Action | Tool |
|--------|------|
| Read a script | `mcp__Roblox_Studio__script_read` |
| Write a script | `mcp__Roblox_Studio__execute_luau` (set `.Source`) |
| Search scripts | `mcp__Roblox_Studio__script_grep` |
| Browse tree | `mcp__Roblox_Studio__search_game_tree` |
| Test | `mcp__Roblox_Studio__start_stop_play` |

**Never write `.lua` files locally. Studio is always source of truth.**

### Context Management
- If context feels bloated mid-session, Roman will say `/compact`
- If implementation is long, continue in steps: *"Continue. Do not restate previous files."*
- Re-ground with: *"Re-read CLAUDE.md and IMPLEMENTATION_SPEC.md. Align with them."*
- One system = One AI: Claude Code owns the combat system. Don't let Codex touch it.
