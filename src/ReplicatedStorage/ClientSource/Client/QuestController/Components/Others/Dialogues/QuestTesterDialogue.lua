--[[
	QuestTesterDialogue.lua
	
	Client-side component for accepting a SIDE QUEST to pick up wood crates.
	Provides a simple dialogue interface for starting a persistent side quest (not Daily/Weekly).
	
	Workspace Setup:
	- Create folder: Workspace.DialoguePrompts
	- Create Model: Workspace.DialoguePrompts['Side Quest Tester 1'] (NPC with Humanoid)
	- Add ProximityPrompt to the Model's HumanoidRootPart
	
	Workspace.Pickup_Item_Quest_Test folder should contain Wood Crate models.
	These crates will be invisible until the quest is accepted.
	
	Usage:
	Approach the Quest Giver NPC and interact with it to accept the quest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestTesterDialogue = {}

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

-- Simplified dialogue for accepting a quest to pick up crates
local QUEST_TESTER_DIALOGUE = {
	InitialLayer = "AcceptQuest",
	SkinName = "Cinematic",

	Layers = {
		AcceptQuest = {
			Dialogue = {
				"Hey there, adventurer!",
				"I have a special side quest for you - collect some wood crates scattered around the area.",
				"This is a persistent quest that you can complete at your own pace. Interested?",
			},
			DialogueSounds = { nil, nil, nil },
			DialogueImage = "rbxassetid://14973462209",
			Title = "Quest Giver",

			Replies = {
				accept = {
					ReplyText = "✅ Accept Quest",
					ReplyLayer = "QuestStarted",
				},

				_goodbye = {
					ReplyText = "❌ Maybe Later",
				},
			},

			Exec = {
				startQuest = {
					Function = function()
						QuestTesterDialogue:StartQuest()
					end,
					ExecTime = "Before",
					ExecContent = "accept",
				},
			},
		},

		QuestStarted = {
			Dialogue = {
				"Excellent! I've added this side quest to your quest log.",
				"Switch to the SIDE tab in your quest UI to track your progress!",
				"The wood crates should now be visible. Go collect them!",
			},
			DialogueSounds = { nil, nil },
			DialogueImage = "rbxassetid://14973462209",
			Title = "Quest Giver",

			Replies = {
				_goodbye = {
					ReplyText = "✅ Got it!",
				},
			},

			Exec = {},
		},
	},
}

--[[
	Start the quest by spawning the wood crates
]]
function QuestTesterDialogue:StartQuest()
	if not QuestService then
		warn("[QuestTesterDialogue] QuestService not available")
		return
	end

	-- Call server to spawn the wood crates (this will be a SideQuest, not Daily)
	local success, result = pcall(function()
		return QuestService:RunPickupItemsTest("SpawnWithWoodCrates")
	end)

	if not success then
		warn("[QuestTesterDialogue] Failed to start side quest:", result)
	end
end

--[[
	Open the quest tester dialogue
]]
function QuestTesterDialogue:OpenDialogue()
	if isDialogueOpen then
		warn("[QuestTesterDialogue] Dialogue already open")
		return
	end

	if not DialogueController then
		warn("[QuestTesterDialogue] DialogueController not available")
		return
	end

	isDialogueOpen = true

	local success = DialogueController:Open(QUEST_TESTER_DIALOGUE)

	if success then
		-- Reset flag after dialogue closes (estimate 1 second delay)
		task.delay(1, function()
			isDialogueOpen = false
		end)
	else
		warn("[QuestTesterDialogue] Failed to open dialogue")
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
				:WaitForChild("Side Quest Tester 1", 10)
				:WaitForChild("HumanoidRootPart", 10)
				:WaitForChild("ProximityPrompt", 10)
		end)

		if success and prompt then
			-- Setup the connection
			proximityConnection = prompt.Triggered:Connect(function(player)
				-- Only respond to the local player
				if player == plr then
					QuestTesterDialogue:OpenDialogue()
				end
			end)
		else
			warn(
				"[QuestTesterDialogue] Could not find proximity prompt at 'Workspace.DialoguePrompts.Side Quest Tester 1.HumanoidRootPart'"
			)
			print("   Setup Instructions:")
			print("   1. Create folder: Workspace.DialoguePrompts")
			print("   2. Add a Model or Part: Workspace.DialoguePrompts['Side Quest Tester 1']")
			print("   3. If using a Model with Humanoid, ProximityPrompt should be in HumanoidRootPart")
			print("   4. If using a Part, add ProximityPrompt directly to the Part")
		end
	end)
end

--[[
	Cleanup function
]]
function QuestTesterDialogue:Cleanup()
	if proximityConnection then
		proximityConnection:Disconnect()
		proximityConnection = nil
	end
end

function QuestTesterDialogue.Start()
	-- Setup proximity prompt connection
	setupProximityPrompt()
end

function QuestTesterDialogue.Init()
	-- Initialize services and controllers
	QuestService = Knit.GetService("QuestService")
	DialogueController = Knit.GetController("DialogueController")
	QuestController = Knit.GetController("QuestController")
end

return QuestTesterDialogue
