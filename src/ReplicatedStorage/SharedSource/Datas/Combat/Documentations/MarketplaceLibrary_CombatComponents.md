# Marketplace Library — Combat Components

These are **optional marketplace library components** that extend the vanilla combat system. They are located in `CombatService/Components/Others/` (server) and `CombatController/Components/Others/` (client). The base combat system works without any of them installed.

---

## Punch System

**Unique ID:** `61a7dde2-83c6-4cd3-acf9-0dd358bc04f9`

**Component:** `NormalAttack.lua` (server + client)

**Description:** Bare-handed melee attack using ClientCast on the player's hand (alternates RightHand / LeftHand per combo hit). Handles PvP via server raycasts and PvE via client-reported NPC hits.

---

## Sword System

**Unique ID:** `d3fbdddc-0bad-451e-ba7c-87797bfca804`

**Component:** `SlashHandler.lua` (server + client)

**Description:** Weapon-based melee attack using ClientCast on the equipped tool's `Blade` mesh. Requires the weapon model to have a `BasePart` named `Blade` with `DmgPoint` attachments.

---

## Block & Parry System

**Component:** `BlockParryHandler.lua` (server + client)

**Description:** Manages blocking stance, parry window evaluation, posture depletion, and guard break stun. Integrates with `StatusEffectService` for stun effects and `BuffTimerUtil` for timed states.