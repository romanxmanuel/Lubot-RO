--[[
	QuestBase.lua
	
	Abstract base class for all quest types.
	Provides common interface and shared functionality.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestBase = {}
QuestBase.__index = QuestBase

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService

--[[
	Constructor
	@param questType string - Type of quest ("Main", "Daily", "Weekly", etc.)
	@param questData table - Quest definition data
	@return QuestBase - New quest instance
]]
function QuestBase.new(questType, questData)
	local self = setmetatable({}, QuestBase)
	self.QuestType = questType
	self.QuestData = questData
	self.State = "NotStarted"
	return self
end

--[[
	Shared methods - Available to all quest types
	
	Note: Subclasses should implement:
	- StartQuest(player, ...) - Initialize/start a quest
	- CheckProgress(player) - Check quest progress
	- Complete(player) - Handle quest completion
	- Reset(player) - Reset quest state
]]

function QuestBase:IsComplete(player)
	local progress = self:GetProgress(player)
	if not progress then
		return false
	end
	
	-- For main quests, check all tasks
	if self.QuestType == "Main" then
		if not self.QuestData or not self.QuestData.Tasks then
			return false
		end
		
		for i, task in ipairs(self.QuestData.Tasks) do
			if not progress.Tasks[i] or progress.Tasks[i].Progress < task.MaxProgress then
				return false
			end
		end
		return true
	else
		-- For side quests
		return progress.Completed == true
	end
end

function QuestBase:GetProgress(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return nil
	end
	
	if self.QuestType == "Main" then
		return profileData.MainQuests
	elseif self.QuestType == "Daily" then
		-- Return daily quest progress
		return profileData.DailyQuests
	elseif self.QuestType == "Weekly" then
		-- Return weekly quest progress
		return profileData.WeeklyQuests
	end
	
	return nil
end

function QuestBase:GetQuestData()
	return self.QuestData
end

function QuestBase:SetState(newState)
	self.State = newState
end

function QuestBase:GetState()
	return self.State
end

-- Initialize ProfileService reference
function QuestBase.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return QuestBase
