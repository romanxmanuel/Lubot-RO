local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestService = Knit.CreateService({
	Name = "QuestService",
	Instance = script,
	Client = {
		-- Quest update signals
		QuestProgressUpdated = Knit.CreateSignal(),
		QuestCompleted = Knit.CreateSignal(),
		QuestStarted = Knit.CreateSignal(),
		QuestReset = Knit.CreateSignal(),

		-- Main quest specific signals
		UpdateMainQuestProgress = Knit.CreateSignal(),
		InitiateFinishedMainQuestAnimation = Knit.CreateSignal(),

		-- Controller ready signal (replaces RemoteFunction)
		MainQuestControllerReady = Knit.CreateSignal(),

		-- NOTE: Quest type-specific signals (TrackPickupItems, TrackDeliveryLocations, etc.)
		-- are now auto-registered by QuestTypeManager via handler.GetRegistration()

		-- ⭐ MULTI-TASK QUEST SIGNALS
		TaskProgressUpdated = Knit.CreateSignal(), -- Server → Client: Task progress updated
		TaskCompleted = Knit.CreateSignal(), -- Server → Client: Task completed
		TaskUnlocked = Knit.CreateSignal(), -- Server → Client: Task unlocked (sequential mode)
	},
})

---- Server-side signals for passive quest system
QuestService.ItemCollected = Signal.new() -- Fired when player collects items (crates, packages, etc.)

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local GameSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService

--[[
	Public API Methods - Delegated to Get/Set Components
]]

-- Get Methods (Read-only queries)
function QuestService:GetQuestProgress(player, questType, questNum)
	return self.GetComponent:GetQuestProgress(player, questType, questNum)
end

function QuestService:IsQuestComplete(player, questType, questNum)
	return self.GetComponent:IsQuestComplete(player, questType, questNum)
end

function QuestService:GetActiveQuests(player)
	return self.GetComponent:GetActiveQuests(player)
end

function QuestService:GetQuestRewards(questType, questNum)
	return self.GetComponent:GetQuestRewards(questType, questNum)
end

function QuestService:GetNextResetTime(player, questType)
	return self.GetComponent:GetNextResetTime(player, questType)
end

-- Set Methods (State mutations)
function QuestService:StartQuest(player, questType, questNum)
	return self.SetComponent:StartQuest(player, questType, questNum)
end

function QuestService:IncrementQuestProgress(player, questType, questDescription, amount)
	return self.SetComponent:IncrementQuestProgress(player, questType, questDescription, amount)
end

function QuestService:SetQuestProgress(player, questType, questDescription, value)
	return self.SetComponent:SetQuestProgress(player, questType, questDescription, value)
end

function QuestService:CompleteQuest(player, questType, questNum)
	return self.SetComponent:CompleteQuest(player, questType, questNum)
end

function QuestService:ResetQuest(player, questType)
	return self.SetComponent:ResetQuest(player, questType)
end

function QuestService:TrackSideQuest(player, questType, questNum)
	return self.SetComponent:TrackSideQuest(player, questType, questNum)
end

-- Client communication methods
function QuestService.Client:GetQuestProgress(player, questType, questNum)
	return QuestService:GetQuestProgress(player, questType, questNum)
end

function QuestService.Client:GetActiveQuests(player)
	return QuestService:GetActiveQuests(player)
end

function QuestService.Client:TrackSideQuest(player, questType, questNum)
	return QuestService:TrackSideQuest(player, questType, questNum)
end

-- NOTE: Quest type-specific client methods (ValidateItemPickup, ValidateDelivery, etc.)
-- are now auto-registered by QuestTypeManager via handler.GetRegistration().ClientMethods

