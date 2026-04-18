# Studio Combat Overhaul Sync (April 18, 2026)

This folder mirrors the major combat scripts/modules that were overhauled in Roblox Studio from the `scripts_reference` spec.

## Implemented in Studio
- ReplicatedStorage.Combat.CombatConfig
- ReplicatedStorage.Combat.TargetingService
- StarterPlayer.StarterPlayerScripts.AbilityClient
- StarterPlayer.StarterPlayerScripts.HitFXController
- ServerScriptService.ComboController
- ServerScriptService.CombatSystem bridge edits:
  - Added `damageOverride` support in `processDamageRequest`.
  - Added Combo bridge counters/status values for debugging.
  - Added VFX model ignore list so damage logic skips `Hakari Aura`, `Meteor`, `Portal`.

## Known Runtime Noise
Third-party imported assets still spam runtime errors unrelated to this overhaul (missing/archived assets and package scripts). Those logs can obscure combat validation.

## Important Note
`ComboController.server.lua` currently includes temporary debug counters (`ComboInputEventCount`, `ComboBridgeFireCount`, `ComboLastTarget`) to verify event flow while stabilizing this pass.

## VFX preservation fix (Apr 18, 2026)
- VFXService now clones directly from Workspace/VFX Drops without mutating particle rates, anchoring, collisions, or scripts.
- Hit mapping verified:
  - Hit 1: Hakari Aura
  - Hit 2: Meteor
  - Hit 3: Meteor
  - Hit 4: Hakari Aura
  - Hit 5: Portal

