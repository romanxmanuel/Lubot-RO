--[[
	SideQuestBase.lua
	
	Base class for all side quest types.
	Provides common patterns for tracking, progress checking, and cleanup.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))
local QuestSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))

---- Knit Services
local ProfileService
local QuestService

---- Components
local QuestRewards
local QuestProgressHandler

local SideQuestBase = {}
SideQuestBase.__index = SideQuestBase

-- ⭐ Module-level state (used when SideQuestBase is used as singleton)
SideQuestBase.IsChecking = {} -- Per-player tracking
SideQuestBase.SpawnedItems = {} -- Track spawned objects per player for cleanup

--[[
	Constructor
	@param maxCount number - Maximum progress count
]]
function SideQuestBase.new(maxCount)
	local self = setmetatable({}, SideQuestBase)
	self.MaxCount = maxCount or 1
	self.CurrentCount = 0
	self.IsChecking = {} -- Per-player tracking
	self.SpawnedItems = {} -- Track spawned objects per player for cleanup
	return self
end

--[[
	Start the quest for a player
	⭐ MULTI-TASK SUPPORT: Handles both single and multi-task quests
	@param player Player
	@param questType string - "Daily", "Weekly", or "SideQuest"
	@param questNum number/string - Index in quest array (or quest name for SideQuest)
]]
function SideQuestBase:StartQuest(player, questType, questNum)
	local questDetail, playerData = self:GetPlayerSideQuestDetails(player, questType, questNum)

	if not self:ValidateQuest(questDetail, playerData) then
		return
	end

	-- All quests use Tasks array structure (even single-task quests)
	self:SpawnQuestObjectives(player, questType, questNum, questDetail, playerData)

	-- ⚠️ DO NOT start progress loop for multi-task quests spawned from SideQuestBase
	-- Multi-task quests have multiple handlers (PickUpItems, Delivery, etc.) that manage their own progress
	-- The progress loop requires CheckQuestProgress() which is abstract in SideQuestBase
	-- Only subclasses with specific CheckQuestProgress() implementations should use the progress loop

	-- Progress checking is only for legacy single-handler quests
	-- Multi-task quests handle progress via individual task handlers (PickUpItems, Delivery, etc.)
end

--[[
	Validate quest before starting
	@param questDetail table
	@param playerData table
	@return boolean
]]
function SideQuestBase:ValidateQuest(questDetail, playerData)
	if not questDetail then
		return false
	end

	if playerData and playerData.Completed then
		return false
	end

	return true
end

--[[
	Get quest details for player
	@param player Player
	@param questType string
	@param questNum number
	@return table, table - questDetail, playerData
]]
function SideQuestBase:GetPlayerSideQuestDetails(player, questType, questNum)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return nil, nil
	end

	if questType == "SideQuest" then
		-- For standalone side quests, questNum is the quest name
		local questName = questNum

		-- NOTE: Quest initialization should be done in Set():TrackSideQuest() ONLY
		-- This function is just a getter and should not initialize quests
		local playerData = profileData.SideQuests[questName]
		local questDetail = QuestDefinitions.SideQuest[questName]

		if not playerData then
			warn("SideQuest not initialized in player profile:", questName)
			warn("   Quest must be tracked first using Set():TrackSideQuest()")
			return nil, nil
		end

		return questDetail, playerData
	else
		-- For Daily/Weekly quests
		local questsData
		if questType == "Daily" then
			questsData = profileData.DailyQuests.Quests
		elseif questType == "Weekly" then
			questsData = profileData.WeeklyQuests.Quests
		else
			return nil, nil
		end

		local playerData = questsData[questNum]
		if not playerData then
			return nil, nil
		end

		local questDetail = QuestDefinitions[questType][playerData.Name]
		return questDetail, playerData
	end
end

--[[
	Start progress checking loop
	@param player Player
	@param questType string
	@param questNum number
]]
function SideQuestBase:StartProgressLoop(player, questType, questNum)
	if self.IsChecking[player] then
		return -- Already checking
	end

	self.IsChecking[player] = true

	task.spawn(function()
		while self.IsChecking[player] and player:IsDescendantOf(Players) do
			-- Check quest progress
			self:CheckQuestProgress(player, questType, questNum)

			-- Check if we should stop
			local shouldStop = self:ShouldStopChecking(player, questType, questNum)

			if shouldStop then
				self:CleanUp(player)
				self.IsChecking[player] = false
				break
			end

			task.wait(1)
		end
	end)
