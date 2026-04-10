--[[
	QuestSideTabToggler.lua
	
	Manages collapsing and expanding the QuestFrame side panel.
	Features a toggle button with "<" and ">" symbols that tweens the panel in/out.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

---- Utilities
local Utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
local SoundPlayer = require(Utilities:WaitForChild("Audio"):WaitForChild("SoundPlayer", 10))

---- Sound References
local Assets = ReplicatedStorage:WaitForChild("Assets", 10)
local Sounds = Assets:WaitForChild("Sounds", 10)
local ClickSound = Sounds:WaitForChild("Click", 10)

local QuestSideTabToggler = {}

---- Player Reference
local player = Players.LocalPlayer

---- UI References
local questGui
local questFrame
local toggleButton

---- State
local isExpanded = true -- Start expanded by default
local isTweening = false -- Prevent overlapping tweens

---- Configuration
local TWEEN_DURATION = 0.5
local TWEEN_EASING_STYLE = Enum.EasingStyle.Quad
local TWEEN_EASING_DIRECTION = Enum.EasingDirection.Out

-- Positions (scale-based, no offsets)
-- QuestFrame actual size: {0.184, 0}, {0.23, 0}
local EXPANDED_POSITION = UDim2.new(0.816, 0, 0.282, 0) -- Original position
local COLLAPSED_POSITION = UDim2.new(1.0, 0, 0.282, 0) -- Right at the screen edge, button visible

--[[
	Initializes UI references and creates the toggle button
]]
function QuestSideTabToggler:InitializeUI()
	local playerGui = player:WaitForChild("PlayerGui")
	if not playerGui then
		warn("[QuestSideTabToggler] PlayerGui not found")
		return
	end
	
	questGui = playerGui:FindFirstChild("QuestGui") or playerGui:WaitForChild("QuestGui")
	if not questGui then
		warn("[QuestSideTabToggler] QuestGui not found")
		return
	end
	
	questFrame = questGui:FindFirstChild("QuestFrame")
	if not questFrame then
		warn("[QuestSideTabToggler] QuestFrame not found")
		return
	end
	
	-- Set initial position (expanded by default)
	questFrame.AnchorPoint = Vector2.new(0, 0) -- Anchor to top-left
	questFrame.Position = EXPANDED_POSITION
	
	-- Create or find toggle button
	toggleButton = questFrame:FindFirstChild("ToggleButton")
	if not toggleButton then
		self:CreateToggleButton()
	end
	
	-- Setup button connection
	if toggleButton then
		self:SetupButtonConnection()
	end
end

--[[
	Creates the toggle button if it doesn't exist
]]
function QuestSideTabToggler:CreateToggleButton()
	toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.Size = UDim2.new(0.12, 0, 0.15, 0) -- Larger button using scale
	toggleButton.Position = UDim2.new(-0.12, 0, 0.5, 0) -- Left side of QuestFrame
	toggleButton.AnchorPoint = Vector2.new(0, 0.5)
	toggleButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	toggleButton.BorderSizePixel = 0
	toggleButton.Text = "<"
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.TextScaled = true
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.AutoButtonColor = false
	toggleButton.ZIndex = 10
	
	-- Add rounded corners
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = toggleButton
	
	-- Add stroke for better visibility
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(100, 100, 100)
	uiStroke.Thickness = 2
	uiStroke.Transparency = 0.3
	uiStroke.Parent = toggleButton
	
	toggleButton.Parent = questFrame
	
	-- Add hover effect
	toggleButton.MouseEnter:Connect(function()
		if not isTweening then
			local tween = TweenService:Create(
				toggleButton,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{ BackgroundColor3 = Color3.fromRGB(50, 50, 50) }
			)
			tween:Play()
		end
	end)
	
	toggleButton.MouseLeave:Connect(function()
		if not isTweening then
			local tween = TweenService:Create(
				toggleButton,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad),
				{ BackgroundColor3 = Color3.fromRGB(35, 35, 35) }
			)
			tween:Play()
		end
	end)
end

--[[
	Sets up the button click connection
]]
function QuestSideTabToggler:SetupButtonConnection()
	if not toggleButton then
		return
	end
	
	toggleButton.MouseButton1Click:Connect(function()
		if not isTweening then
			-- Play click sound
			SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))
			
			-- Toggle the panel
			self:TogglePanel()
		end
	end)
end

--[[
	Toggles the panel between expanded and collapsed states
]]
function QuestSideTabToggler:TogglePanel()
	if isTweening then
		return -- Prevent overlapping animations
	end
	
	isTweening = true
	isExpanded = not isExpanded
	
	-- Determine target position
	local targetPosition = isExpanded and EXPANDED_POSITION or COLLAPSED_POSITION
	
	-- Update button text
	toggleButton.Text = isExpanded and "<" or ">"
	
	-- Create tween for the panel
	local tweenInfo = TweenInfo.new(TWEEN_DURATION, TWEEN_EASING_STYLE, TWEEN_EASING_DIRECTION)
	local panelTween = TweenService:Create(questFrame, tweenInfo, {
		Position = targetPosition
	})
	
	-- Animate button with slight scale effect
	local buttonTween = TweenService:Create(toggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
		Size = UDim2.new(0.14, 0, 0.17, 0)
	})
	buttonTween:Play()
	buttonTween.Completed:Connect(function()
		local resetTween = TweenService:Create(toggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = UDim2.new(0.12, 0, 0.15, 0)
		})
		resetTween:Play()
	end)
	
	-- Play the panel tween
	panelTween:Play()
	panelTween.Completed:Connect(function()
		isTweening = false
	end)
end

--[[
	Expands the panel (if collapsed)
]]
function QuestSideTabToggler:Expand()
	if isExpanded or isTweening then
		return
	end
	
	self:TogglePanel()
end

--[[
	Collapses the panel (if expanded)
]]
function QuestSideTabToggler:Collapse()
	if not isExpanded or isTweening then
		return
	end
	
	self:TogglePanel()
end

--[[
	Gets the current state of the panel
	
	@return boolean - true if expanded, false if collapsed
]]
function QuestSideTabToggler:IsExpanded()
	return isExpanded
end

function QuestSideTabToggler.Start()
	-- Initialize UI after a brief delay to ensure GUI is loaded
	task.delay(0.5, function()
		QuestSideTabToggler:InitializeUI()
	end)
end

function QuestSideTabToggler.Init()
	-- No Knit services needed for this component
end

return QuestSideTabToggler

