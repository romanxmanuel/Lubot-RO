--[[
	DeliveryTesterDialogue.lua
	
	Client-side component for accepting a DELIVERY QUEST.
	Provides a simple dialogue interface for starting a delivery quest.
	
	Workspace Setup:
	- Create folder: Workspace.DialoguePrompts
	- Create Model: Workspace.DialoguePrompts['Side Quest Tester 2'] (NPC with Humanoid)
	- Add ProximityPrompt to the Model's HumanoidRootPart
	
	- Create folder: Workspace.Deliver_Test
	- Add BasePart children to Workspace.Deliver_Test (these are delivery targets)
	- Set delivery parts: CanCollide = false, Anchored = true, Transparency = 0.5 (for testing)
	
	Usage:
	Approach the Quest Giver NPC and interact with it to accept the delivery quest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local DeliveryTesterDialogue = {}

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

-- Delivery quest dialogue
local DELIVERY_QUEST_DIALOGUE = {
	InitialLayer = "AcceptQuest",
	SkinName = "Cinematic",

	Layers = {
		AcceptQuest = {
			Dialogue = {
				"Welcome, courier!",
				"I need someone reliable to deliver a package to the marked location.",
				"You'll see a quest marker ('!') when you accept. Just walk into it to complete the delivery.",
				"Are you up for the task?",
			},
			DialogueSounds = { nil, nil, nil, nil },
			DialogueImage = "rbxassetid://14973462209",
			Title = "Delivery Manager",

			Replies = {
				accept = {
					ReplyText = "✅ Accept Delivery",
					ReplyLayer = "QuestStarted",
				},

				_goodbye = {
					ReplyText = "❌ Not Right Now",
				},
			},

			Exec = {
				startQuest = {
					Function = function()
						DeliveryTesterDialogue:StartQuest()
					end,
					ExecTime = "Before",
					ExecContent = "accept",
				},
			},
		},

		QuestStarted = {
			Dialogue = {
				"Perfect! I've added the delivery quest to your quest log.",
				"Look for the quest marker ('!') - that's your delivery destination.",
				"Simply walk into the quest marker to complete the delivery!",
			},
			DialogueSounds = { nil, nil, nil },
			DialogueImage = "rbxassetid://14973462209",
			Title = "Delivery Manager",

			Replies = {
				_goodbye = {
					ReplyText = "✅ On my way!",
				},
			},

			Exec = {},
		},
	},
}

--[[
	Start the delivery quest
]]
function DeliveryTesterDialogue:StartQuest()
	if not QuestService then
		warn("[DeliveryTesterDialogue] QuestService not available")
		return
	end

	-- Track the delivery side quest
	local success, result = pcall(function()
		-- Call server to track the side quest "DeliverPackage"
		return QuestService:TrackSideQuest("SideQuest", "DeliverPackage")
	end)

	if not success then
		warn("[DeliveryTesterDialogue] Failed to start delivery quest:", result)
	end
end

--[[
	Open the delivery quest dialogue
]]
function DeliveryTesterDialogue:OpenDialogue()
	if isDialogueOpen then
		warn("[DeliveryTesterDialogue] Dialogue already open")
		return
	end

	if not DialogueController then
		warn("[DeliveryTesterDialogue] DialogueController not available")
		return
	end

	isDialogueOpen = true

	local success = DialogueController:Open(DELIVERY_QUEST_DIALOGUE)

	if success then
		-- Reset flag after dialogue closes (estimate 1 second delay)
		task.delay(1, function()
			isDialogueOpen = false
		end)
	else
		warn("[DeliveryTesterDialogue] Failed to open dialogue")
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
				:WaitForChild("Side Quest Tester 2", 10)
				:WaitForChild("HumanoidRootPart", 10)
				:WaitForChild("ProximityPrompt", 10)
		end)

		if success and prompt then
			-- Setup the connection
			proximityConnection = prompt.Triggered:Connect(function(player)
				-- Only respond to the local player
				if player == plr then
					DeliveryTesterDialogue:OpenDialogue()
				end
			end)
		end
	end)
end

--[[
	Cleanup function
]]
function DeliveryTesterDialogue:Cleanup()
	if proximityConnection then
		proximityConnection:Disconnect()
		proximityConnection = nil
	end
end

function DeliveryTesterDialogue.Start()
	-- Setup proximity prompt connection
	setupProximityPrompt()
end

function DeliveryTesterDialogue.Init()
	-- Initialize services and controllers
	QuestService = Knit.GetService("QuestService")
	DialogueController = Knit.GetController("DialogueController")
	QuestController = Knit.GetController("QuestController")
end

return DeliveryTesterDialogue
