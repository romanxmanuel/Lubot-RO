# Lubot-RO Version Control Workflow

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

1. Edit the live Studio place
   - MCP and in-Studio work are allowed.

2. Mirror the same change into local `src`
   - So the repo matches the live place.

3. Commit and push the local repo
   - This creates rollback history.

4. Publish from Studio when Roman wants the live public game updated

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
rojo serve default.project.json --port 13734
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
- no Rojo server is assumed to be running unless started explicitly
