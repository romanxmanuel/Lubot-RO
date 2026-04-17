# Lubot-RO — Project CLAUDE.md
> Roblox game project (Ragnarok Online inspired)
> Repo: `C:\Users\lily7\Documents\SuperbulletAI\Lubot-RO`

---

## SESSION START — MANDATORY (do this before any code work)

1. **Read `SYSTEM_MAP.md`** — it lives at the project root. Read it fully. It is the architecture
   contract: which script owns what, which reads what, all RemoteEvents, all data flows.
   Never add a script, constant, or RemoteEvent without checking it first.

2. **Verify Roblox Studio MCP is connected** — use `mcp__Roblox_Studio__list_roblox_studios`
   to confirm a Studio instance is open and NOT in play mode.

3. **Check git status** — `git -C "C:/Users/lily7/Documents/SuperbulletAI/Lubot-RO" status`
   (only SYSTEM_MAP.md, CLAUDE.md, AGENTS.md, and similar docs should ever appear here —
   never src/ code files).

---

## SOURCE OF TRUTH — ROBLOX STUDIO ONLY

**All game scripts live in Roblox Studio. This repo has NO src/ code mirror.**

- Read scripts: `mcp__Roblox_Studio__script_read`
- Write scripts: `mcp__Roblox_Studio__execute_luau` (set script Source property)
- Search scripts: `mcp__Roblox_Studio__script_grep` / `script_search`
- Inspect tree: `mcp__Roblox_Studio__search_game_tree`
- Test: `mcp__Roblox_Studio__start_stop_play`

**Never create a local src/ directory. Never write .lua files locally.**
If you find yourself writing a .lua file to disk, stop — write it to Studio instead.

**Publishing:** Roman publishes directly from Studio via Team Create. There is no deploy step.

---

## ARCHITECTURE (quick ref — full detail in SYSTEM_MAP.md)

| Tag | Script | Studio Path | Type |
|-----|--------|-------------|------|
| MC  | MasterConfig | ReplicatedStorage.MasterConfig | ModuleScript |
| AC  | AttackController | StarterPlayer.StarterCharacterScripts.AttackController | LocalScript |
| CC  | CameraController | StarterPlayer.StarterCharacterScripts.CameraController | LocalScript |
| DC  | DashController | StarterPlayer.StarterCharacterScripts.DashController | LocalScript |
| APC | AirPhysicsController | StarterPlayer.StarterCharacterScripts.AirPhysicsController | LocalScript |
| CS  | CombatSystem | ServerScriptService.CombatSystem | Script |
| DH  | DashHandler | ServerScriptService.DashHandler | Script |
| PS  | ProgressionSystem | ServerScriptService.ProgressionSystem | Script |
| EC  | EntityConfig | ServerScriptService.EntityConfig | ModuleScript |
| UI  | UIController | StarterPlayer.StarterPlayerScripts.UIController | LocalScript |
| BM  | BackgroundMusic | StarterPlayer.StarterPlayerScripts.BackgroundMusic | LocalScript |

**MasterConfig is the firewall.** Every tunable number lives there. No other script
hardcodes gameplay constants. If you add a new constant, add it to MasterConfig first.

---

## EDIT WORKFLOW

1. Read current Studio script source (`script_read`)
2. Apply changes (`execute_luau` to set .Source)
3. Test in Studio play mode (`start_stop_play`)
4. Update `SYSTEM_MAP.md` if the architecture changed (new scripts, new events, new data flows)
5. Commit docs: `git commit -m "..."` — only .md files, never .lua files

---

## WHAT LIVES LOCALLY (docs only)

| File | Purpose |
|------|---------|
| `CLAUDE.md` | This file — session-start mandates, architecture quick-ref |
| `SYSTEM_MAP.md` | Full architecture contract — must stay current |
| `AGENTS.md` | MCP/Rojo tool setup notes (legacy, kept for reference) |
| `default.project.json` | Rojo config (not used — Studio is source of truth) |

---

## KEY RULES

- **Never ask to see a script before editing it** — always read it from Studio first
- **Never hardcode a number in a script** — add it to MasterConfig
- **Never add a RemoteEvent without updating SYSTEM_MAP.md**
- **Never sync local .lua files** — Studio is truth, local is docs only
