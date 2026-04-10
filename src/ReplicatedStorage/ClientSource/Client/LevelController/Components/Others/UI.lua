local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Controllers
local DataController

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
local mainScreenGui = nil
local openButton = nil -- Reference to the open button
local levelFrames = {}
local originalFrameColors = {} -- Cache original colors

---- UI Constants
local UI_CONFIG = {
	ScreenGuiName = "LevelSystemUI",
	MainFrameSize = UDim2.new(0.4, 0, 0.6, 0), -- Larger: 40% width, 60% height
	MainFramePosition = UDim2.new(0.02, 0, 0.2, 0), -- Left side position
	LevelFrameHeight = 0.4, -- Scale-based height (large for each level type)
	ProgressBarHeight = 0.02, -- Scale-based height
	Colors = {
		Background = Color3.fromRGB(25, 25, 25),
		Frame = Color3.fromRGB(45, 45, 45),
		Text = Color3.fromRGB(255, 255, 255),
		ExpBar = Color3.fromRGB(100, 200, 100),
		ExpBarBG = Color3.fromRGB(50, 50, 50),
		LevelUp = Color3.fromRGB(255, 215, 0),
	},
}

---- Utils

-- Create the open button that appears when UI is closed
function module:BuildOpenButton()
	-- Remove existing button if it exists
	if openButton then
		openButton:Destroy()
	end

	-- Find or create a ScreenGui for the button
	local buttonScreenGui = playerGui:FindFirstChild("LevelButtonGui")
	if not buttonScreenGui then
		buttonScreenGui = Instance.new("ScreenGui")
		buttonScreenGui.Name = "LevelButtonGui"
		buttonScreenGui.ResetOnSpawn = false
		buttonScreenGui.DisplayOrder = 100
		buttonScreenGui.Parent = playerGui
	end

	-- Create button frame
	openButton = Instance.new("TextButton")
	openButton.Name = "LevelOpenButton"
	openButton.Size = UDim2.new(0.06, 0, 0.06, 0) -- Scale only
	openButton.Position = UDim2.new(0.01, 0, 0.01, 0) -- Scale only, positioned at top-left
	openButton.AnchorPoint = Vector2.new(0, 0)
	openButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	openButton.BorderSizePixel = 0
	openButton.Text = "Level"
	openButton.TextScaled = true
	openButton.Font = Enum.Font.SourceSansBold
	openButton.TextColor3 = Color3.fromRGB(0, 0, 0)
	openButton.Visible = false -- Hidden by default when UI is open
	openButton.ZIndex = 1000
	openButton.Parent = buttonScreenGui

	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0) -- Scale-based corner
	corner.Parent = openButton

	-- Add stroke for better visibility
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(200, 170, 0)
	stroke.Thickness = 2
	stroke.Parent = openButton

	-- Add hover effect
	local originalColor = openButton.BackgroundColor3
	local hoverColor = Color3.fromRGB(255, 235, 50)

	openButton.MouseEnter:Connect(function()
		openButton.BackgroundColor3 = hoverColor
	end)

	openButton.MouseLeave:Connect(function()
		openButton.BackgroundColor3 = originalColor
	end)

	-- Click handler to open the UI
	openButton.MouseButton1Click:Connect(function()
		-- Play click sound
		SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))

		if mainScreenGui then
			mainScreenGui.Enabled = true
			openButton.Visible = false
		end
	end)
end

