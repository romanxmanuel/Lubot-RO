--[[
    QuestController
    
    Client-side quest management and UI updates.
    Listens to server signals and manages quest animations.
    
    Phase 11: Client UI Refactoring
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local SoundPlayer = require(ReplicatedStorage.SharedSource.Utilities.Audio.SoundPlayer)

local QuestController = Knit.CreateController({
	Name = "QuestController",
	Instance = script, -- Automatically initializes components
})

---- Player Reference
local player = Players.LocalPlayer

---- Knit Services
local QuestService
local ProfileService

---- Knit Controllers

---- Quest UI State
QuestController.IsReady = false
QuestController.CurrentlyTrackedQuest = nil

--[[
    Called when main quest progress updates from server
]]
function QuestController:OnMainQuestProgressUpdate()
	-- Delegate to MainQuestUI component
	if self.Components and self.Components.MainQuestUI then
		self.Components.MainQuestUI:UpdateQuestDisplay()
	end
end

--[[
    Called when main quest finishes and animation should play
    
    @param questNum number - The completed quest number
    @param rewards table - Rewards data {EXP = number, Cash = number}
]]
function QuestController:OnMainQuestFinished(questNum, rewards)
	-- Delegate to animation component with rewards data
	if self.Components and self.Components.QuestAnimations then
		self.Components.QuestAnimations:PlayCompletionAnimation(questNum, rewards)
	end
end

--[[
    Called by QuestAnimations component when animation completes
    @param questNum number - The quest that finished animating
]]
function QuestController:NotifyQuestAnimationComplete(questNum)
	-- Quest frame visibility is already handled by QuestAnimations component
	-- Server advances to next quest automatically after animation duration
end

--[[
    Called when a side quest is tracked
    
    @param questType string - "Daily", "Weekly", or "SideQuest"
    @param questNum number - The quest index
]]
function QuestController:OnSideQuestTracked(questType, questNum)
	-- Cleanup any previous quest's handlers using QuestTypeManager
	-- This replaces hardcoded cleanup calls for each handler type
	if self.Components and self.Components.QuestTypeManager then
		self.Components.QuestTypeManager:CleanupAllHandlers()
	end

	self.CurrentlyTrackedQuest = {
		QuestType = questType,
		QuestNum = questNum,
	}

	-- Delegate to SideQuestUI component
	if self.Components and self.Components.SideQuestUI then
		self.Components.SideQuestUI:OnQuestTracked(questType, questNum)
	end
end

--[[
    Called when Daily/Weekly quests are reset (new quests generated)
    Auto-tracks the first quest with animation
    
    @param questType string - "Daily" or "Weekly"
]]
function QuestController:OnQuestReset(questType)
	-- Wait a moment for profile data to update
	task.wait(0.5)

	-- Auto-track the first quest in the new list
	if questType == "Daily" or questType == "Weekly" then
		-- Track quest index 1 (first quest in the list)
		self:TrackSideQuest(questType, 1)
	end
end

--[[
    Called when any quest is completed
    
    @param questType string - "Main", "Daily", "Weekly", or "SideQuest"
    @param questNum number - The quest index
    @param rewards table - Rewards granted
]]
function QuestController:OnQuestCompleted(questType, questNum, rewards)
	-- Play quest completion sound
	local questCompletedSound = ReplicatedStorage.Assets.Sounds.Quests.Completed
	if questCompletedSound then
		SoundPlayer.Play(questCompletedSound, { Volume = 0.7 }, workspace)
	end

	-- Cleanup all quest type handlers if this was a side quest
	-- This replaces hardcoded cleanup calls for each handler type
	if
		(questType == "Daily" or questType == "Weekly" or questType == "SideQuest")
		and self.Components
		and self.Components.QuestTypeManager
	then
		self.Components.QuestTypeManager:CleanupAllHandlers()
	end

	-- Refresh UI to show completion status
	self:RefreshAllQuestUI()

	-- Delegate to specific UI components for animations/effects
	if questType == "Main" then
		if self.Components and self.Components.MainQuestUI then
			self.Components.MainQuestUI:OnQuestCompleted(questNum, rewards)
		end
	elseif questType == "Daily" or questType == "Weekly" or questType == "SideQuest" then
		if self.Components and self.Components.SideQuestUI then
			self.Components.SideQuestUI:OnQuestCompleted(questType, questNum, rewards)
		end
	end
end

--[[
    Tracks a new side quest (rate-limited)
    
    @param questType string - "Daily", "Weekly", or "SideQuest"
    @param questNum number/string - The quest index (or quest name for SideQuest)
]]
function QuestController:TrackSideQuest(questType, questNum)
	if not QuestService then
		warn("QuestService not initialized")
		return
	end

	-- Call server method to track the quest
	QuestService:TrackSideQuest(questType, questNum)
end

--[[
    Refreshes all quest UI displays
]]
function QuestController:RefreshAllQuestUI()
	if self.Components then
		if self.Components.MainQuestUI then
			self.Components.MainQuestUI:UpdateQuestDisplay()
		end

		if self.Components.SideQuestUI then
			self.Components.SideQuestUI:UpdateQuestsList()
		end
	end
end

function QuestController:KnitStart()
	-- Mark controller as ready
	self.IsReady = true

	-- Connect to server signals
	if QuestService then
		-- Quest completion signal (all quest types)
		QuestService.QuestCompleted:Connect(function(questType, questNum, rewards)
			self:OnQuestCompleted(questType, questNum, rewards)
		end)

		-- Main quest signals
		QuestService.UpdateMainQuestProgress:Connect(function()
			self:OnMainQuestProgressUpdate()
		end)

		QuestService.InitiateFinishedMainQuestAnimation:Connect(function(questNum, rewards)
			self:OnMainQuestFinished(questNum, rewards)
		end)

		-- Quest reset signal (Daily/Weekly)
		QuestService.QuestReset:Connect(function(questType)
			self:OnQuestReset(questType)
		end)

		-- ⭐ MULTI-TASK QUEST SIGNALS
		-- Task progress updated
		QuestService.TaskProgressUpdated:Connect(
			function(questType, questNum, taskIndex, progress, maxProgress, completed)
				if self.Components and self.Components.SideQuestUI then
					self.Components.SideQuestUI:OnTaskProgressUpdated(
						questType,
						questNum,
						taskIndex,
						progress,
						maxProgress,
						completed
					)
				end
			end
		)

		-- Task completed
		QuestService.TaskCompleted:Connect(function(questType, questNum, taskIndex, allTasksCompleted)
			if self.Components and self.Components.SideQuestUI then
				self.Components.SideQuestUI:OnTaskCompleted(questType, questNum, taskIndex, allTasksCompleted)
			end

			-- Play task completion sound
			local taskCompletedSound = ReplicatedStorage.Assets.Sounds.Quests.Completed
			if taskCompletedSound then
				SoundPlayer.Play(taskCompletedSound, { Volume = 0.5 }, workspace)
			end
		end)

		-- Task unlocked (sequential mode)
		QuestService.TaskUnlocked:Connect(function(questType, questNum, taskIndex)
			if self.Components and self.Components.SideQuestUI then
				self.Components.SideQuestUI:OnTaskUnlocked(questType, questNum, taskIndex)
			end
		end)

		-- Setup RemoteFunction callback for quest tracking
		local TrackNewSideQuestRemote = ReplicatedStorage.SharedSource.Remotes.Quests.TrackNewSideQuest
		TrackNewSideQuestRemote.OnClientInvoke = function(questType, questNum)
			-- Perform cleanup FIRST
			self:OnSideQuestTracked(questType, questNum)

			-- Wait a frame to ensure cleanup completes
			task.wait()

			-- Return success to server
			return true
		end
	end

	-- Listen for profile data updates
	if ProfileService and ProfileService.UpdateSpecificData then
		ProfileService.UpdateSpecificData:Connect(function(Redirectories, newValue)
			-- Refresh UI when quest data changes
			-- Redirectories is an array like ["MainQuests"] or ["DailyQuests"]
			if
				Redirectories[1] == "MainQuests"
				or Redirectories[1] == "DailyQuests"
				or Redirectories[1] == "WeeklyQuests"
			then
				self:RefreshAllQuestUI()
			end
		end)
	end
end

function QuestController:KnitInit()
	---- Knit Services
	QuestService = Knit.GetService("QuestService")
	ProfileService = Knit.GetService("ProfileService")
end

return QuestController
