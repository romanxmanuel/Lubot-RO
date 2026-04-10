local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SetComponent = {}

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local QuestSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService
local QuestService

---- Components
local QuestFactory
local QuestStateMachine
local QuestRewards
local QuestProgressHandler
local RecurringQuest
local ProgressiveQuest

--[[
	SET COMPONENT - STATE MUTATIONS
	All methods here modify quest state
]]
--

--[[
	@param player Player
	@param questType string - "Main", "Daily", or "Weekly"
	@param questNum number - Quest number to start
]]
--
function SetComponent:StartQuest(player, questType, questNum)
	local quest = QuestFactory.Create(questType, questNum)
	if quest then
		quest:StartQuest(player, questNum)

		-- Fire client signal
		QuestService.Client.QuestStarted:Fire(player, questType, questNum)
	else
		warn("Failed to create quest:", questType, questNum)
	end
end

--[[
	@param player Player
	@param questType string
	@param questDescription string - Task description pattern
	@param amount number - Amount to increment by
]]
--
function SetComponent:IncrementQuestProgress(player, questType, questDescription, amount)
	local quest = QuestFactory.Create(questType)
	if quest then
		quest:IncrementProgress(player, questDescription, amount)

		-- Fire client signal
		QuestService.Client.QuestProgressUpdated:Fire(player, questType, questDescription, amount)
	end
end

--[[
	@param player Player
	@param questType string
	@param questDescription string - Task description pattern
	@param value number - Absolute progress value to set
]]
--
function SetComponent:SetQuestProgress(player, questType, questDescription, value)
	local quest = QuestFactory.Create(questType)
	if quest then
		quest:SetProgress(player, questDescription, value)

		-- Fire client signal
		QuestService.Client.QuestProgressUpdated:Fire(player, questType, questDescription, value)
	end
end

--[[
	@param player Player
	@param questType string
	@param questNum number
]]
--
function SetComponent:CompleteQuest(player, questType, questNum)
	local quest = QuestFactory.Create(questType, questNum)
	if not quest then
		warn("Failed to create quest for completion:", questType, questNum)
		return
	end

	-- Use state machine for atomic completion
	local success = QuestStateMachine:Transition(player, quest, "InProgress", "Completed", {
		onSuccess = function()
			-- Calculate and grant rewards
			local questData = quest:GetQuestData()
			local exp, cash = QuestRewards.CalculateRewards(player, questType, questNum, questData.Rewards)
			local rewardSuccess, rewards = QuestRewards.GrantRewards(player, exp, cash)

			if rewardSuccess then
				QuestRewards.NotifyPlayer(player, questType, exp, cash)

				-- Fire client signal
				QuestService.Client.QuestCompleted:Fire(player, questType, questNum, rewards)
			else
				warn("Failed to grant rewards for quest:", questType, questNum)
			end
		end,
		onFailure = function(err)
			warn("Quest completion failed:", err)
		end,
	})

	return success
end

--[[
	@param player Player
	@param questType string - "Daily" or "Weekly"
]]
--
function SetComponent:ResetQuest(player, questType)
	if questType == "Daily" then
		local dailyQuest = RecurringQuest.CreateDaily()
		dailyQuest:Reset(player)
	elseif questType == "Weekly" then
		local weeklyQuest = RecurringQuest.CreateWeekly()
		weeklyQuest:Reset(player)
	else
		warn("Invalid quest type for reset:", questType)
		return
	end

	-- Fire client signal
	QuestService.Client.QuestReset:Fire(player, questType)
end

