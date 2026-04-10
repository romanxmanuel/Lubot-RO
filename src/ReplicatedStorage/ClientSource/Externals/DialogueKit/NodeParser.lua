-- NodeParser.lua
-- Node dialogue parsing: parseNodeDialogue, createConfigFromNode, processLayerNode.

local NodeParser = {}

-- Cross-module references (injected by init.lua)
NodeParser.CreateDialogue = nil

-- Checks if a node's type matches the target (string or table of strings).
local function matchesNodeType(nodeData, targetNodeType)
	if type(targetNodeType) == "table" then
		for _, t in ipairs(targetNodeType) do
			if nodeData.nodeType == t then
				return true
			end
		end
		return false
	end
	return nodeData.nodeType == targetNodeType
end

-- Finds the first node of targetNodeType connected via a left-side connector from sourceNode.
-- Tries preferredConnectorName first, then falls back to scanning all right-side connectors.
local function findConnectedNode(sourceNode, preferredConnectorName, connectorMap, nodeMap, targetNodeType)
	local connector = sourceNode.connectors[preferredConnectorName]

	if not connector or not connector.connectedTo then
		for connectorName, conn in pairs(sourceNode.connectors) do
			if conn.connectedTo and (connectorName:match("right") or connectorName == "rightConnector") then
				for targetId in string.gmatch(conn.connectedTo, "[^,]+") do
					local targetConn = connectorMap[targetId]
					if targetConn then
						local targetNode = nodeMap[targetConn.nodeConfig.Name]
						if
							targetNode
							and matchesNodeType(targetNode, targetNodeType)
							and (targetConn.connectorName:match("Left") or targetConn.connectorName:match("left"))
						then
							connector = conn
							break
						end
					end
				end
				if connector and connector.connectedTo then
					break
				end
			end
		end
	end

	if connector and connector.connectedTo then
		for targetId in string.gmatch(connector.connectedTo, "[^,]+") do
			local targetConn = connectorMap[targetId]
			if targetConn then
				local targetNode = nodeMap[targetConn.nodeConfig.Name]
				if
					targetNode
					and matchesNodeType(targetNode, targetNodeType)
					and (targetConn.connectorName:match("Left") or targetConn.connectorName:match("left"))
				then
					return targetNode
				end
			end
		end
	end

	return nil
end

