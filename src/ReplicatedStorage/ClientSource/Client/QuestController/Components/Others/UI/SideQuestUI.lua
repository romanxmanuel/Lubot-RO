--[[
    SideQuestUI.lua
    
    Handles daily and weekly quest UI display.
    Manages quest tracking, progress bars, and reset timers.
    
    Phase 11: Client UI Refactoring
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Knit = require(ReplicatedStorage.Packages.Knit)

local SideQuestUI = {}

---- Knit Services
local QuestService
local ProfileService

---- Knit Controllers
local DataController
local QuestController

---- Data Sources
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
local GameSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Utilities
local Utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
local QuestUtils = require(Utilities:WaitForChild("QuestUtils", 10))
local TimeFormatter = require(Utilities:WaitForChild("Time"):WaitForChild("TimeFormatter", 10))
local NumberShortener = require(Utilities:WaitForChild("Number"):WaitForChild("NumberShortener", 10))
local ProgressBarAnimator = require(Utilities:WaitForChild("ProgressBarAnimator", 10))
local SoundPlayer = require(Utilities:WaitForChild("Audio"):WaitForChild("SoundPlayer", 10))

---- Sound References
local Assets = ReplicatedStorage:WaitForChild("Assets", 10)
local Sounds = Assets:WaitForChild("Sounds", 10)
local ClickSound = Sounds:WaitForChild("Click", 10)

---- UI References
local questGui
local sideQuestContent
local sideQuestsFrame -- Legacy support
local dailyQuestsFrame -- Legacy support
local weeklyQuestsFrame -- Legacy support

---- Track button rate limiting
local lastTrackTime = {}
local TRACK_COOLDOWN = 2 -- seconds

---- Track button connections (store to disconnect old ones)
local trackButtonConnections = {}

---- Quest tracking
local currentTrackedQuest = nil -- Track which quest is currently displayed
local isAnimatingNewQuest = false -- Flag to prevent updates during animation
local isFirstLoad = true -- Flag to skip animation on first load

--[[
	Calculate scaled rewards for Daily/Weekly quests (client-side)
	@param questType string - "Daily" or "Weekly"
	@param questData table - Quest definition with Rewards
	@return number, number - Scaled EXP and Cash rewards
]]
function SideQuestUI:CalculateScaledRewards(questType, questData)
	if not questData or not questData.Rewards then
		return 0, 0
	end

	-- Get player level
	local profileData = DataController.Data
	if not profileData then
		return 0, 0
	end

	local playerLevel = profileData.Level or 1

	-- Get base rewards
	local baseEXP = questData.Rewards.BaseEXP or questData.Rewards.EXP or 0
	local baseCash = questData.Rewards.BaseCash or questData.Rewards.Cash or 0

	-- Apply scaling (same formula as server)
	local scaling = GameSettings.DailyAndWeeklyQuests.RewardScaling
	local expReward = baseEXP * (scaling.ExpScalePerLevel ^ playerLevel)
	local cashReward = baseCash * (scaling.CashScalePerLevel ^ playerLevel)

	-- Apply weekly multiplier if weekly quest
	if questType == "Weekly" then
		expReward = expReward * scaling.WeeklyExpMultiplier
		cashReward = cashReward * scaling.WeeklyCashMultiplier
	end

	-- Round to integers
	expReward = math.floor(expReward)
	cashReward = math.floor(cashReward)

	return expReward, cashReward
end

--[[
    Initializes UI references
]]
function SideQuestUI:InitializeUI()
	local playerGui = player:WaitForChild("PlayerGui")
	if not playerGui then
		warn("[SideQuestUI] PlayerGui not found")
		return
	end

	questGui = playerGui:FindFirstChild("QuestGui") or playerGui:WaitForChild("QuestGui")
	if not questGui then
		warn("[SideQuestUI] QuestGui not found")
		return
	end

	-- Try to find tab-based structure (QuestFrame.SideQuestContent) for tracked side quest display
	local questFrame = questGui:FindFirstChild("QuestFrame")
	if questFrame then
		sideQuestContent = questFrame:FindFirstChild("SideQuestContent")
		if sideQuestContent then
			-- Initialize reward labels to default "--" state
			local rewardEXPLabel = sideQuestContent:WaitForChild("RewardEXPLabel")
			local rewardCashLabel = sideQuestContent:WaitForChild("RewardCashLabel")
			if rewardEXPLabel then
				rewardEXPLabel.Text = "--"
			end
			if rewardCashLabel then
				rewardCashLabel.Text = "--"
			end
		end
	end

	-- Always try to initialize standalone SideQuestsFrame for Daily/Weekly quest lists
	sideQuestsFrame = questGui:WaitForChild("SideQuestsFrame")
	if sideQuestsFrame then
		local questsFrame = sideQuestsFrame:WaitForChild("QuestsFrame")
		if questsFrame then
			dailyQuestsFrame = questsFrame:WaitForChild("DailyQuestsListFrame")
			weeklyQuestsFrame = questsFrame:WaitForChild("WeeklyQuestsListFrame")
		else
			warn("[SideQuestUI] QuestsFrame not found in SideQuestsFrame!")
		end
	else
		warn("[SideQuestUI] SideQuestsFrame not found in QuestGui!")
	end
end

--[[
    Updates all side quests UI (daily and weekly)
]]
function SideQuestUI:UpdateQuestsList()
	-- If we have the standalone SideQuestsFrame, always update it for Daily/Weekly lists
	if sideQuestsFrame and (dailyQuestsFrame or weeklyQuestsFrame) then
		self:UpdateDailyQuests()
		self:UpdateWeeklyQuests()
		self:UpdateResetTimers()
	end

	-- Also update tab-based structure if available (for tracked side quest)
	if sideQuestContent then
		self:UpdateSideQuestDisplay()
	end
end

--[[
    Updates the side quest display with currently tracked quest (NEW TAB STRUCTURE)
]]
function SideQuestUI:UpdateSideQuestDisplay()
	if not sideQuestContent or not DataController then
		return
	end

	local profileData = DataController.Data
	if not profileData then
		return
	end

	-- Get currently tracked side quest
	local trackedQuest = profileData.CurrentSideQuestTracked
	if not trackedQuest then
		-- No quest tracked, show placeholder
		self:ShowNoQuestTracked()
		-- Mark that we've done the initial load check
		if isFirstLoad then
			isFirstLoad = false
		end
		return
	end

	local questType = trackedQuest.QuestType
	local questNum = trackedQuest.QuestNum

	-- Check if quest was untracked (QuestType or QuestNum set to nil)
	if not questType or not questNum then
		self:ShowNoQuestTracked()
		-- Mark that we've done the initial load check
		if isFirstLoad then
			isFirstLoad = false
		end
		return
	end

	-- Get player's quest data and quest definition
	local playerData
	local questDetail
	local questName

	if questType == "SideQuest" then
		-- For standalone side quests, questNum is the quest name
		questName = questNum

		-- Get player data from SideQuests dictionary
		playerData = profileData.SideQuests and profileData.SideQuests[questName]

		-- Get quest definition from SideQuest definitions
		questDetail = QuestDefinitions.SideQuest and QuestDefinitions.SideQuest[questName]
	elseif questType == "Daily" or questType == "Weekly" then
		-- For Daily/Weekly quests, questNum is an index
		local questsData
		if questType == "Daily" then
			questsData = profileData.DailyQuests and profileData.DailyQuests.Quests
		else
			questsData = profileData.WeeklyQuests and profileData.WeeklyQuests.Quests
		end

		if not questsData or not questsData[questNum] then
			self:ShowNoQuestTracked()
			return
		end

		playerData = questsData[questNum]
		questName = playerData.Name

		-- Get quest definition using QuestUtils
		questDetail = QuestUtils.GetQuestByName(questType, questName)
	else
		warn("[SideQuestUI] Unknown quest type:", questType)
		self:ShowNoQuestTracked()
		return
	end

	if not questDetail or not playerData then
		self:ShowNoQuestTracked()
		return
	end

	-- Update reward labels
	local rewardLabel = sideQuestContent:FindFirstChild("RewardLabel")
	if rewardLabel then
		-- Format display text (SideQuest -> "Side Quest", Daily -> "Daily Quest", etc.)
		local displayText = questType == "SideQuest" and "Side Quest" or string.format("%s Quest", questType)
		rewardLabel.Text = string.format("%s Rewards:", displayText)
	end

	-- Calculate scaled rewards based on player level
	local rewardEXPLabel = sideQuestContent:FindFirstChild("RewardEXPLabel")
	local rewardCashLabel = sideQuestContent:FindFirstChild("RewardCashLabel")

	if questDetail.Rewards then
		-- Get player level for scaling
		local playerLevel = profileData.Level or 1

		-- Calculate scaled rewards (BaseEXP * Level, BaseCash * Level)
		local baseEXP = questDetail.Rewards.BaseEXP or questDetail.Rewards.EXP or 0
		local baseCash = questDetail.Rewards.BaseCash or questDetail.Rewards.Cash or 0

		local scaledEXP = baseEXP * playerLevel
		local scaledCash = baseCash * playerLevel

		if rewardEXPLabel then
			if scaledEXP > 0 then
				rewardEXPLabel.Text = "+" .. NumberShortener.shorten(scaledEXP) .. " EXP"
			else
				rewardEXPLabel.Text = "--"
			end
		end

		if rewardCashLabel then
			if scaledCash > 0 then
				rewardCashLabel.Text = "$" .. NumberShortener.shorten(scaledCash)
			else
				rewardCashLabel.Text = "--"
			end
		end
	else
		-- No rewards at all
		if rewardEXPLabel then
			rewardEXPLabel.Text = "--"
		end
		if rewardCashLabel then
			rewardCashLabel.Text = "--"
		end
	end

	-- Update task progress in TaskContainer using Template
	local taskContainer = sideQuestContent:FindFirstChild("TaskContainer")
	if taskContainer then
		-- Find template (should exist in SideQuestContent too)
		local template = taskContainer:FindFirstChild("Template")

		-- Check if we switched to a different quest
		local questKey = questType .. "_" .. questNum
		local questChanged = currentTrackedQuest ~= questKey and not isFirstLoad

		if questChanged then
			-- Quest actually changed (not first load) - clear ALL old task frames
			for _, child in ipairs(taskContainer:GetChildren()) do
				if child:IsA("GuiObject") and child.Name ~= "Template" and not child:IsA("UIListLayout") then
					child:Destroy()
				end
			end
			currentTrackedQuest = questKey

			-- Set animation flag to prevent updates during animation
			isAnimatingNewQuest = true

			-- Trigger "add quest" animation for new side quest
			if QuestController and QuestController.Components and QuestController.Components.QuestAnimations then
				task.spawn(function()
					QuestController.Components.QuestAnimations:PlayAddQuestAnimation(
						"Side",
						questNum,
						questDetail,
						playerData
					)

					-- Calculate total animation duration
					-- Determine task count for animation timing
					local taskCount = (questDetail.Tasks and #questDetail.Tasks) or 1
					local rewardAnimDuration = 0.4
					local perTaskDuration = 0.4 + 0.3
					local totalDuration = rewardAnimDuration + (taskCount * perTaskDuration)

					-- Wait for animation to complete, then re-enable updates
					task.wait(totalDuration + 0.1) -- Add small buffer
					isAnimatingNewQuest = false

					-- Now refresh display to ensure it's up to date
					SideQuestUI:UpdateSideQuestDisplay()
				end)
			else
				-- Animation not available, reset flag immediately
				isAnimatingNewQuest = false
			end
			-- Return early - animation will handle display
			return
		elseif isFirstLoad and currentTrackedQuest ~= questKey then
			-- First load - clear old frames but don't animate
			for _, child in ipairs(taskContainer:GetChildren()) do
				if child:IsA("GuiObject") and child.Name ~= "Template" and not child:IsA("UIListLayout") then
					child:Destroy()
				end
			end
			currentTrackedQuest = questKey
			isFirstLoad = false
		end

		-- Skip updates if animation is playing
		if isAnimatingNewQuest then
			return
		end

		-- ⭐ MULTI-TASK SUPPORT: Check if quest uses Tasks array
		if questDetail.Tasks and playerData.Tasks then
			-- Multi-task quest: Display all tasks
			self:DisplayMultiTaskQuest(taskContainer, template, questDetail, playerData)
		else
			-- Legacy single-task quest (backward compatibility)
			local progress = playerData.Progress or 0
			local maxProgress = questDetail.MaxProgress or 1
			local isComplete = playerData.Completed or false

			if template then
				-- Try to find existing frame first (to preserve progress bar state for animation)
				-- ⭐ FIX: Use "Task_1" naming to match multi-task convention and prevent duplicates
				local questFrame = taskContainer:FindFirstChild("Task_1")

				if not questFrame then
					-- Create new single task frame
					questFrame = template:Clone()
					questFrame.Name = "Task_1"
					questFrame.Visible = true
					questFrame.Parent = taskContainer
				end

				-- Update description
				local descLabel = questFrame:FindFirstChild("DescriptionLabel")
				if descLabel then
					descLabel.Text = string.format(
						"%s %s",
						isComplete and "✓" or "○",
						questDetail.DisplayName or questDetail.Description or questDetail.Name
					)
					descLabel.TextColor3 = isComplete and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
				end

				-- Update progress label
				local progLabel = questFrame:FindFirstChild("ProgressLabel")
				if progLabel then
					progLabel.Text = string.format("[%d/%d]", progress, maxProgress)
					progLabel.TextColor3 = isComplete and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
				end

				-- Update progress bar with animation
				local maxProgressFrame = questFrame:FindFirstChild("MaxProgressFrame")
				if maxProgressFrame then
					local progressFrame = maxProgressFrame:FindFirstChild("ProgressFrame")
					if progressFrame then
						local progressPercent = math.clamp(progress / maxProgress, 0, 1)
						-- Animate progress bar from current position
						ProgressBarAnimator.AnimateProgress(progressFrame, progressPercent)
					end
				end
			else
				-- Fallback if template doesn't exist
				warn("[SideQuestUI] Template not found, using fallback")

				-- Try to find existing fallback label
				local progressLabel = taskContainer:FindFirstChild("QuestProgress")

				if not progressLabel then
					progressLabel = Instance.new("TextLabel")
					progressLabel.Name = "QuestProgress"
					progressLabel.Size = UDim2.new(1, 0, 0, 30)
					progressLabel.BackgroundTransparency = 1
					progressLabel.TextSize = 14
					progressLabel.TextXAlignment = Enum.TextXAlignment.Left
					progressLabel.Font = Enum.Font.GothamBold
					progressLabel.Parent = taskContainer
				end

				-- Update text and color
				progressLabel.TextColor3 = isComplete and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
				progressLabel.Text = string.format(
					"%s %s [%d/%d]",
					isComplete and "✓" or "○",
					questDetail.DisplayName or questDetail.Name,
					progress,
					maxProgress
				)
			end
		end -- Close legacy single-task branch

		-- Add UIListLayout if not exists
		if not taskContainer:FindFirstChildOfClass("UIListLayout") then
			local layout = Instance.new("UIListLayout")
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 5)
			layout.Parent = taskContainer
		end
	end
end

--[[
    Shows "No Quest Tracked" message
]]
function SideQuestUI:ShowNoQuestTracked()
	if not sideQuestContent then
		return
	end

	-- Reset tracked quest
	currentTrackedQuest = nil

	-- Update reward labels to show no quest
	local rewardLabel = sideQuestContent:FindFirstChild("RewardLabel")
	if rewardLabel then
		rewardLabel.Text = "No Quest Tracked"
	end

	local rewardEXPLabel = sideQuestContent:FindFirstChild("RewardEXPLabel")
	if rewardEXPLabel then
		rewardEXPLabel.Text = "--"
	end

	local rewardCashLabel = sideQuestContent:FindFirstChild("RewardCashLabel")
	if rewardCashLabel then
		rewardCashLabel.Text = "--"
	end

	-- Clear task container and show message
	local taskContainer = sideQuestContent:FindFirstChild("TaskContainer")
	if taskContainer then
		-- Clear existing displays (preserve Template and UIListLayout)
		for _, child in ipairs(taskContainer:GetChildren()) do
			if child:IsA("GuiObject") and child.Name ~= "Template" and not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		-- Create message label
		local messageLabel = Instance.new("TextLabel")
		messageLabel.Name = "NoQuestMessage"
		messageLabel.Size = UDim2.new(0.7, 0, 1, 0)
		messageLabel.BackgroundTransparency = 1
		messageLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		messageLabel.TextScaled = true
		messageLabel.TextXAlignment = Enum.TextXAlignment.Center
		messageLabel.TextYAlignment = Enum.TextYAlignment.Center
		messageLabel.Font = Enum.Font.Gotham
		messageLabel.Text = "Track a Side quest\nto see it here!"
		messageLabel.TextStrokeTransparency = 0
		messageLabel.TextWrapped = true
		messageLabel.Parent = taskContainer
	end
end

--[[
    Updates daily quest displays
]]
function SideQuestUI:UpdateDailyQuests()
	if not dailyQuestsFrame or not DataController then
		return
	end

	local profileData = DataController.Data
	if not profileData or not profileData.DailyQuests then
		return
	end

	local dailyQuests = profileData.DailyQuests.Quests
	if not dailyQuests then
		return
	end

	local maxDailyQuests = GameSettings.DailyAndWeeklyQuests.DailyMax

	-- Update and show active quest frames
	for i, questPlayerData in ipairs(dailyQuests) do
		local questFrame = dailyQuestsFrame:FindFirstChild(tostring(i))
		if questFrame then
			questFrame.Visible = true -- Show active quest
			local questData = QuestUtils.GetQuestByName("Daily", questPlayerData.Name)
			if questData then
				self:UpdateQuestFrame(questFrame, questData, questPlayerData, "Daily", i)
			end
		end
	end

	-- Hide unused quest frames
	for i = #dailyQuests + 1, maxDailyQuests do
		local questFrame = dailyQuestsFrame:FindFirstChild(tostring(i))
		if questFrame then
			questFrame.Visible = false -- Hide unused quest
		end
	end
end

--[[
    Updates weekly quest displays
]]
function SideQuestUI:UpdateWeeklyQuests()
	if not weeklyQuestsFrame or not DataController then
		return
	end

	local profileData = DataController.Data
	if not profileData or not profileData.WeeklyQuests then
		return
	end

	local weeklyQuests = profileData.WeeklyQuests.Quests
	if not weeklyQuests then
		return
	end

	local maxWeeklyQuests = GameSettings.DailyAndWeeklyQuests.WeeklyMax

	-- Update and show active quest frames
	for i, questPlayerData in ipairs(weeklyQuests) do
		local questFrame = weeklyQuestsFrame:FindFirstChild(tostring(i))
		if questFrame then
			questFrame.Visible = true -- Show active quest
			local questData = QuestUtils.GetQuestByName("Weekly", questPlayerData.Name)
			if questData then
				self:UpdateQuestFrame(questFrame, questData, questPlayerData, "Weekly", i)
			end
		end
	end

	-- Hide unused quest frames
	for i = #weeklyQuests + 1, maxWeeklyQuests do
		local questFrame = weeklyQuestsFrame:FindFirstChild(tostring(i))
		if questFrame then
			questFrame.Visible = false -- Hide unused quest
		end
	end
end

--[[
    Updates a single quest frame
    
    @param questFrame Instance - The UI frame
    @param questData table - Quest definition
    @param questPlayerData table - Player's quest progress
    @param questType string - "Daily", "Weekly", or "SideQuest"
    @param questNum number/string - Quest index (or quest name for SideQuest)
]]
function SideQuestUI:UpdateQuestFrame(questFrame, questData, questPlayerData, questType, questNum)
	-- Update quest name with passive indicator
	local nameLabel = questFrame:FindFirstChild("QuestName")
	if nameLabel then
		-- NEW: Add passive quest indicator
		local questName = questData.DisplayName or questData.Name
		if questData.TrackingMode == "Passive" then
			-- Add "⚙️ Auto" badge for passive quests
			nameLabel.Text = string.format("⚙️ %s", string.format(questName, questData.MaxProgress))
		else
			nameLabel.Text = string.format(questName, questData.MaxProgress)
		end
	end

	-- Update rewards display
	local rewardLabel = questFrame:FindFirstChild("RewardTextLabel")
	if rewardLabel then
		-- Calculate scaled rewards locally (same formula as server)
		local expReward, cashReward = self:CalculateScaledRewards(questType, questData)

		rewardLabel.Text = string.format(
			"REWARD: 💸 %s cash + ✨ %s exp",
			NumberShortener.shortenWith2Decimals(cashReward),
			NumberShortener.shortenWith2Decimals(expReward)
		)
	end

	-- Update progress bar with animation
	local progressBar = questFrame:FindFirstChild("MaxProgressBar")
	if progressBar then
		local progressLabel = progressBar:FindFirstChild("ProgressTextLabel")
		local bar = progressBar:FindFirstChild("ProgressBar")

		-- ⭐ MULTI-TASK SUPPORT: Check if quest uses Tasks array
		if questData.Tasks and questPlayerData.Tasks then
			-- Multi-task quest: Show task completion count (e.g., "2/3 tasks")
			local completedTasks = 0
			local totalTasks = #questData.Tasks

			for i, taskData in ipairs(questPlayerData.Tasks) do
				if taskData.Completed then
					completedTasks = completedTasks + 1
				end
			end

			if progressLabel then
				progressLabel.Text = string.format("%d/%d tasks", completedTasks, totalTasks)
			end

			if bar then
				local progress = totalTasks > 0 and (completedTasks / totalTasks) or 0
				progress = math.clamp(progress, 0, 1)
				ProgressBarAnimator.AnimateProgress(bar, progress)
			end
		else
			-- Legacy single-task quest: Show progress/max progress
			if progressLabel then
				local currentProgress = questPlayerData.Progress or 0
				local maxProgress = questData.MaxProgress or 1
				progressLabel.Text = string.format("%d/%d", currentProgress, maxProgress)
			end

			if bar then
				local currentProgress = questPlayerData.Progress or 0
				local maxProgress = questData.MaxProgress or 1
				local progress = math.clamp(currentProgress / maxProgress, 0, 1)
				ProgressBarAnimator.AnimateProgress(bar, progress)
			end
		end
	end

	-- Update completion status
	local taskImage = questFrame:FindFirstChild("TaskImageLabel")
	if taskImage then
		local completedLabel = taskImage:FindFirstChild("TaskCompletedTextLabel")
		if completedLabel then
			completedLabel.Visible = questPlayerData.Completed
		end

		-- Update image if available
		if questData.Image and questData.Image ~= "rbxassetid://0" then
			taskImage.Image = questData.Image
		end
	end

	-- Setup track button
	local trackButton = questFrame:FindFirstChild("TrackButton")
	if trackButton then
		-- NEW: Pass quest data to check if passive
		self:SetupTrackButton(trackButton, questType, questNum, questData)
	end
end

--[[
    Sets up a track button with rate limiting
    
    @param trackButton Instance - The button instance
    @param questType string - "Daily", "Weekly", or "SideQuest"
    @param questNum number/string - Quest index (or quest name for SideQuest)
    @param questData table - Quest definition (optional, for passive quest check)
]]
function SideQuestUI:SetupTrackButton(trackButton, questType, questNum, questData)
	local buttonKey = questType .. "_" .. questNum

	-- Disconnect old connection if it exists
	if trackButtonConnections[buttonKey] then
		trackButtonConnections[buttonKey]:Disconnect()
		trackButtonConnections[buttonKey] = nil
	end

	-- Get player data to check completion status
	local profileData = DataController.Data
	local questPlayerData

	if profileData then
		if questType == "Daily" and profileData.DailyQuests and profileData.DailyQuests.Quests then
			questPlayerData = profileData.DailyQuests.Quests[questNum]
		elseif questType == "Weekly" and profileData.WeeklyQuests and profileData.WeeklyQuests.Quests then
			questPlayerData = profileData.WeeklyQuests.Quests[questNum]
		elseif questType == "SideQuest" and profileData.SideQuests then
			questPlayerData = profileData.SideQuests[questNum]
		end
	end

	-- Check if quest is completed
	if questPlayerData and questPlayerData.Completed then
		-- Quest is completed - show "Finished" and disable button
		trackButton.Active = false
		trackButton.AutoButtonColor = false
		trackButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0) -- Green
		trackButton.Text = "Finished"
		trackButton.TextColor3 = Color3.fromRGB(255, 255, 255)

		-- Add click sound even for finished quests (in case player clicks)
		trackButtonConnections[buttonKey] = trackButton.MouseButton1Click:Connect(function()
			SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))
		end)

		return -- Don't set up tracking handler
	end

	-- NEW: Check if quest is passive (cannot be tracked)
	if questData and questData.TrackingMode == "Passive" then
		-- Disable button for passive quests
		trackButton.Active = false
		trackButton.AutoButtonColor = false
		trackButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Gray out
		trackButton.Text = "Always Active"
		trackButton.TextColor3 = Color3.fromRGB(200, 200, 200)

		-- Add tooltip behavior (show message on hover) with click sound
		trackButtonConnections[buttonKey] = trackButton.MouseButton1Click:Connect(function()
			SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))
			warn("This quest progresses automatically - no tracking needed!")
		end)

		return -- Don't set up click handler
	end

	-- Active quest - normal button behavior
	trackButton.Active = true
	trackButton.AutoButtonColor = true
	trackButton.BackgroundColor3 = Color3.fromRGB(0, 170, 255) -- Blue
	trackButton.Text = "Track Quest"
	trackButton.TextColor3 = Color3.fromRGB(255, 255, 255)

	-- Create new connection
	trackButtonConnections[buttonKey] = trackButton.MouseButton1Click:Connect(function()
		-- Play click sound
		SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))

		-- Rate limiting
		local now = tick()

		if lastTrackTime[buttonKey] and (now - lastTrackTime[buttonKey]) < TRACK_COOLDOWN then
			warn("Please wait before tracking another quest")
			return
		end

		lastTrackTime[buttonKey] = now

		-- Track the quest via controller
		if QuestController then
			QuestController:TrackSideQuest(questType, questNum)
		end
	end)
