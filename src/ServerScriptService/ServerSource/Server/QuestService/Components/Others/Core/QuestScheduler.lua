--[[
	QuestScheduler.lua
	
	Event-driven quest reset scheduler.
	Replaces inefficient polling loops with centralized checking.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestScheduler = {}

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local GameSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))

---- Knit Services
local ProfileService
local QuestService

local isRunning = false

--[[
	Get next reset time for a quest type
	@param player Player
	@param questType string - "Daily" or "Weekly"
	@return number - Unix timestamp of next reset
]]
function QuestScheduler:GetNextResetTime(player, questType)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return 0
	end
	
	local questData
	local resetInterval
	
	if questType == "Daily" then
		questData = profileData.DailyQuests
		resetInterval = GameSettings.DailyAndWeeklyQuests.DailyResetInterval
	elseif questType == "Weekly" then
		questData = profileData.WeeklyQuests
		resetInterval = GameSettings.DailyAndWeeklyQuests.WeeklyResetInterval
	else
		return 0
	end
	
	local lastResetTime = questData.LastResetTime or 0
	return lastResetTime + resetInterval
end

--[[
	Check if a quest type should reset
	@param player Player
	@param questType string
	@return boolean
]]
function QuestScheduler:ShouldReset(player, questType)
	local nextResetTime = self:GetNextResetTime(player, questType)
	local currentTime = workspace:GetServerTimeNow()
	
	-- Add grace period to prevent missed resets
	local gracePeriod = GameSettings.Scheduler.ResetGracePeriod or 0
	
	return currentTime >= (nextResetTime - gracePeriod)
end

--[[
	Start the scheduler loop
	Called from QuestService:KnitStart()
]]
function QuestScheduler.Start()
	if isRunning then
		warn("QuestScheduler already running")
		return
	end
	
	isRunning = true
	
	-- Single centralized loop that checks all players periodically
	task.spawn(function()
		while isRunning do
			local checkInterval = GameSettings.Scheduler.CheckInterval or 60
			
			-- Check all online players
			for _, player in pairs(Players:GetPlayers()) do
				if player:IsDescendantOf(Players) then
					-- Check daily reset
					if QuestScheduler:ShouldReset(player, "Daily") then
						local success, err = pcall(function()
							QuestService:ResetQuest(player, "Daily")
						end)
						
						if not success then
							warn("Failed to reset daily quests for " .. player.Name .. ":", err)
						end
					end
					
					-- Check weekly reset
					if QuestScheduler:ShouldReset(player, "Weekly") then
						local success, err = pcall(function()
							QuestService:ResetQuest(player, "Weekly")
						end)
						
						if not success then
							warn("Failed to reset weekly quests for " .. player.Name .. ":", err)
						end
					end
				end
			end
			
			-- Wait before next check (default: 60 seconds)
			task.wait(checkInterval)
		end
	end)
end

--[[
	Stop the scheduler loop
]]
function QuestScheduler.Stop()
	isRunning = false
end

-- Initialize service references
function QuestScheduler.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")
end

return QuestScheduler
