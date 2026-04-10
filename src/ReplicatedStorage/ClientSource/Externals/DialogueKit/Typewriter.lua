-- Typewriter.lua
-- Rich text parsing and typewriter effect for DialogueKit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local DialogueSettings = require(ReplicatedStorage.SharedSource.Datas.GameSettings.DialogueSettings)

local State = require(script.Parent.State)

local Typewriter = {}

-- Cross-module references (injected by init.lua)
Typewriter.DialogueFlow = nil

local TAG_PATTERNS = {
	{ pattern = '<font color=".-">', closeTag = "</font>", type = "richFormatting" },
	{ pattern = '<font transparency=".-">', closeTag = "</font>", type = "richFormatting" },
	{ pattern = '<font size=".-">', closeTag = "</font>", type = "richFormatting" },
	{ pattern = '<stroke color=".-" thickness=".-">', closeTag = "</stroke>", type = "richFormatting" },
	{ pattern = '<stroke thickness=".-" color=".-">', closeTag = "</stroke>", type = "richFormatting" },
	{ pattern = "<b>", closeTag = "</b>", type = "richFormatting" },
	{ pattern = "<i>", closeTag = "</i>", type = "richFormatting" },
	{ pattern = "<u>", closeTag = "</u>", type = "richFormatting" },
	{ pattern = "<s>", closeTag = "</s>", type = "richFormatting" },
	{ pattern = "<uc>", closeTag = "</uc>", type = "richFormatting" },
	{ pattern = "<sc>", closeTag = "</sc>", type = "richFormatting" },
	{ pattern = "<br/>", closeTag = "", type = "lineBreak" },
	{ pattern = "&lt;", closeTag = "", type = "escape" },
	{ pattern = "&gt;", closeTag = "", type = "escape" },
	{ pattern = "&quot;", closeTag = "", type = "escape" },
	{ pattern = "&apos;", closeTag = "", type = "escape" },
	{ pattern = "&amp;", closeTag = "", type = "escape" },
}

-- Shared post-typewriter logic: run after execs, then show replies or continue button.
local function finishTypewriter()
	local layerData = State.currentDialogue.Layers[State.currentLayer]
	local isLastContent = State.currentContentIndex == #layerData.Dialogue
	local hasReplies = layerData.Replies and next(layerData.Replies) ~= nil

	local afterExecs = Typewriter.DialogueFlow.findExecForContent(State.currentContentIndex, "After")
	if afterExecs then
		for _, execData in ipairs(afterExecs) do
			Typewriter.DialogueFlow.executeLayerFunction(execData)
		end
	end

	if isLastContent and hasReplies then
		Typewriter.DialogueFlow.showReplies()
	else
		local continueButton = State.skins[State.currentSkin].Continue.ContinueButton
		continueButton.Active = true
		Typewriter.DialogueFlow.showContinueButton()
	end
end

function Typewriter.parseRichText(text)
	local segments = {}
	local currentPosition = 1

	while currentPosition <= #text do
		local foundTag = false
		local tagStart, tagEnd, closeTag, tagType

		for _, tagInfo in ipairs(TAG_PATTERNS) do
			local start, ending = string.find(text, tagInfo.pattern, currentPosition)
			if start and (not tagStart or start < tagStart) then
				tagStart = start
				tagEnd = ending
				closeTag = tagInfo.closeTag
				tagType = tagInfo.type
				foundTag = true
			end
		end

		if not foundTag then
			if currentPosition <= #text then
				table.insert(segments, {
					type = "text",
					content = string.sub(text, currentPosition),
				})
			end
			break
		end

		if currentPosition < tagStart then
			table.insert(segments, {
				type = "text",
				content = string.sub(text, currentPosition, tagStart - 1),
			})
		end

		if tagType == "lineBreak" or tagType == "escape" then
			table.insert(segments, {
				type = tagType,
				content = string.sub(text, tagStart, tagEnd),
			})
			currentPosition = tagEnd + 1
		else
			local openTag = string.sub(text, tagStart, tagEnd)
			local closeTagStart = string.find(text, closeTag, tagEnd + 1)

			if closeTagStart then
				local tagContent = string.sub(text, tagEnd + 1, closeTagStart - 1)

				table.insert(segments, {
					type = "rich_text",
					openTag = openTag,
					content = tagContent,
					closeTag = closeTag,
				})

				currentPosition = closeTagStart + #closeTag
			else
				table.insert(segments, {
					type = "text",
					content = string.sub(text, tagStart),
				})
				break
			end
		end
	end

	return segments
end