--[[
	@param player Player
	@param questType string - "Daily", "Weekly", or "SideQuest"
	@param questNum number/string - Quest index in array (or quest name for SideQuest)
]]
--
function SetComponent:TrackSideQuest(player, questType, questNum)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	-- Handle SideQuest initialization and repeatability
	if questType == "SideQuest" then
		local questName = questNum
		local questData = QuestDefinitions.SideQuest[questName]

		if not questData then
			warn("SideQuest definition not found:", questName)
			return
		end

		-- Initialize quest if it doesn't exist
		if not profileData.SideQuests[questName] then
			-- Initialize with Tasks array structure
			if questData.Tasks then
				local tasks = {}
				for taskIndex, taskDef in ipairs(questData.Tasks) do
					table.insert(tasks, {
						Description = taskDef.Description,
						Progress = 0,
						MaxProgress = taskDef.MaxProgress,
						Completed = false,
					})
				end

				profileData.SideQuests[questName] = {
					Name = questName,
					Completed = false,
					Tasks = tasks,
				}
			else
				-- Fallback for legacy structure (should not happen)
				warn("SideQuest missing Tasks array:", questName)
				profileData.SideQuests[questName] = {
					Name = questName,
					Progress = 0,
					Completed = false,
				}
			end
			ProfileService:ChangeData(player, { "SideQuests" }, profileData.SideQuests)
		-- Check if quest is already completed
		elseif profileData.SideQuests[questName].Completed then
			if questData.Repeatable then
				-- Reset completed repeatable quest with Tasks array
				if questData.Tasks then
					-- Reset all tasks
					for taskIndex, taskData in ipairs(profileData.SideQuests[questName].Tasks) do
						taskData.Progress = 0
						taskData.Completed = false
					end
				else
					-- Legacy fallback
					profileData.SideQuests[questName].Progress = 0
				end
				profileData.SideQuests[questName].Completed = false
				ProfileService:ChangeData(player, { "SideQuests" }, profileData.SideQuests)
			else
				-- Non-repeatable quest already completed - cannot track again
				warn("Cannot track non-repeatable SideQuest that's already completed:", questName)
				return
			end
		end
	end

	-- Update tracked quest
	local trackedData = {
		QuestType = questType,
		QuestNum = questNum,
	}

	ProfileService:ChangeData(player, { "CurrentSideQuestTracked" }, trackedData)

	-- Call client cleanup and WAIT for response before spawning new objectives
	-- This prevents race condition where new objectives arrive before cleanup
	local RemoteFunction = ReplicatedStorage.SharedSource.Remotes.Quests.TrackNewSideQuest
	local success, cleanupComplete = pcall(function()
		return RemoteFunction:InvokeClient(player, questType, questNum)
	end)

	if not success then
		warn("TrackSideQuest: Failed to invoke client cleanup:", cleanupComplete)
		return
	end

	if not cleanupComplete then
		warn("TrackSideQuest: Client cleanup failed or timed out")
		return
	end

	-- ⭐ SERVER-SIDE CLEANUP: Clear any previous quest's server-side data
	-- This prevents stale data from polluting new quest tracking
	local ComponentsFolder = script.Parent.Parent
	local TriggeredQuestTypes = ComponentsFolder.Components.Others.TriggeredQuest.Types
	
	-- Cleanup PickUpItems data
	local PickUpItemsModule = TriggeredQuestTypes:FindFirstChild("PickUpItems")
	if PickUpItemsModule then
		local PickUpItems = require(PickUpItemsModule)
		if PickUpItems.CleanUp then
			PickUpItems:CleanUp(player)
		end
	end
	
	-- Cleanup Delivery data
	local DeliveryModule = TriggeredQuestTypes:FindFirstChild("Delivery")
	if DeliveryModule then
		local Delivery = require(DeliveryModule)
		if Delivery.CleanUp then
			Delivery:CleanUp(player)
		end
	end

	-- Get quest data to find ServerSideQuestName
	local questData
	if questType == "SideQuest" then
		-- For standalone side quests, questNum is the quest name
		questData = QuestDefinitions.SideQuest[questNum]
	elseif questType == "Daily" then
		if profileData.DailyQuests.Quests[questNum] then
			local questName = profileData.DailyQuests.Quests[questNum].Name
			questData = QuestDefinitions.Daily[questName]
		end
	elseif questType == "Weekly" then
		if profileData.WeeklyQuests.Quests[questNum] then
			local questName = profileData.WeeklyQuests.Quests[questNum].Name
			questData = QuestDefinitions.Weekly[questName]
		end
	end

	-- NEW: Check if quest is passive (cannot be tracked)
	if questData and questData.TrackingMode == "Passive" then
		warn("Cannot track passive quest:", questData.DisplayName or questData.Name)
		warn("   Passive quests progress automatically and don't require tracking.")

		-- Send error notification to client
		local NotifierService = Knit.GetService("NotifierService")
		NotifierService:NotifyPlayer(
			player,
			string.format("%s progresses automatically - no tracking needed!", questData.DisplayName or questData.Name),
			"Warning"
		)
		return
	end

	if not questData then
		warn("TrackSideQuest: Quest data not found for:", questType, questNum)
		return
	end

	-- ⭐ MULTI-TASK QUEST SUPPORT: Check if quest uses Tasks array structure
	if questData.Tasks and #questData.Tasks > 0 then
		-- Multi-task quest or single-task using Tasks array
		-- Use SideQuestBase to handle all task spawning dynamically
		local ComponentsFolder = script.Parent.Parent
		local SideQuestBase = require(ComponentsFolder.Components.Others.TriggeredQuest.SideQuestBase)

		if SideQuestBase and SideQuestBase.StartQuest then
			SideQuestBase:StartQuest(player, questType, questNum)
		else
			warn("TrackSideQuest: SideQuestBase.StartQuest method not found")
		end
	elseif questData.ServerSideQuestName then
		-- Legacy single-task quest with quest-level ServerSideQuestName
		-- (This path should rarely be used with new multi-task system)
		local ComponentsFolder = script.Parent.Parent
		local TriggeredQuestTypes = ComponentsFolder.Components.Others.TriggeredQuest.Types
		local questModule = TriggeredQuestTypes:FindFirstChild(questData.ServerSideQuestName)

		if questModule then
			local sideQuestHandler = require(questModule)
			if sideQuestHandler.StartQuest then
				sideQuestHandler:StartQuest(player, questType, questNum)
			else
				warn("TrackSideQuest: StartQuest method not found in handler:", questData.ServerSideQuestName)
			end
		else
			warn("TrackSideQuest: Side quest handler module not found:", questData.ServerSideQuestName)
		end
	else
		warn("TrackSideQuest: Quest has no Tasks array or ServerSideQuestName:", questType, questNum)
	end
