--[[
	ProgressiveQuest/init.lua
	
	Main quest system - handles linear story progression quests.
	Players complete quests in sequential order (1, 2, 3, ...).
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
local TaskHandlerRegistry

---- Module-level shared state (persists across all instances)
local CompletingQuest = {} -- Mutex for completion - shared across all ProgressiveQuest instances

local ProgressiveQuest = {}
ProgressiveQuest.__index = ProgressiveQuest

--[[
	Constructor
]]
function ProgressiveQuest.new(questNum)
	if not QuestBase then
		-- Lazy load QuestBase if not initialized yet
		QuestService = QuestService or Knit.GetService("QuestService")
		QuestBase = require(QuestService.Instance.Components.Others.Core.QuestBase)
		-- Set up proper inheritance
		setmetatable(ProgressiveQuest, { __index = QuestBase })
	end

	local questData = questNum and QuestDefinitions.Main[questNum] or nil
	local self = QuestBase.new("Main", questData)
	setmetatable(self, ProgressiveQuest)
	-- Note: CompletingQuest is now module-level, not instance-level
	return self
end

--[[
	Start a main quest for the player
	@param player Player
	@param questNum number
]]
function ProgressiveQuest:StartQuest(player, questNum)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	-- Initialize quest data
	local questDetail = QuestDefinitions.Main[questNum]
	if not questDetail then
		warn("Invalid quest number:", questNum)
		return
	end

	-- Initialize tasks
	local tasks = {}
	for i, task in ipairs(questDetail.Tasks) do
		tasks[i] = {
			Description = task.Description,
			Progress = 0,
			MaxProgress = task.MaxProgress,
		}
	end

	-- Update profile data directly first (so it's immediately available)
	profileData.MainQuests.QuestNum = questNum
	profileData.MainQuests.Tasks = tasks

	-- Save to profile
	ProfileService:ChangeData(player, { "MainQuests" }, profileData.MainQuests)

	self:SetState("InProgress")

	-- Refresh progress from current game state
	self:RefreshQuestProgress(player, questNum)
end

--[[
	Refresh quest progress from current game state
	Uses pluggable task handlers instead of hardcoded logic
	@param player Player
	@param questNum number
]]
function ProgressiveQuest:RefreshQuestProgress(player, questNum)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	local questDetail = QuestDefinitions.Main[questNum]
	if not questDetail then
		warn("RefreshQuest: Invalid quest number:", questNum)
		return
	end

	-- Ensure tasks are initialized
	if not profileData.MainQuests or not profileData.MainQuests.Tasks then
		warn(string.format("RefreshQuest: MainQuests.Tasks not initialized for player: %s", player.Name))
		return
	end

	for i, taskDetail in ipairs(questDetail.Tasks) do
		-- Use pluggable task handler
		local handler = TaskHandlerRegistry.GetHandler(taskDetail.Description)

		if handler then
			local progress = handler:GetProgress(player)
			self:SetTaskProgress(player, i, progress)
		else
			warn("RefreshQuest: No handler found for task:", taskDetail.Description)
		end
	end

	-- Check if quest is complete (but don't trigger completion if already completing)
	-- Main quests should only complete once, and refreshing progress shouldn't re-complete
	local isComplete = self:IsComplete(player)

	if isComplete and not CompletingQuest[player] then
		self:Complete(player)
	end
end

--[[
	Set progress for a specific task
	@param player Player
	@param taskIndex number
	@param progress number
]]
function ProgressiveQuest:SetTaskProgress(player, taskIndex, progress)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData or not profileData.MainQuests.Tasks[taskIndex] then
		warn(
			string.format(
				"[SetTaskProgress] Cannot set task progress - Task %d not found for player %s",
				taskIndex,
				player.Name
			)
		)
		return
	end

	-- Update task progress
	profileData.MainQuests.Tasks[taskIndex].Progress = progress

	-- Save to profile - Use specific task path for better client sync
	ProfileService:ChangeData(player, { "MainQuests", "Tasks", taskIndex, "Progress" }, progress)
end

--[[
	Increment progress for a task by description pattern
	@param player Player
	@param questDescription string - Pattern to match
	@param amount number
]]
function ProgressiveQuest:IncrementProgress(player, questDescription, amount)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	local questNum = profileData.MainQuests.QuestNum
	local questDetail = QuestDefinitions.Main[questNum]

	if not questDetail then
		return
	end

	for i, task in ipairs(questDetail.Tasks) do
		if task.Description:match(questDescription) then
			local currentProgress = profileData.MainQuests.Tasks[i].Progress
			local newProgress = math.min(currentProgress + amount, task.MaxProgress)
			self:SetTaskProgress(player, i, newProgress)
			break
		end
	end
end

--[[
	Set progress for a task by description pattern
	@param player Player
	@param questDescription string
	@param value number
]]
function ProgressiveQuest:SetProgress(player, questDescription, value)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	local questNum = profileData.MainQuests.QuestNum
	local questDetail = QuestDefinitions.Main[questNum]

	if not questDetail then
		return
	end

	for i, task in ipairs(questDetail.Tasks) do
		if task.Description:match(questDescription) then
			self:SetTaskProgress(player, i, value)
			break
		end
	end

	-- Check for quest completion (but don't trigger if already completing)
	if self:IsComplete(player) and not CompletingQuest[player] then
		self:Complete(player)
	end
end

--[[
	Complete the current main quest
	@param player Player
]]
function ProgressiveQuest:Complete(player)
	-- Prevent duplicate completions (using module-level mutex shared across all instances)
	if CompletingQuest[player] then
		return
	end
	CompletingQuest[player] = true

	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		CompletingQuest[player] = nil
		return
	end

	local questNum = profileData.MainQuests.QuestNum
	local questDetail = QuestDefinitions.Main[questNum]

	if not questDetail then
		CompletingQuest[player] = nil
		return
	end

	-- Check if next quest exists BEFORE completing and giving rewards
	local nextQuestNum = questNum + 1
	local nextQuestExists = QuestDefinitions.Main[nextQuestNum] ~= nil
	
	if not nextQuestExists and GameSettings.MainQuests.AutoAdvance then
		-- This is the last quest - we need to handle it specially
		-- Mark it as completed by advancing QuestNum past the last quest
		-- Set QuestNum to one beyond the last quest to prevent re-completion
		profileData.MainQuests.QuestNum = nextQuestNum
		ProfileService:ChangeData(player, { "MainQuests", "QuestNum" }, nextQuestNum)
	end

	-- Access QuestRewards through parent service's Instance.Components
	local QuestRewards = require(QuestService.Instance.Components.Others.Core.QuestRewards)

	-- Calculate and grant rewards
	local exp, cash = QuestRewards.CalculateRewards(player, "Main", questNum, questDetail.Rewards)
	local rewardSuccess, rewards = QuestRewards.GrantRewards(player, exp, cash)

	if rewardSuccess then
		-- Create rewards table for animation
		local rewardsData = { EXP = exp, Cash = cash }

		-- Fire animation signal to client with rewards data
		QuestService.Client.InitiateFinishedMainQuestAnimation:Fire(player, questNum, rewardsData)

		-- Fire completion signal (for UI updates)
		QuestService.Client.QuestCompleted:Fire(player, "Main", questNum, rewardsData)
	else
		warn("Failed to grant rewards for main quest:", questNum)
	end

	-- Wait for animation to complete before advancing to next quest
	if GameSettings.MainQuests.AutoAdvance and nextQuestExists then
		-- Animation duration from old code: 2 + 0.75 + 0.5 + 1 = 4.25 seconds
		local animationDuration = GameSettings.MainQuests.AnimationDuration or 4.5
		task.wait(animationDuration)

		-- Advance to next quest
		self:StartQuest(player, nextQuestNum)
	end

	CompletingQuest[player] = nil
	self:SetState("Completed")
end

--[[
	Reset quest (not typically used for main quests)
	@param player Player
]]
function ProgressiveQuest:Reset(player)
	-- Main quests don't typically reset
	warn("Main quest reset requested - this is unusual")
end

--[[
	Check progress of current quest
	@param player Player
	@return boolean
]]
function ProgressiveQuest:CheckProgress(player)
	return self:IsComplete(player)
end

-- Initialize module
function ProgressiveQuest.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")
	QuestBase = require(QuestService.Instance.Components.Others.Core.QuestBase)
	TaskHandlerRegistry = require(script.TaskHandlers)

	-- Set up proper inheritance from QuestBase
	setmetatable(ProgressiveQuest, { __index = QuestBase })
end

return ProgressiveQuest