local function createConfigFromNode(configNode)
	local config = Instance.new("Folder")
	config.Name = "Config"

	local backgroundSound = Instance.new("NumberValue")
	backgroundSound.Name = "BackgroundSound"
	backgroundSound.Value = configNode:GetAttribute("Param_BackgroundSound") or 0
	backgroundSound:SetAttribute("BackgroundSoundPitch", configNode:GetAttribute("Param_BackgroundSoundPitch") or 1)
	backgroundSound:SetAttribute("BackgroundSoundVolume", configNode:GetAttribute("Param_BackgroundSoundVolume") or 0.5)
	backgroundSound.Parent = config

	local cinematicBars = Instance.new("BoolValue")
	cinematicBars.Name = "CinematicBars"
	cinematicBars.Value = configNode:GetAttribute("Param_CinematicBars")
	if cinematicBars.Value == nil then
		cinematicBars.Value = true
	end
	cinematicBars:SetAttribute("TweenBars", configNode:GetAttribute("Param_TweenBars") or true)
	cinematicBars.Parent = config

	local continueButton = Instance.new("Configuration")
	continueButton.Name = "ContinueButton"
	continueButton:SetAttribute(
		"FunctionalDuringTypewriter",
		configNode:GetAttribute("Param_FunctionalDuringTypewriter") or true
	)
	continueButton:SetAttribute("VisibleDuringReply", configNode:GetAttribute("Param_VisibleDuringReply") or false)
	continueButton:SetAttribute(
		"VisibleDuringTypewriter",
		configNode:GetAttribute("Param_VisibleDuringTypewriter") or false
	)
	continueButton:SetAttribute(
		"TransparencyWhenUnclickable",
		configNode:GetAttribute("Param_TransparencyWhenUnclickable") or 1
	)
	continueButton.Parent = config

	local coreGui = Instance.new("BoolValue")
	coreGui.Name = "CoreGui"
	coreGui.Value = configNode:GetAttribute("Param_CoreGuiEnabled")
	if coreGui.Value == nil then
		coreGui.Value = true
	end
	coreGui:SetAttribute("BackpackEnabled", configNode:GetAttribute("Param_BackpackEnabled") or true)
	coreGui:SetAttribute("ChatEnabled", configNode:GetAttribute("Param_ChatEnabled") or true)
	coreGui:SetAttribute("LeaderboardEnabled", configNode:GetAttribute("Param_LeaderboardEnabled") or true)
	coreGui.Parent = config

	local dialogueCamera = Instance.new("ObjectValue")
	dialogueCamera.Name = "DialogueCamera"
	local cameraPath = configNode:GetAttribute("Param_DialogueCamera") or ""
	if cameraPath ~= "" then
		local current = workspace
		for _, part in ipairs(string.split(cameraPath, ".")) do
			if current then
				current = current:FindFirstChild(part)
			end
		end
		if current then
			dialogueCamera.Value = current
		end
	end
	dialogueCamera.Parent = config

	local walkSpeed = Instance.new("NumberValue")
	walkSpeed.Name = "DialogueWalkSpeed"
	walkSpeed.Value = configNode:GetAttribute("Param_DialogueWalkSpeed") or 0
	walkSpeed:SetAttribute("DefaultWalkSpeed", configNode:GetAttribute("Param_DefaultWalkSpeed") or 16)
	walkSpeed.Parent = config

	local keyCode = Instance.new("StringValue")
	keyCode.Name = "KeyCode"
	keyCode.Value = configNode:GetAttribute("Param_ContinueKey") or "Return"
	keyCode:SetAttribute("ContinueController", configNode:GetAttribute("Param_ContinueController") or "ButtonR1")
	keyCode:SetAttribute("Reply1", configNode:GetAttribute("Param_Reply1Key") or "One")
	keyCode:SetAttribute("Reply2", configNode:GetAttribute("Param_Reply2Key") or "Two")
	keyCode:SetAttribute("Reply3", configNode:GetAttribute("Param_Reply3Key") or "Three")
	keyCode:SetAttribute("Reply4", configNode:GetAttribute("Param_Reply4Key") or "Four")
	keyCode:SetAttribute("Reply1Controller", configNode:GetAttribute("Param_Reply1Controller") or "ButtonX")
	keyCode:SetAttribute("Reply2Controller", configNode:GetAttribute("Param_Reply2Controller") or "ButtonY")
	keyCode:SetAttribute("Reply3Controller", configNode:GetAttribute("Param_Reply3Controller") or "ButtonB")
	keyCode:SetAttribute("Reply4Controller", configNode:GetAttribute("Param_Reply4Controller") or "ButtonA")
	keyCode.Parent = config

	local playerDead = Instance.new("StringValue")
	playerDead.Name = "PlayerDead"
	playerDead.Value = "PlayerDead"
	playerDead:SetAttribute("InteractWhenDead", configNode:GetAttribute("Param_InteractWhenDead") or false)
	playerDead:SetAttribute("StopDialogueOnDeath", configNode:GetAttribute("Param_StopDialogueOnDeath") or true)
	playerDead.Parent = config

	local richText = Instance.new("BoolValue")
	richText.Name = "RichText"
	richText.Value = configNode:GetAttribute("Param_RichTextEnabled")
	if richText.Value == nil then
		richText.Value = true
	end
	richText.Parent = config

	local typewriter = Instance.new("BoolValue")
	typewriter.Name = "Typewriter"
	typewriter.Value = configNode:GetAttribute("Param_TypewriterEnabled")
	if typewriter.Value == nil then
		typewriter.Value = true
	end
	typewriter:SetAttribute("Sound", configNode:GetAttribute("Param_Sound") or 0)
	typewriter:SetAttribute("SoundPitch", configNode:GetAttribute("Param_SoundPitch") or 1)
	typewriter:SetAttribute("Speed", configNode:GetAttribute("Param_Speed") or 0.01)
	typewriter:SetAttribute("SpeedSpecial", configNode:GetAttribute("Param_SpeedSpecial") or 0.5)
	typewriter.Parent = config

	return config
end

local function processLayerNode(layerNode, nodeMap, connectorMap)
	local layerData = {
		Dialogue = {},
		DialogueSounds = {},
		DialogueImage = layerNode.config:GetAttribute("Param_DialogueImage") or "",
		Title = layerNode.config:GetAttribute("Param_DialogueTitle") or "",
		Replies = {},
	}

	-- Resolve dialogue content chain
	local dialogueNodes = {}
	local currentDialogueNode =
		findConnectedNode(layerNode, "DialogueRightConnector", connectorMap, nodeMap, "Dialogue Content Node")

	while currentDialogueNode do
		table.insert(dialogueNodes, currentDialogueNode)

		local contentTypes = { "Dialogue Content Node", "Dialogue Content Node+" }
		local contentRightConnector = currentDialogueNode.connectors["ContentRightConnector"]
		if not contentRightConnector or not contentRightConnector.connectedTo then
			contentRightConnector = currentDialogueNode.connectors["rightConnector"]
		end

		local nextDialogueNode = nil
		if contentRightConnector and contentRightConnector.connectedTo then
			for targetId in string.gmatch(contentRightConnector.connectedTo, "[^,]+") do
				local targetConn = connectorMap[targetId]
				if targetConn then
					local targetNode = nodeMap[targetConn.nodeConfig.Name]
					if
						targetNode
						and matchesNodeType(targetNode, contentTypes)
						and (targetConn.connectorName:match("Left") or targetConn.connectorName:match("left"))
					then
						nextDialogueNode = targetNode
						break
					end
				end
			end
		end

		currentDialogueNode = nextDialogueNode
	end

	if #dialogueNodes > 0 then
		for _, dialogueNode in ipairs(dialogueNodes) do
			local content = dialogueNode.config:GetAttribute("Param_Content")
				or dialogueNode.config:GetAttribute("Param_DialogueContent")
				or ""
			table.insert(layerData.Dialogue, content)
		end
	else
		table.insert(layerData.Dialogue, "")
	end

	-- Resolve reply node
	local replyNode =
		findConnectedNode(layerNode, "RepliesRightConnector", connectorMap, nodeMap, "ReplyNode")

	if replyNode then
		local replyParams = { "Param_Reply1", "Param_Reply2", "Param_Reply3", "Param_Reply4" }

		for i, paramName in ipairs(replyParams) do
			local replyText = replyNode.config:GetAttribute(paramName)
			if replyText and replyText ~= "" then
				local replyName = "reply" .. i

				local replyConnectorName = "Reply" .. i .. "RightConnector"
				local targetLayerNode =
					findConnectedNode(replyNode, replyConnectorName, connectorMap, nodeMap, "Layer Node")

				if targetLayerNode then
					layerData.Replies[replyName] = {
						ReplyText = replyText,
						ReplyLayer = targetLayerNode.config.Name,
					}
				else
					layerData.Replies["_goodbye" .. i] = {
						ReplyText = replyText,
					}
				end
			end
		end
	end

	return layerData
