-- ReplyManager.lua
-- Reply display, interaction, and tween animations.

local TweenService = game:GetService("TweenService")

local State = require(script.Parent.Parent.State)

local ReplyManager = {}

-- Hub reference (injected by init.lua)
ReplyManager.Flow = nil

function ReplyManager.clearReplyConnections()
	for _, connection in ipairs(State.replyConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	State.replyConnections = {}
end

local function createReplyClone(replyName, replyData, defaultReply, defaultReplyStroke, repliesContainer, tweenInfo)
	local replyClone = defaultReply:Clone()
	replyClone.Name = replyName
	replyClone.Parent = repliesContainer

	local replyButton = replyClone.ReplyButton
	replyButton.Text = replyData.ReplyText

	replyClone.BackgroundTransparency = 1
	replyButton.BackgroundTransparency = 1
	replyButton.TextTransparency = 1

	local replyStroke = replyClone:FindFirstChildOfClass("UIStroke")
	if replyStroke then
		replyStroke.Transparency = 1
	end

	local buttonStroke = replyButton:FindFirstChildOfClass("UIStroke")
	if buttonStroke then
		buttonStroke.Transparency = 1
	end

	for _, descendant in ipairs(replyClone:GetDescendants()) do
		if descendant:IsA("UIStroke") then
			descendant.Transparency = 1
		end
	end

	replyClone.Visible = true

	local skinCache = State.defaultTransparencyValues[State.currentSkin]

	local originalCloneBackgroundTransparency = skinCache[defaultReply]
			and skinCache[defaultReply].BackgroundTransparency
		or 0

	local originalButtonBackgroundTransparency = skinCache[defaultReply.ReplyButton]
			and skinCache[defaultReply.ReplyButton].BackgroundTransparency
		or 0

	local originalButtonTextTransparency = skinCache[defaultReply.ReplyButton]
			and skinCache[defaultReply.ReplyButton].TextTransparency
		or 0

	local originalStrokeTransparency = 0
	if defaultReplyStroke then
		originalStrokeTransparency = skinCache[defaultReplyStroke]
				and skinCache[defaultReplyStroke].Transparency
			or 0
	end

	local cloneTween =
		TweenService:Create(replyClone, tweenInfo, { BackgroundTransparency = originalCloneBackgroundTransparency })
	local buttonTween = TweenService:Create(replyButton, tweenInfo, {
		BackgroundTransparency = originalButtonBackgroundTransparency,
		TextTransparency = originalButtonTextTransparency,
	})

	if replyStroke then
		TweenService:Create(replyStroke, tweenInfo, { Transparency = originalStrokeTransparency }):Play()
	end

	if buttonStroke then
		TweenService:Create(buttonStroke, tweenInfo, { Transparency = originalStrokeTransparency }):Play()
	end

	for _, descendant in ipairs(replyClone:GetDescendants()) do
		if descendant:IsA("UIStroke") and descendant ~= replyStroke and descendant ~= buttonStroke then
			local originalTransparency = 0
			if skinCache[descendant] then
				originalTransparency = skinCache[descendant].Transparency or 0
			end

			TweenService:Create(descendant, tweenInfo, { Transparency = originalTransparency }):Play()
		end
	end

	cloneTween:Play()
	buttonTween:Play()

	local connection = replyButton.Activated:Connect(function()
		ReplyManager.Flow.onReplyButtonClicked(replyName, replyData)
	end)

	table.insert(State.replyConnections, connection)
end

function ReplyManager.showReplies()
	if State.isShowingReplies or not State.currentDialogue or not State.currentLayer or not State.currentSkin then
		return
	end

	State.isShowingReplies = true

	local layerData = State.currentDialogue.Layers[State.currentLayer]
	if not layerData or not layerData.Replies or next(layerData.Replies) == nil then
		return
	end

	local skin = State.skins[State.currentSkin]
	local repliesContainer = skin.Replies
	local config = State.currentDialogue.Config

	local continueButtonConfig = config and config:FindFirstChild("ContinueButton")
	local visibleDuringReply = continueButtonConfig and continueButtonConfig:GetAttribute("VisibleDuringReply")

	if not visibleDuringReply then
		local continueButton = skin.Continue.ContinueButton
		local hideTweenInfo = TweenInfo.new(
			skin:GetAttribute("TweenTime"),
			Enum.EasingStyle[skin:GetAttribute("EasingStyle")],
			Enum.EasingDirection[skin:GetAttribute("EasingDirection")]
		)

		continueButton.Active = false
		TweenService
			:Create(continueButton, hideTweenInfo, { TextTransparency = 1, BackgroundTransparency = 1 })
			:Play()

		for _, descendant in ipairs(continueButton:GetDescendants()) do
			if descendant:IsA("UIStroke") then
				TweenService:Create(descendant, hideTweenInfo, { Transparency = 1 }):Play()
			end
		end
	end

	local replyPosition = skin:GetAttribute("ReplyPosition")
	local easingStyle = skin:GetAttribute("EasingStyle")
	local easingDirection = skin:GetAttribute("EasingDirection")
	local tweenTime = skin:GetAttribute("TweenTime")

	ReplyManager.Flow.SkinManager.tweenPosition(skin, replyPosition, easingStyle, easingDirection, tweenTime)

	local layoutObjects = {}
	for _, child in ipairs(repliesContainer:GetChildren()) do
		if
			child:IsA("UIGridLayout")
			or child:IsA("UIGradient")
			or child:IsA("UIPadding")
			or not (child:IsA("Frame") or child:IsA("CanvasGroup"))
		then
			layoutObjects[child.Name] = child
		else
			child:Destroy()
		end
	end

	local replyCount = 0
	local defaultReply = skin.DefaultReply
	local defaultReplyStroke = defaultReply:FindFirstChildOfClass("UIStroke")
	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle[easingStyle], Enum.EasingDirection[easingDirection])

	local orderedReplyNames = { "reply1", "reply2", "reply3", "reply4" }
	local orderedSet = {}
	for _, name in ipairs(orderedReplyNames) do
		orderedSet[name] = true
	end

	-- Add ordered replies first
	for _, replyName in ipairs(orderedReplyNames) do
		local replyData = layerData.Replies[replyName]
		if replyData then
			replyCount = replyCount + 1
			if replyCount > 4 then
				break
			end
			createReplyClone(replyName, replyData, defaultReply, defaultReplyStroke, repliesContainer, tweenInfo)
		end
	end

	-- Add remaining unordered replies
	for replyName, replyData in pairs(layerData.Replies) do
		if not orderedSet[replyName] then
			replyCount = replyCount + 1
			if replyCount > 4 then
				break
			end
			createReplyClone(replyName, replyData, defaultReply, defaultReplyStroke, repliesContainer, tweenInfo)
		end
	end

	for _, layoutObject in pairs(layoutObjects) do
		layoutObject.Parent = repliesContainer
	end
