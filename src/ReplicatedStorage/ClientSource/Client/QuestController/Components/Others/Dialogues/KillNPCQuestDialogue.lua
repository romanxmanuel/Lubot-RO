-- KillNPCQuestDialogue.lua
-- Dialogue component for NPC "Kill NPC Quest"
-- Gives the KillMonster quest (kill 5x Bandit)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local KillNPCQuestDialogue = {}

---- Knit Services
local QuestService

---- Knit Controllers
local DialogueController
local QuestController

---- Local Player
local plr = game.Players.LocalPlayer

local isDialogueOpen = false
local proximityConnection = nil

-- Dialogue UI
local QUEST1_DIALOGUE = {
	InitialLayer = "AcceptQuest",
	SkinName = "Cinematic",

	Layers = {
		AcceptQuest = {
			Dialogue = {
				"Hello adventurer!",
				"A group of dangerous bandits have been spotted nearby.",
				"We need you to eliminate 5 of them.",
				"Do you accept this task?",
			},
			DialogueImage = "rbxassetid://14973462209",
			Title = "Quest Giver",

			Replies = {
				accept = {
					ReplyText = "🗡 Accept Bandit Hunt",
					ReplyLayer = "QuestStarted",
				},
				_goodbye = {
					ReplyText = "❌ Not now",
				},
			},

			Exec = {
				startQuest = {
					ExecTime = "Before",
					ExecContent = "accept",
					Function = function()
						KillNPCQuestDialogue:StartQuest()
					end,
				},
			},
		},

		QuestStarted = {
			Dialogue = {
				"Good luck, hunter!",
				"Defeat 5 bandits.",
				"Your quest journal has been updated.",
			},
			Title = "Quest Giver",

			Replies = {
				_goodbye = { ReplyText = "Let's go!" }
			},
		},
	},
}

function KillNPCQuestDialogue:StartQuest()
	if not QuestService then return end

	-- TrackSideQuest is a RemoteFunction-like call (returns a Promise)
	QuestService:TrackSideQuest("SideQuest", "KillMonster")
		:andThen(function()
			print("✅ KillMonster quest started successfully!")
		end)
		:catch(function(err)
			warn("❌ Failed to start KillMonster quest:", err)
		end)
end

-- Open dialogue
function KillNPCQuestDialogue:OpenDialogue()
	if isDialogueOpen then return end
	isDialogueOpen = true

	local success = DialogueController:Open(QUEST1_DIALOGUE)

	task.delay(1.2, function()
		isDialogueOpen = false
	end)
end

-- Setup proximity prompt for NPC
local function setupPrompt()
	if not RunService:IsStudio() then return end

	task.spawn(function()
		local prompt = workspace
			:WaitForChild("DialoguePrompts")
			:WaitForChild("Kill NPC Quest")
			:WaitForChild("HumanoidRootPart")
			:WaitForChild("ProximityPrompt")

		proximityConnection = prompt.Triggered:Connect(function(player)
			if player == plr then
				KillNPCQuestDialogue:OpenDialogue()
			end
		end)
	end)
end

function KillNPCQuestDialogue.Start()
	setupPrompt()
end

function KillNPCQuestDialogue.Init()
	QuestService = Knit.GetService("QuestService")
	DialogueController = Knit.GetController("DialogueController")
	QuestController = Knit.GetController("QuestController")
end

return KillNPCQuestDialogue
