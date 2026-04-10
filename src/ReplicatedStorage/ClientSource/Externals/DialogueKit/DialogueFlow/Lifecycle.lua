-- Lifecycle.lua
-- Core dialogue lifecycle: close, continue clicked, and CreateDialogue entry point.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local State = require(script.Parent.Parent.State)

local Lifecycle = {}

-- Hub reference (injected by init.lua)
Lifecycle.Flow = nil

function Lifecycle.closeDialogue()
	if not State.currentSkin then
		return
	end

	if State.typewriterThread then
		State.isTyping = false
		task.cancel(State.typewriterThread)
	end

	if State.activeDialogueSound then
		State.activeDialogueSound:Stop()
		State.activeDialogueSound:Destroy()
		State.activeDialogueSound = nil
	end

	local dialogueSound = SoundService:FindFirstChild("DialogueKit")
	if dialogueSound and dialogueSound:FindFirstChild("TypewriterSound") then
		dialogueSound.TypewriterSound:Stop()
	end

	Lifecycle.Flow.clearReplyConnections()
	State.isShowingReplies = false

	if State.contentClickConnection then
		State.contentClickConnection:Disconnect()
		State.contentClickConnection = nil
	end

	if State.continueConnection then
		State.continueConnection:Disconnect()
		State.continueConnection = nil
	end

	Lifecycle.Flow.InputHandler.teardownInputHandling()
	Lifecycle.Flow.InputHandler.teardownMouseClickHandling()

	local continueButton = State.skins[State.currentSkin].Continue.ContinueButton
	continueButton.Active = false
	Lifecycle.Flow.hideContinueButton()

	local repliesContainer = State.skins[State.currentSkin].Replies
	for _, child in ipairs(repliesContainer:GetChildren()) do
		if child:IsA("Frame") or child:IsA("CanvasGroup") then
			child:Destroy()
		end
	end

	local skin = State.skins[State.currentSkin]
	local closedPosition = skin:GetAttribute("ClosedPosition")
	local easingStyle = skin:GetAttribute("EasingStyle")
	local easingDirection = skin:GetAttribute("EasingDirection")
	local tweenTime = skin:GetAttribute("TweenTime")

	local tweenDuration = Lifecycle.Flow.SkinManager.tweenTransparencyOut(State.currentSkin)

	Lifecycle.Flow.SkinManager.tweenPosition(skin, closedPosition, easingStyle, easingDirection, tweenTime)

	local gradient = skin:FindFirstChild("Gradient")
	if gradient then
		local gradientClosedPosition = gradient:GetAttribute("ClosedPosition")
		if gradientClosedPosition then
			local tweenInfo =
				TweenInfo.new(tweenTime, Enum.EasingStyle[easingStyle], Enum.EasingDirection[easingDirection])
			TweenService:Create(gradient, tweenInfo, { Position = gradientClosedPosition }):Play()
		end
	end

	if #State.cinematicBars == 2 then
		local topBar = State.cinematicBars[1]
		local bottomBar = State.cinematicBars[2]

		local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle[easingStyle], Enum.EasingDirection[easingDirection])

		TweenService:Create(topBar, tweenInfo, { Position = UDim2.new(0.5, 0, -0.2, 0) }):Play()
		TweenService:Create(bottomBar, tweenInfo, { Position = UDim2.new(0.5, 0, 1.2, 0) }):Play()

		task.delay(tweenTime, function()
			topBar:Destroy()
			bottomBar:Destroy()
			State.cinematicBars = {}
		end)
	end

	if State.currentDialogue and State.currentDialogue.Config then
		Lifecycle.Flow.restorePlayerSettings(State.currentDialogue.Config)
	end

	task.delay(tweenDuration, function()
		State.currentDialogue = nil
		State.currentLayer = nil
		State.currentContentIndex = nil
		State.currentSkin = nil
		skin.Visible = false
	end)
end

function Lifecycle.onContinueButtonClicked()
	if
		not State.currentDialogue
		or not State.currentLayer
		or not State.currentContentIndex
		or not State.currentSkin
	then
		return
	end

	if State.isTyping then
		local config = State.currentDialogue.Config
		local continueButtonConfig = config and config:FindFirstChild("ContinueButton")
		local functionalDuringTypewriter = continueButtonConfig
			and continueButtonConfig:GetAttribute("FunctionalDuringTypewriter")

		if functionalDuringTypewriter then
			Lifecycle.Flow.Typewriter.skipTypewriter()
		end
		return
	end

	local continueExecs = Lifecycle.Flow.findExecForContinue(State.currentContentIndex)
	if continueExecs then
		for _, execData in ipairs(continueExecs) do
			Lifecycle.Flow.executeLayerFunction(execData)
		end
	end

	local layerData = State.currentDialogue.Layers[State.currentLayer]

	if not layerData or not layerData.Dialogue then
		warn("Invalid layer data")
		Lifecycle.Flow.closeDialogue()
		return
	end

	local dialogueCount = #layerData.Dialogue

	if State.currentContentIndex >= dialogueCount then
		if layerData.Replies and next(layerData.Replies) ~= nil then
			Lifecycle.Flow.showReplies()
		else
			Lifecycle.Flow.closeDialogue()
		end
		return
	end

	State.currentContentIndex = State.currentContentIndex + 1
	Lifecycle.Flow.displayContent()
