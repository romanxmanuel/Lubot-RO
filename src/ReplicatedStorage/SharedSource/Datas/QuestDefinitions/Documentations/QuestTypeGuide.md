# 🛡️ Advanced Quest System & Implementation Registry

## 📋 Overview

The Quest System manages complex gameplay loops by linking **Quest Definitions** with specialized **Server-Side Logic Types**. This registry serves as the authoritative guide for configuring task behaviors and ensuring all physical workspace dependencies are met.

---

## 🛠️ Functional Quest Types (Server-Side Logic)

### KillNPC System

**ID:** `[6a2706f6-40fa-4ed5-b335-cc5938b4ee1d]`

**Description:** A signal-based combat tracker that monitors entity health and death events via the `DamageService`.

* **Configurable Logic**: Uses `KillConfig` to filter specific targets.
* **Task Parameters**:
* `TargetName`: The string name of the monster model.


* **Workspace Dependency**: Requires target models to be located in `Workspace.Kill_Monster_Test`.

### MineOre System

**ID:** `[6d4b0f04-19b8-46ef-a8e5-da32049b394d]`

**Description:** An interaction-driven resource gathering engine that handles spatial tracking of deposit folders.

* **Configurable Logic**: Uses `MiningConfig` to manage visual feedback and target identification.
* **Task Parameters**:
* `OreName`: The name of the folder containing the ore parts.
* `HighlightConfig`: Dictates `FillColor`, `Transparency`, and `DepthMode` for the mining UI.



### Stay-in-Zone Hold Quest System

**ID:** `[044fefb1-e16f-415d-9fd1-97385f33acfc]`

**Description:** An area-tracking engine that measures player persistence within a defined volume over time.

* **Configurable Logic**: Uses `ZoneConfig` to define boundary visuals and tracking duration.
* **Task Parameters**:
* `ZoneFolder`: The Workspace folder containing the zone part.
* `ZoneName`: The specific part name to monitor.


* **Visuals**: Supports dynamic `HighlightColor` and `OutlineColor`.

### TalkToNPC System

**ID:** `[9aa4cc65-d7fe-4df5-a2cd-146adce98ffd]`

**Description:** A proximity-based social interaction engine that triggers completion upon reaching a specific distance threshold.

* **Configurable Logic**: Uses `Config` to set interaction bounds and visual cues.
* **Task Parameters**:
* `TargetName`: The NPC model to talk to.
* `InteractionDistance`: The radius in studs for successful contact.


* **Workspace Dependency**: Targets must exist in `Workspace.Talk_Test`.

### Movement Quest System

**ID:** `[34e62209-af2a-4558-b03d-f12fb2e1e623]`

**Description:** A Movement tracking engine that monitors player travel distance to complete objectives.

* **Configurable Logic**: Uses `MovementConfig` to define the type of physical activity tracked.
* **Task Parameters**:
* `ActionType`: The specific movement state (e.g., "Run").
* `MaxProgress`: The total distance in studs required for completion.


* **Core Logic**: Processed via `src/ServerScriptService/.../TriggeredQuest/Types/Movement.lua`.

### Timing-Challenge Quest System

**ID:** `[2e882974-3ef6-4f86-9bfe-1cc5daf75a0c]`

**Description:** A minigame-tracking engine that tests player reflexes through a timing minigame.

* **Configurable Logic**: Uses `ChallengeConfig` to define win requirements and game counting logic.
* **Task Parameters**:
* `RequireWins`: If true, only successful minigame completions count toward progress.
* `CountAllGames`: If true, all attempts are tracked regardless of win/loss.


* **Core Logic**: Integrated via `src/ServerScriptService/.../TriggeredQuest/Types/TimingChallenge.lua`.

---

## 📊 Technical Comparison & Configuration

| Quest Type | Logic ID (`ServerSideQuestName`) | Required Config Table | Tracking Engine |
| --- | --- | --- | --- |
| **Combat** | `KillNPC` | `KillConfig` | Signal Handling |
| **Social** | `TalkToNPC` | `Config` | Proximity Detection |
| **Challenge** | `StayZone` | `ZoneConfig` | Area Tracking |
| **Minigame** | `TimingChallenge` | `ChallengeConfig` | Event Logic |
| **Mining** | `MineOre` | `MiningConfig` | Resource Interaction |
| **Movement** | `Movement` | `MovementConfig` | Studs Calculation |

---

## ⚙️ Core Integration Rules

### 📍 Registry Registration

Metadata must be appended to the central table in:
`src/ReplicatedStorage/SharedSource/Datas/QuestDefinitions/SideQuest.lua`.

### ⚠️ Dependency Guardrails

* **Server Logic**: Never remove files in `src/ServerScriptService/.../TriggeredQuest/Types/` as they contain the core task execution code.
* **Client Handlers**: Files in `src/ReplicatedStorage/ClientSource/.../` manage the local UI and visual highlights for players.
* **NPC Givers**: All quests require an interaction prompt located in `Workspace.DialoguePrompts` (e.g., `Quest1` through `Quest6`).

---