-- Create the main UI structure
function module:BuildMainUI()
	-- Remove existing UI if it exists
	if mainScreenGui then
		mainScreenGui:Destroy()
	end

	-- Create main ScreenGui
	mainScreenGui = Instance.new("ScreenGui")
	mainScreenGui.Name = UI_CONFIG.ScreenGuiName
	mainScreenGui.ResetOnSpawn = false
	mainScreenGui.Parent = playerGui

	-- Create main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UI_CONFIG.MainFrameSize
	mainFrame.Position = UI_CONFIG.MainFramePosition
	mainFrame.BackgroundColor3 = UI_CONFIG.Colors.Background
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = mainScreenGui

	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame

	-- Add title icon
	local titleIcon = Instance.new("ImageLabel")
	titleIcon.Name = "TitleIcon"
	titleIcon.Size = UDim2.new(0.09, 0, 0.128, 0)
	titleIcon.Position = UDim2.new(0.023, 0, 0.016, 0)
	titleIcon.BackgroundTransparency = 1
	titleIcon.Image = "rbxassetid://102080561024780"
	titleIcon.ScaleType = Enum.ScaleType.Fit
	titleIcon.Parent = mainFrame

	-- Add title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(0.58, 0, 0.16, 0)
	titleLabel.Position = UDim2.new(0.129, 0, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Character Levels"
	titleLabel.TextColor3 = UI_CONFIG.Colors.Text
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = mainFrame

	-- Add close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0.1, 0, 0.14, 0)
	closeButton.Position = UDim2.new(0.886, 0, 0.01, 0)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = UI_CONFIG.Colors.Text
	closeButton.TextScaled = true
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.Parent = mainFrame

	-- Add corner radius to close button
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	-- Add hover effect to close button
	local originalCloseColor = closeButton.BackgroundColor3
	local hoverCloseColor = Color3.fromRGB(230, 70, 70)

	closeButton.MouseEnter:Connect(function()
		closeButton.BackgroundColor3 = hoverCloseColor
	end)

	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = originalCloseColor
	end)

	-- Close button functionality
	closeButton.MouseButton1Click:Connect(function()
		-- Play click sound
		SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))

		mainScreenGui.Enabled = false
		if openButton then
			openButton.Visible = true
		end
	end)

	-- No global rebirth button - each level type will have its own

	-- Create scroll frame for level displays
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "LevelScrollFrame"
	scrollFrame.Size = UDim2.new(0.943, 0, 0.76, 0)
	scrollFrame.Position = UDim2.new(0.029, 0, 0.2, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.Parent = mainFrame

	-- Add UIListLayout to scroll frame
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = scrollFrame

	-- Update canvas size when content changes
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end)

	-- Build individual level frames
	self:BuildLevelFrames()

	-- Build the open button
	self:BuildOpenButton()
end

-- Build individual level display frames
function module:BuildLevelFrames()
	if not mainScreenGui then
		return
	end

	local scrollFrame = mainScreenGui.MainFrame.LevelScrollFrame
	levelFrames = {}

	-- Clear existing frames
	for _, child in pairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:sub(-10) == "LevelFrame" then
			child:Destroy()
		end
	end

	-- Get all level types from config
	local allData = self:_GetLevelController():GetAllLevelData()

	for levelType, data in pairs(allData) do
		local levelFrame = self:CreateLevelFrame(levelType, data)
		levelFrame.Parent = scrollFrame
		levelFrames[levelType] = levelFrame
	end
end

