# How to Delete Crate Side Quest Tester

This guide provides step-by-step instructions for completely removing the Crate Side Quest Tester from your quest system.

## Overview

The Crate Side Quest Tester demonstrates pickup item mechanics with wood crate models. When removing this tester, you'll clean up workspace models, dialogue systems, and quest data entries.

## Important Notes

⚠️ **DO NOT** remove the Pick Up Items system itself - only the crate tester implementation.

The Pick Up Items mechanics should remain functional for other quests.

## Step-by-Step Removal Process

### 1. Remove Workspace Models

In Roblox Studio Workspace, delete:

- **`Workspace.DialoguePrompts["Side Quest Tester 1"]`** - The entire NPC rig model (includes Humanoid, HumanoidRootPart, ProximityPrompt)
- **`Workspace.Pickup_Item_Quest_Test`** - The folder containing all wood crate models for testing

### 2. Remove Dialogue System (Client-Side)

Delete the dialogue component file:

**File to Delete:**
- `src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/Testing/QuestTesterDialogue.lua`

This file contains the QUEST_TESTER_DIALOGUE dialogue tree and NPC interaction logic.

### 3. Update Quest Data

Edit the quest definitions file to remove the crate quest:

**File:** `src/ReplicatedStorage/SharedSource/Datas/QuestDefinitions/SideQuest.lua`

**Remove this entire quest entry:**

```lua
["PickupCrates"] = {
    Name = "PickupCrates",
    DisplayName = "Cargo Collection",
    Description = "Collect crates scattered around the island",
    TaskMode = "Sequential",
    Image = "rbxassetid://112130465285368",
    Rewards = {
        EXP = 50,
        Cash = 200,
    },
    Requirements = {
        MinLevel = 1,
    },
    Repeatable = true,
    Category = "Tutorial",
    Tasks = {
        {
            Description = "Collect 4 crates",
            MaxProgress = 4,
            DisplayText = "Collect crates scattered around the island",
            ServerSideQuestName = "PickUpItems",
            PickupConfig = {
                HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
            },
        },
    },
},
```

### 4. (Optional) Remove Testing Utilities

If you want to remove server-side testing code:

**File:** `src/ServerScriptService/ServerSource/Server/QuestService/Components/Others/Testing/PickupItemsTester.lua`

You can either:
- Delete the entire file if you're done testing pickup items
- Keep it if you plan to use pickup items for other quests

## What Stays (Keep These)

The following components should **remain in your project**:

- **`src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/Handlers/PickupItemsHandler.lua`** - Client-side pickup handler
- **`src/ServerScriptService/ServerSource/Server/QuestService/Components/Others/TriggeredQuest/Types/PickUpItems.lua`** - Server-side pickup quest type
- Any other quests that use `ServerSideQuestName = "PickUpItems"`

## File Summary

| File/Folder | Action |
|------------|--------|
| `Workspace.DialoguePrompts["Side Quest Tester 1"]` | **DELETE** (Workspace) |
| `Workspace.Pickup_Item_Quest_Test` | **DELETE** (Workspace) |
| `QuestTesterDialogue.lua` | **DELETE** (Client) |
| `["PickupCrates"]` in `SideQuest.lua` | **DELETE** (Quest Data) |
| `PickupItemsHandler.lua` | **KEEP** |
| `PickUpItems.lua` (quest type) | **KEEP** |

---

*Last Updated: November 16, 2025*

