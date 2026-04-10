# How to Delete Daily or Weekly Quest Tester

This guide provides step-by-step instructions for completely removing the Daily or Weekly Quest Tester from your quest system.

## Overview

The Daily or Weekly Quest Tester is an NPC that opens a UI displaying all available daily and weekly quests. This removal process cleans up the tester NPC, its dialogue/UI toggler, and optionally all daily/weekly quest data.

## Important Notes

⚠️ **Decision Point:** Do you want to keep daily/weekly quests but just remove the tester NPC?

- **Option A:** Remove only the tester NPC and UI toggler (keep quest system functional)
- **Option B:** Remove the entire daily/weekly quest system (all quest data)

This guide covers both options.

---

## Option A: Remove Only the Tester NPC (Keep Quest System)

Use this option if you want to keep daily/weekly quests but access them through a different UI/NPC.

### 1. Remove Workspace Model

In Roblox Studio Workspace, delete:

- **`Workspace.DialoguePrompts["Daily or Weekly Quest Tester"]`** - The entire NPC rig model (includes Humanoid, HumanoidRootPart, ProximityPrompt)

### 2. Remove UI Toggler (Client-Side)

Delete the UI toggler component file:

**File to Delete:**

- `src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/UI/DailyWeeklyQuestToggler.lua`

This file opens/closes the `SideQuestsFrame` UI when interacting with the NPC.

### 3. Update QuestController Initialization

**File:** `src/ReplicatedStorage/ClientSource/Client/QuestController/init.lua`

Remove the reference to `DailyWeeklyQuestToggler` from the Components table (if it exists).

### 4. Verification

- ✅ `Workspace.DialoguePrompts["Daily or Weekly Quest Tester"]` is deleted
- ✅ `DailyWeeklyQuestToggler.lua` is deleted
- ✅ No console errors appear on server/client start
- ✅ Daily/weekly quest system still functions through other UIs

---

## Option B: Remove Entire Daily/Weekly Quest System

⚠️ **WARNING:** This removes ALL daily and weekly quest functionality, not just the tester.

### 1. Remove Workspace Model

In Roblox Studio Workspace, delete:

- **`Workspace.DialoguePrompts["Daily or Weekly Quest Tester"]`** - The entire NPC rig model

### 2. Remove UI Toggler (Client-Side)

Delete the UI toggler component file:

**File to Delete:**

- `src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/DailyWeeklyQuestToggler.lua`

### 3. Remove ALL Daily Quest Data

**File:** `src/ReplicatedStorage/SharedSource/Datas/QuestDefinitions/Daily.lua`

**Remove ALL quest entries:**

- `["CollectCrates"]` - Active mode pickup quest
- `["DailyDeliverPackage"]` - Active mode delivery quest
- `["CollectCrates_Passive"]` - Passive mode pickup quest
- `["DailyDeliverPackage_Passive"]` - Passive mode delivery quest
- `["DailyAdventure"]` - Sequential multi-task quest
- `["DailyChallenges"]` - Parallel multi-task quest

You can either delete the entire file or leave an empty dictionary:

```lua
local DailyQuests = {}
return DailyQuests
```

### 4. Remove ALL Weekly Quest Data

**File:** `src/ReplicatedStorage/SharedSource/Datas/QuestDefinitions/Weekly.lua`

**Remove ALL quest entries:**

- `["WeeklyCollectCrates"]` - Active mode pickup quest
- `["WeeklyDeliverPackage"]` - Active mode delivery quest
- `["WeeklyCollectCrates_Passive"]` - Passive mode pickup quest
- `["WeeklyDeliverPackage_Passive"]` - Passive mode delivery quest
- `["WeeklyChallenge"]` - Sequential multi-task quest
- `["WeeklyMegaChallenge"]` - Parallel multi-task quest

You can either delete the entire file or leave an empty dictionary:

```lua
local WeeklyQuests = {}
return WeeklyQuests
```

### 5. (Optional) DataStore Cleanup

If you want to reset player data:

**Player Profile Fields to Clear:**

- `DailyQuests = { LastResetTime = 0, Quests = {} }`
- `WeeklyQuests = { LastResetTime = 0, Quests = {} }`

⚠️ This will delete all player progress for daily/weekly quests. Use the server command console or ProfileService to reset data.

---

## What Stays (Keep These)

**For Option A (NPC removal only):**

- All daily/weekly quest system files
- All quest data in `Daily.lua` and `Weekly.lua`
- `RecurringQuest/` server components
- `PassiveQuest/` server components

**For Option B (Full removal):**

- Core quest system for Main and Side quests
- Quest UI framework (if you have other quest types)
- Server-side quest handlers that aren't daily/weekly specific

## Re-enabling Daily/Weekly Quests (Option B)

If you removed everything and want to add daily/weekly quests again:

1. **Re-add quest entries** to `Daily.lua` or `Weekly.lua`
2. **Create quest-giving NPC** or UI element
3. **Test quest reset timers** (00:00 UTC for daily, Monday 00:00 UTC for weekly)
4. **Verify player DataStore** has correct quest structure

## File Summary

### Option A (NPC Only)

| File/Folder                                                 | Action                 |
| ----------------------------------------------------------- | ---------------------- |
| `Workspace.DialoguePrompts["Daily or Weekly Quest Tester"]` | **DELETE** (Workspace) |
| `DailyWeeklyQuestToggler.lua`                               | **DELETE** (Client)    |
| `Daily.lua` quest entries                                   | **KEEP**               |
| `Weekly.lua` quest entries                                  | **KEEP**               |
| Recurring quest system                                      | **KEEP**               |

### Option B (Full Removal)

| File/Folder                                                 | Action                           |
| ----------------------------------------------------------- | -------------------------------- |
| `Workspace.DialoguePrompts["Daily or Weekly Quest Tester"]` | **DELETE** (Workspace)           |
| `DailyWeeklyQuestToggler.lua`                               | **DELETE** (Client)              |
| ALL entries in `Daily.lua`                                  | **DELETE** (Quest Data)          |
| ALL entries in `Weekly.lua`                                 | **DELETE** (Quest Data)          |
| Daily/Weekly documentation                                  | **DELETE** (Optional - Docs)     |
| Player daily/weekly quest progress                          | **CLEAR** (Optional - DataStore) |
| `RecurringQuest/` system                                    | **KEEP** (Optional)              |
| `PassiveQuest/` system                                      | **KEEP** (Optional)              |

---

_Last Updated: November 16, 2025_
