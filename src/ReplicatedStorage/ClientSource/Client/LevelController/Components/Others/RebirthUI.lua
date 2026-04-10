local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Controllers
local LevelController

---- Config
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

---- Utilities
local RebirthHelpers = require(ReplicatedStorage.SharedSource.Utilities.Levels.RebirthHelpers)
local SoundPlayer = require(ReplicatedStorage.SharedSource.Utilities.Audio.SoundPlayer)

---- Sound References
local Assets = ReplicatedStorage:WaitForChild("Assets", 10)
local Sounds = Assets:WaitForChild("Sounds", 10)
local ClickSound = Sounds:WaitForChild("Click", 10)

---- UI References
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local starterGui = game:GetService("StarterGui")
local rebirthScreenGui = nil
local currentLevelType = nil -- Track which specific level type is currently shown

---- UI Constants
local UI_CONFIG = {
	ScreenGuiName = "RebirthSystemUI",
	MainFrameSize = UDim2.new(0.4, 0, 0.45, 0),
	MainFramePosition = UDim2.new(0.3, 0, 0.275, 0),
	Colors = {
		Background = Color3.fromRGB(20, 20, 20),
		Frame = Color3.fromRGB(40, 40, 40),
		Text = Color3.fromRGB(255, 255, 255),
		ReadyButton = Color3.fromRGB(50, 200, 50),
		NotReadyButton = Color3.fromRGB(100, 100, 100),
		LockedButton = Color3.fromRGB(60, 60, 60),
		Accent = Color3.fromRGB(255, 215, 0),
		Warning = Color3.fromRGB(255, 100, 100),
	},
}

function module.Start()
	-- Connect to data updates
	task.spawn(function()
		task.wait(2) -- Wait for LevelController to initialize
		if LevelController and LevelController.DataChanged then
			LevelController.DataChanged:Connect(function()
				if rebirthScreenGui and rebirthScreenGui.Enabled and currentLevelType then
					module:UpdateLevelTypeDisplay()
				end
			end)
			print("[RebirthUI] Connected to data updates")
		end

		-- Also listen for rebirth events
		if LevelController and LevelController.Rebirthed then
			LevelController.Rebirthed:Connect(function(levelType, newRebirthCount)
				print(string.format("[RebirthUI] Rebirth detected: %s -> %d", levelType, newRebirthCount))
				task.wait(0.5) -- Give time for data to update
				if currentLevelType then
					module:UpdateLevelTypeDisplay()
				end
			end)
		end
	end)
end

function module.Init()
	LevelController = Knit.GetController("LevelController")
end

-- Get or setup the rebirth UI (use existing UI from StarterGui)
function module:SetupRebirthUI()
	-- Check if UI already exists in PlayerGui
	rebirthScreenGui = playerGui:FindFirstChild(UI_CONFIG.ScreenGuiName)

	if not rebirthScreenGui then
		-- Clone from StarterGui
		local templateUI = starterGui:FindFirstChild(UI_CONFIG.ScreenGuiName)
		if templateUI then
			rebirthScreenGui = templateUI:Clone()
			rebirthScreenGui.Parent = playerGui
			print("[RebirthUI] Cloned rebirth UI from StarterGui to PlayerGui")
		else
			warn("[RebirthUI] RebirthSystemUI not found in StarterGui!")
			return
		end
	end

	-- Ensure it starts hidden
	rebirthScreenGui.Enabled = false

	-- Setup close button connection
	local mainFrame = rebirthScreenGui:FindFirstChild("MainFrame")
	if mainFrame then
		local contentFrame = mainFrame:FindFirstChild("ContentFrame")
		if contentFrame then
			local closeButton = contentFrame:FindFirstChild("CloseButton")
			if closeButton and closeButton:IsA("TextButton") then
				closeButton.MouseButton1Click:Connect(function()
					-- Play click sound
					SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))
					
					module:HideRebirthUI()
				end)
			end
		end
	end

	print("[RebirthUI] Rebirth UI setup complete")
end