end

function ReplyManager.onReplyButtonClicked(replyName, replyData)
	if not State.currentDialogue or not State.currentLayer or not State.currentSkin then
		return
	end

	local replyExecs = ReplyManager.Flow.findExecForReply(replyName)
	if replyExecs then
		for _, execData in ipairs(replyExecs) do
			ReplyManager.Flow.executeLayerFunction(execData)
		end
	end

	local repliesContainer = State.skins[State.currentSkin].Replies
	for _, child in ipairs(repliesContainer:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("ReplyButton") then
			child.ReplyButton.Active = false
		end
	end

	local skin = State.skins[State.currentSkin]
	local easingStyle = skin:GetAttribute("EasingStyle")
	local easingDirection = skin:GetAttribute("EasingDirection")
	local tweenTime = skin:GetAttribute("TweenTime")

	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle[easingStyle], Enum.EasingDirection[easingDirection])
	local tweensDone = 0
	local totalTweens = 0

	local isGoodbye = string.sub(replyName, 1, 8) == "_goodbye" or replyData.ReplyLayer == nil
	local targetLayer = not isGoodbye and replyData.ReplyLayer
	local isInvalidLayer = targetLayer and not State.currentDialogue.Layers[targetLayer]

	for _, child in ipairs(repliesContainer:GetChildren()) do
		if child:IsA("Frame") and child:FindFirstChild("ReplyButton") then
			totalTweens = totalTweens + 1

			local frameTween =
				TweenService:Create(child, tweenInfo, { BackgroundTransparency = 1 })
			local buttonTween =
				TweenService:Create(child.ReplyButton, tweenInfo, { BackgroundTransparency = 1, TextTransparency = 1 })

			local stroke = child:FindFirstChildOfClass("UIStroke")
			if stroke then
				totalTweens = totalTweens + 1
				local strokeTween = TweenService:Create(stroke, tweenInfo, { Transparency = 1 })
				strokeTween.Completed:Connect(function()
					tweensDone = tweensDone + 1
					if tweensDone >= totalTweens then
						ReplyManager.Flow.onRepliesTweenComplete(isGoodbye, targetLayer, isInvalidLayer)
					end
				end)
				strokeTween:Play()
			end

			local buttonStroke = child.ReplyButton:FindFirstChildOfClass("UIStroke")
			if buttonStroke then
				totalTweens = totalTweens + 1
				local buttonStrokeTween = TweenService:Create(buttonStroke, tweenInfo, { Transparency = 1 })
				buttonStrokeTween.Completed:Connect(function()
					tweensDone = tweensDone + 1
					if tweensDone >= totalTweens then
						ReplyManager.Flow.onRepliesTweenComplete(isGoodbye, targetLayer, isInvalidLayer)
					end
				end)
				buttonStrokeTween:Play()
			end

			for _, descendant in ipairs(child:GetDescendants()) do
				if descendant:IsA("UIStroke") and descendant ~= stroke and descendant ~= buttonStroke then
					totalTweens = totalTweens + 1
					local descendantStrokeTween = TweenService:Create(descendant, tweenInfo, { Transparency = 1 })
					descendantStrokeTween.Completed:Connect(function()
						tweensDone = tweensDone + 1
						if tweensDone >= totalTweens then
							ReplyManager.Flow.onRepliesTweenComplete(isGoodbye, targetLayer, isInvalidLayer)
						end
					end)
					descendantStrokeTween:Play()
				end
			end

			frameTween.Completed:Connect(function()
				tweensDone = tweensDone + 1
				if tweensDone >= totalTweens then
					ReplyManager.Flow.onRepliesTweenComplete(isGoodbye, targetLayer, isInvalidLayer)
				end
			end)

			buttonTween.Completed:Connect(function()
				tweensDone = tweensDone + 1
				if tweensDone >= totalTweens then
					ReplyManager.Flow.onRepliesTweenComplete(isGoodbye, targetLayer, isInvalidLayer)
				end
			end)

			frameTween:Play()
			buttonTween:Play()
		end
	end

	ReplyManager.clearReplyConnections()

	if totalTweens == 0 then
		ReplyManager.Flow.onRepliesTweenComplete(isGoodbye, targetLayer, isInvalidLayer)
	end
