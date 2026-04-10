-- InputHandler.lua
-- Keyboard, gamepad, and mouse input handling for DialogueKit.

local UserInputService = game:GetService("UserInputService")

local State = require(script.Parent.State)

local InputHandler = {}

-- Cross-module references (injected by init.lua)
InputHandler.DialogueFlow = nil
InputHandler.Typewriter = nil

-- Safe KeyCode lookup that returns nil instead of erroring on invalid names.
local function getKeyCode(name)
	if not name or name == "" then
		return nil
	end
	local ok, keyCode = pcall(function()
		return Enum.KeyCode[name]
	end)
	if ok then
		return keyCode
	end
	return nil
end

function InputHandler.setupInputHandling(config)
	if not config then
		return
	end

	local keyCodeConfig = config:FindFirstChild("KeyCode")
	if not keyCodeConfig or not keyCodeConfig:IsA("StringValue") then
		return
	end

	InputHandler.teardownInputHandling()

	local continueKeyCode = getKeyCode(keyCodeConfig.Value)
	local continueControllerKeyCode = getKeyCode(keyCodeConfig:GetAttribute("ContinueController"))

	State.inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if continueKeyCode and continueKeyCode == input.KeyCode then
				local continueButton = State.skins[State.currentSkin]
					and State.skins[State.currentSkin].Continue.ContinueButton
				if continueButton and continueButton.Active then
					InputHandler.DialogueFlow.onContinueButtonClicked()
				end
			end

			if State.isShowingReplies then
				for i = 1, 4 do
					local replyKeyCode = getKeyCode(keyCodeConfig:GetAttribute("Reply" .. i))
					if replyKeyCode and replyKeyCode == input.KeyCode then
						InputHandler.triggerReplyByIndex(i)
					end
				end
			end
		elseif input.UserInputType == Enum.UserInputType.Gamepad1 then
			if continueControllerKeyCode and continueControllerKeyCode == input.KeyCode then
				local continueButton = State.skins[State.currentSkin]
					and State.skins[State.currentSkin].Continue.ContinueButton
				if continueButton and continueButton.Active then
					InputHandler.DialogueFlow.onContinueButtonClicked()
				end
			end

			if State.isShowingReplies then
				for i = 1, 4 do
					local replyKeyCode = getKeyCode(keyCodeConfig:GetAttribute("Reply" .. i .. "Controller"))
					if replyKeyCode and replyKeyCode == input.KeyCode then
						InputHandler.triggerReplyByIndex(i)
					end
				end
			end
		end
	end)
end

function InputHandler.teardownInputHandling()
	if State.inputBeganConnection then
		State.inputBeganConnection:Disconnect()
		State.inputBeganConnection = nil
	end
end

-- Handle clicks/taps anywhere on screen to advance dialogue
local function handleClickToAdvance(input)
	if
		input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch
	then
		return
	end

	if State.isTyping then
		InputHandler.Typewriter.skipTypewriter()
	elseif State.isShowingReplies then
		if not State.currentSkin or not State.currentDialogue or not State.currentLayer then
			return
		end

		local layerData = State.currentDialogue.Layers[State.currentLayer]
		if not layerData or not layerData.Replies then
			return
		end

		local repliesContainer = State.skins[State.currentSkin].Replies
		local visibleReplies = {}
		for _, child in ipairs(repliesContainer:GetChildren()) do
			if child:IsA("Frame") and child:FindFirstChild("ReplyButton") and child.Visible then
				local replyButton = child.ReplyButton
				if replyButton.Active then
					table.insert(visibleReplies, { name = child.Name, data = layerData.Replies[child.Name] })
				end
			end
		end

		if #visibleReplies == 1 then
			local replyName = visibleReplies[1].name
			local replyData = visibleReplies[1].data
			if replyName and replyData then
				InputHandler.DialogueFlow.onReplyButtonClicked(replyName, replyData)
			end
		end
	else
		if State.currentSkin then
			local continueButton = State.skins[State.currentSkin].Continue.ContinueButton
			if continueButton and continueButton.Active then
				InputHandler.DialogueFlow.onContinueButtonClicked()
			end
		end
	end
end

function InputHandler.setupMouseClickHandling()
	InputHandler.teardownMouseClickHandling()

	State.mouseClickConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		handleClickToAdvance(input)
	end)
end

function InputHandler.teardownMouseClickHandling()
	if State.mouseClickConnection then
		State.mouseClickConnection:Disconnect()
		State.mouseClickConnection = nil
	end
end

function InputHandler.triggerReplyByIndex(index)
	if not State.currentSkin or not State.isShowingReplies then
		return
	end

	local repliesContainer = State.skins[State.currentSkin].Replies
	local visibleReplies = {}

	for _, child in ipairs(repliesContainer:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("ReplyButton") and child.Visible then
			table.insert(visibleReplies, child)
		end
	end

	table.sort(visibleReplies, function(a, b)
		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)

	if index <= #visibleReplies and visibleReplies[index].ReplyButton.Active then
		local replyName = visibleReplies[index].Name
		local layerData = State.currentDialogue.Layers[State.currentLayer]
		if layerData and layerData.Replies and layerData.Replies[replyName] then
			InputHandler.DialogueFlow.onReplyButtonClicked(replyName, layerData.Replies[replyName])
		end
	end
end

return InputHandler