-- Show rebirth UI for a specific level type
function module:ShowForLevelType(levelType)
	if not rebirthScreenGui then
		self:SetupRebirthUI()
		if not rebirthScreenGui then
			warn("[RebirthUI] Failed to setup UI")
			return
		end
	end

	currentLevelType = levelType

	-- Get level type config
	local typeConfig = LevelingConfig.Types[levelType]
	if not typeConfig then
		warn("[RebirthUI] Invalid level type:", levelType)
		return
	end

	-- Get rebirth configuration for this level type
	local rebirthDisplayName = RebirthHelpers.GetRebirthDisplayName(levelType)

	-- Get main frame and content frame
	local mainFrame = rebirthScreenGui:FindFirstChild("MainFrame")
	if not mainFrame then
		warn("[RebirthUI] MainFrame not found")
		return
	end

	-- Update title (if TitleLabel exists in MainFrame or ContentFrame)
	local titleLabel = mainFrame:FindFirstChild("TitleLabel")
	if titleLabel then
		if rebirthDisplayName ~= "" then
			titleLabel.Text = string.format("⭐ %s - %s ⭐", typeConfig.Name, rebirthDisplayName)
		else
			titleLabel.Text = string.format("⭐ %s Rebirth ⭐", typeConfig.Name)
		end
	end

	-- Get level data
	local levelData = LevelController:GetLevelData(levelType)
	local eligibility = LevelController:GetRebirthEligibility(levelType)

	-- Update subtitle with rebirth count for this specific type (if SubtitleLabel exists)
	local subtitleLabel = mainFrame:FindFirstChild("SubtitleLabel")
	if subtitleLabel and rebirthDisplayName ~= "" then
		local rebirthCount = (levelData and levelData.Rebirths) or 0
		local maxRebirth = typeConfig.MaxRebirth
		if maxRebirth then
			subtitleLabel.Text = string.format("%s Count: %d / %d", rebirthDisplayName, rebirthCount, maxRebirth)
		else
			subtitleLabel.Text = string.format("%s Count: %d", rebirthDisplayName, rebirthCount)
		end
	end

	-- Update existing UI elements in ContentFrame
	local contentFrame = mainFrame:FindFirstChild("ContentFrame")
	if contentFrame then
		self:UpdateExistingUIElements(contentFrame, levelType, eligibility, levelData)
	end

	-- Show UI
	rebirthScreenGui.Enabled = true

	print(string.format("[RebirthUI] Showing rebirth UI for %s", levelType))
end

-- Update existing UI elements with current level type data
function module:UpdateExistingUIElements(contentFrame, levelType, eligibility, levelData)
	if not contentFrame or not levelType then
		return
	end

	local typeCfg = LevelingConfig.Types[levelType]
	if not typeCfg then
		return
	end

	-- Get current data
	local currentLevel = eligibility and eligibility.currentLevel or (levelData and levelData.Level) or 0
	local maxLevel = eligibility and eligibility.maxLevel or 0
	local rebirthCount = eligibility and eligibility.rebirthCount or (levelData and levelData.Rebirths) or 0
	local progress = maxLevel > 0 and (currentLevel / maxLevel) or 0

	-- Update InfoFrame elements
	local infoFrame = contentFrame:FindFirstChild("InfoFrame")
	if infoFrame then
		-- Update current level label
		local currentLevelLabel = infoFrame:FindFirstChild("CurrentLevelLabel")
		if currentLevelLabel then
			currentLevelLabel.Text = string.format("Current Level: %d / %d", currentLevel, maxLevel)
		end

		-- Update progress bar
		local progressBG = infoFrame:FindFirstChild("ProgressBackground")
		if progressBG then
			local progressFill = progressBG:FindFirstChild("ProgressFill")
			if progressFill then
				progressFill.Size = UDim2.new(progress, 0, 1, 0)
				progressFill.BackgroundColor3 = eligibility and eligibility.eligible and UI_CONFIG.Colors.ReadyButton
					or UI_CONFIG.Colors.Accent
			end

			local progressText = progressBG:FindFirstChild("ProgressText")
			if progressText then
				progressText.Text = string.format("%.1f%%", progress * 100)
			end
		end

		-- Update rebirth count label
		local rebirthCountLabel = infoFrame:FindFirstChild("RebirthCountLabel")
		if rebirthCountLabel then
			local maxRebirth = typeCfg.MaxRebirth
			if maxRebirth then
				rebirthCountLabel.Text = string.format("Rebirth: %d / %d", rebirthCount, maxRebirth)
			else
				rebirthCountLabel.Text = string.format("Rebirth: %d", rebirthCount)
			end
		end
	end

	-- Update StatusFrame elements
	local statusFrame = contentFrame:FindFirstChild("StatusFrame")
	if statusFrame then
		local statusLabel = statusFrame:FindFirstChild("StatusLabel")
		if statusLabel then
			if eligibility and eligibility.isMaxRebirth then
				-- Special display for max rebirth reached
				statusLabel.Text = [[🔒 MAX REBIRTH REACHED]]
				statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			elseif eligibility and eligibility.eligible then
				statusLabel.Text = [[✅ Ready to Rebirth!]]
				statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
			else
				local reason = eligibility and eligibility.reason or "Requirements not met"
				statusLabel.Text = "❌ " .. reason
				statusLabel.TextColor3 = UI_CONFIG.Colors.Warning
			end
		end
	end

	-- Update RebirthButton
	local rebirthButton = contentFrame:FindFirstChild("RebirthButton")
	if rebirthButton and rebirthButton:IsA("TextButton") then
		if eligibility and eligibility.isMaxRebirth then
			-- Special styling for max rebirth
			rebirthButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			rebirthButton.Text = "🔒 MAX REACHED"
		elseif eligibility and eligibility.eligible then
			rebirthButton.BackgroundColor3 = UI_CONFIG.Colors.ReadyButton
			local actionName = RebirthHelpers.GetRebirthActionName(currentLevelType)
			rebirthButton.Text = string.format("⭐ %s NOW!", actionName)
		else
			rebirthButton.BackgroundColor3 = UI_CONFIG.Colors.NotReadyButton
			rebirthButton.Text = "🔒 NOT READY"
		end

		local buttonStroke = rebirthButton:FindFirstChild("UIStroke")
		if buttonStroke then
			if eligibility and eligibility.isMaxRebirth then
				buttonStroke.Color = Color3.fromRGB(150, 50, 50)
			elseif eligibility and eligibility.eligible then
				buttonStroke.Color = Color3.fromRGB(80, 80, 80)
			else
				buttonStroke.Color = Color3.fromRGB(80, 80, 80)
			end
		end

		-- Setup button click handler (clear old connections first)
		local connections = rebirthButton:GetAttribute("_connections")
		if not connections then
			rebirthButton.MouseButton1Click:Connect(function()
				-- Play click sound
				SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))
				
				module:OnRebirthClick()
			end)
			rebirthButton:SetAttribute("_connections", true)
		end
	end