end

--========================================
-- MULTI-TASK QUEST METHODS
--========================================

--[[
	Set task progress for a specific task in a multi-task quest
	@param player Player
	@param questType string
	@param questNum number/string
	@param taskIndex number
	@param newProgress number
	@return boolean
]]
function SetComponent:SetTaskProgress(player, questType, questNum, taskIndex, newProgress)
	return QuestProgressHandler.SetTaskProgress(player, questType, questNum, taskIndex, newProgress)
end

--[[
	Increment task progress for a specific task
	@param player Player
	@param questType string
	@param questNum number/string
	@param taskIndex number
	@param amount number
	@return boolean
]]
function SetComponent:IncrementTaskProgress(player, questType, questNum, taskIndex, amount)
	return QuestProgressHandler.IncrementTaskProgress(player, questType, questNum, taskIndex, amount)
end

--[[
	Complete a specific task manually
	@param player Player
	@param questType string
	@param questNum number/string
	@param taskIndex number
	@return boolean
]]
function SetComponent:CompleteTask(player, questType, questNum, taskIndex)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return false
	end

	local quest = QuestProgressHandler.GetQuestData(profileData, questType, questNum)
	if not quest or not quest.Tasks or not quest.Tasks[taskIndex] then
		return false
	end

	-- Mark task as completed
	quest.Tasks[taskIndex].Completed = true
	quest.Tasks[taskIndex].Progress = quest.Tasks[taskIndex].MaxProgress

	-- Save
	if questType == "SideQuest" then
		ProfileService:ChangeData(player, { "SideQuests" }, profileData.SideQuests)
	elseif questType == "Daily" then
		ProfileService:ChangeData(player, { "DailyQuests" }, profileData.DailyQuests)
	elseif questType == "Weekly" then
		ProfileService:ChangeData(player, { "WeeklyQuests" }, profileData.WeeklyQuests)
	end

	return true
end

function SetComponent.Start()
	-- Component started
end

function SetComponent.Init()
	---- Knit Services
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")

	---- Components
	local ComponentsFolder = script.Parent.Parent
	local CoreFolder = ComponentsFolder.Components.Others.Core

	QuestFactory = require(CoreFolder.QuestFactory)
	QuestStateMachine = require(CoreFolder.QuestStateMachine)
	QuestRewards = require(CoreFolder.QuestRewards)
	QuestProgressHandler = require(CoreFolder.QuestProgressHandler)

	local RecurringQuestFolder = ComponentsFolder.Components.Others.RecurringQuest
	RecurringQuest = require(RecurringQuestFolder)

	local ProgressiveQuestFolder = ComponentsFolder.Components.Others.ProgressiveQuest
	ProgressiveQuest = require(ProgressiveQuestFolder)
end

return SetComponent