-- Create a single level display frame
function module:CreateLevelFrame(levelType, data)
	local levelFrame = Instance.new("Frame")
	levelFrame.Name = levelType .. "LevelFrame"
	levelFrame.Size = UDim2.new(1, 0, UI_CONFIG.LevelFrameHeight, 0)
	levelFrame.BackgroundColor3 = UI_CONFIG.Colors.Frame
	levelFrame.BorderSizePixel = 0

	-- Cache the original color for this level type
	originalFrameColors[levelType] = UI_CONFIG.Colors.Frame

	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = levelFrame

	-- Level type name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.36, 0, 0.31, 0)
	nameLabel.Position = UDim2.new(0.03, 0, 0.06, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = data.Name or levelType
	nameLabel.TextColor3 = UI_CONFIG.Colors.Text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextScaled = true
	nameLabel.Parent = levelFrame

	-- Level display label
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0.3, 0, 0.31, 0)
	levelLabel.Position = UDim2.new(0.667, 0, 0.06, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Lv. " .. (data.Level or 1)
	levelLabel.TextColor3 = UI_CONFIG.Colors.Text
	levelLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel.Font = Enum.Font.SourceSans
	levelLabel.TextScaled = true
	levelLabel.Parent = levelFrame

	-- Rebirth display label
	local rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "RebirthLabel"
	rebirthLabel.Size = UDim2.new(0.45, 0, 0.25, 0)
	rebirthLabel.Position = UDim2.new(0.03, 0, 0.375, 0)
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.Text = self:_GetRebirthText(levelType, data)
	rebirthLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthLabel.Font = Enum.Font.SourceSansBold
	rebirthLabel.TextScaled = true
	rebirthLabel.Parent = levelFrame

	-- Experience progress bar background
	local progressBG = Instance.new("Frame")
	progressBG.Name = "ProgressBarBG"
	progressBG.Size = UDim2.new(0.94, 0, 0.1, 0)
	progressBG.Position = UDim2.new(0.03, 0, 0.775, 0)
	progressBG.BackgroundColor3 = UI_CONFIG.Colors.ExpBarBG
	progressBG.BorderSizePixel = 0
	progressBG.Parent = levelFrame

	-- Progress bar corner
	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 4)
	progressCorner.Parent = progressBG

	-- Experience progress bar
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(0, 0, 1, 0)
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3 = UI_CONFIG.Colors.ExpBar
	progressBar.BorderSizePixel = 0
	progressBar.Parent = progressBG

	-- Progress bar corner
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = progressBar

	-- Experience text label
	local expLabel = Instance.new("TextLabel")
	expLabel.Name = "ExpLabel"
	expLabel.Size = UDim2.new(0.57, 0, 0.1875, 0)
	expLabel.Position = UDim2.new(0.03, 0, 0.5875, 0)
	expLabel.BackgroundTransparency = 1
	expLabel.Text = string.format("%d/%d %s", data.Exp or 0, data.MaxExp or 100, data.ExpName or "EXP")
	expLabel.TextColor3 = UI_CONFIG.Colors.Text
	expLabel.TextXAlignment = Enum.TextXAlignment.Left
	expLabel.Font = Enum.Font.SourceSans
	expLabel.TextScaled = true
	expLabel.Parent = levelFrame

	-- Rebirth button for this level type (only show if rebirth is enabled)
	if RebirthHelpers.IsRebirthEnabled(levelType) then
		local rebirthButton = Instance.new("TextButton")
		rebirthButton.Name = "RebirthButton"
		rebirthButton.Size = UDim2.new(0.35, 0, 0.25, 0)
		rebirthButton.Position = UDim2.new(0.63, 0, 0.35, 0)
		rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
		rebirthButton.Text = RebirthHelpers.GetRebirthButtonText(levelType)
		rebirthButton.TextColor3 = Color3.fromRGB(0, 0, 0)
		rebirthButton.TextScaled = true
		rebirthButton.Font = Enum.Font.SourceSansBold
		rebirthButton.Parent = levelFrame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = rebirthButton

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = Color3.fromRGB(200, 170, 0)
		btnStroke.Thickness = 1.5
		btnStroke.Parent = rebirthButton

		-- Button click handler - opens rebirth UI for this specific level type
		rebirthButton.MouseButton1Click:Connect(function()
			-- Play click sound
			SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))

			local LevelController = self:_GetLevelController()
			if LevelController then
				LevelController:ShowRebirthUI(levelType)
			end
		end)
	end

	return levelFrame
end

-- Update all level displays
function module:UpdateAllDisplays()
	if not mainScreenGui then
		return
	end

	local allData = self:_GetLevelController():GetAllLevelData()

	for levelType, data in pairs(allData) do
		if levelFrames[levelType] then
			self:UpdateLevelDisplay(levelType, data)
		else
			-- Create new frame if it doesn't exist
			local scrollFrame = mainScreenGui.MainFrame.LevelScrollFrame
			local newFrame = self:CreateLevelFrame(levelType, data)
			newFrame.Parent = scrollFrame
			levelFrames[levelType] = newFrame
		end
	end
end

