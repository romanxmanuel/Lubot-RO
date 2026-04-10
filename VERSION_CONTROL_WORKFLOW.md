# Lubot-RO Version Control Workflow

## Team policy (locked)

These are now mandatory for this project:

1. Every prompt/feature ends with a Git commit + push to GitHub.
2. Commit descriptions must be plain-language and easy to read:
   - clear enough for non-engineers
   - specific about what changed
   - not vague, not over-technical
3. Keep local files, Rojo sync, Studio runtime, and Git history aligned.
4. Before any Studio file/script edit, always stop play test mode first.

## Workspace split (locked)

- `C:\Users\lily7\Documents\SuperbulletAI\Lubot-RO` is the active implementation repository.
- `C:\Users\lily7\Claude Code Projects\Ragnarok Online` is docs/planning context.
- If docs in the context workspace conflict with runtime behavior, this repo + Studio runtime wins.

## Native Roblox inventory naming

- `Backpack`: Roblox's full tool container.
- `Hotbar`: the bottom quick-access slots (`1`-`0`).
- `Backpack overflow panel`: the searchable panel that appears when tools exceed visible hotbar slots.

Note: the native API does not reliably expose a "toggle overflow panel only" action while keeping hotbar behavior isolated. Design UI actions around supported `Backpack` behaviors.

## Source of truth

There are three separate states:

1. `Local source files`
   - `C:\Users\lily7\Documents\SuperbulletAI\Lubot-RO\src`
   - This is what Git and GitHub track.

2. `Live Roblox Studio place`
   - The open Team Create / Studio DataModel.
   - MCP edits change this directly.

3. `Published Roblox experience`
   - What public players get after Studio publish.

These are **not automatically the same** unless Rojo is running and connected.

## What Rojo does

Rojo syncs:

- `local files -> Studio`

It does **not**:

- publish Studio to Roblox
- create Git commits
- push to GitHub

## What Git/GitHub do

Git tracks:

- local files only

GitHub stores:

- pushed Git commits from the local repo

Git/GitHub do **not**:

- update Studio automatically
- publish the Roblox place

## What publish does

Publish sends:

- `Studio -> published Roblox game`

Publish does **not**:

- update local files
- create Git commits
- push to GitHub

## Required workflow

When making a real game change, use this order:

1. Stop play test mode
   - Never edit Studio scripts while in play mode.

2. Edit the live Studio place
   - MCP and in-Studio work are allowed.

3. Mirror the same change into local `src`
   - So the repo matches the live place.

4. Team Test / runtime verify
   - Confirm behavior in live play.

5. Commit and push the local repo
   - This creates rollback history.

6. Publish from Studio when Roman wants the live public game updated

## Current project rule

For `Lubot-RO`, treat this as the operational default:

- MCP/live Studio is the implementation surface
- local `src` must be kept in sync after meaningful changes
- GitHub is the rollback history
- publish is a separate intentional step

## Practical command reminders

Start Rojo from this folder:

```powershell
cd "C:\Users\lily7\Documents\SuperbulletAI\Lubot-RO"
rojo serve default.project.json --port 34872
```

Expected SuperbulletAI panel ports:

- Rojo Port: `34872`
- Server Port: `13528`
- Rojo status should show connected before feature implementation.

Start Roblox Studio MCP bridge:

```powershell
cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat
```

Expected MCP config:

```json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": [
        "/c",
        "%LOCALAPPDATA%\\Roblox\\mcp.bat"
      ]
    }
  }
}
```

Commit and push:

```powershell
cd "C:\Users\lily7\Documents\SuperbulletAI\Lubot-RO"
git status
git add .
git commit -m "Describe the change"
git push
```

## Current status

As of setup:

- local repo exists
- GitHub remote exists
- Rojo config exists in `default.project.json`
- default Rojo runtime target for this project is port `34872`