end

function ReplyManager.onRepliesTweenComplete(isGoodbye, targetLayer, isInvalidLayer)
	local skin = State.skins[State.currentSkin]
	local repliesContainer = skin.Replies

	for _, child in ipairs(repliesContainer:GetChildren()) do
		if child:IsA("Frame") or child:IsA("CanvasGroup") then
			child:Destroy()
		end
	end

	if isGoodbye then
		State.isShowingReplies = false
		ReplyManager.Flow.closeDialogue()
		return
	end

	if isInvalidLayer then
		warn("Invalid reply target layer: " .. tostring(targetLayer))
		State.isShowingReplies = false
		ReplyManager.Flow.closeDialogue()
		return
	end

	local openPosition = skin:GetAttribute("OpenPosition")
	local easingStyle = skin:GetAttribute("EasingStyle")
	local easingDirection = skin:GetAttribute("EasingDirection")
	local tweenTime = skin:GetAttribute("TweenTime")

	ReplyManager.Flow.SkinManager.tweenPosition(skin, openPosition, easingStyle, easingDirection, tweenTime)

	task.delay(tweenTime, function()
		State.currentLayer = targetLayer
		State.currentContentIndex = 1
		State.isShowingReplies = false

		ReplyManager.Flow.displayContent()
	end)
end

return ReplyManager