end

--[[
    Updates reset timer displays
]]
function SideQuestUI:UpdateResetTimers()
	if not sideQuestsFrame or not DataController then
		return
	end

	local profileData = DataController.Data
	if not profileData then
		return
	end

	local questsFrame = sideQuestsFrame:FindFirstChild("QuestsFrame")
	if not questsFrame then
		return
	end

	-- Update daily reset timer
	local dailyResetLabel = questsFrame:FindFirstChild("DailyResetTimeLabel")
	if dailyResetLabel and profileData.DailyQuests then
		local ONE_DAY_IN_SECONDS = 24 * 60 * 60
		local timePassed = workspace:GetServerTimeNow() - (profileData.DailyQuests.LastResetTime or 0)
		local timeRemaining = math.max(0, ONE_DAY_IN_SECONDS - timePassed)

		dailyResetLabel.Text = TimeFormatter.ToDaysHoursMinutesSeconds(timeRemaining)
	end

	-- Update weekly reset timer
	local weeklyResetLabel = questsFrame:FindFirstChild("WeeklyResetTimeLabel")
	if weeklyResetLabel and profileData.WeeklyQuests then
		local SEVEN_DAYS_IN_SECONDS = 7 * 24 * 60 * 60
		local timePassed = workspace:GetServerTimeNow() - (profileData.WeeklyQuests.LastResetTime or 0)
		local timeRemaining = math.max(0, SEVEN_DAYS_IN_SECONDS - timePassed)

		weeklyResetLabel.Text = TimeFormatter.ToDaysHoursMinutesSeconds(timeRemaining)
	end
