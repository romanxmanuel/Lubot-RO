--[[
	DailyWeeklyQuestToggler.lua
	
	Client-side component for toggling the Daily/Weekly Quest UI frame.
	Provides interaction with an NPC to open/close the SideQuestsFrame and display quest lists.
	
	Integrates with SideQuestUI component to:
	- Display daily quest list (up to 3 quests)
	- Display weekly quest list (typically 1 quest)
	- Show quest progress, rewards, and completion status
	- Allow tracking quests
	- Show reset timers
	
	Workspace Setup:
	- Create folder: Workspace.DialoguePrompts
	- Create Model: Workspace.DialoguePrompts['Daily or Weekly Quest Tester'] (NPC with Humanoid)
	- Add ProximityPrompt to the Model's HumanoidRootPart
	
	UI Setup:
	- StarterGui.QuestGui.SideQuestsFrame should exist (legacy structure)
	- SideQuestsFrame.QuestsFrame.DailyQuestsListFrame (with frames named "1", "2", "3")
	- SideQuestsFrame.QuestsFrame.WeeklyQuestsListFrame (with frame named "1")
	- SideQuestsFrame.ExitButton should exist for closing
	
	Usage:
	Approach the NPC and interact with it to toggle the Daily/Weekly Quest UI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

---- Utilities
local Utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
local SoundPlayer = require(Utilities:WaitForChild("Audio"):WaitForChild("SoundPlayer", 10))

---- Sound References
local Assets = ReplicatedStorage:WaitForChild("Assets", 10)
local Sounds = Assets:WaitForChild("Sounds", 10)
local ClickSound = Sounds:WaitForChild("Click", 10)

local DailyWeeklyQuestToggler = {}

---- Knit Controllers
local QuestController

---- Player Reference
local plr = Players.LocalPlayer

---- UI References
local questGui
local sideQuestsFrame
local exitButton

---- Connections
local proximityConnection = nil
local exitButtonConnection = nil

---- Animation Settings
local TWEEN_INFO = TweenInfo.new(
	0.3, -- Duration
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

--[[
	Initializes UI references
]]
local function initializeUI()
	local playerGui = plr:WaitForChild("PlayerGui")
	if not playerGui then
		warn("[DailyWeeklyQuestToggler] PlayerGui not found")
		return false
	end

	questGui = playerGui:FindFirstChild("QuestGui") or playerGui:WaitForChild("QuestGui")
	if not questGui then
		warn("[DailyWeeklyQuestToggler] QuestGui not found")
		return false
	end

	sideQuestsFrame = questGui:FindFirstChild("SideQuestsFrame")
	if not sideQuestsFrame then
		warn("[DailyWeeklyQuestToggler] SideQuestsFrame not found in QuestGui")
		return false
	end

	exitButton = sideQuestsFrame:FindFirstChild("ExitButton")
	if not exitButton then
		warn("[DailyWeeklyQuestToggler] ExitButton not found in SideQuestsFrame")
		return false
	end

	-- Ensure frame is initially hidden
	sideQuestsFrame.Visible = false

	return true
end

--[[
	Opens the Daily/Weekly Quest UI with animation
]]
function DailyWeeklyQuestToggler:OpenUI()
	if not sideQuestsFrame then
		warn("[DailyWeeklyQuestToggler] Cannot open UI - not initialized")
		return
	end

	if sideQuestsFrame.Visible then
		-- Already open
		return
	end

	-- Update quest data before showing (use SideQuestUI component)
	if QuestController and QuestController.Components and QuestController.Components.SideQuestUI then
		QuestController.Components.SideQuestUI:UpdateQuestsList()
	end

	-- Show the frame
	sideQuestsFrame.Visible = true

	-- Animate in (scale from 0 to 1)
	sideQuestsFrame.Size = UDim2.new(0, 0, 0, 0)
	local targetSize = UDim2.new(0.4, 0, 0.6, 0) -- Adjust size as needed

	local tween = TweenService:Create(sideQuestsFrame, TWEEN_INFO, {
		Size = targetSize,
	})
	tween:Play()
end

--[[
	Closes the Daily/Weekly Quest UI with animation
]]
function DailyWeeklyQuestToggler:CloseUI()
	if not sideQuestsFrame then
		warn("[DailyWeeklyQuestToggler] Cannot close UI - not initialized")
		return
	end

	if not sideQuestsFrame.Visible then
		-- Already closed
		return
	end

	-- Animate out (scale to 0)
	local tween = TweenService:Create(sideQuestsFrame, TWEEN_INFO, {
		Size = UDim2.new(0, 0, 0, 0),
	})

	tween:Play()
	tween.Completed:Connect(function()
		sideQuestsFrame.Visible = false
	end)
end

--[[
	Toggles the Daily/Weekly Quest UI
]]
function DailyWeeklyQuestToggler:ToggleUI()
	if not sideQuestsFrame then
		warn("[DailyWeeklyQuestToggler] Cannot toggle UI - not initialized")
		return
	end

	if sideQuestsFrame.Visible then
		self:CloseUI()
	else
		self:OpenUI()
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
				:WaitForChild("Daily or Weekly Quest Tester", 10)
				:WaitForChild("HumanoidRootPart", 10)
				:WaitForChild("ProximityPrompt", 10)
		end)

		if success and prompt then
			-- Setup the connection
			proximityConnection = prompt.Triggered:Connect(function(player)
				-- Only respond to the local player
				if player == plr then
					DailyWeeklyQuestToggler:ToggleUI()
				end
			end)
		end
	end)
end

--[[
	Setup exit button connection
]]
local function setupExitButton()
	if not exitButton then
		warn("[DailyWeeklyQuestToggler] Exit button not available")
		return
	end

	exitButtonConnection = exitButton.MouseButton1Click:Connect(function()
		-- Play click sound
		SoundPlayer.Play(ClickSound, { Volume = 0.5 }, plr:WaitForChild("PlayerGui"))
		
		DailyWeeklyQuestToggler:CloseUI()
	end)
end

--[[
	Cleanup function
]]
function DailyWeeklyQuestToggler:Cleanup()
	if proximityConnection then
		proximityConnection:Disconnect()
		proximityConnection = nil
	end

	if exitButtonConnection then
		exitButtonConnection:Disconnect()
		exitButtonConnection = nil
	end
end

function DailyWeeklyQuestToggler.Start()
	-- Initialize UI references
	local success = initializeUI()

	if success then
		-- Setup proximity prompt connection
		setupProximityPrompt()

		-- Setup exit button
		setupExitButton()
	else
		warn("[DailyWeeklyQuestToggler] Failed to initialize UI")
	end
end

function DailyWeeklyQuestToggler.Init()
	-- Get QuestController reference for accessing SideQuestUI component
	QuestController = Knit.GetController("QuestController")
end

return DailyWeeklyQuestToggler
