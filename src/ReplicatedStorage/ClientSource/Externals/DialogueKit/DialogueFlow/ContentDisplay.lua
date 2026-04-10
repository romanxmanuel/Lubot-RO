-- ContentDisplay.lua
-- Dialogue content display with typewriter and exec support.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local DialogueSettings = require(ReplicatedStorage.SharedSource.Datas.GameSettings.DialogueSettings)

local State = require(script.Parent.Parent.State)

local ContentDisplay = {}

-- Hub reference (injected by init.lua)
ContentDisplay.Flow = nil

function ContentDisplay.displayContent()
	if
		not State.currentDialogue
		or not State.currentLayer
		or not State.currentContentIndex
		or not State.currentSkin
	then
		return
	end

	local layerData = State.currentDialogue.Layers[State.currentLayer]

	if not layerData or not layerData.Dialogue or State.currentContentIndex > #layerData.Dialogue then
		warn("Invalid content index or dialogue data")
		ContentDisplay.Flow.closeDialogue()
		return
	end

	local contentText = layerData.Dialogue[State.currentContentIndex]
	local dialogueSound = layerData.DialogueSounds and layerData.DialogueSounds[State.currentContentIndex]

	local contentLabel = State.skins[State.currentSkin].Content.ContentText

	local config = State.currentDialogue.Config

	local richTextEnabled = true
	local richTextValue = config and config:FindFirstChild("RichText")
	if richTextValue ~= nil and richTextValue:IsA("BoolValue") then
		richTextEnabled = richTextValue.Value
	end

	contentLabel.RichText = richTextEnabled

	local typewriterEnabled = config and config:FindFirstChild("Typewriter") and config.Typewriter.Value

	if dialogueSound then
		if State.activeDialogueSound then
			State.activeDialogueSound:Stop()
			State.activeDialogueSound:Destroy()
			State.activeDialogueSound = nil
		end

		local dialogueSoundService = SoundService:FindFirstChild("DialogueKit")
		if dialogueSoundService and dialogueSoundService:FindFirstChild("DialogueSound") then
			State.activeDialogueSound = dialogueSoundService.DialogueSound:Clone()
			State.activeDialogueSound.SoundId = "rbxassetid://" .. dialogueSound
			State.activeDialogueSound.Parent = State.skins[State.currentSkin]
			State.activeDialogueSound:Play()

			State.activeDialogueSound.Ended:Connect(function()
				if State.activeDialogueSound then
					State.activeDialogueSound:Destroy()
					State.activeDialogueSound = nil
				end
			end)
		end
	end

	local beforeExecs = ContentDisplay.Flow.findExecForContent(State.currentContentIndex, "Before")
	if beforeExecs then
		for _, execData in ipairs(beforeExecs) do
			ContentDisplay.Flow.executeLayerFunction(execData)
		end
	end

	local isLastContent = State.currentContentIndex == #layerData.Dialogue
	local hasReplies = layerData.Replies and next(layerData.Replies) ~= nil

	if typewriterEnabled then
		ContentDisplay.Flow.Typewriter.typewriterEffect(contentLabel, contentText, config)
	else
		contentLabel.Text = contentText

		local afterExecs = ContentDisplay.Flow.findExecForContent(State.currentContentIndex, "After")
		if afterExecs then
			for _, execData in ipairs(afterExecs) do
				ContentDisplay.Flow.executeLayerFunction(execData)
			end
		end

		if isLastContent and hasReplies then
			ContentDisplay.Flow.showReplies()
		else
			local continueButton = State.skins[State.currentSkin].Continue.ContinueButton
			continueButton.Active = true
			ContentDisplay.Flow.showContinueButton()
		end
	end
end

return ContentDisplay
