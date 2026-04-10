-- CinematicBars.lua
-- Cinematic bar creation and animation.

local TweenService = game:GetService("TweenService")

local State = require(script.Parent.Parent.State)

local CinematicBars = {}

function CinematicBars.createCinematicBars(config)
	local cinematicBarsValue = config and config:FindFirstChild("CinematicBars")
	if not cinematicBarsValue or not cinematicBarsValue:IsA("BoolValue") or not cinematicBarsValue.Value then
		return false
	end

	local topBar = Instance.new("Frame")
	topBar.Name = "CinematicBarTop"
	topBar.Size = UDim2.new(1, 0, 0.2, 0)
	topBar.Position = UDim2.new(0.5, 0, -0.2, 0)
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	topBar.BorderSizePixel = 0
	topBar.Parent = State.dialogueKitUI

	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "CinematicBarBottom"
	bottomBar.Size = UDim2.new(1, 0, 0.2, 0)
	bottomBar.Position = UDim2.new(0.5, 0, 1.2, 0)
	bottomBar.AnchorPoint = Vector2.new(0.5, 1)
	bottomBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bottomBar.BorderSizePixel = 0
	bottomBar.Parent = State.dialogueKitUI

	State.cinematicBars = { topBar, bottomBar }

	local skin = State.skins[State.currentSkin]
	local hasGradient = skin:FindFirstChild("Gradient") ~= nil

	if hasGradient then
		topBar.BorderSizePixel = 6
		bottomBar.BorderSizePixel = 6
		topBar.BorderColor3 = Color3.fromRGB(0, 0, 0)
		bottomBar.BorderColor3 = Color3.fromRGB(0, 0, 0)

		topBar.ZIndex = -1
		bottomBar.ZIndex = -1

		topBar.Parent = skin
		bottomBar.Parent = skin

		local topStroke = Instance.new("UIStroke")
		topStroke.Color = Color3.fromRGB(255, 255, 255)
		topStroke.Thickness = 3
		topStroke.Parent = topBar

		local bottomStroke = Instance.new("UIStroke")
		bottomStroke.Color = Color3.fromRGB(255, 255, 255)
		bottomStroke.Thickness = 3
		bottomStroke.Parent = bottomBar
	end

	local tweenBars = cinematicBarsValue:GetAttribute("TweenBars")
	if tweenBars then
		local easingStyle = skin:GetAttribute("EasingStyle")
		local easingDirection = skin:GetAttribute("EasingDirection")
		local tweenTime = skin:GetAttribute("TweenTime")

		local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle[easingStyle], Enum.EasingDirection[easingDirection])

		TweenService:Create(topBar, tweenInfo, { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
		TweenService:Create(bottomBar, tweenInfo, { Position = UDim2.new(0.5, 0, 1, 0) }):Play()
	else
		topBar.Position = UDim2.new(0.5, 0, 0, 0)
		bottomBar.Position = UDim2.new(0.5, 0, 1, 0)
	end

	return true
end

return CinematicBars
