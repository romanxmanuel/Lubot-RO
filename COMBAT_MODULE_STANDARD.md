# Lubot-RO Interchangeable Combat Standard

## Goal

Support many combat styles from marketplace assets without hardcoding combat into the player and without breaking creator scripts.

## Core pattern

Use a component/module-driven combat swap system:

1. `CombatHandler` (controller)
   - Single input listener for combat actions.
   - Routes actions to the currently active combat module.

2. `CombatModuleRegistry` (dictionary module)
   - Maps equipped item IDs to combat modules.
   - Example: `deku_combat_emblem -> DekuLegacyModule`

3. Combat modules (implementation)
   - One module per combat style/system.
   - All modules must expose the same function contract.

## Required module contract

All combat modules must implement the same API so the handler can stay generic:

- `Attack(context)`
- `Block(context)` (if supported)
- `Dash(context)` (if supported)
- `OnEquip(context)`
- `OnUnequip(context)`

If a module does not support an action, it should no-op and return cleanly.

## Equip flow

When an item is equipped from the backpack:

1. `CombatHandler` checks `CombatModuleRegistry`.
2. If item has a mapped module, that module becomes active.
3. Inputs route to that module until unequipped or replaced.

## Marketplace safety rule

For imported creator systems:

- Keep raw imported scripts/assets intact in their own folder.
- Do not rewrite creator scripts unless required for safety or compatibility.
- If an imported tool has its own keybind logic, base MMO keybinds must back off while that tool is equipped.

## Organization rule for imported assets

For each marketplace asset ID:

- Use its own folder under imported assets.
- Preserve source package separately from runtime template.
- Make it easy to grant via loot, world pickup, admin grant, or inventory item.

## Scaling rule

Never add one-off combat logic directly into player bootstrap scripts.

Always:

- add or update a module
- register it in the dictionary
- keep handler logic generic

This keeps combat systems interchangeable as content scales.
