--[[
	PassiveQuestMonitor.lua
	
	Monitors game events and automatically updates progress for passive quests.
	Listens to various game services and increments quest progress accordingly.
	
	Features:
	- Lazy event registration (only register events that have active passive quests)
	- Progress throttling to avoid spam
	- Notification management
	- Quest completion detection
	- Filter function support for conditional progress
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PassiveQuestMonitor = {}

---- Module State
local RegisteredListeners = {} -- { [eventType] = connection }
local LastNotificationTime = {} -- { [player][questType_questNum] = timestamp }
local ActiveEventTypes = {} -- Cache of active event types

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local GameSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Event Mappings
local EventMappings = require(script.EventMappings)

---- Knit Services
local ProfileService
local QuestService

---- Components
local QuestProgressHandler
local QuestRewards

--[[
	Refresh event listeners based on currently active passive quests
	Only registers listeners for events that have active passive quests
]]
function PassiveQuestMonitor.RefreshEventListeners()
	local activeEvents = PassiveQuestMonitor.GetActiveEventTypes()

	-- Register new event listeners
	for _, eventType in ipairs(activeEvents) do
		if not RegisteredListeners[eventType] then
			PassiveQuestMonitor.RegisterEventListener(eventType)
		end
	end

	ActiveEventTypes = activeEvents
end

--[[
	Get all event types that have active passive quests
	Scans all players' daily/weekly quests
	@return table - Array of event type strings
]]
function PassiveQuestMonitor.GetActiveEventTypes()
	local events = {}
	local addedEvents = {}

	-- Scan quest definitions (not player data) to find all passive quest events
	-- This is more efficient than scanning all players

	-- Daily quests
	for questName, questDef in pairs(QuestDefinitions.Daily) do
		if questDef.TrackingMode == "Passive" and questDef.Tasks then
			-- Iterate through tasks to find all ProgressEvent types
			for _, taskDef in ipairs(questDef.Tasks) do
				if taskDef.ProgressEvent and not addedEvents[taskDef.ProgressEvent] then
					table.insert(events, taskDef.ProgressEvent)
					addedEvents[taskDef.ProgressEvent] = true
				end
			end
		end
	end

	-- Weekly quests
	for questName, questDef in pairs(QuestDefinitions.Weekly) do
		if questDef.TrackingMode == "Passive" and questDef.Tasks then
			-- Iterate through tasks to find all ProgressEvent types
			for _, taskDef in ipairs(questDef.Tasks) do
				if taskDef.ProgressEvent and not addedEvents[taskDef.ProgressEvent] then
					table.insert(events, taskDef.ProgressEvent)
					addedEvents[taskDef.ProgressEvent] = true
				end
			end
		end
	end

	return events
end

--[[
	Register an event listener for a specific event type
	@param eventType string - The ProgressEvent name from quest definition
]]
function PassiveQuestMonitor.RegisterEventListener(eventType)
	local mapping = EventMappings[eventType]

	if not mapping then
		warn("PassiveQuestMonitor: No event mapping found for:", eventType)
		return
	end

	-- Get the service
	local success, service = pcall(function()
		return Knit.GetService(mapping.ServiceName)
	end)

	if not success or not service then
		warn("PassiveQuestMonitor: Service not found:", mapping.ServiceName)
		return
	end

	-- Check if signal exists
	if not service[mapping.SignalName] then
		warn("PassiveQuestMonitor: Signal not found:", mapping.ServiceName .. "." .. mapping.SignalName)
		return
	end

	-- Connect to the signal
	local connection = service[mapping.SignalName]:Connect(function(...)
		local eventData = mapping.DataMapper(...)
		if eventData and eventData.Player then
			PassiveQuestMonitor.ProcessEvent(eventData.Player, eventType, eventData)
		end
	end)

	RegisteredListeners[eventType] = connection
end

--[[
	Process a game event and update matching passive quests
	@param player Player - The player who triggered the event
	@param eventType string - The event type (e.g., "EnemyKilled")
	@param eventData table - Event-specific data
]]
function PassiveQuestMonitor.ProcessEvent(player, eventType, eventData)
	-- Get player profile
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	-- Find and update matching daily quests
	if profileData.DailyQuests and profileData.DailyQuests.Quests then
		for questIndex, playerQuest in ipairs(profileData.DailyQuests.Quests) do
			-- Skip if quest is already completed
			if not playerQuest.Completed then
				local questDef = QuestDefinitions.Daily[playerQuest.Name]

				if questDef and questDef.TrackingMode == "Passive" and questDef.Tasks then
					-- Iterate through tasks to find matching event
					for taskIndex, taskDef in ipairs(questDef.Tasks) do
						local taskData = playerQuest.Tasks and playerQuest.Tasks[taskIndex]

						-- Check if this task listens to this event and is not completed
						if taskDef.ProgressEvent == eventType and taskData and not taskData.Completed then
							-- Check if task passes filter
							if PassiveQuestMonitor.PassesTaskFilter(taskDef, eventData) then
								PassiveQuestMonitor.IncrementTaskProgress(
									player,
									"Daily",
									questIndex,
									taskIndex,
									playerQuest.Name,
									questDef,
									taskDef,
									eventData
								)
							end
						end
					end
				end
			end
		end
	end

	-- Find and update matching weekly quests
	if profileData.WeeklyQuests and profileData.WeeklyQuests.Quests then
		for questIndex, playerQuest in ipairs(profileData.WeeklyQuests.Quests) do
			-- Skip if quest is already completed
			if not playerQuest.Completed then
				local questDef = QuestDefinitions.Weekly[playerQuest.Name]

				if questDef and questDef.TrackingMode == "Passive" and questDef.Tasks then
					-- Iterate through tasks to find matching event
					for taskIndex, taskDef in ipairs(questDef.Tasks) do
						local taskData = playerQuest.Tasks and playerQuest.Tasks[taskIndex]

						-- Check if this task listens to this event and is not completed
						if taskDef.ProgressEvent == eventType and taskData and not taskData.Completed then
							-- Check if task passes filter
							if PassiveQuestMonitor.PassesTaskFilter(taskDef, eventData) then
								PassiveQuestMonitor.IncrementTaskProgress(
									player,
									"Weekly",
									questIndex,
									taskIndex,
									playerQuest.Name,
									questDef,
									taskDef,
									eventData
								)
							end
						end
					end
				end
			end
		end
	end
end

--[[
	Check if event data passes the task's filter function
	@param taskDef table - Task definition
	@param eventData table - Event data
	@return boolean - True if passes filter (or no filter exists)
]]
function PassiveQuestMonitor.PassesTaskFilter(taskDef, eventData)
	if not taskDef.ProgressFilter then
		return true -- No filter = always pass
	end

	-- Execute filter function
	local success, result = pcall(taskDef.ProgressFilter, eventData)
	if not success then
		warn("PassiveQuestMonitor: Filter function error for task:", result)
		return true -- On error, allow progress
	end

	return result == true
end

--[[
	Increment task progress for a passive quest
	@param player Player
	@param questType string - "Daily" or "Weekly"
	@param questIndex number - Quest index in array
	@param taskIndex number - Task index in quest
	@param questName string - Quest name
	@param questDef table - Quest definition
	@param taskDef table - Task definition
	@param eventData table - Event data
]]
function PassiveQuestMonitor.IncrementTaskProgress(
	player,
	questType,
	questIndex,
	taskIndex,
	questName,
	questDef,
	taskDef,
	eventData
)
	-- Determine increment amount
	local amount = eventData.Amount or 1

	-- Use task-based progress handler
	local success = QuestProgressHandler.IncrementTaskProgress(player, questType, questIndex, taskIndex, amount)

	if not success then
		return
	end

	-- Get updated progress
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	local questData = questType == "Daily" and profileData.DailyQuests.Quests[questIndex]
		or profileData.WeeklyQuests.Quests[questIndex]

	if not questData or not questData.Tasks or not questData.Tasks[taskIndex] then
		return
	end

	local taskData = questData.Tasks[taskIndex]

	-- Fire client signal for UI update (task-specific)
	if QuestService.Client.TaskProgressUpdated then
		QuestService.Client.TaskProgressUpdated:Fire(
			player,
			questType,
			questIndex,
			taskIndex,
			taskData.Progress,
			taskDef.MaxProgress,
			taskData.Completed
		)
	end

	-- Show notification if appropriate
	if PassiveQuestMonitor.ShouldNotifyTaskProgress(player, questType, questIndex, taskIndex, questDef, taskDef) then
		local NotifierService = Knit.GetService("NotifierService")
		NotifierService:NotifyPlayer(player, {
			MessageType = "Normal Notification",
			Message = string.format(
				"Quest Progress: %s - %s (%d/%d)",
				questDef.DisplayName,
				taskDef.Description or ("Task " .. taskIndex),
				taskData.Progress,
				taskDef.MaxProgress
			),
			TextColor = Color3.fromRGB(255, 200, 100),
			Duration = 3,
		})
	end

	-- Check if all tasks completed
	if QuestProgressHandler.AreAllTasksCompleted(questData) and not questData.Completed then
		PassiveQuestMonitor.CompleteQuest(player, questType, questIndex, questName, questDef)
	end
end

--[[
	Complete a passive quest
	@param player Player
	@param questType string - "Daily" or "Weekly"
	@param questIndex number - Quest index
	@param questName string - Quest name
	@param questDef table - Quest definition
]]
function PassiveQuestMonitor.CompleteQuest(player, questType, questIndex, questName, questDef)
	-- Mark as completed
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	local questsData = questType == "Daily" and profileData.DailyQuests or profileData.WeeklyQuests
	if not questsData.Quests[questIndex] then
		return
	end

	questsData.Quests[questIndex].Completed = true

	-- Save to profile
	local pathKey = questType == "Daily" and "DailyQuests" or "WeeklyQuests"
	ProfileService:ChangeData(player, { pathKey }, questsData)

	-- Calculate and grant rewards
	local exp, cash = QuestRewards.CalculateRewards(player, questType, questIndex, questDef.Rewards)
	local rewardSuccess, rewards = QuestRewards.GrantRewards(player, exp, cash)

	if rewardSuccess then
		-- Fire completion signal
		QuestService.Client.QuestCompleted:Fire(player, questType, questIndex, rewards)

		-- Show completion notification
		local NotifierService = Knit.GetService("NotifierService")
		NotifierService:NotifyPlayer(player, {
			MessageType = "Normal Notification",
			Message = string.format("Quest Complete: %s! +%d EXP, +%d Cash", questDef.DisplayName, exp, cash),
			TextColor = Color3.fromRGB(120, 255, 120),
			Duration = 5,
		})
	else
		warn("Failed to grant rewards for passive quest:", questType, questName)
	end
end

--[[
	Check if should show progress notification (throttled) for a specific task
	@param player Player
	@param questType string
	@param questIndex number
	@param taskIndex number
	@param questDef table
	@param taskDef table
	@return boolean
]]
function PassiveQuestMonitor.ShouldNotifyTaskProgress(player, questType, questIndex, taskIndex, questDef, taskDef)
	-- Get config from task definition, fallback to quest definition, then defaults
	local passiveConfig = taskDef.PassiveConfig or questDef.PassiveConfig or {}
	local showNotifications = passiveConfig.ShowProgressNotifications
	if showNotifications == nil then
		showNotifications = GameSettings.DailyAndWeeklyQuests.PassiveQuestDefaults.ShowProgressNotifications
	end

	if not showNotifications then
		return false
	end

	-- Check throttle
	local throttle = passiveConfig.NotificationThrottle
		or GameSettings.DailyAndWeeklyQuests.PassiveQuestDefaults.NotificationThrottle

	-- Use task-specific key for throttling
	local key = questType .. "_" .. questIndex .. "_" .. taskIndex
	if not LastNotificationTime[player] then
		LastNotificationTime[player] = {}
	end

	local lastTime = LastNotificationTime[player][key] or 0
	local currentTime = tick()

	if currentTime - lastTime >= throttle then
		LastNotificationTime[player][key] = currentTime
		return true
	end

	return false
end

--[[
	Component initialization (called automatically)
]]
function PassiveQuestMonitor.Init()
	-- Get Knit services
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")

	-- Access Core components through QuestService instance
	local CoreFolder = QuestService.Instance.Components.Others.Core

	QuestProgressHandler = require(CoreFolder.QuestProgressHandler)
	QuestRewards = require(CoreFolder.QuestRewards)
end

--[[
	Component start (called automatically after all Init())
]]
function PassiveQuestMonitor.Start()
	-- Register event listeners for currently active event types
	PassiveQuestMonitor.RefreshEventListeners()

	-- Listen for player removal to cleanup notification timestamps
	Players.PlayerRemoving:Connect(function(player)
		LastNotificationTime[player] = nil
	end)
end

return PassiveQuestMonitor
