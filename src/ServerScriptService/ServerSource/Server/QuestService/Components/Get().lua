local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local GetComponent = {}

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local GameSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService

---- Components
local QuestScheduler

--[[
	GET COMPONENT - READ-ONLY QUERIES
	All methods here should be pure reads with no side effects
]]--

--[[
	@param player Player - The player to get quest progress for
	@param questType string - "Main", "Daily", or "Weekly"
	@param questNum number - Quest index (for Daily/Weekly) or QuestNum (for Main)
	@return table | nil - Quest progress data
]]--
function GetComponent:GetQuestProgress(player, questType, questNum)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return nil
	end
	
	if questType == "Main" then
		return profileData.MainQuests
	elseif questType == "Daily" then
		if profileData.DailyQuests and profileData.DailyQuests.Quests then
			return profileData.DailyQuests.Quests[questNum]
		end
	elseif questType == "Weekly" then
		if profileData.WeeklyQuests and profileData.WeeklyQuests.Quests then
			return profileData.WeeklyQuests.Quests[questNum]
		end
	end
	
	return nil
end

--[[
	@param player Player - The player to check
	@param questType string - "Main", "Daily", or "Weekly"
	@param questNum number - Quest index
	@return boolean - Whether the quest is complete
]]--
function GetComponent:IsQuestComplete(player, questType, questNum)
	local progress = self:GetQuestProgress(player, questType, questNum)
	if not progress then
		return false
	end
	
	if questType == "Main" then
		local questDetail = QuestDefinitions.Main[progress.QuestNum]
		if not questDetail then
			return false
		end
		
		for i, task in ipairs(questDetail.Tasks) do
			if not progress.Tasks[i] or progress.Tasks[i].Progress < task.MaxProgress then
				return false
			end
		end
		return true
	else
		return progress.Completed == true
	end
end

--[[
	@param player Player - The player to get quests for
	@return table - All active quests for the player
]]--
function GetComponent:GetActiveQuests(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return {
			Main = nil,
			Daily = {},
			Weekly = {},
			TrackedSideQuest = nil
		}
	end
	
	return {
		Main = profileData.MainQuests,
		Daily = profileData.DailyQuests.Quests or {},
		Weekly = profileData.WeeklyQuests.Quests or {},
		TrackedSideQuest = profileData.CurrentSideQuestTracked
	}
end

--[[
	@param questType string - "Main", "Daily", or "Weekly"
	@param questNum number | string - Quest number or name
	@return table | nil - Quest rewards
]]--
function GetComponent:GetQuestRewards(questType, questNum)
	if questType == "Main" then
		local questData = QuestDefinitions.Main[questNum]
		return questData and questData.Rewards
	elseif questType == "Daily" then
		local questData = QuestDefinitions.Daily[questNum]
		return questData and questData.Rewards
	elseif questType == "Weekly" then
		local questData = QuestDefinitions.Weekly[questNum]
		return questData and questData.Rewards
	end
	return nil
end

--[[
	@param player Player - The player to check
	@param questType string - "Daily" or "Weekly"
	@return number - Unix timestamp of next reset
]]--
function GetComponent:GetNextResetTime(player, questType)
	return QuestScheduler:GetNextResetTime(player, questType)
end

--[[
	@param player Player - The player to check
	@return boolean - Whether daily quests should reset
]]--
function GetComponent:ShouldResetDaily(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return false
	end
	
	local currentTime = workspace:GetServerTimeNow()
	local lastResetTime = profileData.DailyQuests.LastResetTime or 0
	local timeSinceReset = currentTime - lastResetTime
	
	return timeSinceReset >= GameSettings.DailyAndWeeklyQuests.DailyResetInterval
end

--[[
	@param player Player - The player to check
	@return boolean - Whether weekly quests should reset
]]--
function GetComponent:ShouldResetWeekly(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return false
	end
	
	local currentTime = workspace:GetServerTimeNow()
	local lastResetTime = profileData.WeeklyQuests.LastResetTime or 0
	local timeSinceReset = currentTime - lastResetTime
	
	return timeSinceReset >= GameSettings.DailyAndWeeklyQuests.WeeklyResetInterval
end

function GetComponent.Start()
	-- Component started
end

function GetComponent.Init()
	---- Knit Services
	ProfileService = Knit.GetService("ProfileService")
	
	---- Components
	local ComponentsFolder = script.Parent.Parent
	QuestScheduler = require(ComponentsFolder.Components.Others.Core.QuestScheduler)
end

return GetComponent
