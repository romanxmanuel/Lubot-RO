# How to Delete Combined Side Quest Tester

This guide provides step-by-step instructions for completely removing the Combined Side Quest Tester from your quest system.

## Overview

The Combined Side Quest Tester demonstrates multi-task quest mechanics (both Sequential and Parallel task modes). This guide covers removing the tester rig, dialogue, and quest data.

## Step-by-Step Removal Process

### 1. Remove Workspace Model

In Roblox Studio Workspace, delete:

- **`Workspace.DialoguePrompts["Combined Side Quest Tester"]`** - The entire NPC rig model (includes Humanoid, HumanoidRootPart, ProximityPrompt)

Note: The pickup and delivery test folders (`Pickup_Item_Quest_Test` and `Deliver_Test`) are shared with other testers, so don't delete them yet.

### 2. Remove Dialogue System (Client-Side)

Delete the dialogue component file:

**File to Delete:**
- `src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/Testing/CombinedQuestTesterDialogue.lua`

This file contains the COMBINED_QUEST_DIALOGUE dialogue tree with quest type selection (Sequential vs Parallel).

### 3. Update Quest Data

Edit the quest definitions file to remove the combined quest entries:

**File:** `src/ReplicatedStorage/SharedSource/Datas/QuestDefinitions/SideQuest.lua`

**Remove these TWO quest entries:**

**Entry 1: MultiStepQuest (Sequential)**
```lua
["MultiStepQuest"] = {
    Name = "MultiStepQuest",
    DisplayName = "Island Challenge",
    Description = "Complete multiple challenges across the island",
    TaskMode = "Sequential",
    -- ... entire quest definition with Tasks array
},
```

**Entry 2: ParallelChallenge (Parallel)**
```lua
["ParallelChallenge"] = {
    Name = "ParallelChallenge",
    DisplayName = "Simultaneous Tasks",
    Description = "Complete multiple tasks at the same time",
    TaskMode = "Parallel",
    -- ... entire quest definition with Tasks array
},
```

## What Stays (Keep These)

The following components should **remain in your project**:

- **Multi-task quest system** - The core system that handles Sequential and Parallel task modes
- **`src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/Handlers/PickupItemsHandler.lua`** - Client-side pickup handler (used by other quests)
- **`src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/Handlers/DeliveryHandler.lua`** - Client-side delivery handler (used by other quests)
- **`src/ServerScriptService/ServerSource/Server/QuestService/Components/Others/TriggeredQuest/Types/PickUpItems.lua`** - Server-side pickup quest type
- **`src/ServerScriptService/ServerSource/Server/QuestService/Components/Others/TriggeredQuest/Types/Delivery.lua`** - Server-side delivery quest type
- **Workspace folders** - `Pickup_Item_Quest_Test` and `Deliver_Test` (if other testers are using them)

## Notes

- This removal only affects the Combined Side Quest Tester quests
- The multi-task quest architecture remains functional for future quests
- You can still create new Sequential or Parallel multi-task quests by adding entries to `SideQuest.lua`

## File Summary

| File/Folder | Action |
|------------|--------|
| `Workspace.DialoguePrompts["Combined Side Quest Tester"]` | **DELETE** (Workspace) |
| `CombinedQuestTesterDialogue.lua` | **DELETE** (Client) |
| `["MultiStepQuest"]` in `SideQuest.lua` | **DELETE** (Quest Data) |
| `["ParallelChallenge"]` in `SideQuest.lua` | **DELETE** (Quest Data) |
| `Combined-Side-Quest-Tester-Setup.md` | **DELETE** (Optional - Docs) |
| Multi-task quest system | **KEEP** |
| Pickup/Delivery handlers | **KEEP** |

---

*Last Updated: November 16, 2025*