end

--[[
    Called when a side quest is completed
    
    @param questType string - "Daily", "Weekly", or "SideQuest"
    @param questNum number|string - Quest index (for Daily/Weekly) or quest name (for SideQuest)
    @param rewards table - Rewards granted
]]
function SideQuestUI:OnQuestCompleted(questType, questNum, rewards)
	-- Refresh UI to show completion immediately
	self:UpdateQuestsList()

	-- Optional: Add completion animation/effect here
	-- For now, the UI update is sufficient
end

--[[
    Called when a quest is tracked
    
    @param questType string - "Daily" or "Weekly"
    @param questNum number - Quest index
]]
function SideQuestUI:OnQuestTracked(questType, questNum)
	-- Update UI to show the tracked quest
	if sideQuestContent then
		-- New tab structure - update side quest display
		self:UpdateSideQuestDisplay()
	else
		-- Legacy structure - update quest list
		self:UpdateQuestsList()
	end
end

--[[
    Starts the reset timer update loop
]]
function SideQuestUI:StartTimerUpdates()
	task.spawn(function()
		while true do
			task.wait(1)
			self:UpdateResetTimers()
		end
	end)
end

--[[
	⭐ MULTI-TASK SUPPORT: Display multiple tasks for a quest
	@param taskContainer Frame - Container for task frames
	@param template Frame - Template for task frames
	@param questDetail table - Quest definition
	@param playerData table - Player's quest progress
]]
function SideQuestUI:DisplayMultiTaskQuest(taskContainer, template, questDetail, playerData)
	if not template then
		return
	end

	-- Get active task index for Sequential mode
	local activeTaskIndex = nil
	if questDetail.TaskMode == "Sequential" then
		-- Find first incomplete task
		for i, taskData in ipairs(playerData.Tasks) do
			if not taskData.Completed then
				activeTaskIndex = i
				break
			end
		end
	end

	-- ⭐ FIX: Remove legacy "QuestTask" frames (migration cleanup)
	local oldQuestTask = taskContainer:FindFirstChild("QuestTask")
	if oldQuestTask then
		oldQuestTask:Destroy()
	end

	-- Clean up excess task frames (if quest has fewer tasks than before)
	local totalTasks = #questDetail.Tasks
	for _, child in ipairs(taskContainer:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:match("^Task_%d+$") then
			local taskNum = tonumber(child.Name:match("%d+"))
			if taskNum and taskNum > totalTasks then
				child:Destroy()
			end
		end
	end

	-- Update or create task frames for each task
	for taskIndex, taskDef in ipairs(questDetail.Tasks) do
		local taskData = playerData.Tasks[taskIndex]
		if not taskData then
			continue -- Skip if task data missing
		end

		-- Try to find existing frame first (to preserve progress bar state for animation)
		local taskFrame = taskContainer:FindFirstChild("Task_" .. taskIndex)

		if not taskFrame then
			-- Create new frame if it doesn't exist
			taskFrame = template:Clone()
			taskFrame.Name = "Task_" .. taskIndex
			taskFrame.Visible = true
			taskFrame.Parent = taskContainer
		end

		local progress = taskData.Progress or 0
		local maxProgress = taskDef.MaxProgress or 1
		local isComplete = taskData.Completed or false
		local isActive = (activeTaskIndex == taskIndex) or (questDetail.TaskMode == "Parallel")

		-- Update description
		local descLabel = taskFrame:FindFirstChild("DescriptionLabel")
		if descLabel then
			-- Display task without numbering
			descLabel.Text = string.format(
				"%s %s",
				isComplete and "✓" or (isActive and "○" or "⊙"), -- ⊙ for locked tasks
				taskDef.DisplayText or taskDef.Description
			)

			-- Color: Green if complete, White if active, Gray if locked
			if isComplete then
				descLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green
			elseif isActive then
				descLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White
			else
				descLabel.TextColor3 = Color3.fromRGB(150, 150, 150) -- Gray (locked)
			end
		end

		-- Update progress label
		local progLabel = taskFrame:FindFirstChild("ProgressLabel")
		if progLabel then
			progLabel.Text = string.format("[%d/%d]", progress, maxProgress)

			if isComplete then
				progLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green
			elseif isActive then
				progLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White
			else
				progLabel.TextColor3 = Color3.fromRGB(150, 150, 150) -- Gray
			end
		end

		-- Update progress bar with animation
		local maxProgressFrame = taskFrame:FindFirstChild("MaxProgressFrame")
		if maxProgressFrame then
			local progressFrame = maxProgressFrame:FindFirstChild("ProgressFrame")
			if progressFrame then
				local progressPercent = maxProgress > 0 and (progress / maxProgress) or 0

				-- Animate the progress bar
				ProgressBarAnimator.AnimateProgress(progressFrame, math.clamp(progressPercent, 0, 1))

				-- Set bar color based on state
				if isComplete then
					progressFrame.BackgroundColor3 = Color3.fromRGB(0, 200, 0) -- Green
				elseif isActive then
					progressFrame.BackgroundColor3 = Color3.fromRGB(100, 150, 255) -- Blue (active)
				else
					progressFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Gray (locked)
				end
			end
		end

		-- Highlight active task frame in Sequential mode
		if questDetail.TaskMode == "Sequential" and isActive then
			taskFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50) -- Slightly brighter background
			taskFrame.BackgroundTransparency = 0.3
		else
			taskFrame.BackgroundTransparency = 0.5
		end
	end