end

--[[
	Check if we should stop checking progress
	@param player Player
	@param questType string
	@param questNum number
	@return boolean
]]
function SideQuestBase:ShouldStopChecking(player, questType, questNum)
	if not player:IsDescendantOf(Players) then
		return true
	end

	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return true
	end

	-- Check if quest is completed
	local quest

	if questType == "SideQuest" then
		-- For standalone side quests, questNum is the quest name
		quest = profileData.SideQuests and profileData.SideQuests[questNum]
	elseif questType == "Daily" or questType == "Weekly" then
		-- For Daily/Weekly quests, questNum is an index
		local questsData
		if questType == "Daily" then
			questsData = profileData.DailyQuests.Quests
		else
			questsData = profileData.WeeklyQuests.Quests
		end

		if questsData then
			quest = questsData[questNum]
		end
	end

	if quest and quest.Completed then
		return true
	end

	return false
end

--[[
	Attempt to complete a side quest
	Respects EnableAutoCompletion setting and handles all completion logic
	@param player Player
	@param questType string - "Daily" or "Weekly"
	@param questNum number
	@return boolean - Success status
]]
function SideQuestBase:TryCompleteQuest(player, questType, questNum)
	-- Check if auto-completion is enabled
	if not QuestSettings.SideQuests.EnableAutoCompletion then
		return false
	end

	-- Get quest data
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return false
	end

	local quest, questDef, questName

	if questType == "SideQuest" then
		-- For standalone side quests, questNum is the quest name
		questName = questNum
		quest = profileData.SideQuests and profileData.SideQuests[questName]
		questDef = QuestDefinitions.SideQuest and QuestDefinitions.SideQuest[questName]
	elseif questType == "Daily" or questType == "Weekly" then
		-- For Daily/Weekly quests, questNum is an index
		local questsData
		if questType == "Daily" then
			questsData = profileData.DailyQuests.Quests
		else
			questsData = profileData.WeeklyQuests.Quests
		end

		if not questsData or not questsData[questNum] then
			return false
		end

		quest = questsData[questNum]
		questName = quest.Name
		questDef = QuestDefinitions[questType][questName]
	else
		warn("Unknown quest type:", questType)
		return false
	end

	if not quest or not questDef then
		return false
	end

	-- Check if already completed
	if quest.Completed then
		return false
	end

	-- Check if all tasks completed (multi-task support)
	if not QuestProgressHandler.AreAllTasksCompleted(quest) then
		return false
	end

	-- Mark as completed
	quest.Completed = true

	-- Save completion status
	if questType == "SideQuest" then
		ProfileService:ChangeData(player, { "SideQuests" }, profileData.SideQuests)
	elseif questType == "Daily" then
		ProfileService:ChangeData(player, { "DailyQuests" }, profileData.DailyQuests)
	else
		ProfileService:ChangeData(player, { "WeeklyQuests" }, profileData.WeeklyQuests)
	end

	-- Calculate and grant rewards
	local exp, cash = QuestRewards.CalculateRewards(player, questType, questNum, questDef.Rewards)
	local rewardSuccess, rewards = QuestRewards.GrantRewards(player, exp, cash)

	if rewardSuccess then
		-- Notify player
		QuestRewards.NotifyPlayer(player, questType, exp, cash)

		-- Fire client signal for quest completion
		if QuestService and QuestService.Client.QuestCompleted then
			QuestService.Client.QuestCompleted:Fire(player, questType, questNum, rewards)
		end

		-- Untrack the quest after completion (player must manually track again to repeat)
		ProfileService:ChangeData(player, { "CurrentSideQuestTracked" }, {
			QuestType = nil,
			QuestNum = nil,
		})

		return true
	else
		warn("Failed to grant rewards for quest:", questType, questNum, quest.Name)
		return false
	end
end

