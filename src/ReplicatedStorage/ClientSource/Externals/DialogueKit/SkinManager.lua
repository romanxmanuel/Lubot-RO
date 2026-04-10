-- SkinManager.lua
-- Skin initialization and tween utilities for DialogueKit.

local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)

local SkinManager = {}

local function initializeSkin(skinName)
	local skin = State.skins[skinName]
	if not skin then
		warn("Skin not found: " .. tostring(skinName))
		return
	end

	if State.defaultTransparencyValues[skin.Name] then
		return
	end

	skin.Visible = false
	State.defaultTransparencyValues[skin.Name] = {}

	for _, descendant in ipairs(skin:GetDescendants()) do
		if
			descendant:IsA("GuiObject")
			or descendant:IsA("TextLabel")
			or descendant:IsA("TextButton")
			or descendant:IsA("ImageLabel")
			or descendant:IsA("UIStroke")
		then
			local properties = {}

			if descendant:IsA("GuiObject") then
				properties.BackgroundTransparency = descendant.BackgroundTransparency
				descendant.BackgroundTransparency = 1
			end

			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				properties.TextTransparency = descendant.TextTransparency
				descendant.TextTransparency = 1
			end

			if descendant:IsA("ImageLabel") then
				properties.ImageTransparency = descendant.ImageTransparency
				descendant.ImageTransparency = 1
			end

			if descendant:IsA("UIStroke") then
				properties.Transparency = descendant.Transparency
				descendant.Transparency = 1
			end

			if descendant:GetAttribute("GroupTransparency") ~= nil then
				properties.GroupTransparency = descendant:GetAttribute("GroupTransparency")
			end

			State.defaultTransparencyValues[skin.Name][descendant] = properties
		end
	end
end

function SkinManager.initializeSkin(skinName)
	initializeSkin(skinName)
end

function SkinManager.initializeSkins()
	for _, skin in ipairs(State.skins:GetChildren()) do
		initializeSkin(skin.Name)
	end
end

function SkinManager.tweenPosition(element, targetPosition, easingStyle, easingDirection, tweenTime)
	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle[easingStyle], Enum.EasingDirection[easingDirection])
	local tween = TweenService:Create(element, tweenInfo, { Position = targetPosition })
	tween:Play()
	return tween
end

function SkinManager.tweenTransparencyIn(skinName)
	local skin = State.skins[skinName]
	local tweenInfo = TweenInfo.new(
		skin:GetAttribute("TweenTime"),
		Enum.EasingStyle[skin:GetAttribute("EasingStyle")],
		Enum.EasingDirection[skin:GetAttribute("EasingDirection")]
	)

	for descendant, properties in pairs(State.defaultTransparencyValues[skinName]) do
		local tweenGoals = {}

		if properties.BackgroundTransparency ~= nil then
			tweenGoals.BackgroundTransparency = properties.BackgroundTransparency
		end

		if properties.TextTransparency ~= nil then
			tweenGoals.TextTransparency = properties.TextTransparency
		end

		if properties.ImageTransparency ~= nil then
			tweenGoals.ImageTransparency = properties.ImageTransparency
		end

		if properties.Transparency ~= nil then
			tweenGoals.Transparency = properties.Transparency
		end

		if properties.GroupTransparency ~= nil and descendant:IsA("CanvasGroup") then
			tweenGoals.GroupTransparency = properties.GroupTransparency
		end

		TweenService:Create(descendant, tweenInfo, tweenGoals):Play()
	end
end

function SkinManager.tweenTransparencyOut(skinName)
	local skin = State.skins[skinName]
	local tweenInfo = TweenInfo.new(
		skin:GetAttribute("TweenTime"),
		Enum.EasingStyle[skin:GetAttribute("EasingStyle")],
		Enum.EasingDirection[skin:GetAttribute("EasingDirection")]
	)

	for descendant, properties in pairs(State.defaultTransparencyValues[skinName]) do
		local tweenGoals = {}

		if descendant:IsA("GuiObject") then
			tweenGoals.BackgroundTransparency = 1
		end

		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			tweenGoals.TextTransparency = 1
		end

		if descendant:IsA("ImageLabel") then
			tweenGoals.ImageTransparency = 1
		end

		if descendant:IsA("UIStroke") then
			tweenGoals.Transparency = 1
		end

		if properties.GroupTransparency ~= nil and descendant:IsA("CanvasGroup") then
			tweenGoals.GroupTransparency = 1
		end

		TweenService:Create(descendant, tweenInfo, tweenGoals):Play()
	end

	return tweenInfo.Time
end

return SkinManager