end

function Lifecycle.CreateDialogue(dialogueData)
	if State.currentDialogue then
		return
	end

	if not dialogueData or not dialogueData.InitialLayer or not dialogueData.SkinName or not dialogueData.Layers then
		warn("Invalid dialogue data. Required fields: InitialLayer, SkinName, Layers")
		return
	end

	Lifecycle.Flow.SkinManager.initializeSkin(dialogueData.SkinName)

	if not dialogueData.Layers[dialogueData.InitialLayer] then
		warn("Initial layer not found: " .. tostring(dialogueData.InitialLayer))
		return
	end

	if not State.skins:FindFirstChild(dialogueData.SkinName) then
		warn("Skin not found: " .. tostring(dialogueData.SkinName))
		return
	end

	if dialogueData.Config then
		local playerDeadConfig = dialogueData.Config:FindFirstChild("PlayerDead")
		if playerDeadConfig and playerDeadConfig:IsA("StringValue") then
			local interactWhenDead = playerDeadConfig:GetAttribute("InteractWhenDead")
			if interactWhenDead == false then
				local player = game.Players.LocalPlayer
				local humanoid = player and player.Character and player.Character:FindFirstChild("Humanoid")
				if humanoid and humanoid.Health <= 0 then
					return
				end
			end
		end
	end

	State.currentDialogue = dialogueData
	State.currentLayer = dialogueData.InitialLayer
	State.currentContentIndex = 1
	State.currentSkin = dialogueData.SkinName

	local skin = State.skins[State.currentSkin]

	skin.Visible = true

	local layerData = State.currentDialogue.Layers[State.currentLayer]
	skin.Title.TitleText.Text = layerData.Title

	if layerData.DialogueImage then
		skin.Content.DialogueImage.Image = layerData.DialogueImage
	end

	local closedPosition = skin:GetAttribute("ClosedPosition")
	skin.Position = closedPosition

	local gradient = skin:FindFirstChild("Gradient")
	if gradient then
		local gradientClosedPosition = gradient:GetAttribute("ClosedPosition")
		if gradientClosedPosition then
			gradient.Position = gradientClosedPosition
		end
	end

	local continueButton = skin.Continue.ContinueButton
	continueButton.TextTransparency = 1
	continueButton.BackgroundTransparency = 1

	if State.continueConnection then
		State.continueConnection:Disconnect()
	end

	State.continueConnection = continueButton.Activated:Connect(function()
		if continueButton.Active then
			Lifecycle.Flow.onContinueButtonClicked()
		end
	end)

	if State.contentClickConnection then
		State.contentClickConnection:Disconnect()
	end

	local contentLabel = skin.Content.ContentText
	State.contentClickConnection = contentLabel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and State.isTyping then
			Lifecycle.Flow.Typewriter.skipTypewriter()
		end
	end)

	Lifecycle.Flow.applyPlayerSettings(dialogueData.Config)

	Lifecycle.Flow.setupPlayerDeathHandling(dialogueData.Config)

	Lifecycle.Flow.InputHandler.setupInputHandling(dialogueData.Config)
	Lifecycle.Flow.InputHandler.setupMouseClickHandling()

	Lifecycle.Flow.createCinematicBars(dialogueData.Config)

	local openPosition = skin:GetAttribute("OpenPosition")
	local easingStyle = skin:GetAttribute("EasingStyle")
	local easingDirection = skin:GetAttribute("EasingDirection")
	local tweenTime = skin:GetAttribute("TweenTime")

	Lifecycle.Flow.SkinManager.tweenPosition(skin, openPosition, easingStyle, easingDirection, tweenTime)

	if gradient then
		local gradientOpenPosition = gradient:GetAttribute("OpenPosition")
		if gradientOpenPosition then
			local tweenInfo =
				TweenInfo.new(tweenTime, Enum.EasingStyle[easingStyle], Enum.EasingDirection[easingDirection])
			TweenService:Create(gradient, tweenInfo, { Position = gradientOpenPosition }):Play()
		end
	end

	Lifecycle.Flow.SkinManager.tweenTransparencyIn(State.currentSkin)

	Lifecycle.Flow.displayContent()

	return true
end

return Lifecycle