end

--[[
	⭐ MULTI-TASK: Handle task progress update from server
	@param questType string
	@param questNum number/string
	@param taskIndex number
	@param progress number
	@param maxProgress number
	@param completed boolean
]]
function SideQuestUI:OnTaskProgressUpdated(questType, questNum, taskIndex, progress, maxProgress, completed)
	-- Refresh the quest display if this is the currently tracked quest
	if not DataController or not DataController.Data then
		return
	end

	local trackedQuest = DataController.Data.CurrentSideQuestTracked
	if not trackedQuest then
		return
	end

	-- Check if this update is for the currently tracked quest
	if trackedQuest.QuestType == questType and trackedQuest.QuestNum == questNum then
		-- Refresh display to show updated progress
		self:UpdateSideQuestDisplay()
	end
end

--[[
	⭐ MULTI-TASK: Handle task completion from server
	@param questType string
	@param questNum number/string
	@param taskIndex number
	@param allTasksCompleted boolean
]]
function SideQuestUI:OnTaskCompleted(questType, questNum, taskIndex, allTasksCompleted)
	-- Refresh the quest display
	self:OnTaskProgressUpdated(questType, questNum, taskIndex, 0, 0, true)

	-- If all tasks completed, the main quest completion handler will fire separately
	-- So we don't need to do anything extra here