end

-- Show a notification popup
function module:ShowNotification(message, notificationType)
	notificationType = notificationType or "error"

	local colors = {
		error = Color3.fromRGB(220, 50, 50),
		warning = Color3.fromRGB(255, 180, 50),
		success = Color3.fromRGB(50, 200, 50),
		info = Color3.fromRGB(80, 150, 255),
	}

	local notification = Instance.new("Frame")
	notification.Name = "Notification"
	notification.Size = UDim2.new(0, 350, 0, 90)
	notification.Position = UDim2.new(0.5, 0, 0.5, 0)
	notification.AnchorPoint = Vector2.new(0.5, 0.5)
	notification.BackgroundColor3 = colors[notificationType] or colors.error
	notification.BorderSizePixel = 0
	notification.ZIndex = 1000
	notification.Parent = playerGui

	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = notification

	-- Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = notification

	-- Icon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 50, 1, 0)
	iconLabel.Position = UDim2.new(0, 0, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.SourceSansBold
	iconLabel.TextSize = 32
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.Text = notificationType == "error" and "⚠️"
		or notificationType == "warning" and "⚠️"
		or notificationType == "success" and "✅"
		or "ℹ️"
	iconLabel.Parent = notification

	-- Message text
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "MessageText"
	textLabel.Size = UDim2.new(1, -60, 1, -10)
	textLabel.Position = UDim2.new(0, 55, 0, 5)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.TextSize = 16
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.TextWrapped = true
	textLabel.Text = message
	textLabel.Parent = notification

	-- Animate in
	notification.BackgroundTransparency = 1
	textLabel.TextTransparency = 1
	iconLabel.TextTransparency = 1
	stroke.Transparency = 1

	local tweenIn = TweenService:Create(
		notification,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.1 }
	)

	local textTweenIn = TweenService:Create(
		textLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	)

	local iconTweenIn = TweenService:Create(
		iconLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	)

	local strokeTweenIn = TweenService:Create(
		stroke,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Transparency = 0 }
	)

	tweenIn:Play()
	textTweenIn:Play()
	iconTweenIn:Play()
	strokeTweenIn:Play()

	-- Auto-dismiss after 4 seconds (in a separate thread)
	task.spawn(function()
		task.wait(3.5)

		local tweenOut = TweenService:Create(
			notification,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)

		local textTweenOut = TweenService:Create(
			textLabel,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		)

		local iconTweenOut = TweenService:Create(
			iconLabel,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		)

		local strokeTweenOut = TweenService:Create(
			stroke,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1 }
		)

		tweenOut:Play()
		textTweenOut:Play()
		iconTweenOut:Play()
		strokeTweenOut:Play()

		tweenOut.Completed:Connect(function()
			notification:Destroy()
		end)
	end)
