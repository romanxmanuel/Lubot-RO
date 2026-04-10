--[[
    MainQuestUI.lua
    
    Handles main quest UI display and updates.
    Separated from animation logic for cleaner architecture.
    
    Phase 11: Client UI Refactoring
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Knit = require(ReplicatedStorage.Packages.Knit)

local MainQuestUI = {}

---- Knit Services
local QuestService
local ProfileService

---- Knit Controllers
local DataController
local QuestController

---- Utilities
local Utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
local QuestUtils = require(Utilities:WaitForChild("QuestUtils", 10))
local NumberShortener = require(Utilities:WaitForChild("Number", 10):WaitForChild("NumberShortener", 10))
local ProgressBarAnimator = require(Utilities:WaitForChild("ProgressBarAnimator", 10))

---- UI References
local questGui
local mainQuestFrame
local mainQuestContent

---- Quest tracking
local currentQuestNum = nil -- Track which quest is currently displayed
local isFirstLoad = true -- Track if this is the first time loading quests
local isAnimatingNewQuest = false -- Track if add quest animation is currently playing
local isAnimatingQuestCompletion = false -- Track if completion animation is currently playing

--[[
    Initializes UI references
]]
function MainQuestUI:InitializeUI()
	local playerGui = player:WaitForChild("PlayerGui")
	if not playerGui then
		warn("PlayerGui not found")
		return
	end

	questGui = playerGui:WaitForChild("QuestGui")
	if questGui then
		mainQuestFrame = questGui:WaitForChild("QuestFrame")
		if not mainQuestFrame then
			warn("QuestFrame not found in QuestGui")
		else
			-- Get MainQuestContent container
			mainQuestContent = mainQuestFrame:WaitForChild("MainQuestContent")
			if not mainQuestContent then
				warn("MainQuestContent not found in QuestFrame")
				return
			end

			-- Initialize reward labels to default "--" state
			local rewardEXPLabel = mainQuestContent:WaitForChild("RewardEXPLabel")
			local rewardCashLabel = mainQuestContent:WaitForChild("RewardCashLabel")
			if rewardEXPLabel then
				rewardEXPLabel.Text = "--"
			end
			if rewardCashLabel then
				rewardCashLabel.Text = "--"
			end
		end
	else
		warn("QuestGui not found")
	end
end

--[[
    Updates the main quest display with current progress
]]
function MainQuestUI:UpdateQuestDisplay()
	-- Skip updates while add quest animation is playing
	if isAnimatingNewQuest then
		return
	end

	-- Skip updates while completion animation is playing
	if isAnimatingQuestCompletion then
		return
	end

	if not mainQuestContent or not DataController then
		return
	end

	local profileData = DataController.Data
	if not profileData or not profileData.MainQuests then
		return
	end

	local mainQuests = profileData.MainQuests
	local questNum = mainQuests.QuestNum
	local questDetail = QuestUtils.GetMainQuestByNum(questNum)

	-- Check if player has completed all quests
	if not questDetail then
		self:ShowAllQuestsCompleteMessage()
		return
	end

	-- Ensure quest frame is visible (in case it was hidden by completion animation)
	if mainQuestFrame then
		mainQuestFrame.Visible = true
	end

	-- Hide completion message if it exists (player has active quests)
	self:HideAllQuestsCompleteMessage()

	-- Update rewards display using MainQuestContent structure
	local rewardEXPLabel = mainQuestContent:WaitForChild("RewardEXPLabel")
	local rewardCashLabel = mainQuestContent:WaitForChild("RewardCashLabel")

	if questDetail.Rewards then
		if rewardEXPLabel then
			if questDetail.Rewards.EXP and questDetail.Rewards.EXP > 0 then
				rewardEXPLabel.Text = "+" .. NumberShortener.shorten(questDetail.Rewards.EXP) .. " EXP"
			else
				rewardEXPLabel.Text = "--"
			end
		end

		if rewardCashLabel then
			if questDetail.Rewards.Cash and questDetail.Rewards.Cash > 0 then
				rewardCashLabel.Text = "$" .. NumberShortener.shorten(questDetail.Rewards.Cash)
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

	local rewardLabel = mainQuestContent:WaitForChild("RewardLabel")
	if rewardLabel then
		rewardLabel.Text = string.format("Quest #%d Rewards:", questNum)
	end

	-- Update task progress in TaskContainer using Template
	local taskContainer = mainQuestContent:WaitForChild("TaskContainer")
	if taskContainer and questDetail.Tasks then
		-- Find template
		local template = taskContainer:WaitForChild("Template")
		if not template then
			warn("[MainQuestUI] Template not found in TaskContainer")
			return
		end

		-- Check if quest changed
		local questChanged = currentQuestNum ~= questNum and not isFirstLoad

		if questChanged then
			-- Quest actually changed (not first load) - clear ALL old task frames
			for _, child in ipairs(taskContainer:GetChildren()) do
				if child:IsA("GuiObject") and child.Name:match("^Task_%d+$") and child.Name ~= "Template" then
					child:Destroy()
				end
			end
			currentQuestNum = questNum

			-- Set animation flag to prevent updates during animation
			isAnimatingNewQuest = true

			-- Trigger "add quest" animation for new quest
			if QuestController and QuestController.Components and QuestController.Components.QuestAnimations then
				task.spawn(function()
					QuestController.Components.QuestAnimations:PlayAddQuestAnimation(
						"Main",
						questNum,
						questDetail,
						mainQuests
					)

					-- Calculate total animation duration
					-- Reward animation (0.4s) + (tasks * (animation 0.4s + pause 0.3s))
					local rewardAnimDuration = 0.4
					local perTaskDuration = 0.4 + 0.3
					local totalDuration = rewardAnimDuration + (#questDetail.Tasks * perTaskDuration)

					-- Wait for animation to complete, then re-enable updates
					task.wait(totalDuration + 0.1) -- Add small buffer
					isAnimatingNewQuest = false

					-- Now refresh display to ensure it's up to date
					MainQuestUI:UpdateQuestDisplay()
				end)
			else
				-- Animation not available, reset flag immediately
				isAnimatingNewQuest = false
			end
			-- Return early - animation will handle display
			return
		elseif isFirstLoad and currentQuestNum ~= questNum then
			-- First load - clear old frames but don't animate
			for _, child in ipairs(taskContainer:GetChildren()) do
				if child:IsA("GuiObject") and child.Name:match("^Task_%d+$") and child.Name ~= "Template" then
					child:Destroy()
				end
			end
			currentQuestNum = questNum
			isFirstLoad = false
		else
			-- Same quest - only clear excess task frames
			for _, child in ipairs(taskContainer:GetChildren()) do
				if child:IsA("GuiObject") and child.Name:match("^Task_%d+$") and child.Name ~= "Template" then
					-- Parse the task number from the name
					local taskNum = tonumber(child.Name:match("%d+"))
					-- Remove if this task number exceeds current quest's task count
					if taskNum and taskNum > #questDetail.Tasks then
						child:Destroy()
					end
				end
			end
		end

		-- Update or create task displays from template
		for i, task in ipairs(questDetail.Tasks) do
			local playerProgress = mainQuests.Tasks[i] and mainQuests.Tasks[i].Progress or 0
			local isComplete = playerProgress >= task.MaxProgress

			-- Try to find existing task frame
			local taskFrame = taskContainer:FindFirstChild("Task_" .. i)
			local isNewFrame = false

			if not taskFrame then
				-- Create new frame from template
				taskFrame = template:Clone()
				taskFrame.Name = "Task_" .. i
				taskFrame.Visible = true
				taskFrame.Parent = taskContainer
				isNewFrame = true
			end

			-- Update description
			local descLabel = taskFrame:WaitForChild("DescriptionLabel")
			if descLabel then
				-- Use DisplayText if available, otherwise format Description with MaxProgress
				local displayText = task.DisplayText or string.format(task.Description, task.MaxProgress)
				descLabel.Text = string.format("%s %s", isComplete and "✓" or "○", displayText)
				descLabel.TextColor3 = isComplete and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
			end

			-- Update progress label
			local progLabel = taskFrame:WaitForChild("ProgressLabel")
			if progLabel then
				progLabel.Text = string.format("[%d/%d]", playerProgress, task.MaxProgress)
				progLabel.TextColor3 = isComplete and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
			end

			-- Update progress bar with animation
			local maxProgressFrame = taskFrame:WaitForChild("MaxProgressFrame")
			if maxProgressFrame then
				local progressFrame = maxProgressFrame:WaitForChild("ProgressFrame")
				if progressFrame then
					local progressPercent = math.clamp(playerProgress / task.MaxProgress, 0, 1)

					if isNewFrame then
						-- New frame, set progress instantly (no animation)
						ProgressBarAnimator.SetProgressInstant(progressFrame, progressPercent)
					else
						-- Existing frame, animate from current to new progress
						ProgressBarAnimator.AnimateProgress(progressFrame, progressPercent)
					end
				end
			end
		end

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
    Called when a main quest is completed
    
    @param questNum number - Quest index
    @param rewards table - Rewards granted
]]
function MainQuestUI:OnQuestCompleted(questNum, rewards)
	-- Refresh UI to show completion immediately
	self:UpdateQuestDisplay()

	-- Optional: Add completion animation/effect here
	-- For now, the UI update is sufficient
end

--[[
    Sets the completion animation flag to prevent UI updates during animation
]]
function MainQuestUI:SetCompletionAnimationPlaying(isPlaying)
	isAnimatingQuestCompletion = isPlaying
	if not isPlaying then
		-- Animation finished, refresh display
		self:UpdateQuestDisplay()
	end
end

--[[
    Refreshes the quest UI from server
]]
function MainQuestUI:RefreshFromServer()
	if QuestService and DataController then
		local questNum = QuestService:GetCurrentMainQuestNum(player)
		if questNum then
			self:UpdateQuestDisplay()
		end
	end
end

--[[
    Shows "All Quests Complete" message
]]
function MainQuestUI:ShowAllQuestsCompleteMessage()
	if not mainQuestContent then
		return
	end

	-- Ensure quest frame is visible (in case it was hidden by completion animation)
	if mainQuestFrame then
		mainQuestFrame.Visible = true
	end

	-- Hide normal quest elements
	local taskContainer = mainQuestContent:FindFirstChild("TaskContainer")
	local rewardLabel = mainQuestContent:FindFirstChild("RewardLabel")
	local rewardEXPLabel = mainQuestContent:FindFirstChild("RewardEXPLabel")
	local rewardCashLabel = mainQuestContent:FindFirstChild("RewardCashLabel")
	local cashImage = mainQuestContent:FindFirstChild("CashImage")
	local separatorTextLabel = mainQuestContent:FindFirstChild("SeperatorTextLabel")

	if taskContainer then
		taskContainer.Visible = false
	end
	if rewardLabel then
		rewardLabel.Visible = false
	end
	if rewardEXPLabel then
		rewardEXPLabel.Visible = false
	end
	if rewardCashLabel then
		rewardCashLabel.Visible = false
	end
	if cashImage then
		cashImage.Visible = false
	end
	if separatorTextLabel then
		separatorTextLabel.Visible = false
	end

	-- Check if completion message already exists
	local completionMessage = mainQuestContent:FindFirstChild("AllQuestsCompleteLabel")
	if completionMessage then
		completionMessage.Visible = true
		return
	end

	-- Create completion message
	completionMessage = Instance.new("TextLabel")
	completionMessage.Name = "AllQuestsCompleteLabel"
	completionMessage.Size = UDim2.new(1, -20, 0, 60)
	completionMessage.Position = UDim2.new(0.5, 0, 0.5, 0)
	completionMessage.AnchorPoint = Vector2.new(0.5, 0.5)
	completionMessage.BackgroundTransparency = 1
	completionMessage.Text = "✓ ALL QUESTS COMPLETE!"
	completionMessage.TextColor3 = Color3.fromRGB(0, 255, 0)
	completionMessage.TextScaled = true
	completionMessage.Font = Enum.Font.GothamBold
	completionMessage.TextWrapped = true
	completionMessage.TextXAlignment = Enum.TextXAlignment.Center
	completionMessage.TextYAlignment = Enum.TextYAlignment.Center

	-- Add black UIStroke
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(0, 0, 0)
	uiStroke.Thickness = 2
	uiStroke.Transparency = 0
	uiStroke.Parent = completionMessage

	completionMessage.Parent = mainQuestContent
end

--[[
    Hides "All Quests Complete" message
]]
function MainQuestUI:HideAllQuestsCompleteMessage()
	if not mainQuestContent then
		return
	end

	-- Show normal quest elements
	local taskContainer = mainQuestContent:FindFirstChild("TaskContainer")
	local rewardLabel = mainQuestContent:FindFirstChild("RewardLabel")
	local rewardEXPLabel = mainQuestContent:FindFirstChild("RewardEXPLabel")
	local rewardCashLabel = mainQuestContent:FindFirstChild("RewardCashLabel")
	local cashImage = mainQuestContent:FindFirstChild("CashImage")
	local separatorTextLabel = mainQuestContent:FindFirstChild("SeperatorTextLabel")

	if taskContainer then
		taskContainer.Visible = true
	end
	if rewardLabel then
		rewardLabel.Visible = true
	end
	if rewardEXPLabel then
		rewardEXPLabel.Visible = true
	end
	if rewardCashLabel then
		rewardCashLabel.Visible = true
	end
	if cashImage then
		cashImage.Visible = true
	end
	if separatorTextLabel then
		separatorTextLabel.Visible = true
	end

	-- Hide completion message
	local completionMessage = mainQuestContent:FindFirstChild("AllQuestsCompleteLabel")
	if completionMessage then
		completionMessage.Visible = false
	end
end

function MainQuestUI.Init()
	QuestService = Knit.GetService("QuestService")
	ProfileService = Knit.GetService("ProfileService")
	DataController = Knit.GetController("DataController")
	QuestController = Knit.GetController("QuestController")
end

function MainQuestUI.Start()
	-- Initialize UI after ensuring data is loaded
	task.spawn(function()
		-- Wait for UI to be ready
		task.wait(1)
		MainQuestUI:InitializeUI()

		-- Wait for profile data to be loaded before updating display
		if DataController then
			DataController:WaitUntilProfileLoaded()
		end

		-- Now update the display with actual data
		MainQuestUI:UpdateQuestDisplay()

		-- Listen for profile data updates to refresh UI in real-time
		if ProfileService and ProfileService.UpdateSpecificData then
			ProfileService.UpdateSpecificData:Connect(function(Redirectories, newValue)
				-- Refresh main quest UI when MainQuests data changes
				if Redirectories[1] == "MainQuests" then
					MainQuestUI:UpdateQuestDisplay()
				end
			end)
		end
	end)
end

return MainQuestUI
