--[[
	QuestProgressHandler.lua
	
	Centralized utility for managing quest progress across all quest types.
	Eliminates code duplication by providing a unified interface for:
	- Getting quest data and definitions
	- Incrementing quest progress
	- Saving quest progress
	
	⭐ MULTI-TASK SUPPORT:
	- IncrementTaskProgress: Increment progress for specific task
	- SetTaskProgress: Set progress for specific task
	- AreAllTasksCompleted: Check if all tasks in quest are done
	- GetActiveTaskIndex: Get current active task for sequential quests
	
	Supports: Main, Daily, Weekly, and SideQuest types
	
	Usage:
	local QuestProgressHandler = require(...)
	local success = QuestProgressHandler.IncrementTaskProgress(player, questType, questNum, taskIndex, amount)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService
local QuestService

local QuestProgressHandler = {}

--========================================
-- QUEST TYPE CONFIGURATIONS
--========================================

--[[
	Quest type configuration table.
	Each quest type defines how to:
	- Get quest data from profile
	- Get quest definition
	- Save quest progress
]]
local QuestTypeConfig = {
	SideQuest = {
		getQuest = function(profileData, questIdentifier)
			-- For SideQuest, questIdentifier is the quest name
			local questName = questIdentifier

			-- Initialize quest progress if it doesn't exist
			if not profileData.SideQuests[questName] then
				-- Get quest definition to initialize task structure
				local questDef = QuestDefinitions.SideQuest[questName]
				if questDef and questDef.Tasks then
					-- Initialize with Tasks array structure
					local tasks = {}
					for taskIndex, taskDef in ipairs(questDef.Tasks) do
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
					-- Fallback (should not happen if all quests follow new structure)
					warn("SideQuest missing Tasks array:", questName)
					profileData.SideQuests[questName] = {
						Name = questName,
						Progress = 0,
						Completed = false,
					}
				end
			end

			local quest = profileData.SideQuests[questName]
			local questDef = QuestDefinitions.SideQuest[questName]

			return quest, questDef
		end,

		saveQuest = function(player, profileData)
			ProfileService:ChangeData(player, { "SideQuests" }, profileData.SideQuests)
		end,
	},

	Daily = {
		getQuest = function(profileData, questIdentifier)
			-- For Daily, questIdentifier is the quest index
			local questNum = questIdentifier
			local questsData = profileData.DailyQuests.Quests

			if not questsData or not questsData[questNum] then
				return nil, nil
			end

			local quest = questsData[questNum]
			local questDef = QuestDefinitions.Daily[quest.Name]

			return quest, questDef
		end,

		saveQuest = function(player, profileData)
			ProfileService:ChangeData(player, { "DailyQuests" }, profileData.DailyQuests)
		end,
	},

	Weekly = {
		getQuest = function(profileData, questIdentifier)
			-- For Weekly, questIdentifier is the quest index
			local questNum = questIdentifier
			local questsData = profileData.WeeklyQuests.Quests

			if not questsData or not questsData[questNum] then
				return nil, nil
			end

			local quest = questsData[questNum]
			local questDef = QuestDefinitions.Weekly[quest.Name]

			return quest, questDef
		end,

		saveQuest = function(player, profileData)
			ProfileService:ChangeData(player, { "WeeklyQuests" }, profileData.WeeklyQuests)
		end,
	},

	-- Future quest types can be added here without changing existing code
	-- Example:
	-- Event = {
	--     getQuest = function(profileData, questIdentifier) ... end,
	--     saveQuest = function(player, profileData) ... end,
	-- },
}

--========================================
-- PUBLIC API
--========================================

--[[
	Get quest data and definition for any quest type
	@param player Player
	@param questType string - "Main", "Daily", "Weekly", "SideQuest", etc.
	@param questIdentifier number|string - Quest number/index or quest name (depends on type)
	@return table|nil, table|nil - quest data, quest definition (or nil, nil if not found)
]]
function QuestProgressHandler.GetQuest(player, questType, questIdentifier)
	-- Get profile data
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("QuestProgressHandler: No profile data for player", player.Name)
		return nil, nil
	end

	-- Get configuration for this quest type
	local config = QuestTypeConfig[questType]
	if not config then
		warn("QuestProgressHandler: Unknown quest type:", questType)
		return nil, nil
	end

	-- Get quest using type-specific logic
	local quest, questDef = config.getQuest(profileData, questIdentifier)

	if not quest then
		warn(
			string.format(
				"QuestProgressHandler: Quest not found - Type: %s, Identifier: %s",
				questType,
				tostring(questIdentifier)
			)
		)
		return nil, nil
	end

	if not questDef then
		warn(
			string.format(
				"QuestProgressHandler: Quest definition not found - Type: %s, Identifier: %s",
				questType,
				tostring(questIdentifier)
			)
		)
		return nil, nil
	end

	return quest, questDef
end

--[[
	Register a new quest type configuration (for extensibility)
	@param questType string - Name of the new quest type
	@param config table - Configuration with getQuest and saveQuest functions
]]
function QuestProgressHandler.RegisterQuestType(questType, config)
	if QuestTypeConfig[questType] then
		warn("QuestProgressHandler: Quest type already registered:", questType)
		return false
	end

	if not config.getQuest or not config.saveQuest then
		warn("QuestProgressHandler: Invalid config - must have getQuest and saveQuest functions")
		return false
	end

	QuestTypeConfig[questType] = config
	return true
end

--========================================
-- MULTI-TASK QUEST SUPPORT
--========================================

--[[
	Get quest data directly from profile (utility method)
	@param profileData table - Player's profile data
	@param questType string
	@param questNum number|string - Quest index or name
	@return table|nil - Quest data or nil
]]
function QuestProgressHandler.GetQuestData(profileData, questType, questNum)
	if questType == "SideQuest" then
		return profileData.SideQuests[questNum]
	elseif questType == "Daily" then
		return profileData.DailyQuests.Quests[questNum]
	elseif questType == "Weekly" then
		return profileData.WeeklyQuests.Quests[questNum]
	end
	return nil
end

--[[
	Increment progress for a specific task in a multi-task quest
	@param player Player
	@param questType string - "Daily", "Weekly", or "SideQuest"
	@param questNum number|string - Quest index or name
	@param taskIndex number - Task index (1-based)
	@param amount number - Amount to increment
	@return boolean - Success status
]]
function QuestProgressHandler.IncrementTaskProgress(player, questType, questNum, taskIndex, amount)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return false
	end

	-- Get configuration for this quest type
	local config = QuestTypeConfig[questType]
	if not config then
		warn("QuestProgressHandler: Unknown quest type:", questType)
		return false
	end

	-- Get quest data
	local quest, questDef = config.getQuest(profileData, questNum)
	if not quest or not questDef then
		return false
	end

	-- Validate Tasks array exists
	if not quest.Tasks or not questDef.Tasks then
		warn("QuestProgressHandler: Quest missing Tasks array:", quest.Name)
		return false
	end

	-- Validate task index
	if taskIndex < 1 or taskIndex > #quest.Tasks then
		warn("Invalid task index:", taskIndex, "for quest:", quest.Name)
		return false
	end

	local task = quest.Tasks[taskIndex]
	local taskDef = questDef.Tasks[taskIndex]

	-- Increment progress
	task.Progress = math.min(task.Progress + amount, taskDef.MaxProgress)

	-- Check if task just completed (was not completed before, but is now)
	local wasCompleted = task.Completed
	if task.Progress >= taskDef.MaxProgress and not task.Completed then
		task.Completed = true
	end

	-- Save progress
	config.saveQuest(player, profileData)

	-- Fire task progress signal to client
	if QuestService and QuestService.Client.TaskProgressUpdated then
		QuestService.Client.TaskProgressUpdated:Fire(
			player,
			questType,
			questNum,
			taskIndex,
			task.Progress,
			taskDef.MaxProgress,
			task.Completed
		)
	end

	-- Handle task completion (only fire once when task completes)
	if task.Completed and not wasCompleted then
		-- Check if all tasks completed
		local allTasksCompleted = QuestProgressHandler.AreAllTasksCompleted(quest)

		-- Fire task completed signal
		if QuestService and QuestService.Client.TaskCompleted then
			QuestService.Client.TaskCompleted:Fire(player, questType, questNum, taskIndex, allTasksCompleted)
		end

		-- For sequential mode, unlock and spawn next task
		if questDef.TaskMode == "Sequential" then
			local nextTaskIndex = taskIndex + 1
			if quest.Tasks[nextTaskIndex] and not quest.Tasks[nextTaskIndex].Completed then
				-- Fire task unlocked signal
				if QuestService and QuestService.Client.TaskUnlocked then
					QuestService.Client.TaskUnlocked:Fire(player, questType, questNum, nextTaskIndex)
				end

				-- Get reference to quest handler modules folder
				local ServerScriptService = game:GetService("ServerScriptService")
				local QuestServiceFolder = ServerScriptService:WaitForChild("ServerSource", 10).Server.QuestService
				local TriggeredQuestTypes = QuestServiceFolder.Components.Others.TriggeredQuest.Types

				-- Clean up previous task's spawned items from its handler
				local prevTaskDef = questDef.Tasks[taskIndex]
				if prevTaskDef.ServerSideQuestName then
					local prevQuestModule = TriggeredQuestTypes:FindFirstChild(prevTaskDef.ServerSideQuestName)
					if prevQuestModule then
						local prevTaskHandler = require(prevQuestModule)
						if prevTaskHandler.CleanUpTask then
							prevTaskHandler:CleanUpTask(player, taskIndex)
						end
					end
				end

				-- Spawn next task's objectives
				local nextTaskDef = questDef.Tasks[nextTaskIndex]
				if nextTaskDef.ServerSideQuestName then
					-- Load task-specific handler
					local questModule = TriggeredQuestTypes:FindFirstChild(nextTaskDef.ServerSideQuestName)

					if questModule then
						local taskHandler = require(questModule)

						-- Call task-specific spawn method
						if taskHandler.SpawnObjectivesForTask then
							taskHandler:SpawnObjectivesForTask(player, questType, questNum, nextTaskIndex, nextTaskDef)
						else
							warn(
								string.format(
									"Handler '%s' doesn't implement SpawnObjectivesForTask method",
									nextTaskDef.ServerSideQuestName
								)
							)
						end
					else
						warn(string.format("Task handler module not found: %s", nextTaskDef.ServerSideQuestName))
					end
				end
			end
		end
	end

	return true
end

--[[
	Set progress for a specific task
	@param player Player
	@param questType string
	@param questNum number|string
	@param taskIndex number
	@param newProgress number
	@return boolean
]]
function QuestProgressHandler.SetTaskProgress(player, questType, questNum, taskIndex, newProgress)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return false
	end

	-- Get configuration for this quest type
	local config = QuestTypeConfig[questType]
	if not config then
		return false
	end

	-- Get quest data
	local quest, questDef = config.getQuest(profileData, questNum)
	if not quest or not questDef then
		return false
	end

	-- Validate task index
	if not quest.Tasks or taskIndex < 1 or taskIndex > #quest.Tasks then
		return false
	end

	local task = quest.Tasks[taskIndex]
	local taskDef = questDef.Tasks[taskIndex]

	-- Set progress
	task.Progress = math.min(math.max(newProgress, 0), taskDef.MaxProgress)

	-- Update completion status
	task.Completed = task.Progress >= taskDef.MaxProgress

	-- Save
	config.saveQuest(player, profileData)

	return true
end

--[[
	Check if all tasks in a quest are completed
	@param quest table - Player's quest data
	@return boolean
]]
function QuestProgressHandler.AreAllTasksCompleted(quest)
	if not quest or not quest.Tasks then
		return false
	end

	-- Check all tasks
	for _, task in ipairs(quest.Tasks) do
		if not task.Completed then
			return false
		end
	end

	return true
end

--[[
	Get the current active task for sequential quests
	@param quest table - Player's quest data
	@param questDef table - Quest definition
	@return number|nil - Task index, or nil if no active task
]]
function QuestProgressHandler.GetActiveTaskIndex(quest, questDef)
	if not quest or not quest.Tasks then
		return nil
	end

	-- Check if sequential mode
	if questDef.TaskMode ~= "Sequential" then
		return nil -- All tasks active in parallel mode
	end

	-- Find first incomplete task
	for i, task in ipairs(quest.Tasks) do
		if not task.Completed then
			return i
		end
	end

	return nil -- All tasks completed
end

--========================================
-- INITIALIZATION
--========================================

function QuestProgressHandler.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")
end

return QuestProgressHandler
