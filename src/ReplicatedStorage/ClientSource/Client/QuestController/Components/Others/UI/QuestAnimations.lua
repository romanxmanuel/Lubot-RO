--[[
    QuestAnimations.lua
    
    Handles quest completion animations.
    Separated from business logic for cleaner architecture.
    
    Implements the "dope" main quest completion animation with:
    - 4-phase animation sequence (scale up, move, scale 2x, fade out)
    - Parallel EXP and Cash reward animations
    - Sound effects at key moments
    - Quest frame hiding during animation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestAnimations = {}

---- Module-level variables
local questGui
local rewardFrame
local questFrame
local questSoundFolder
local appearedEffectsFolder

---- Knit references (initialized in .Init())
local QuestService
local QuestController
local QuestTabManager
local MainQuestUI

---- Utilities
local Utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
local NumberShortener = require(Utilities:WaitForChild("Number"):WaitForChild("NumberShortener", 10))

---- Animation Settings
local TWEEN_DURATION_1 = 2 -- Resize from small to big
local TWEEN_DURATION_2 = 0.75 -- Resize + move to target (Back easing)
local TWEEN_DURATION_3 = 0.5 -- Scale up to 2x
local TWEEN_DURATION_4 = 1 -- Fade out

---- Helper Functions (defined before public methods)

--[[
    Gets or creates the Debris folder in SoundService
    @return Folder - The Debris folder
]]
local function getDebrisFolder()
	local debris = SoundService:FindFirstChild("Debris")
	if not debris then
		debris = Instance.new("Folder")
		debris.Name = "Debris"
		debris.Parent = SoundService
	end
	return debris
end

--[[
    Plays a sound by cloning it and parenting to SoundService/Debris
    The sound will automatically be destroyed after it finishes playing
    @param sound Sound - The sound to play
]]
local function playSound(sound)
	if not sound then
		return
	end

	local soundClone = sound:Clone()
	soundClone.Parent = getDebrisFolder()
	soundClone:Play()

	-- Fallback cleanup in case Ended doesn't fire (safety measure)
	task.delay(sound.TimeLength + 5, function()
		if soundClone and soundClone.Parent then
			soundClone:Destroy()
		end
	end)
end

--[[
    Initializes UI and sound references
    Called from .Start() method during component lifecycle
]]
local function initializeUI()
	local playerGui = player:WaitForChild("PlayerGui")
	if not playerGui then
		return
	end

	questGui = playerGui:FindFirstChild("QuestGui") or playerGui:WaitForChild("QuestGui")
	if questGui then
		rewardFrame = questGui:FindFirstChild("RewardFrame")
		questFrame = questGui:FindFirstChild("QuestFrame")
		appearedEffectsFolder = questGui:FindFirstChild("AppearedEffects")

		if rewardFrame then
			rewardFrame.Visible = false
		end
	end

	-- Load sound assets
	local Assets = ReplicatedStorage:WaitForChild("Assets")
	if Assets then
		local Sounds = Assets:WaitForChild("Sounds")
		if Sounds then
			questSoundFolder = Sounds:WaitForChild("Quests")
			if questSoundFolder then
				-- Preload all quest sounds on initialization to prevent playback issues
				local ContentProvider = game:GetService("ContentProvider")
				local soundsToPreload = {}

				-- Collect all sound objects
				for _, sound in ipairs(questSoundFolder:GetChildren()) do
					if sound:IsA("Sound") then
						table.insert(soundsToPreload, sound)
					end
				end

				-- Preload them asynchronously
				if #soundsToPreload > 0 then
					task.spawn(function()
						pcall(function()
							ContentProvider:PreloadAsync(soundsToPreload)
						end)
					end)
				end
			end
		end
	end
end

--[[
    Helper function: Resize and center frame
    @param frame Instance - The GUI frame to resize
    @param originalPosition UDim2 - Original position
    @param originalSize UDim2 - Original size
    @param scaleFactor number - Scale multiplier
    @param getOnlyFutureProperties boolean - If true, only return values without setting
    @return UDim2, UDim2 - New position and size
]]
local function resizeAndCenter(frame, originalPosition, originalSize, scaleFactor, getOnlyFutureProperties)
	local newSize = UDim2.new(originalSize.X.Scale * scaleFactor, 0, originalSize.Y.Scale * scaleFactor, 0)

	local positionAdjustmentX = (originalSize.X.Scale - newSize.X.Scale) / 2
	local positionAdjustmentY = (originalSize.Y.Scale - newSize.Y.Scale) / 2

	local newPosition =
		UDim2.new(originalPosition.X.Scale + positionAdjustmentX, 0, originalPosition.Y.Scale + positionAdjustmentY, 0)

	if not getOnlyFutureProperties then
		frame.Size = newSize
		frame.Position = newPosition
	end

	return newPosition, newSize
end

--[[
    EXP Reward Animation
    @param expAmount number - Amount of EXP awarded
]]
local function rewardEXPAnimation(expAmount)
	local originalPosition = UDim2.new(0.258, 0, 0.424, 0)
	local originalSize = UDim2.new(0.192, 0, 0.103, 0)

	local targetLabel = rewardFrame:FindFirstChild("RewardEXPLabel")
	if not targetLabel then
		return
	end

	-- Set initial state
	targetLabel.TextTransparency = 0
	local uiStroke = targetLabel:FindFirstChild("UIStroke")
	if uiStroke then
		uiStroke.Transparency = 0
	end
	targetLabel.Size = originalSize
	targetLabel.Position = originalPosition
	targetLabel.Text = "+" .. NumberShortener.shorten(expAmount) .. " EXP"

	-- Phase 1: Start small, scale to original size
	resizeAndCenter(targetLabel, originalPosition, originalSize, 0.25)
	local pos, size = resizeAndCenter(targetLabel, originalPosition, originalSize, 1, true)

	local tween = TweenService:Create(
		targetLabel,
		TweenInfo.new(TWEEN_DURATION_1, Enum.EasingStyle.Quad),
		{ Position = pos, Size = size }
	)
	tween:Play()
	task.wait(TWEEN_DURATION_1)

	-- Phase 2: Move to target position with Back easing (left side of screen for EXP)
	local originalPosition2 = UDim2.new(0.05, 0, 0.1, 0) -- Left side of screen
	pos, size = resizeAndCenter(targetLabel, originalPosition2, originalSize, 0.6, true)

	tween = TweenService:Create(
		targetLabel,
		TweenInfo.new(TWEEN_DURATION_2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Position = pos, Size = size }
	)
	tween:Play()
	task.wait(TWEEN_DURATION_2)

	-- Phase 3: Scale up to 2x
	pos, size = resizeAndCenter(targetLabel, originalPosition2, originalSize, 2, true)
	tween = TweenService:Create(
		targetLabel,
		TweenInfo.new(TWEEN_DURATION_3, Enum.EasingStyle.Quad),
		{ Position = pos, Size = size }
	)
	tween:Play()
	task.wait(TWEEN_DURATION_3)

	-- Phase 4: Fade out
	tween = TweenService:Create(
		targetLabel,
		TweenInfo.new(TWEEN_DURATION_4, Enum.EasingStyle.Quad),
		{ TextTransparency = 1 }
	)
	tween:Play()

	if uiStroke then
		local strokeTween =
			TweenService:Create(uiStroke, TweenInfo.new(TWEEN_DURATION_4, Enum.EasingStyle.Quad), { Transparency = 1 })
		strokeTween:Play()
	end
	task.wait(TWEEN_DURATION_4)
end

--[[
    Cash Reward Animation
    @param cashAmount number - Amount of Cash awarded
]]
local function rewardCashAnimation(cashAmount)
	local originalPosition = UDim2.new(0.597, 0, 0.424, 0)
	local originalSize = UDim2.new(0.142, 0, 0.103, 0)

	local targetLabel = rewardFrame:FindFirstChild("RewardCashLabel")
	if not targetLabel then
		return
	end

	local cashImage = targetLabel:FindFirstChild("CashImage")

	-- Set initial state
	targetLabel.TextTransparency = 0
	local uiStroke = targetLabel:FindFirstChild("UIStroke")
	if uiStroke then
		uiStroke.Transparency = 0
	end
	targetLabel.Size = originalSize
	targetLabel.Position = originalPosition
	targetLabel.Text = "$" .. NumberShortener.shorten(cashAmount)

	if cashImage then
		cashImage.Visible = true
	end

	-- Phase 1: Start small, scale to original size
	resizeAndCenter(targetLabel, originalPosition, originalSize, 0.25)
	local pos, size = resizeAndCenter(targetLabel, originalPosition, originalSize, 1, true)

	local tween = TweenService:Create(
		targetLabel,
		TweenInfo.new(TWEEN_DURATION_1, Enum.EasingStyle.Quad),
		{ Position = pos, Size = size }
	)
	tween:Play()
	task.wait(TWEEN_DURATION_1)

	-- Phase 2: Move to target position with Back easing (CurrencyFrame at bottom-right)
	local originalPosition2 = UDim2.new(0.825, 0, 0.925, 0) -- Bottom-right corner where CurrencyFrame is located
	pos, size = resizeAndCenter(targetLabel, originalPosition2, originalSize, 0.6, true)

	tween = TweenService:Create(
		targetLabel,
		TweenInfo.new(TWEEN_DURATION_2, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Position = pos, Size = size }
	)
	tween:Play()
	task.wait(TWEEN_DURATION_2)

	-- Hide cash image after phase 2
	if cashImage then
		cashImage.Visible = false
	end

	-- Phase 3: Scale up to 2x
	pos, size = resizeAndCenter(targetLabel, originalPosition2, originalSize, 2, true)
	tween = TweenService:Create(
		targetLabel,
		TweenInfo.new(TWEEN_DURATION_3, Enum.EasingStyle.Quad),
		{ Position = pos, Size = size }
	)
	tween:Play()
	task.wait(TWEEN_DURATION_3)

	-- Phase 4: Fade out
	tween = TweenService:Create(
		targetLabel,
		TweenInfo.new(TWEEN_DURATION_4, Enum.EasingStyle.Quad),
		{ TextTransparency = 1 }
	)
	tween:Play()

	if uiStroke then
		local strokeTween =
			TweenService:Create(uiStroke, TweenInfo.new(TWEEN_DURATION_4, Enum.EasingStyle.Quad), { Transparency = 1 })
		strokeTween:Play()
	end
	task.wait(TWEEN_DURATION_4)
end

---- Public Methods

--[[
    Main completion animation sequence
    @param questNum number - The completed quest number
    @param rewards table - Rewards data {EXP = number, Cash = number}
]]
function QuestAnimations:PlayCompletionAnimation(questNum, rewards)
	if not rewardFrame then
		-- Notify controller immediately so quest can advance
		if QuestController then
			QuestController:NotifyQuestAnimationComplete(questNum)
		end
		return
	end

	if not rewards or not rewards.EXP or not rewards.Cash then
		-- Notify controller immediately so quest can advance
		if QuestController then
			QuestController:NotifyQuestAnimationComplete(questNum)
		end
		return
	end

	-- Notify MainQuestUI that completion animation is starting
	if MainQuestUI then
		MainQuestUI:SetCompletionAnimationPlaying(true)
	end

	-- Spawn animation in a separate thread to avoid blocking
	task.spawn(function()
		-- Hide quest frame, show reward frame
		if questFrame then
			questFrame.Visible = false
		end

		rewardFrame.Visible = true

		local seperatorLabel = rewardFrame:FindFirstChild("SeperatorTextLabel")
		if seperatorLabel then
			seperatorLabel.Visible = true
		end

		-- Start both animations in parallel
		task.spawn(function()
			rewardEXPAnimation(rewards.EXP)
		end)
		task.spawn(function()
			rewardCashAnimation(rewards.Cash)
		end)

		-- Play start sound (with loading check)
		if questSoundFolder then
			local startSound = questSoundFolder:FindFirstChild("QuestRewardStart")
			if startSound then
				playSound(startSound)

				-- Small wait to ensure sound starts playing
				task.wait(0.05)
			end
		end

		task.wait(TWEEN_DURATION_1)

		-- Hide separator after phase 1
		if seperatorLabel then
			seperatorLabel.Visible = false
		end

		task.wait(TWEEN_DURATION_2)

		-- Play end sound (with loading check)
		if questSoundFolder then
			local endSound = questSoundFolder:FindFirstChild("QuestRewardEnd")
			if endSound then
				playSound(endSound)

				-- Small wait to ensure sound starts playing before animation ends
				task.wait(0.05)
			end
		end

		task.wait(TWEEN_DURATION_3 + TWEEN_DURATION_4)

		-- Hide reward frame
		rewardFrame.Visible = false

		-- Don't show quest frame here - the add quest animation will handle it
		-- (The server will trigger a profile update that starts the next quest)

		-- Notify controller that animation is complete
		if QuestController then
			QuestController:NotifyQuestAnimationComplete(questNum)
		end

		-- Notify MainQuestUI that completion animation is finished
		-- This will trigger UpdateQuestDisplay to show the quest frame again
		if MainQuestUI then
			MainQuestUI:SetCompletionAnimationPlaying(false)
		end
	end)
end

--[[
    Plays the "add new quest" animation when a new quest is started
    This animates each task frame bouncing in one by one
    
    @param questType string - "Main" or "Side" - The type of quest being added
    @param questNum number - The quest number being added
    @param questDetail table - Quest definition with Tasks and Rewards
    @param questData table - Player's quest profile data
]]
function QuestAnimations:PlayAddQuestAnimation(questType, questNum, questDetail, questData)
	if not questFrame or not questDetail or not questData then
		return
	end

	-- Switch to appropriate tab based on quest type
	if QuestTabManager then
		if questType == "Main" then
			QuestTabManager:SwitchToTab("Main")
		elseif questType == "Side" then
			QuestTabManager:SwitchToTab("Side")
		end
	end

	-- Get appropriate quest content container based on type
	local questContent
	if questType == "Main" then
		questContent = questFrame:FindFirstChild("MainQuestContent")
	elseif questType == "Side" then
		questContent = questFrame:FindFirstChild("SideQuestContent")
	end

	if not questContent then
		return
	end

	local taskContainer = questContent:FindFirstChild("TaskContainer")
	if not taskContainer then
		return
	end

	local template = taskContainer:FindFirstChild("Template")
	if not template then
		return
	end

	-- Ensure template is hidden
	template.Visible = false

	-- Animation settings
	local tweenDuration = 0.4
	local tweenDuration2 = 0.4
	local pause = 0.3

	-- Make sure quest frame is visible
	questFrame.Visible = true

	-- Update reward label text
	local rewardLabel = questContent:FindFirstChild("RewardLabel")
	if rewardLabel then
		if questType == "Main" then
			rewardLabel.Text = string.format("Quest #%d Rewards:", questNum)
		elseif questType == "Side" then
			rewardLabel.Text = "Side Quest Rewards:"
		end
	end

	-- Update rewards display with bounce animation
	local rewardEXPLabel = questContent:FindFirstChild("RewardEXPLabel")
	local rewardCashLabel = questContent:FindFirstChild("RewardCashLabel")
	local cashImage = questContent:FindFirstChild("CashImage")

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
	end

	-- Animate reward labels bouncing in
	-- Store current positions and sizes (where they should end up)
	local rewardLabels = {
		["RewardEXPLabel"] = rewardEXPLabel,
		["RewardCashLabel"] = rewardCashLabel,
	}

	local originalProps = {}
	local compressedProps = {}

	-- Capture current properties and calculate compressed state
	for key, label in pairs(rewardLabels) do
		if label then
			-- Store original properties
			originalProps[key] = {
				Position = label.Position,
				Size = label.Size,
			}

			-- Calculate compressed state (0.25x size, moved off to side)
			local compressedSize = UDim2.new(
				label.Size.X.Scale * 0.25,
				label.Size.X.Offset * 0.25,
				label.Size.Y.Scale * 0.25,
				label.Size.Y.Offset * 0.25
			)

			local compressedPosition
			if key == "RewardEXPLabel" then
				-- Move left
				compressedPosition = UDim2.new(
					label.Position.X.Scale - 0.15,
					label.Position.X.Offset,
					label.Position.Y.Scale,
					label.Position.Y.Offset
				)
			else -- RewardCashLabel
				-- Move right
				compressedPosition = UDim2.new(
					label.Position.X.Scale + 0.15,
					label.Position.X.Offset,
					label.Position.Y.Scale,
					label.Position.Y.Offset
				)
			end

			compressedProps[key] = {
				Position = compressedPosition,
				Size = compressedSize,
			}
		end
	end

	-- Apply initial compressed state and tween to normal
	for key, label in pairs(rewardLabels) do
		if label and originalProps[key] and compressedProps[key] then
			-- Set to compressed state
			label.Size = compressedProps[key].Size
			label.Position = compressedProps[key].Position

			-- Animate to original state
			local tween = TweenService:Create(label, TweenInfo.new(tweenDuration, Enum.EasingStyle.Bounce), {
				Size = originalProps[key].Size,
				Position = originalProps[key].Position,
			})
			tween:Play()
		end
	end

	task.wait(tweenDuration)

	-- Animate each task frame appearing one by one
	-- For Main Quests: Iterate through Tasks array
	-- For Side Quests: Check if multi-task or single-task
	local tasksToAnimate = {}

	if questType == "Main" and questDetail.Tasks then
		-- Main Quest: Multiple tasks
		for i, taskData in ipairs(questDetail.Tasks) do
			local playerProgress = questData.Tasks[i] and questData.Tasks[i].Progress or 0
			table.insert(tasksToAnimate, {
				Index = i,
				Description = taskData.DisplayText or string.format(taskData.Description, taskData.MaxProgress),
				Progress = playerProgress,
				MaxProgress = taskData.MaxProgress,
				IsComplete = playerProgress >= taskData.MaxProgress,
			})
		end
	elseif questType == "Side" then
		-- ⭐ MULTI-TASK SUPPORT: Check if side quest has Tasks array
		if questDetail.Tasks and questData.Tasks then
			-- Multi-task side quest: Iterate through tasks
			for i, taskDef in ipairs(questDetail.Tasks) do
				local taskData = questData.Tasks[i]
				if taskData then
					local playerProgress = taskData.Progress or 0
					table.insert(tasksToAnimate, {
						Index = i,
						Description = taskDef.DisplayText or taskDef.Description,
						Progress = playerProgress,
						MaxProgress = taskDef.MaxProgress or 1,
						IsComplete = taskData.Completed or false,
					})
				end
			end
		else
			-- Legacy single-task side quest
			local playerProgress = questData.Progress or 0
			local maxProgress = questDetail.MaxProgress or 1
			table.insert(tasksToAnimate, {
				Index = 1,
				Description = questDetail.DisplayName or questDetail.Description or questDetail.Name,
				Progress = playerProgress,
				MaxProgress = maxProgress,
				IsComplete = questData.Completed or false,
			})
		end
	end

	for _, taskInfo in ipairs(tasksToAnimate) do
		local i = taskInfo.Index

		-- Find or create task frame
		-- ⭐ FIX: Always use "Task_" + index naming to prevent duplicates
		local taskFrameName = "Task_" .. i
		local taskFrame = taskContainer:FindFirstChild(taskFrameName)
		if not taskFrame then
			taskFrame = template:Clone()
			taskFrame.Name = taskFrameName
			taskFrame.Visible = false -- Hide immediately after cloning
			taskFrame.Parent = taskContainer
		else
			-- If frame already exists, make sure it's hidden
			taskFrame.Visible = false
		end

		-- Start with enlarged size (1.606x)
		taskFrame.Size = UDim2.new(1.606, 0, 1.606, 0)

		-- Update description
		local descLabel = taskFrame:FindFirstChild("DescriptionLabel")
		if descLabel then
			descLabel.Text = string.format("%s %s", taskInfo.IsComplete and "✓" or "○", taskInfo.Description)
			descLabel.TextColor3 = taskInfo.IsComplete and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
		end

		-- Update progress label
		local progLabel = taskFrame:FindFirstChild("ProgressLabel")
		if progLabel then
			progLabel.Text = string.format("[%d/%d]", taskInfo.Progress, taskInfo.MaxProgress)
			progLabel.TextColor3 = taskInfo.IsComplete and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
		end

		-- Update progress bar (instant, no animation for initial display)
		local maxProgressFrame = taskFrame:FindFirstChild("MaxProgressFrame")
		if maxProgressFrame then
			local progressFrame = maxProgressFrame:FindFirstChild("ProgressFrame")
			if progressFrame then
				local progressPercent = math.clamp(taskInfo.Progress / taskInfo.MaxProgress, 0, 1)
				progressFrame.Size = UDim2.new(progressPercent, 0, 1, 0)
			end
		end

		-- Create white flash effect (if AppearedEffects folder exists)
		local appearedEffectFrame
		if appearedEffectsFolder then
			appearedEffectFrame = appearedEffectsFolder:FindFirstChild(tostring(i))
			if not appearedEffectFrame then
				local template = appearedEffectsFolder:FindFirstChild("Template")
				if template then
					appearedEffectFrame = template:Clone()
					appearedEffectFrame.Name = tostring(i)
					appearedEffectFrame.Parent = appearedEffectsFolder
				end
			end

			if appearedEffectFrame then
				-- Setup effect frame to match task frame position
				appearedEffectFrame.Visible = true
				appearedEffectFrame.BackgroundTransparency = 0
				appearedEffectFrame.Position = UDim2.new(0, 0, 0, taskFrame.AbsolutePosition.Y)
				appearedEffectFrame.Size = UDim2.new(1, 0, 0, taskFrame.AbsoluteSize.Y)
			end
		end

		-- Create the animation tween BEFORE showing the frame
		local tween = TweenService:Create(
			taskFrame,
			TweenInfo.new(tweenDuration2, Enum.EasingStyle.Bounce),
			{ Size = UDim2.new(1, 0, 1, 0) }
		)

		-- Show frame and immediately start animation (minimizes visible time at wrong size)
		taskFrame.Visible = true
		tween:Play()

		-- Animate white flash effect tracking the task frame position
		if appearedEffectFrame then
			task.spawn(function()
				-- Fade effect from opaque to transparent
				local effectTween = TweenService:Create(
					appearedEffectFrame,
					TweenInfo.new(tweenDuration2, Enum.EasingStyle.Quad),
					{ BackgroundTransparency = 1 }
				)
				effectTween:Play()

				-- Track task frame position during bounce animation
				local RunService = game:GetService("RunService")
				while tween.PlaybackState == Enum.PlaybackState.Playing do
					appearedEffectFrame.Position = UDim2.new(0, 0, 0, taskFrame.AbsolutePosition.Y)
					appearedEffectFrame.Size = UDim2.new(1, 0, 0, taskFrame.AbsoluteSize.Y)
					RunService.RenderStepped:Wait()
				end

				-- Hide effect after animation completes
				appearedEffectFrame.Visible = false
			end)
		end

		-- Play sound effect
		if questSoundFolder then
			local newTaskSound = questSoundFolder:FindFirstChild("NewTaskAdded")
			if newTaskSound then
				playSound(newTaskSound)
			end
		end

		task.wait(tweenDuration2)
		task.wait(pause)
	end
end

--[[
    Plays a quest start animation
    
    @param questNum number - The started quest number
]]
function QuestAnimations:PlayQuestStartAnimation(questNum)
	-- Optional: Add quest start animation here
end

--[[
    Plays a progress update animation
    
    @param taskDescription string - The task that progressed
    @param currentProgress number - Current progress value
    @param maxProgress number - Max progress value
]]
function QuestAnimations:PlayProgressAnimation(taskDescription, currentProgress, maxProgress)
	-- Optional: Add progress animation here
	-- Could be a small popup showing "+1 Progress" etc.
end

--[[
    Plays a side quest tracked animation
    
    @param questType string - "Daily" or "Weekly"
    @param questNum number - Quest index
]]
function QuestAnimations:PlayQuestTrackedAnimation(questType, questNum)
	-- Optional: Add tracking animation here
end

---- Component Lifecycle Methods (MUST BE AT END)

--[[
    Component Start - Called after all .Init() methods complete
    Use for: UI setup, event connections, final initialization
]]
function QuestAnimations.Start()
	-- Initialize UI references and sounds
	initializeUI()

	-- Get component references
	if QuestController and QuestController.Components then
		QuestTabManager = QuestController.Components.QuestTabManager
		MainQuestUI = QuestController.Components.MainQuestUI
	end
end

--[[
    Component Init - Called during componentsInitializer(script)
    Use ONLY for: Knit.GetService() and Knit.GetController() calls
]]
function QuestAnimations.Init()
	-- Get required Knit references
	QuestService = Knit.GetService("QuestService")
	QuestController = Knit.GetController("QuestController")

	-- Get QuestTabManager component if available
	-- Note: This is a component, not a Knit controller
	-- We'll check if it exists in Start() instead
end

return QuestAnimations
