--[[
	RecurringQuest/init.lua
	
	Base class for recurring quests (Daily/Weekly).
	Unifies shared reset logic and quest selection algorithms.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local GameSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService
local QuestService

---- Components
local QuestBase

local RecurringQuest = {}
RecurringQuest.__index = RecurringQuest

--[[
	Constructor
	@param questType string - "Daily" or "Weekly"
	@param resetInterval number - Seconds between resets
]]
function RecurringQuest.new(questType, resetInterval)
	if not QuestBase then
		-- Lazy load QuestBase if not initialized yet
		QuestService = QuestService or Knit.GetService("QuestService")
		QuestBase = require(QuestService.Instance.Components.Others.Core.QuestBase)
		-- Set up proper inheritance
		setmetatable(RecurringQuest, { __index = QuestBase })
	end

	local self = QuestBase.new(questType)
	setmetatable(self, RecurringQuest)
	self.ResetInterval = resetInterval
	return self
end

--[[
	Factory methods for Daily/Weekly quests
]]
function RecurringQuest.CreateDaily()
	local ONE_DAY_IN_SECONDS = GameSettings.DailyAndWeeklyQuests.DailyResetInterval
	return RecurringQuest.new("Daily", ONE_DAY_IN_SECONDS)
end

function RecurringQuest.CreateWeekly()
	local SEVEN_DAYS_IN_SECONDS = GameSettings.DailyAndWeeklyQuests.WeeklyResetInterval
	return RecurringQuest.new("Weekly", SEVEN_DAYS_IN_SECONDS)
end

--[[
	Check if quests should reset
	@param player Player
	@return boolean
]]
function RecurringQuest:ShouldReset(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return false
	end

	local questData = self:GetQuestDataFromProfile(profileData)
	local currentTime = workspace:GetServerTimeNow()
	local lastResetTime = questData.LastResetTime or 0
	local timeSinceReset = currentTime - lastResetTime

	return timeSinceReset >= self.ResetInterval
end

--[[
	Reset quests for the player
	@param player Player
]]
function RecurringQuest:Reset(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	local maxQuests = self:GetMaxQuests()

	local newQuests = {
		LastResetTime = workspace:GetServerTimeNow(),
		Quests = {},
	}

	-- Pick random unique quests
	for i = 1, maxQuests do
		local questName = self:PickRandomQuest(newQuests.Quests)
		if questName then
			-- Get quest definition to initialize task structure
			local questDef = QuestDefinitions[self.QuestType][questName]

			if questDef and questDef.Tasks then
				-- ⭐ MULTI-TASK SUPPORT: Initialize with Tasks array structure
				local tasks = {}
				for taskIndex, taskDef in ipairs(questDef.Tasks) do
					table.insert(tasks, {
						Description = taskDef.Description,
						Progress = 0,
						MaxProgress = taskDef.MaxProgress,
						Completed = false,
					})
				end

				table.insert(newQuests.Quests, {
					Name = questName,
					Completed = false,
					Tasks = tasks,
				})
			else
				-- Fallback for legacy structure (should not happen if all quests updated)
				warn(
					string.format(
						"%s quest '%s' missing Tasks array! Please update quest definition.",
						self.QuestType,
						questName
					)
				)
				table.insert(newQuests.Quests, {
					Name = questName,
					Progress = 0,
					Completed = false,
				})
			end
		else
			-- Not enough unique quests available
			if GameSettings.Validation.WarnOnSmallQuestPool then
				warn(
					string.format(
						"Not enough unique %s quests! Wanted %d, got %d. Add more quest definitions.",
						self.QuestType,
						maxQuests,
						i - 1
					)
				)
			end
			break
		end
	end

	-- Save to profile
	self:SaveQuestData(player, newQuests)
end

--[[
	Pick a random quest that isn't already in the list
	@param existingQuests table - Array of existing quest data
	@return string | nil - Quest name or nil if no more available
]]
function RecurringQuest:PickRandomQuest(existingQuests)
	local availableQuests = QuestDefinitions[self.QuestType]
	local questNames = {}

	-- Build list of quest names not already assigned
	for questName, quest in pairs(availableQuests) do
		if not self:IsQuestInList(questName, existingQuests) then
			-- Check requirements if they exist
			if self:MeetsRequirements(quest) then
				table.insert(questNames, questName)
			end
		end
	end

	if #questNames == 0 then
		return nil
	end

	return questNames[math.random(1, #questNames)]
end

--[[
	Check if a quest name is already in the list
	@param questName string
	@param questList table
	@return boolean
]]
function RecurringQuest:IsQuestInList(questName, questList)
	for _, quest in ipairs(questList) do
		if quest.Name == questName then
			return true
		end
	end
	return false
end

--[[
	Check if quest requirements are met (placeholder for future)
	@param quest table
	@return boolean
]]
function RecurringQuest:MeetsRequirements(quest)
	-- Future: Check MinLevel, MinRebirth, etc.
	return true
end

--[[
	Get quest data from profile
	@param profileData table
	@return table
]]
function RecurringQuest:GetQuestDataFromProfile(profileData)
	if self.QuestType == "Daily" then
		return profileData.DailyQuests
	elseif self.QuestType == "Weekly" then
		return profileData.WeeklyQuests
	end
	return {}
end

--[[
	Get max quests for this type
	@return number
]]
function RecurringQuest:GetMaxQuests()
	if self.QuestType == "Daily" then
		return GameSettings.DailyAndWeeklyQuests.DailyMax
	elseif self.QuestType == "Weekly" then
		return GameSettings.DailyAndWeeklyQuests.WeeklyMax
	end
	return 0
end

--[[
	Save quest data to profile
	@param player Player
	@param newQuests table
]]
function RecurringQuest:SaveQuestData(player, newQuests)
	if self.QuestType == "Daily" then
		ProfileService:ChangeData(player, { "DailyQuests" }, newQuests)
	elseif self.QuestType == "Weekly" then
		ProfileService:ChangeData(player, { "WeeklyQuests" }, newQuests)
	end
end

-- Implement quest methods
function RecurringQuest:StartQuest(player)
	-- Wait for ProfileService to be initialized (async)
	local maxWaitTime = 10
	local startTime = os.clock()
	while not ProfileService and (os.clock() - startTime) < maxWaitTime do
		task.wait(0.1)
	end

	if not ProfileService then
		warn(
			string.format(
				"RecurringQuest:StartQuest() - ProfileService not initialized for %s after %d seconds",
				player.Name,
				maxWaitTime
			)
		)
		return
	end

	-- Recurring quests are started via Reset()
	self:Reset(player)
end

function RecurringQuest:Complete(player)
	-- Individual quests within recurring quests are completed separately
	warn("RecurringQuest:Complete() should not be called directly")
end

function RecurringQuest:CheckProgress(player)
	return self:ShouldReset(player)
end

-- Initialize module
function RecurringQuest.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")
	QuestBase = require(QuestService.Instance.Components.Others.Core.QuestBase)

	-- Set up proper inheritance from QuestBase
	setmetatable(RecurringQuest, { __index = QuestBase })
end

return RecurringQuest