end

-- Update the display for the current level type
function module:UpdateLevelTypeDisplay()
	if not currentLevelType or not rebirthScreenGui then
		return
	end

	local mainFrame = rebirthScreenGui:FindFirstChild("MainFrame")
	if not mainFrame then
		return
	end

	local contentFrame = mainFrame:FindFirstChild("ContentFrame")
	if not contentFrame then
		return
	end

	-- Get fresh data
	local levelData = LevelController:GetLevelData(currentLevelType)
	local eligibility = LevelController:GetRebirthEligibility(currentLevelType)

	-- Update subtitle
	local subtitleLabel = mainFrame:FindFirstChild("SubtitleLabel")
	if subtitleLabel then
		local rebirthDisplayName = RebirthHelpers.GetRebirthDisplayName(currentLevelType)
		if rebirthDisplayName ~= "" and levelData then
			local rebirthCount = levelData.Rebirths or 0
			local typeConfig = LevelingConfig.Types[currentLevelType]
			local maxRebirth = typeConfig and typeConfig.MaxRebirth
			if maxRebirth then
				subtitleLabel.Text = string.format("%s Count: %d / %d", rebirthDisplayName, rebirthCount, maxRebirth)
			else
				subtitleLabel.Text = string.format("%s Count: %d", rebirthDisplayName, rebirthCount)
			end
		end
	end

	-- Update existing UI elements (no rebuild needed)
	self:UpdateExistingUIElements(contentFrame, currentLevelType, eligibility, levelData)
end

-- Handle rebirth button click
function module:OnRebirthClick()
	if not currentLevelType then
		return
	end

	local eligibility = LevelController:GetRebirthEligibility(currentLevelType)
	local typeConfig = LevelingConfig.Types[currentLevelType]
	local rebirthDisplayName = RebirthHelpers.GetRebirthDisplayName(currentLevelType)

	if not eligibility or not eligibility.eligible then
		-- Show specific notification based on reason
		if eligibility and eligibility.isMaxRebirth then
			-- Special notification for max rebirth reached
			local maxCount = eligibility.maxRebirthCount or "?"
			local message = string.format(
				"You've reached the maximum %s limit!\n%s cannot be performed anymore.",
				rebirthDisplayName ~= "" and rebirthDisplayName or "rebirth",
				rebirthDisplayName ~= "" and rebirthDisplayName or "Rebirth"
			)
			self:ShowNotification(message, "error")
			print("[RebirthUI] Cannot rebirth: Max rebirth limit reached")
		else
			-- Generic notification for other reasons
			local reason = eligibility and eligibility.reason or "Unknown"
			local message = string.format("Cannot rebirth: %s", reason)
			self:ShowNotification(message, "warning")
			print("[RebirthUI] Cannot rebirth:", reason)
		end
		return
	end

	-- Perform rebirth
	print("[RebirthUI] Attempting rebirth for", currentLevelType)

	LevelController:PerformRebirth(currentLevelType)
		:andThen(function(success, message)
			if success then
				print("[RebirthUI] Rebirth successful!", message)
				-- Show success notification
				local successMsg =
					string.format("%s successful! 🎉", rebirthDisplayName ~= "" and rebirthDisplayName or "Rebirth")
				module:ShowNotification(successMsg, "success")
				-- Update UI after a short delay
				task.wait(0.5)
				module:UpdateLevelTypeDisplay()
			else
				warn("[RebirthUI] Rebirth failed:", message)
				module:ShowNotification("Rebirth failed: " .. (message or "Unknown error"), "error")
			end
		end)
		:catch(function(err)
			warn("[RebirthUI] Rebirth error:", err)
			module:ShowNotification("An error occurred during rebirth", "error")
		end)
end

-- Show rebirth UI for a specific level type (main entry point)
function module:ShowRebirthUI(levelType)
	if not levelType then
		warn("[RebirthUI] ShowRebirthUI called without levelType")
		return
	end

	-- Check if rebirth is enabled for this level type
	if not RebirthHelpers.IsRebirthEnabled(levelType) then
		warn(string.format("[RebirthUI] Rebirth is disabled for level type: %s", levelType))
		return
	end

	self:ShowForLevelType(levelType)
end

-- Hide rebirth UI
function module:HideRebirthUI()
	if rebirthScreenGui then
		rebirthScreenGui.Enabled = false
	end
end

return module