function Typewriter.typewriterEffect(textLabel, fullText, config)
	if State.typewriterThread then
		task.cancel(State.typewriterThread)
	end

	State.isTyping = true

	local continueButtonConfig = config:FindFirstChild("ContinueButton")
	local visibleDuringTypewriter = continueButtonConfig
		and continueButtonConfig:GetAttribute("VisibleDuringTypewriter")
	local functionalDuringTypewriter = continueButtonConfig
		and continueButtonConfig:GetAttribute("FunctionalDuringTypewriter")

	local continueButton = State.skins[State.currentSkin].Continue.ContinueButton

	if visibleDuringTypewriter then
		continueButton.Active = functionalDuringTypewriter
		Typewriter.DialogueFlow.showContinueButton()
	else
		Typewriter.DialogueFlow.hideContinueButton()
	end

	local typewriterConfig = config:FindFirstChild("Typewriter")
	local speed = typewriterConfig and typewriterConfig:GetAttribute("Speed") or 0.03
	local speedSpecial = typewriterConfig and typewriterConfig:GetAttribute("SpeedSpecial") or 0.1
	local soundPitch = typewriterConfig and typewriterConfig:GetAttribute("SoundPitch")
		or DialogueSettings.TypewriterSound.DefaultPitch

	-- Get dialogue sound from specified path
	local dialogueSound = ReplicatedStorage
	for _, pathPart in ipairs(string.split(DialogueSettings.TypewriterSound.SoundPath, ".")) do
		if dialogueSound then
			dialogueSound = dialogueSound:FindFirstChild(pathPart)
		end
	end

	textLabel.Text = ""

	local segments = Typewriter.parseRichText(fullText)

	State.typewriterThread = task.spawn(function()
		local displayedText = ""
		local characterCount = 0

		for segmentIndex, segment in ipairs(segments) do
			if segment.type == "text" then
				for i = 1, #segment.content do
					if not State.isTyping then
						break
					end

					local char = string.sub(segment.content, i, i)
					displayedText = displayedText .. char
					textLabel.Text = displayedText

					characterCount = characterCount + 1

					if DialogueSettings.TypewriterSound.Enabled and dialogueSound then
						if characterCount % DialogueSettings.TypewriterSound.CharacterInterval == 0 then
							local soundClone = dialogueSound:Clone()
							soundClone.PlaybackSpeed = soundPitch
							soundClone.Volume = DialogueSettings.TypewriterSound.DefaultVolume
							soundClone.Parent = SoundService
							soundClone:Play()

							soundClone.Ended:Connect(function()
								soundClone:Destroy()
							end)
						end
					end

					local isLastCharInSegment = (i == #segment.content)
					local isLastSegment = (segmentIndex == #segments)
					local isLastChar = isLastCharInSegment and isLastSegment

					if string.match(char, '[%.,%?!":]') and not isLastChar then
						task.wait(speedSpecial)
					else
						task.wait(speed)
					end
				end
			elseif segment.type == "rich_text" then
				local partialText = ""

				displayedText = displayedText .. segment.openTag

				for i = 1, #segment.content do
					if not State.isTyping then
						break
					end

					local char = string.sub(segment.content, i, i)
					partialText = partialText .. char

					textLabel.Text = displayedText .. partialText .. segment.closeTag

					characterCount = characterCount + 1

					if DialogueSettings.TypewriterSound.Enabled and dialogueSound then
						if characterCount % DialogueSettings.TypewriterSound.CharacterInterval == 0 then
							local soundClone = dialogueSound:Clone()
							soundClone.PlaybackSpeed = soundPitch
							soundClone.Volume = DialogueSettings.TypewriterSound.DefaultVolume
							soundClone.Parent = SoundService
							soundClone:Play()

							soundClone.Ended:Connect(function()
								soundClone:Destroy()
							end)
						end
					end

					local isLastCharInSegment = (i == #segment.content)
					local isLastSegment = (segmentIndex == #segments)
					local isLastChar = isLastCharInSegment and isLastSegment

					if string.match(char, '[%.,%?!":]') and not isLastChar then
						task.wait(speedSpecial)
					else
						task.wait(speed)
					end
				end

				displayedText = displayedText .. partialText .. segment.closeTag
			elseif segment.type == "lineBreak" then
				displayedText = displayedText .. segment.content
				textLabel.Text = displayedText
			elseif segment.type == "escape" then
				displayedText = displayedText .. segment.content
				textLabel.Text = displayedText
			end

			if not State.isTyping then
				break
			end
		end

		if State.isTyping then
			State.isTyping = false
			finishTypewriter()
		end
	end)
end

function Typewriter.skipTypewriter()
	if State.isTyping and State.typewriterThread then
		State.isTyping = false
		task.cancel(State.typewriterThread)

		local dialogueSound = SoundService:FindFirstChild("DialogueKit")
		if dialogueSound and dialogueSound:FindFirstChild("TypewriterSound") then
			dialogueSound.TypewriterSound:Stop()
		end

		if State.currentDialogue and State.currentLayer and State.currentContentIndex then
			local contentText = State.currentDialogue.Layers[State.currentLayer].Dialogue[State.currentContentIndex]
			local contentLabel = State.skins[State.currentSkin].Content.ContentText
			contentLabel.Text = contentText

			finishTypewriter()
		end
	end
end

return Typewriter
