--[[
	QuestRewards.lua
	
	Centralized quest reward calculation and granting.
	Handles atomic reward distribution with rollback on failure.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestRewards = {}

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local QuestSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))

---- Utilities
local Utilities = ReplicatedStorage:WaitForChild("SharedSource", 10).Utilities
local NumberShortener = require(Utilities:WaitForChild("Number"):WaitForChild("NumberShortener", 10))

---- Knit Services
local ProfileService
local NotifierService
local LevelService
local CurrencyService

--[[
	Calculate rewards with scaling
	@param player Player
	@param questType string
	@param questNum number | string
	@param baseRewards table
	@return number, number - EXP and Cash amounts
]]
function QuestRewards.CalculateRewards(player, questType, questNum, baseRewards)
	if not baseRewards then
		return 0, 0
	end

	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return 0, 0
	end

	local playerLevel = profileData.Level or 1

	-- Calculate base amounts
	local expReward = baseRewards.BaseEXP or baseRewards.EXP or 0
	local cashReward = baseRewards.BaseCash or baseRewards.Cash or 0

	-- Apply scaling for Daily/Weekly quests
	if questType == "Daily" or questType == "Weekly" then
		local scaling = QuestSettings.DailyAndWeeklyQuests.RewardScaling

		-- Scale by player level
		expReward = expReward * (scaling.ExpScalePerLevel ^ playerLevel)
		cashReward = cashReward * (scaling.CashScalePerLevel ^ playerLevel)

		-- Apply weekly multiplier
		if questType == "Weekly" then
			expReward = expReward * scaling.WeeklyExpMultiplier
			cashReward = cashReward * scaling.WeeklyCashMultiplier
		end
	end

	-- Round to integers
	expReward = math.floor(expReward)
	cashReward = math.floor(cashReward)

	return expReward, cashReward
end

--[[
	Grant rewards to player atomically
	@param player Player
	@param expReward number
	@param cashReward number
	@return boolean, table - Success status and granted rewards list
]]
function QuestRewards.GrantRewards(player, expReward, cashReward)
	local grantedRewards = {}

	local success, err = pcall(function()
		-- Use proper services to grant rewards
		if expReward and expReward > 0 then
			-- Use LevelService to add experience to the "levels" type
			local addSuccess = LevelService.SetComponent:AddExp(player, expReward, "levels")
			if addSuccess then
				table.insert(grantedRewards, { type = "EXP", amount = expReward })
			else
				error("Failed to add EXP to player")
			end
		end

		if cashReward and cashReward > 0 then
			-- Use CurrencyService to add cash currency
			local addSuccess = CurrencyService.SetComponent:IncreaseCurrency(player, "cash", cashReward)
			if addSuccess then
				table.insert(grantedRewards, { type = "Cash", amount = cashReward })
			else
				error("Failed to add cash to player")
			end
		end
	end)

	if not success then
		warn("Failed to grant rewards:", err)
		-- Attempt rollback
		QuestRewards.RollbackRewards(player, grantedRewards)
		return false, err
	end

	return true, grantedRewards
end

--[[
	Rollback rewards if granting failed (best effort)
	@param player Player
	@param grantedRewards table - List of rewards to rollback
]]
function QuestRewards.RollbackRewards(player, grantedRewards)
	-- Rollback rewards using the proper services
	for _, reward in ipairs(grantedRewards) do
		if reward.type == "EXP" then
			-- Subtract EXP using LevelService (use negative amount to subtract)
			LevelService.SetComponent:AddExp(player, -reward.amount, "levels")
		elseif reward.type == "Cash" then
			-- Subtract cash using CurrencyService
			CurrencyService.SetComponent:DecreaseCurrency(player, "cash", reward.amount)
		end
	end

	warn("Rolled back " .. #grantedRewards .. " rewards for " .. player.Name)
end

--[[
	Notify player of quest completion
	@param player Player
	@param questType string
	@param expReward number
	@param cashReward number
]]
function QuestRewards.NotifyPlayer(player, questType, expReward, cashReward)
	-- Format numbers for display using NumberShortener
	-- Format display text (SideQuest -> "Side Quest", Daily -> "Daily quest", etc.)
	local displayText = questType == "SideQuest" and "Side Quest" or string.format("%s quest", questType)
	local message = string.format(
		"Completed a %s! [+%s EXP | +%s Cash]",
		displayText,
		NumberShortener.shortenWith2Decimals(expReward),
		NumberShortener.shortenWith2Decimals(cashReward)
	)

	-- Send notification to player
	NotifierService:NotifyPlayer(player, {
		MessageType = "Normal Notification",
		Message = message,
		TextColor = Color3.fromRGB(120, 255, 120), -- Green color for quest completion
		Duration = 4,
	})
end

-- Initialize service references
function QuestRewards.Init()
	ProfileService = Knit.GetService("ProfileService")
	NotifierService = Knit.GetService("NotifierService")
	LevelService = Knit.GetService("LevelService")
	CurrencyService = Knit.GetService("CurrencyService")
end

return QuestRewards
