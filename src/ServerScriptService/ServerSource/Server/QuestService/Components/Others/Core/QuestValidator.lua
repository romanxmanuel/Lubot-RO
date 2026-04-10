--[[
	QuestValidator.lua
	
	Validates quest data integrity at startup and runtime.
	Catches configuration errors before they cause player-facing bugs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestValidator = {}

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local GameSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService

--[[
	Validate all quest data on server startup
	Throws error if validation fails
]]
function QuestValidator.ValidateAllQuestData()
	local errors = {}
	local warnings = {}

	-- Validate Main Quests
	for i, quest in ipairs(QuestDefinitions.Main) do
		local ok, err = pcall(function()
			QuestValidator.ValidateMainQuest(i, quest)
		end)
		if not ok then
			table.insert(errors, "Main Quest " .. i .. ": " .. err)
		end
	end

	-- Validate Daily Quests
	for questName, quest in pairs(QuestDefinitions.Daily) do
		local ok, err = pcall(function()
			QuestValidator.ValidateSideQuest("Daily", questName, quest)
		end)
		if not ok then
			table.insert(errors, "Daily Quest '" .. questName .. "': " .. err)
		end
	end

	-- Validate Weekly Quests
	for questName, quest in pairs(QuestDefinitions.Weekly) do
		local ok, err = pcall(function()
			QuestValidator.ValidateSideQuest("Weekly", questName, quest)
		end)
		if not ok then
			table.insert(errors, "Weekly Quest '" .. questName .. "': " .. err)
		end
	end

	-- Check quest pool sizes
	local dailyCount = 0
	for _ in pairs(QuestDefinitions.Daily) do
		dailyCount = dailyCount + 1
	end

	local weeklyCount = 0
	for _ in pairs(QuestDefinitions.Weekly) do
		weeklyCount = weeklyCount + 1
	end

	if GameSettings.Validation.WarnOnSmallQuestPool then
		if dailyCount < GameSettings.DailyAndWeeklyQuests.DailyMax then
			table.insert(
				warnings,
				string.format(
					"Only %d daily quests defined but DailyMax is %d. Players may get duplicate quests!",
					dailyCount,
					GameSettings.DailyAndWeeklyQuests.DailyMax
				)
			)
		end

		if weeklyCount < GameSettings.DailyAndWeeklyQuests.WeeklyMax then
			table.insert(
				warnings,
				string.format(
					"Only %d weekly quests defined but WeeklyMax is %d. Players may get duplicate quests!",
					weeklyCount,
					GameSettings.DailyAndWeeklyQuests.WeeklyMax
				)
			)
		end
	end

	-- Print warnings (non-blocking)
	if #warnings > 0 then
		warn("Quest Data Warnings:")
		for _, warning in ipairs(warnings) do
			warn("   " .. warning)
		end
	end

	-- Throw errors (blocking)
	if #errors > 0 then
		error("Quest Data Validation Failed:\n" .. table.concat(errors, "\n"))
	end
end

--[[
	Validate a main quest definition
	@param questNum number
	@param quest table
]]
function QuestValidator.ValidateMainQuest(questNum, quest)
	assert(quest, "Quest is nil")
	assert(
		quest.QuestNum == questNum,
		"QuestNum mismatch: expected " .. questNum .. ", got " .. tostring(quest.QuestNum)
	)
	assert(quest.Title, "Missing Title")
	assert(quest.Description, "Missing Description")
	assert(quest.Rewards, "Missing Rewards")
	assert(quest.Rewards.EXP, "Missing EXP reward")
	assert(quest.Rewards.Cash, "Missing Cash reward")
	assert(quest.Tasks, "Missing Tasks")
	assert(#quest.Tasks > 0, "Must have at least 1 task")

	for i, task in ipairs(quest.Tasks) do
		assert(task.Description, "Task " .. i .. " missing Description")
		assert(task.MaxProgress, "Task " .. i .. " missing MaxProgress")
		assert(type(task.MaxProgress) == "number", "Task " .. i .. " MaxProgress must be number")
	end
end

--[[
	Validate a side quest (Daily/Weekly) definition
	⭐ UPDATED: Now validates Tasks array structure instead of quest-level MaxProgress
	@param questType string
	@param questName string
	@param quest table
]]
function QuestValidator.ValidateSideQuest(questType, questName, quest)
	assert(quest, "Quest is nil")
	assert(quest.Name == questName, "Quest name mismatch")
	assert(quest.DisplayName, "Missing DisplayName")
	assert(quest.Description, "Missing Description")

	-- ⭐ MULTI-TASK SUPPORT: Validate Tasks array instead of quest-level MaxProgress
	assert(quest.Tasks, "Missing Tasks array (required for multi-task support)")
	assert(type(quest.Tasks) == "table", "Tasks must be a table")
	assert(#quest.Tasks > 0, "Tasks array must have at least 1 task")

	-- Validate TaskMode
	assert(quest.TaskMode, "Missing TaskMode (required: 'Sequential' or 'Parallel')")
	assert(
		quest.TaskMode == "Sequential" or quest.TaskMode == "Parallel",
		"TaskMode must be 'Sequential' or 'Parallel', got: " .. tostring(quest.TaskMode)
	)

	-- Validate each task
	for i, task in ipairs(quest.Tasks) do
		assert(task.Description, "Task " .. i .. " missing Description")
		assert(task.MaxProgress, "Task " .. i .. " missing MaxProgress")
		assert(type(task.MaxProgress) == "number", "Task " .. i .. " MaxProgress must be number")
		assert(task.MaxProgress > 0, "Task " .. i .. " MaxProgress must be > 0")
	end

	assert(quest.Rewards, "Missing Rewards")
	assert(quest.Rewards.BaseEXP or quest.Rewards.EXP, "Missing EXP reward")
	assert(quest.Rewards.BaseCash or quest.Rewards.Cash, "Missing Cash reward")
	assert(quest.Image, "Missing Image")

	-- NEW: Validate TrackingMode field
	assert(quest.TrackingMode, "Missing TrackingMode field (must be 'Active' or 'Passive')")
	assert(
		quest.TrackingMode == "Active" or quest.TrackingMode == "Passive",
		"Invalid TrackingMode: '" .. tostring(quest.TrackingMode) .. "' (must be 'Active' or 'Passive')"
	)

	-- ⭐ MULTI-TASK VALIDATION: Validate task-level ServerSideQuestName if present
	-- Note: Not all tasks need ServerSideQuestName (some tasks are passive)
	local ComponentsFolder = script.Parent.Parent
	local TriggeredQuestTypes = ComponentsFolder.TriggeredQuest.Types

	for i, task in ipairs(quest.Tasks) do
		-- If task has ServerSideQuestName, validate the module exists
		if task.ServerSideQuestName then
			local moduleExists = TriggeredQuestTypes:FindFirstChild(task.ServerSideQuestName)
			assert(
				moduleExists,
				"Task "
					.. i
					.. " ServerSideQuestName '"
					.. task.ServerSideQuestName
					.. "' module not found in TriggeredQuest/Types/"
			)
		end

		-- Optional: Validate ProgressEvent for passive tracking
		if task.ProgressEvent then
			assert(type(task.ProgressEvent) == "string", "Task " .. i .. " ProgressEvent must be a string")
		end
	end
end

--[[
	Validate quest exists by name
	@param questType string
	@param questName string
	@return boolean, table | nil
]]
function QuestValidator.ValidateQuestExists(questType, questName)
	local quests = QuestDefinitions[questType]
	if not quests then
		return false, nil
	end

	if quests[questName] then
		return true, quests[questName]
	end

	return false, nil
end

--[[
	Find invalid quests in player's profile
	@param player Player
	@return table - Array of invalid quest info
]]
function QuestValidator.FindInvalidPlayerQuests(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return {}
	end

	local invalidQuests = {}

	-- Check daily quests
	if profileData.DailyQuests and profileData.DailyQuests.Quests then
		for i, playerQuest in ipairs(profileData.DailyQuests.Quests) do
			local exists = QuestValidator.ValidateQuestExists("Daily", playerQuest.Name)
			if not exists then
				table.insert(invalidQuests, {
					type = "Daily",
					index = i,
					name = playerQuest.Name,
				})
			end
		end
	end

	-- Check weekly quests
	if profileData.WeeklyQuests and profileData.WeeklyQuests.Quests then
		for i, playerQuest in ipairs(profileData.WeeklyQuests.Quests) do
			local exists = QuestValidator.ValidateQuestExists("Weekly", playerQuest.Name)
			if not exists then
				table.insert(invalidQuests, {
					type = "Weekly",
					index = i,
					name = playerQuest.Name,
				})
			end
		end
	end

	return invalidQuests
end

-- Initialize ProfileService reference
function QuestValidator.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return QuestValidator