-- Update a specific level display
function module:UpdateLevelDisplay(levelType, data)
	local levelFrame = levelFrames[levelType]
	if not levelFrame then
		return
	end

	-- Update level label
	local levelLabel = levelFrame:FindFirstChild("LevelLabel")
	if levelLabel then
		local formattedLevel = self:_GetLevelController().GetComponent:GetFormattedLevel(levelType)
		levelLabel.Text = "Lv. " .. formattedLevel
	end

	-- Update rebirth label
	local rebirthLabel = levelFrame:FindFirstChild("RebirthLabel")
	if rebirthLabel then
		rebirthLabel.Text = self:_GetRebirthText(levelType, data)
	end

	-- Update exp label
	local expLabel = levelFrame:FindFirstChild("ExpLabel")
	if expLabel then
		local formattedExp = self:_GetLevelController().GetComponent:GetFormattedExp(levelType)
		expLabel.Text = formattedExp
	end

	-- Update progress bar
	local progressBar = levelFrame:FindFirstChild("ProgressBarBG"):FindFirstChild("ProgressBar")
	if progressBar then
		local progress = self:_GetLevelController().GetComponent:GetProgressPercent(levelType)

		-- Animate progress bar
		local tween = TweenService:Create(
			progressBar,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(progress, 0, 1, 0) }
		)
		tween:Play()
	end
end

-- Show level up effect
function module:ShowLevelUpEffect(levelType, newLevel)
	local levelFrame = levelFrames[levelType]
	if not levelFrame then
		return
	end

	-- Create level up notification
	local notification = Instance.new("TextLabel")
	notification.Name = "LevelUpNotification"
	notification.Size = UDim2.new(1, 0, 1, 0)
	notification.Position = UDim2.new(0, 0, 0, 0)
	notification.BackgroundColor3 = UI_CONFIG.Colors.LevelUp
	notification.BackgroundTransparency = 0.2
	notification.Text = "LEVEL UP!"
	notification.TextColor3 = Color3.fromRGB(0, 0, 0)
	notification.TextScaled = true
	notification.Font = Enum.Font.SourceSansBold
	notification.Parent = levelFrame

	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = notification

	-- Animate level up effect
	notification.BackgroundTransparency = 1
	notification.TextTransparency = 1

	local showTween = TweenService:Create(
		notification,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.2, TextTransparency = 0 }
	)

	local hideTween = TweenService:Create(
		notification,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1, TextTransparency = 1 }
	)

	showTween:Play()
	showTween.Completed:Connect(function()
		task.wait(1)
		hideTween:Play()
		hideTween.Completed:Connect(function()
			notification:Destroy()
		end)
	end)

	-- Flash the level frame using cached original color
	local originalColor = originalFrameColors[levelType] or UI_CONFIG.Colors.Frame

	-- Flash to yellow
	local flashToYellow = TweenService:Create(
		levelFrame,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = UI_CONFIG.Colors.LevelUp }
	)

	-- Flash back to original
	local flashToOriginal = TweenService:Create(
		levelFrame,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundColor3 = originalColor }
	)

	flashToYellow:Play()
	flashToYellow.Completed:Connect(function()
		flashToOriginal:Play()
	end)
end

-- Toggle UI visibility
function module:ToggleUI()
	if mainScreenGui then
		mainScreenGui.Enabled = not mainScreenGui.Enabled
		-- Update open button visibility
		if openButton then
			openButton.Visible = not mainScreenGui.Enabled
		end
	end
end

-- Helper to get rebirth text
function module:_GetRebirthText(levelType, data)
	local displayName = RebirthHelpers.GetRebirthDisplayName(levelType)
	if displayName == "" then
		return ""
	end
	local rebirthCount = data.Rebirths or 0
	return string.format("⭐ %s: %d", displayName, rebirthCount)
end

-- Helper to get LevelController reference
function module:_GetLevelController()
	return Knit.GetController("LevelController")
end

function module.Start()
	-- No-op
end

function module.Init()
	DataController = Knit.GetController("DataController")
end

return module
