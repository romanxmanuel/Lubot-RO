# How to Delete Delivery Side Quest Tester

This guide provides step-by-step instructions for completely removing the Delivery Side Quest Tester from your quest system.

## Overview

The Delivery Side Quest Tester demonstrates delivery quest mechanics where players touch specific parts to complete deliveries. When removing this tester, you'll clean up the rig, dialogue, and workspace folders while keeping the delivery quest type system intact.

## Important Notes

⚠️ **The Delivery Quest Type System Will Stay** - Only the tester implementation is removed.

The core delivery quest mechanics remain available for creating future delivery quests.

## Step-by-Step Removal Process

### 1. Remove Workspace Models

In Roblox Studio Workspace, delete:

- **`Workspace.DialoguePrompts["Side Quest Tester 2"]`** - The entire NPC rig model (includes Humanoid, HumanoidRootPart, ProximityPrompt)
- **`Workspace.Deliver_Test`** - The folder containing all delivery target parts for testing

### 2. Remove Dialogue System (Client-Side)

Delete the dialogue component file:

**File to Delete:**

- `src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/Testing/DeliveryTesterDialogue.lua`

This file contains the DELIVERY_QUEST_DIALOGUE dialogue tree and NPC interaction logic.

### 3. Update Quest Data

Edit the quest definitions file to remove the delivery quest:

**File:** `src/ReplicatedStorage/SharedSource/Datas/QuestDefinitions/SideQuest.lua`

**Remove this entire quest entry:**

```lua
["DeliverPackage"] = {
    Name = "DeliverPackage",
    DisplayName = "Special Delivery",
    Description = "Deliver a package to the marked location",
    TaskMode = "Sequential",
    Image = "rbxassetid://0",
    Rewards = {
        EXP = 100,
        Cash = 500,
    },
    Requirements = {
        MinLevel = 1,
    },
    Repeatable = true,
    Category = "Delivery",
    Tasks = {
        {
            Description = "Deliver 1 package",
            MaxProgress = 1,
            DisplayText = "Deliver a package to the marked location",
            ServerSideQuestName = "Delivery",
            DeliveryConfig = {
                TargetFolder = "Deliver_Test",
                HighlightColor = Color3.fromRGB(0, 255, 0),
                RequireHumanoid = true,
                HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            },
        },
    },
},
```

### 4. (Optional) Remove Testing Utilities

If you want to remove server-side testing code:

**File:** `src/ServerScriptService/ServerSource/Server/QuestService/Components/Others/Testing/DeliveryTester.lua`

You can either:

- Delete the entire file if you're done testing delivery quests
- Keep it if you plan to use delivery mechanics for other quests

## What Stays (Keep These)

The following components should **remain in your project**:

- **`src/ReplicatedStorage/ClientSource/Client/QuestController/Components/Others/Handlers/DeliveryHandler.lua`** - Client-side delivery handler
- **`src/ServerScriptService/ServerSource/Server/QuestService/Components/Others/TriggeredQuest/Types/Delivery.lua`** - Server-side delivery quest type
- The ability to create new delivery quests with different `TargetFolder` configurations

## Future Use

After removing the tester, you can still create new delivery quests by:

1. **Add delivery quest to quest data:**

   - Edit `SideQuest.lua`, `Daily.lua`, or `Weekly.lua`
   - Add a quest with `ServerSideQuestName = "Delivery"`
   - Configure `DeliveryConfig.TargetFolder` to your own folder name

2. **Create delivery targets in workspace:**

   - Create a folder in Workspace (e.g., `Workspace.MyDeliveryQuest`)
   - Add BasePart children as delivery targets
   - Set parts: `CanCollide = false`, `Anchored = true`

3. **Setup quest-giving NPC:**
   - Create dialogue or UI to start the quest
   - Call `QuestService:TrackSideQuest("SideQuest", "YourQuestName")`

## File Summary

| File/Folder                                        | Action                          |
| -------------------------------------------------- | ------------------------------- |
| `Workspace.DialoguePrompts["Side Quest Tester 2"]` | **DELETE** (Workspace)          |
| `Workspace.Deliver_Test`                           | **DELETE** (Workspace)          |
| `DeliveryTesterDialogue.lua`                       | **DELETE** (Client)             |
| `["DeliverPackage"]` in `SideQuest.lua`            | **DELETE** (Quest Data)         |
| `DeliveryTester.lua`                               | **DELETE** (Optional - Testing) |
| Delivery documentation files                       | **DELETE** (Optional - Docs)    |
| `DeliveryHandler.lua`                              | **KEEP**                        |
| `Delivery.lua` (quest type)                        | **KEEP**                        |

---

_Last Updated: November 16, 2025_