end

local function parseNodeDialogue(nodeProjectName)
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local dialogueNodeFolder = replicatedStorage:FindFirstChild("Dialogue_node")

	if not dialogueNodeFolder then
		warn("Dialogue_node folder not found in ReplicatedStorage")
		return nil
	end

	local nodeFolder = dialogueNodeFolder:FindFirstChild(nodeProjectName)
	if not nodeFolder then
		warn("Node project '" .. nodeProjectName .. "' not found")
		return nil
	end

	local nodesFolder = nodeFolder:FindFirstChild("nodes")
	if not nodesFolder then
		warn("No 'nodes' folder found in " .. nodeProjectName)
		return nil
	end

	local nodeMap = {}
	local connectorMap = {}

	for _, config in ipairs(nodesFolder:GetChildren()) do
		if config:IsA("Configuration") then
			local nodeType = config:GetAttribute("NodeType")
			nodeMap[config.Name] = {
				config = config,
				nodeType = nodeType,
				connectors = {},
			}

			local connectorCount = config:GetAttribute("ConnectorCount") or 0
			for i = 1, connectorCount do
				local connectorId = config:GetAttribute("Connector" .. i .. "_ID")
				local connectorName = config:GetAttribute("Connector" .. i .. "_Name")
				local connectedTo = config:GetAttribute("Connector" .. i .. "_ConnectedTo")
				local connectedFrom = config:GetAttribute("Connector" .. i .. "_ConnectedFrom")

				if connectorId then
					connectorMap[connectorId] = {
						nodeConfig = config,
						connectorName = connectorName,
						connectedTo = connectedTo,
						connectedFrom = connectedFrom,
					}

					nodeMap[config.Name].connectors[connectorName] = {
						id = connectorId,
						connectedTo = connectedTo,
						connectedFrom = connectedFrom,
					}
				end
			end
		end
	end

	local configNode = nil
	for _, nodeData in pairs(nodeMap) do
		if nodeData.nodeType == "Config Node" then
			configNode = nodeData
			break
		end
	end

	if not configNode then
		warn("No Config Node found in " .. nodeProjectName)
		return nil
	end

	local dialogueStartNode =
		findConnectedNode(configNode, "rightConnector", connectorMap, nodeMap, "Dialogue Start Node")

	if not dialogueStartNode then
		warn("No Dialogue Start Node connected to Config Node")
		return nil
	end

	local initialLayerNode =
		findConnectedNode(dialogueStartNode, "rightConnector", connectorMap, nodeMap, "Layer Node")

	if not initialLayerNode then
		warn("No Layer Node connected to Dialogue Start Node")
		return nil
	end

	local skinName = dialogueStartNode.config:GetAttribute("Param_SkinName") or "DefaultDark"

	local dialogueData = {
		InitialLayer = initialLayerNode.config.Name,
		SkinName = skinName,
		Config = createConfigFromNode(configNode.config),
		Layers = {},
	}

	for nodeName, nodeData in pairs(nodeMap) do
		if nodeData.nodeType == "Layer Node" then
			local layerData = processLayerNode(nodeData, nodeMap, connectorMap)
			dialogueData.Layers[nodeName] = layerData
		end
	end

	return dialogueData
end

function NodeParser.startNodeDialogue(nodeProjectName)
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local dialogueNodeFolder = replicatedStorage:FindFirstChild("Dialogue_node")

	if not dialogueNodeFolder then
		warn("Dialogue_node folder not found in ReplicatedStorage. Node dialogues are not available.")
		return
	end

	local dialogueData = parseNodeDialogue(nodeProjectName)
	if not dialogueData then
		warn("Failed to parse node dialogue: " .. nodeProjectName)
		return
	end

	NodeParser.CreateDialogue(dialogueData)
end

return NodeParser