end

--[[
	⭐ MULTI-TASK: Handle task unlock in Sequential mode
	@param questType string
	@param questNum number/string
	@param taskIndex number
]]
function SideQuestUI:OnTaskUnlocked(questType, questNum, taskIndex)
	-- Refresh the quest display to show newly unlocked task
	self:OnTaskProgressUpdated(questType, questNum, taskIndex, 0, 0, false)

	-- Play subtle unlock sound (optional)
	local unlockSound = ReplicatedStorage.Assets.Sounds.Quests.Completed
	if unlockSound then
		SoundPlayer.Play(unlockSound, { Volume = 0.3 }, workspace)
	end
end

function SideQuestUI.Init()
	QuestService = Knit.GetService("QuestService")
	ProfileService = Knit.GetService("ProfileService")
	DataController = Knit.GetController("DataController")
	QuestController = Knit.GetController("QuestController")
end

function SideQuestUI.Start()
	-- Initialize UI after a brief delay to ensure GUI is loaded
	task.delay(1, function()
		SideQuestUI:InitializeUI()
		SideQuestUI:UpdateQuestsList()

		-- Start timer updates if we have the standalone SideQuestsFrame
		if sideQuestsFrame then
			SideQuestUI:StartTimerUpdates()
		end

		-- Listen for profile data updates to refresh UI in real-time
		if ProfileService and ProfileService.UpdateSpecificData then
			ProfileService.UpdateSpecificData:Connect(function(Redirectories, newValue)
				-- Refresh side quest UI when quest data changes
				-- Redirectories is an array like ["DailyQuests"], ["SideQuests"], or ["CurrentSideQuestTracked"]
				if
					Redirectories[1] == "DailyQuests"
					or Redirectories[1] == "WeeklyQuests"
					or Redirectories[1] == "SideQuests"
					or Redirectories[1] == "CurrentSideQuestTracked"
				then
					SideQuestUI:UpdateQuestsList()
				end
			end)
		end
	end)
end

return SideQuestUI