--[[
	⭐ NEW: Spawn quest objectives for multi-task quests
	Dynamically loads appropriate handler for each task
	@param player Player
	@param questType string
	@param questNum number/string
	@param questDetail table - Quest definition
	@param playerData table - Player's quest data
]]
function SideQuestBase:SpawnQuestObjectives(player, questType, questNum, questDetail, playerData)
	-- Get reference to quest handler modules folder
	local ServerScriptService = game:GetService("ServerScriptService")
	local QuestServiceFolder = ServerScriptService:WaitForChild("ServerSource", 10).Server.QuestService
	local TriggeredQuestTypes = QuestServiceFolder.Components.Others.TriggeredQuest.Types

	-- Validate Tasks array
	if not questDetail.Tasks then
		warn("Quest missing Tasks array:", questDetail.Name)
		return
	end

	-- Determine which tasks to spawn based on mode
	local tasksToSpawn = {}

	if questDetail.TaskMode == "Sequential" then
		-- Only spawn objectives for current active task
		local activeTaskIndex = QuestProgressHandler.GetActiveTaskIndex(playerData, questDetail)

		if activeTaskIndex then
			table.insert(tasksToSpawn, activeTaskIndex)
		end
	else
		-- Parallel mode: Spawn objectives for all incomplete tasks
		for taskIndex, taskDef in ipairs(questDetail.Tasks) do
			local taskData = playerData.Tasks[taskIndex]

			if taskData and not taskData.Completed then
				table.insert(tasksToSpawn, taskIndex)
			end
		end
	end

	-- ⭐ DYNAMIC HANDLER LOADING: Load appropriate handler for each task
	for _, taskIndex in ipairs(tasksToSpawn) do
		local taskDef = questDetail.Tasks[taskIndex]

		if taskDef.ServerSideQuestName then
			-- Load task-specific handler module
			local questModule = TriggeredQuestTypes:FindFirstChild(taskDef.ServerSideQuestName)

			if questModule then
				local taskHandler = require(questModule)

				-- Call task-specific spawn method
				if taskHandler.SpawnObjectivesForTask then
					taskHandler:SpawnObjectivesForTask(player, questType, questNum, taskIndex, taskDef)
				else
					warn(
						string.format(
							"Handler '%s' doesn't implement SpawnObjectivesForTask method",
							taskDef.ServerSideQuestName
						)
					)
				end
			else
				warn(string.format("Task handler module not found: %s", taskDef.ServerSideQuestName))
			end
		else
			-- Task has no ServerSideQuestName - passive tracking only
			-- No objectives to spawn
		end
	end
end

--[[
	Abstract methods - Must be implemented by subclasses
]]
function SideQuestBase:CheckQuestProgress(player, questType, questNum)
	error("Must implement CheckQuestProgress() in subclass")
end

--[[
	Cleanup when quest ends
	@param player Player
]]
function SideQuestBase:CleanUp(player)
	self.IsChecking[player] = nil

	-- NEW: Multi-task cleanup
	if self.SpawnedItems and self.SpawnedItems[player] then
		-- Iterate through all tasks
		for taskIndex, taskItems in pairs(self.SpawnedItems[player]) do
			-- Cleanup items for this specific task
			for _, itemData in pairs(taskItems) do
				if itemData.Item and itemData.Item.Parent then
					itemData.Item:Destroy()
				end
			end
		end

		self.SpawnedItems[player] = nil
	end
end

--[[
	⭐ NEW: Cleanup specific task (when task completed in sequential mode)
	@param player Player
	@param taskIndex number
]]
function SideQuestBase:CleanUpTask(player, taskIndex)
	if not self.SpawnedItems or not self.SpawnedItems[player] or not self.SpawnedItems[player][taskIndex] then
		return
	end

	-- Cleanup only this task's items
	for _, itemData in pairs(self.SpawnedItems[player][taskIndex]) do
		if itemData.Item and itemData.Item.Parent then
			itemData.Item:Destroy()
		end
	end

	self.SpawnedItems[player][taskIndex] = nil
end

-- Initialize ProfileService reference
function SideQuestBase.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")

	-- Load QuestRewards component
	local ServerScriptService = game:GetService("ServerScriptService")
	local QuestServiceFolder = ServerScriptService:WaitForChild("ServerSource", 10).Server.QuestService
	local CoreFolder = QuestServiceFolder.Components.Others.Core
	QuestRewards = require(CoreFolder.QuestRewards)
	QuestProgressHandler = require(CoreFolder.QuestProgressHandler)
end

return SideQuestBase
