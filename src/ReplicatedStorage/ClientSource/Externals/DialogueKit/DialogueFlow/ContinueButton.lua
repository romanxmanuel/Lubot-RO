-- ContinueButton.lua
-- Continue button show/hide with tween animations.

local TweenService = game:GetService("TweenService")

local State = require(script.Parent.Parent.State)

local ContinueButton = {}

-- Hub reference (injected by init.lua)
ContinueButton.Flow = nil

function ContinueButton.showContinueButton()
	local continueButton = State.skins[State.currentSkin].Continue.ContinueButton
	local skin = State.skins[State.currentSkin]
	local tweenInfo = TweenInfo.new(
		skin:GetAttribute("TweenTime"),
		Enum.EasingStyle[skin:GetAttribute("EasingStyle")],
		Enum.EasingDirection[skin:GetAttribute("EasingDirection")]
	)

	local originalTextTransparency = State.defaultTransparencyValues[State.currentSkin][continueButton].TextTransparency
		or 0
	local originalBackgroundTransparency = State.defaultTransparencyValues[State.currentSkin][continueButton].BackgroundTransparency
		or 0

	continueButton.Active = true

	TweenService
		:Create(
			continueButton,
			tweenInfo,
			{ TextTransparency = originalTextTransparency, BackgroundTransparency = originalBackgroundTransparency }
		)
		:Play()

	local continuePosition = skin:GetAttribute("ContinuePosition")
	if continuePosition then
		local easingStyle = skin:GetAttribute("EasingStyle")
		local easingDirection = skin:GetAttribute("EasingDirection")
		local tweenTime = skin:GetAttribute("TweenTime")

		ContinueButton.Flow.SkinManager.tweenPosition(skin, continuePosition, easingStyle, easingDirection, tweenTime)
	end
end

function ContinueButton.hideContinueButton()
	local continueButton = State.skins[State.currentSkin].Continue.ContinueButton
	local skin = State.skins[State.currentSkin]
	local tweenInfo = TweenInfo.new(
		skin:GetAttribute("TweenTime"),
		Enum.EasingStyle[skin:GetAttribute("EasingStyle")],
		Enum.EasingDirection[skin:GetAttribute("EasingDirection")]
	)

	continueButton.Active = false

	local transparencyWhenUnclickable = 1
	if State.currentDialogue and State.currentDialogue.Config then
		local continueButtonConfig = State.currentDialogue.Config:FindFirstChild("ContinueButton")
		if continueButtonConfig then
			local configValue = continueButtonConfig:GetAttribute("TransparencyWhenUnclickable")
			if configValue ~= nil then
				transparencyWhenUnclickable = configValue
			end
		end
	end

	TweenService
		:Create(
			continueButton,
			tweenInfo,
			{ TextTransparency = transparencyWhenUnclickable, BackgroundTransparency = 1 }
		)
		:Play()

	if skin:GetAttribute("ContinuePosition") then
		local openPosition = skin:GetAttribute("OpenPosition")
		local easingStyle = skin:GetAttribute("EasingStyle")
		local easingDirection = skin:GetAttribute("EasingDirection")
		local tweenTime = skin:GetAttribute("TweenTime")

		if not State.isShowingReplies then
			ContinueButton.Flow.SkinManager.tweenPosition(skin, openPosition, easingStyle, easingDirection, tweenTime)
		end
	end

	return tweenInfo.Time
end

return ContinueButton
