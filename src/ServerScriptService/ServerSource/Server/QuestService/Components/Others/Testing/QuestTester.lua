--[[
	QuestTester.lua
	
	Testing utilities for quest system development.
	Access in Studio: Knit.GetService("QuestService").QuestTester
	
	Example usage:
		local Knit = require(game.ReplicatedStorage.Packages.Knit)
		local QuestService = Knit.GetService("QuestService")
		QuestService.QuestTester.ResetPlayerQuests(player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestTester = {}

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local GameSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService
local QuestService

--[[
	Reset all quests for a player
	@param player Player
]]
function QuestTester.ResetPlayerQuests(player)
	print("🔄 Resetting all quests for " .. player.Name)

	-- Reset daily quests
	QuestService:ResetQuest(player, "Daily")
	print("  ✅ Daily quests reset")

	-- Reset weekly quests
	QuestService:ResetQuest(player, "Weekly")
	print("  ✅ Weekly quests reset")

	-- Reset main quest to #1
	local _, profileData = ProfileService:GetProfile(player)
	if profileData then
		profileData.MainQuests.QuestNum = 1
		profileData.MainQuests.Tasks = {}
		ProfileService:ChangeData(player, { "MainQuests" }, profileData.MainQuests)
		QuestService:StartQuest(player, "Main", 1)
		print("  ✅ Main quest reset to #1")
	end

	print("✅ All quests reset successfully!")
end

--[[
	Complete the current main quest for a player
	@param player Player
]]
function QuestTester.CompleteCurrentMainQuest(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("❌ No profile found for player")
		return
	end

	local questNum = profileData.MainQuests.QuestNum
	local questDetail = QuestDefinitions.Main[questNum]

	if not questDetail then
		warn("❌ Invalid quest number:", questNum)
		return
	end

	print("⚡ Completing main quest #" .. questNum .. " for " .. player.Name)

	-- Set all task progress to max
	for i, task in ipairs(questDetail.Tasks) do
		if profileData.MainQuests.Tasks[i] then
			profileData.MainQuests.Tasks[i].Progress = task.MaxProgress
			print("  ✅ Task " .. i .. ": " .. task.Description)
		end
	end

	ProfileService:ChangeData(player, { "MainQuests" }, profileData.MainQuests)

	print("✅ Main quest #" .. questNum .. " completed!")
end

--[[
	Test all main quests for validation errors
]]
function QuestTester.TestAllMainQuests()
	print("🧪 Testing all main quests...")

	local QuestValidator = require(script.Parent.Parent.Core.QuestValidator)
	local errors = 0

	for i = 1, #QuestDefinitions.Main do
		local quest = QuestDefinitions.Main[i]

		local ok, err = pcall(function()
			QuestValidator.ValidateMainQuest(i, quest)
		end)

		if not ok then
			warn("❌ Main Quest #" .. i .. " failed:", err)
			errors = errors + 1
		else
			print("✅ Main Quest #" .. i .. " passed")
		end
	end

	if errors > 0 then
		warn(string.format("❌ %d main quest(s) failed validation", errors))
	else
		print("✅ All main quests validated successfully!")
	end

	return errors == 0
end

--[[
	Test all daily quests
]]
function QuestTester.TestAllDailyQuests()
	print("🧪 Testing all daily quests...")

	local QuestValidator = require(script.Parent.Parent.Core.QuestValidator)
	local errors = 0

	for questName, quest in pairs(QuestDefinitions.Daily) do
		local ok, err = pcall(function()
			QuestValidator.ValidateSideQuest("Daily", questName, quest)
		end)

		if not ok then
			warn("❌ Daily Quest '" .. questName .. "' failed:", err)
			errors = errors + 1
		else
			print("✅ Daily Quest '" .. questName .. "' passed")
		end
	end

	if errors > 0 then
		warn(string.format("❌ %d daily quest(s) failed validation", errors))
	else
		print("✅ All daily quests validated successfully!")
	end

	return errors == 0
end

--[[
	Test all weekly quests
]]
function QuestTester.TestAllWeeklyQuests()
	print("🧪 Testing all weekly quests...")

	local QuestValidator = require(script.Parent.Parent.Core.QuestValidator)
	local errors = 0

	for questName, quest in pairs(QuestDefinitions.Weekly) do
		local ok, err = pcall(function()
			QuestValidator.ValidateSideQuest("Weekly", questName, quest)
		end)

		if not ok then
			warn("❌ Weekly Quest '" .. questName .. "' failed:", err)
			errors = errors + 1
		else
			print("✅ Weekly Quest '" .. questName .. "' passed")
		end
	end

	if errors > 0 then
		warn(string.format("❌ %d weekly quest(s) failed validation", errors))
	else
		print("✅ All weekly quests validated successfully!")
	end

	return errors == 0
end

--[[
	Simulate quest progression
	@param player Player
	@param questType string
	@param description string
	@param amount number
]]
function QuestTester.SimulateQuestProgression(player, questType, description, amount)
	print(string.format("⚡ Simulating %s quest progress: %s +%d", questType, description, amount))

	QuestService:IncrementQuestProgress(player, questType, description, amount)

	print("✅ Progress simulated")
end

--[[
	Print player's current quest status
	@param player Player
]]
function QuestTester.PrintQuestStatus(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("❌ No profile found")
		return
	end

	print("📋 Quest Status for " .. player.Name)
	print(
		"─────────────────────────────────────"
	)

	-- Main Quest
	print("🎯 Main Quest:")
	print("  Current Quest: #" .. (profileData.MainQuests.QuestNum or 0))
	if profileData.MainQuests.Tasks then
		for i, task in ipairs(profileData.MainQuests.Tasks) do
			print(string.format("  Task %d: %d/%d", i, task.Progress, task.MaxProgress))
		end
	end

	-- Daily Quests
	print("📅 Daily Quests:")
	if profileData.DailyQuests.Quests then
		for i, quest in ipairs(profileData.DailyQuests.Quests) do
			local status = quest.Completed and "✅" or "⏳"
			print(string.format("  %s %d. %s (%d progress)", status, i, quest.Name, quest.Progress))
		end
	end

	-- Weekly Quests
	print("📆 Weekly Quests:")
	if profileData.WeeklyQuests.Quests then
		for i, quest in ipairs(profileData.WeeklyQuests.Quests) do
			local status = quest.Completed and "✅" or "⏳"
			print(string.format("  %s %d. %s (%d progress)", status, i, quest.Name, quest.Progress))
		end
	end

	print(
		"─────────────────────────────────────"
	)
end

-- Initialize services
function QuestTester.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")
end

return QuestTester
