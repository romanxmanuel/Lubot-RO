--[[
	CombinedQuestTesterDialogue.lua
	
	Client-side component for testing MULTI-TASK SIDE QUESTS.
	Allows testing both Sequential and Parallel multi-task quests.
	
	Workspace Setup:
	- Create folder: Workspace.DialoguePrompts
	- Create Model: Workspace.DialoguePrompts['Combined Side Quest Tester'] (NPC with Humanoid)
	- Add ProximityPrompt to the Model's HumanoidRootPart
	
	Required workspace folders:
	- Workspace.Pickup_Item_Quest_Test (for crate pickups)
	- Workspace.Deliver_Test (for delivery locations)
	
	Quests Available:
	1. MultiStepQuest (Sequential) - Collect crates → Deliver packages
	2. ParallelChallenge (Parallel) - Collect crates AND deliver packages simultaneously
	
	Usage:
	Approach the Quest Giver NPC and interact with it to choose a quest type.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local CombinedQuestTesterDialogue = {}

---- Knit Services
local QuestService

---- Knit Controllers
local DialogueController
local QuestController

---- Local References
local plr = game.Players.LocalPlayer

-- Flag to prevent multiple dialogue instances
local isDialogueOpen = false

-- Store proximity prompt connection for cleanup
local proximityConnection = nil

-- Multi-task quest tester dialogue with quest type selection
local COMBINED_QUEST_DIALOGUE = {
	InitialLayer = "ChooseQuestType",
	SkinName = "Cinematic",

	Layers = {
		ChooseQuestType = {
			Dialogue = {
				"Greetings, adventurer!",
				"I have TWO special multi-task quests available for testing.",
				"",
				"🔹 SEQUENTIAL QUEST: Complete tasks in order (Collect → Deliver)",
				"🔹 PARALLEL QUEST: Complete tasks simultaneously (Collect + Deliver)",
				"",
				"Which type would you like to test?",
			},
			DialogueSounds = { nil, nil, nil, nil, nil, nil, nil },
			DialogueImage = "rbxassetid://14973462209",
			Title = "Multi-Task Quest Tester",

			Replies = {
				sequential = {
					ReplyText = "🔹 Sequential Quest",
					ReplyLayer = "ConfirmSequential",
				},

				parallel = {
					ReplyText = "🔸 Parallel Quest",
					ReplyLayer = "ConfirmParallel",
				},

				_goodbye = {
					ReplyText = "❌ Not Right Now",
				},
			},

			Exec = {},
		},

		ConfirmSequential = {
			Dialogue = {
				"✅ SEQUENTIAL QUEST SELECTED",
				"",
				"Quest: Island Challenge",
				"📦 Task 1: Collect 10 crates",
				"📬 Task 2: Deliver 5 packages (unlocks after Task 1)",
				"",
				"Tasks unlock in order - complete Task 1 to unlock Task 2!",
				"Ready to start?",
			},
			DialogueSounds = { nil, nil, nil, nil, nil, nil, nil, nil },
			DialogueImage = "rbxassetid://14973462209",
			Title = "Multi-Task Quest Tester",

			Replies = {
				back = {
					ReplyText = "← Go Back",
					ReplyLayer = "ChooseQuestType",
				},

				_goodbye = {
					ReplyText = "❌ Cancel",
				},

				accept = {
					ReplyText = "✅ Start Sequential Quest",
					ReplyLayer = "QuestStarted",
				},
			},

			Exec = {
				startQuest = {
					Function = function()
						CombinedQuestTesterDialogue:StartQuest("MultiStepQuest")
					end,
					ExecTime = "Before",
					ExecContent = "accept",
				},
			},
		},

		ConfirmParallel = {
			Dialogue = {
				"✅ PARALLEL QUEST SELECTED",
				"",
				"Quest: Simultaneous Tasks",
				"📦 Task 1: Collect 8 crates",
				"📬 Task 2: Deliver 4 packages",
				"",
				"Both tasks are active at the same time - complete in any order!",
				"Ready to start?",
			},
			DialogueSounds = { nil, nil, nil, nil, nil, nil, nil, nil },
			DialogueImage = "rbxassetid://14973462209",
			Title = "Multi-Task Quest Tester",

			Replies = {
				back = {
					ReplyText = "← Go Back",
					ReplyLayer = "ChooseQuestType",
				},

				_goodbye = {
					ReplyText = "❌ Cancel",
				},

				accept = {
					ReplyText = "✅ Start Parallel Quest",
					ReplyLayer = "QuestStarted",
				},
			},

			Exec = {
				startQuest = {
					Function = function()
						CombinedQuestTesterDialogue:StartQuest("ParallelChallenge")
					end,
					ExecTime = "Before",
					ExecContent = "accept",
				},
			},
		},

		QuestStarted = {
			Dialogue = {
				"Excellent! I've added the quest to your quest log.",
				"",
				"🎯 Switch to the SIDE tab in your quest UI to track progress",
				"📦 Collect crates (they should now be highlighted)",
				"📬 Deliver packages (quest markers will appear)",
				"",
				"Good luck with your multi-task adventure!",
			},
			DialogueSounds = { nil, nil, nil, nil, nil, nil, nil },
			DialogueImage = "rbxassetid://14973462209",
			Title = "Multi-Task Quest Tester",

			Replies = {
				_goodbye = {
					ReplyText = "✅ Let's go!",
				},
			},

			Exec = {},
		},
	},
}

--[[
	Start a multi-task side quest
	@param questName string - "MultiStepQuest" or "ParallelChallenge"
]]
function CombinedQuestTesterDialogue:StartQuest(questName)
	if not QuestService then
		return
	end

	if not questName or (questName ~= "MultiStepQuest" and questName ~= "ParallelChallenge") then
		return
	end

	-- Track the selected side quest
	pcall(function()
		return QuestService:TrackSideQuest("SideQuest", questName)
	end)
end

--[[
	Open the combined quest tester dialogue
]]
function CombinedQuestTesterDialogue:OpenDialogue()
	if isDialogueOpen then
		return
	end

	if not DialogueController then
		return
	end

	isDialogueOpen = true

	local success = DialogueController:Open(COMBINED_QUEST_DIALOGUE)

	if success then
		-- Reset flag after dialogue closes (estimate 2 seconds for multi-layer dialogue)
		task.delay(2, function()
			isDialogueOpen = false
		end)
	else
		isDialogueOpen = false
	end
end

--[[
	Setup proximity prompt connection
]]
local function setupProximityPrompt()
	-- Only run in Studio
	if not RunService:IsStudio() then
		return
	end

	task.spawn(function()
		local success, prompt = pcall(function()
			return workspace
				:WaitForChild("DialoguePrompts", 10)
				:WaitForChild("Combined Side Quest Tester", 10)
				:WaitForChild("HumanoidRootPart", 10)
				:WaitForChild("ProximityPrompt", 10)
		end)

		if success and prompt then
			-- Setup the connection
			proximityConnection = prompt.Triggered:Connect(function(player)
				-- Only respond to the local player
				if player == plr then
					CombinedQuestTesterDialogue:OpenDialogue()
				end
			end)
		end
	end)
end

--[[
	Cleanup function
]]
function CombinedQuestTesterDialogue:Cleanup()
	if proximityConnection then
		proximityConnection:Disconnect()
		proximityConnection = nil
	end

	isDialogueOpen = false
end

function CombinedQuestTesterDialogue.Start()
	-- Setup proximity prompt connection
	setupProximityPrompt()
end

function CombinedQuestTesterDialogue.Init()
	-- Initialize services and controllers
	QuestService = Knit.GetService("QuestService")
	DialogueController = Knit.GetController("DialogueController")
	QuestController = Knit.GetController("QuestController")
end

return CombinedQuestTesterDialogue