-- Testing API - Only available in Studio
function QuestService.Client:RunPickupItemsTest(player, testType, ...)
	if not RunService:IsStudio() then
		warn("Testing API only available in Studio")
		return false
	end

	if not QuestService.PickupItemsTester then
		warn("PickupItemsTester not available")
		return false
	end

	local args = { ... }
	local tester = QuestService.PickupItemsTester

	if testType == "SpawnWithWoodCrates" then
		return tester:TestWithWoodCrates(player, unpack(args))
	elseif testType == "SpawnItems" then
		return tester:TestSpawnItems(player, unpack(args))
	elseif testType == "CreateSpawnPoints" then
		return tester:CreateTestSpawnPoints(unpack(args))
	elseif testType == "RemoveSpawnPoints" then
		return tester:RemoveTestSpawnPoints()
	elseif testType == "RunFullTest" then
		return tester:RunFullTest(player)
	else
		warn("Unknown test type:", testType)
		return false
	end
end

function QuestService:KnitStart()
	-- Validate all quest data on startup
	if GameSettings.Validation.ValidateOnStartup then
		local QuestValidator = require(script.Components.Others.Core.QuestValidator)
		local success, err = pcall(function()
			QuestValidator.ValidateAllQuestData()
		end)

		if not success then
			error("Quest Data Validation Failed: " .. tostring(err))
		end
	end

	-- Listen to ProfileService for level changes to refresh main quest progress
	-- This uses the built-in UpdateSpecificData signal, no need to modify LevelService
	if ProfileService and ProfileService.UpdateSpecificData then
		ProfileService.UpdateSpecificData:Connect(function(player, Redirectories, newValue)
			-- Check if this is a level change for the main "levels" type
			-- Path: ["Leveling", "Types", "levels", "Level"]
			if
				Redirectories[1] == "Leveling"
				and Redirectories[2] == "Types"
				and Redirectories[3] == "levels"
				and Redirectories[4] == "Level"
			then
				-- Refresh main quest progress when player levels up
				local ProgressiveQuest = require(script.Components.Others.ProgressiveQuest)
				local _, profileData = ProfileService:GetProfile(player)
				if profileData and profileData.MainQuests then
					local questNum = profileData.MainQuests.QuestNum
					local mainQuest = ProgressiveQuest.new(questNum)

					-- Pass profileData to avoid race condition
					mainQuest:RefreshQuestProgress(player, questNum, profileData)

					-- Fire signal to update client UI
					self.Client.UpdateMainQuestProgress:Fire(player)
				end
			end
		end)
	end

	-- Function to handle player initialization (for both new joins and existing players)
	local function initializePlayerQuests(player)
		-- Wait for profile to load
		ProfileService:WaitUntilProfileLoaded(player)

		-- Initialize quests if needed
		local _, profileData = ProfileService:GetProfile(player)
		
		-- Validate player quests
		local QuestValidator = require(script.Components.Others.Core.QuestValidator)
		local invalidQuests = QuestValidator.FindInvalidPlayerQuests(player)

		if #invalidQuests > 0 then
			warn("Player " .. player.Name .. " has invalid quests:")
			for _, quest in ipairs(invalidQuests) do
				warn("  - " .. quest.type .. " #" .. quest.index .. ": " .. quest.name)
			end

			-- Auto-reset invalid quests
			if GameSettings.Validation.AutoResetInvalidQuests then
				for _, quest in ipairs(invalidQuests) do
					if quest.type == "Daily" then
						self:ResetQuest(player, "Daily")
					elseif quest.type == "Weekly" then
						self:ResetQuest(player, "Weekly")
					end
				end
			end
		end

		-- Check if daily quests need reset
		if self.GetComponent:ShouldResetDaily(player) then
			self:ResetQuest(player, "Daily")
		end

		-- Check if weekly quests need reset
		if self.GetComponent:ShouldResetWeekly(player) then
			self:ResetQuest(player, "Weekly")
		end

		-- Initialize main quest if not started
		if not profileData.MainQuests.QuestNum or profileData.MainQuests.QuestNum < 1 then
			self:StartQuest(player, "Main", GameSettings.MainQuests.StartingQuestNum)
		else
			-- Quest already exists, check if Tasks array needs to be reinitialized
			local questNum = profileData.MainQuests.QuestNum
			local questDetail = QuestDefinitions.Main[questNum]
			
			-- Check if player has completed all quests
			if not questDetail then
				-- Fire signal to update client UI (to show "All Quests Complete" or hide quest UI)
				self.Client.UpdateMainQuestProgress:Fire(player)
			else
				-- Quest exists, proceed with normal initialization
				if not profileData.MainQuests.Tasks or #profileData.MainQuests.Tasks == 0 then
					-- Tasks array is empty or missing, reinitialize it
					local tasks = {}
					for i, task in ipairs(questDetail.Tasks) do
						tasks[i] = {
							Description = task.Description,
							Progress = 0,
							MaxProgress = task.MaxProgress,
						}
					end
					profileData.MainQuests.Tasks = tasks
					ProfileService:ChangeData(player, { "MainQuests", "Tasks" }, tasks)
				end

				-- Refresh progress based on current player level
				local ProgressiveQuest = require(script.Components.Others.ProgressiveQuest)
				local mainQuest = ProgressiveQuest.new(questNum)
				mainQuest:RefreshQuestProgress(player, questNum)

				-- Fire signal to update client UI
				self.Client.UpdateMainQuestProgress:Fire(player)
			end
		end

		-- Check for auto-completion of tracked side quest
		if GameSettings.SideQuests.EnableAutoCompletion then
			local trackedQuest = profileData.CurrentSideQuestTracked
			if trackedQuest and trackedQuest.QuestType and trackedQuest.QuestNum then
				-- Get quest definition to find the handler module
				local questData
				if trackedQuest.QuestType == "SideQuest" then
					questData = QuestDefinitions.SideQuest[trackedQuest.QuestNum]
				elseif trackedQuest.QuestType == "Daily" then
					if profileData.DailyQuests.Quests[trackedQuest.QuestNum] then
						local questName = profileData.DailyQuests.Quests[trackedQuest.QuestNum].Name
						questData = QuestDefinitions.Daily[questName]
					end
				elseif trackedQuest.QuestType == "Weekly" then
					if profileData.WeeklyQuests.Quests[trackedQuest.QuestNum] then
						local questName = profileData.WeeklyQuests.Quests[trackedQuest.QuestNum].Name
						questData = QuestDefinitions.Weekly[questName]
					end
				end

				-- Try to complete using the appropriate handler
				if questData and questData.ServerSideQuestName then
					local ComponentsFolder = script.Components
					local TriggeredQuestTypes = ComponentsFolder.Others.TriggeredQuest.Types
					local questModule = TriggeredQuestTypes:FindFirstChild(questData.ServerSideQuestName)

					if questModule then
						local sideQuestHandler = require(questModule)
						if sideQuestHandler.TryCompleteQuest then
							task.defer(function()
								sideQuestHandler:TryCompleteQuest(player, trackedQuest.QuestType, trackedQuest.QuestNum)
							end)
						end
					else
						warn("Side quest handler not found:", questData.ServerSideQuestName)
					end
				end
			end
		end
	end

	-- Handle player joins
	Players.PlayerAdded:Connect(function(player)
		initializePlayerQuests(player)
	end)

	-- Handle players who joined before PlayerAdded was connected
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			initializePlayerQuests(player)
		end)
	end

	-- Studio testing utilities
	if RunService:IsStudio() then
		local ComponentsFolder = script.Components
		QuestService.QuestTester = require(ComponentsFolder.Others.Testing.QuestTester)
		QuestService.PickupItemsTester = require(ComponentsFolder.Others.Testing.PickupItemsTester)
		QuestService.CrateVisibilityManager = require(ComponentsFolder.Others.Managers.CrateVisibilityManager)

		-- Load DeliveryTester if it exists
		local deliveryTesterModule = ComponentsFolder.Others.Testing:FindFirstChild("DeliveryTester")
		if deliveryTesterModule then
			QuestService.DeliveryTester = require(deliveryTesterModule)
		end

		-- Initialize crate visibility (hide crates at startup)
		QuestService.CrateVisibilityManager.Init()
	end
end

function QuestService:KnitInit()
	---- Knit Services
	ProfileService = Knit.GetService("ProfileService")
end

return QuestService
