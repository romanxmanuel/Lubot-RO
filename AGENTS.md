# Lubot-RO Project Operating Rules

## Scope and source of truth

- Active implementation repo: `C:\Users\lily7\Documents\SuperbulletAI\Lubot-RO`
- Docs-only workspace (never used for implementation): `C:\Users\lily7\Claude Code Projects\Ragnarok Online`
- Treat this repo and live Studio state as implementation truth.

## Session-start checklist (mandatory)

1. Verify Roblox Studio MCP is connected using:
   - `command = "cmd.exe"`
   - `args = ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]`
   - startup command: `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`
2. Verify Rojo is serving this project on port `34872`:
   - `rojo serve default.project.json --port 34872`
3. Verify active Studio instance is correct before changes.
4. Check play state and stop play mode before any Studio script/file edit.
5. Check git status before edits.
6. Verify SuperbulletAI panel baseline:
   - Rojo status should be connected
   - Rojo Port: `34872`
   - Server Port: `13528`
7. If either Rojo or MCP is disconnected, reconnect them before implementation work.

## Workflow (mandatory for each feature prompt)

1. Stop play mode before Studio edits.
2. Implement the change.
3. Verify behavior in play test / Team Test flow.
4. Keep local files, Rojo sync, Studio runtime state, and GitHub history aligned.
5. Commit and push after the feature is verified.
6. Report the exact commit description in the response.

### Playtest availability protocol (mandatory)

1. During local-only work (planning, local file edits, git operations), Roman is **FREE to play test**.
2. Right before any Studio write/sync step, stop play mode first, then announce: **NOT FREE to play test - saving/applying Studio changes now.**
3. After Studio writes and verification are done and Studio is back in edit mode, announce: **FREE to play test again.**
4. Assume Roman wants to play test while work is in progress unless told otherwise.
5. End each completed prompt with Studio left in edit mode unless Roman explicitly asks to stay in play mode.

Commit messages must be plain-language, specific, and easy to understand.

## Combat architecture (interchangeable systems)

- Do not hardcode combat logic in player bootstrap.
- Use `CombatHandler` as the single input router.
- Use a combat module registry mapping `itemId -> module`.
- Combat modules must share this API:
  - `Attack(context)`
  - `Block(context)`
  - `Dash(context)`
  - `OnEquip(context)`
  - `OnUnequip(context)`

When a mapped item is equipped, `CombatHandler` activates and routes to that module.

## Imported marketplace assets rules

- Keep imported tools/scripts as intact as possible.
- Preserve each imported asset in its own folder.
- Keep source package separate from runtime template.
- Imported tool keybind/scripts take precedence while that tool is equipped.
- Organize assets for future grant/drop/pickup use cases.

## Inventory and UI rules

- Use Roblox native Backpack/hotbar behavior.
- Keep materials/cards out of hotbar tool materialization unless explicitly requested.
- Keep player-facing labels clear and not misleading.
