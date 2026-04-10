--!nonstrict
-- NativeToolHandler.lua
-- Handles native Roblox Tool events (Equipped, Unequipped, Activated)
-- Makes the server work independently without requiring client signals
-- 
-- DEDUPLICATION: If a client module exists for a tool, this handler skips
-- activation processing (Full Mode uses RemoteFunction instead)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local NativeToolHandler = {}

---- Client Tools Path (for checking if client module exists)
local ClientToolsFolder = nil -- Initialized in Init()

---- Utilities
local ToolHelpers

---- Knit Services
local ToolService

---- Other Components
local ActivationManager
local CooldownManager
local ValidationManager

---- Connections tracking
local _toolConnections = {} -- [tool] = { equipped, unequipped, activated }
local _characterConnections = {} -- [player] = connection

---- Cache for client module existence checks
local _clientModuleExistsCache = {} -- [toolId] = boolean

--[=[
	Check if a client module exists for this tool
	Used for deduplication - if client module exists, Full Mode is active
	@param toolId string
	@param toolData table
	@return boolean
]=]
local function HasClientModule(toolId: string, toolData: any): boolean
	-- Check cache first
	if _clientModuleExistsCache[toolId] ~= nil then
		return _clientModuleExistsCache[toolId]
	end
	
	-- Build path to client module
	-- Path: ClientSource/Client/ToolController/Tools/Categories/[Category]/[Subcategory]/[toolId].lua
	local exists = false
	
	if ClientToolsFolder then
		local categoryFolder = ClientToolsFolder:FindFirstChild(toolData.Category)
		if categoryFolder then
			local subcategoryFolder = categoryFolder:FindFirstChild(toolData.Subcategory)
			if subcategoryFolder then
				local toolModule = subcategoryFolder:FindFirstChild(toolId)
				exists = toolModule ~= nil and toolModule:IsA("ModuleScript")
			end
		end
	end
	
	-- Cache the result
	_clientModuleExistsCache[toolId] = exists
	
	return exists
end

--[=[
	Extract toolId from a Tool instance
	Uses ToolId attribute or derives from name
	@param tool Tool
	@return string? toolId or nil
]=]
local function GetToolIdFromInstance(tool: Tool): string?
	-- Check for ToolId attribute first
	local toolId = tool:GetAttribute("ToolId")
	if toolId and type(toolId) == "string" then
		return toolId
	end
	
	-- Derive from name (add underscores between words, lowercase)
	-- e.g., "SwordClassic" -> "sword_classic"
	local name = tool.Name
	local derived = name:gsub("(%u)", "_%1"):lower():gsub("^_", "")
	
	-- Verify this toolId exists in registry
	if ToolHelpers.GetToolData(derived) then
		return derived
	end
	
	-- Try exact name match
	if ToolHelpers.GetToolData(name) then
		return name
	end
	
	-- Try lowercase name
	if ToolHelpers.GetToolData(name:lower()) then
		return name:lower()
	end
	
	return nil
end

--[=[
	Handle native Tool.Equipped event
	@param player Player
	@param tool Tool
]=]
local function OnToolEquipped(player: Player, tool: Tool)
	local toolId = GetToolIdFromInstance(tool)
	if not toolId then
		-- Not a registered tool, ignore
		return
	end
	
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then
		return
	end
	
	-- Check if already tracked by ToolService (equipped via EquipTool method)
	local existingEquipped = ToolService._equippedTools[player]
	if existingEquipped and existingEquipped.toolId == toolId then
		-- Already tracked, skip duplicate handling
		return
	end
	
	-- Register this tool in ToolService tracking
	ToolService._equippedTools[player] = {
		toolId = toolId,
		toolInstance = tool,
	}
	
	-- Notify server tool module
	if ActivationManager then
		ActivationManager:OnToolEquipped(player, toolId)
	end
	
	-- Notify client (for client modules that listen to server signals)
	ToolService.Client.ToolEquipped:Fire(player, toolId)
	
	print("[NativeToolHandler] Tool equipped via native event:", toolId, "for player:", player.Name)
end

--[=[
	Handle native Tool.Unequipped event
	@param player Player
	@param tool Tool
]=]
local function OnToolUnequipped(player: Player, tool: Tool)
	local toolId = GetToolIdFromInstance(tool)
	if not toolId then
		return
	end
	
	-- Check if this tool was tracked
	local existingEquipped = ToolService._equippedTools[player]
	if not existingEquipped or existingEquipped.toolId ~= toolId then
		-- Not tracked or different tool, skip
		return
	end
	
	-- Notify server tool module (before cleanup)
	if ActivationManager then
		ActivationManager:OnToolUnequipped(player, toolId)
	end
	
	-- Clear tracking
	ToolService._equippedTools[player] = nil
	
	-- Notify client
	ToolService.Client.ToolUnequipped:Fire(player)
	
	print("[NativeToolHandler] Tool unequipped via native event:", toolId, "for player:", player.Name)
end

--[=[
	Handle native Tool.Activated event
	This is called when the tool is activated via mouse click or touch
	
	DEDUPLICATION LOGIC:
	- If client module exists → Full Mode → Skip (client sends RemoteFunction)
	- If no client module → Server-Only Mode → Process here
	
	@param player Player
	@param tool Tool
]=]
local function OnToolActivated(player: Player, tool: Tool)
	local toolId = GetToolIdFromInstance(tool)
	if not toolId then
		return
	end
	
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then
		return
	end
	
	-- DEDUPLICATION: Check if client module exists
	-- If yes, this is Full Mode - client will send RemoteFunction, skip native handling
	if HasClientModule(toolId, toolData) then
		-- Full Mode: Client handles input and sends RemoteFunction
		-- Don't process here to avoid double activation
		return
	end
	
	-- Server-Only Mode: No client module, process activation here
	print("[NativeToolHandler] Server-Only Mode activation for:", toolId)
	
	-- Validate activation
	if ValidationManager then
		local isValid, errorMsg = ValidationManager:ValidateActivation(player, toolId, nil)
		if not isValid then
			warn("[NativeToolHandler] Activation validation failed:", errorMsg)
			return
		end
	end
	
	-- Check cooldown
	if ToolService.GetComponent:IsOnCooldown(player, toolId) then
		-- Silently ignore - player is spamming
		return
	end
	
	-- Build target data from tool's mouse data (if available)
	local targetData = {
		Target = nil,
		Position = Vector3.zero,
		Direction = Vector3.new(0, 0, -1),
	}
	
	-- Get character look direction as fallback
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			targetData.Direction = hrp.CFrame.LookVector
			targetData.Position = hrp.Position + targetData.Direction * 5
		end
	end
	
	-- Activate the tool via ActivationManager
	if ActivationManager then
		local success = ActivationManager:Activate(player, toolId, targetData)
		
		if success then
			-- Start cooldown
			if CooldownManager then
				CooldownManager:StartCooldown(player, toolId)
			end
			
			-- Notify client
			ToolService.Client.ToolActivated:Fire(player, toolId, targetData)
			
			print("[NativeToolHandler] Tool activated via native event:", toolId)
		end
	end
end

--[=[
	Setup event listeners for a Tool instance
	@param player Player
	@param tool Tool
]=]
local function SetupToolListeners(player: Player, tool: Tool)
	-- Skip if already connected
	if _toolConnections[tool] then
		return
	end
	
	local connections = {}
	
	-- Tool.Equipped - fires when player equips the tool
	connections.equipped = tool.Equipped:Connect(function()
		OnToolEquipped(player, tool)
	end)
	
	-- Tool.Unequipped - fires when player unequips the tool
	connections.unequipped = tool.Unequipped:Connect(function()
		OnToolUnequipped(player, tool)
	end)
	
	-- Tool.Activated - fires when player activates (clicks with) the tool
	connections.activated = tool.Activated:Connect(function()
		OnToolActivated(player, tool)
	end)
	
	_toolConnections[tool] = connections
	
	-- If tool is already equipped (in character), trigger equip
	if tool.Parent and tool.Parent == player.Character then
		OnToolEquipped(player, tool)
	end
end

--[=[
	Cleanup event listeners for a Tool instance
	@param tool Tool
]=]
local function CleanupToolListeners(tool: Tool)
	local connections = _toolConnections[tool]
	if connections then
		for _, conn in pairs(connections) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end
		_toolConnections[tool] = nil
	end
end

--[=[
	Setup monitoring for a player's backpack and character
	@param player Player
]=]
local function SetupPlayerMonitoring(player: Player)
	-- Monitor Backpack for new tools
	local backpack = player:WaitForChild("Backpack")
	
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			SetupToolListeners(player, child)
		end
	end)
	
	backpack.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			-- Don't cleanup immediately - tool might be moving to character
			task.delay(0.1, function()
				if not child.Parent then
					CleanupToolListeners(child)
				end
			end)
		end
	end)
	
	-- Setup existing tools in backpack
	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") then
			SetupToolListeners(player, child)
		end
	end
	
	-- Monitor character for tools
	local function SetupCharacterMonitoring(character)
		if not character then return end
		
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				SetupToolListeners(player, child)
				-- Trigger equipped if just added to character
				task.defer(function()
					if child.Parent == character then
						OnToolEquipped(player, child)
					end
				end)
			end
		end)
		
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				-- Tool moved out of character - might be to backpack or destroyed
				task.defer(function()
					if child.Parent == backpack then
						-- Moved to backpack - trigger unequip
						OnToolUnequipped(player, child)
					elseif not child.Parent then
						-- Destroyed
						CleanupToolListeners(child)
					end
				end)
			end
		end)
		
		-- Setup existing tools in character
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				SetupToolListeners(player, child)
			end
		end
	end
	
	-- Monitor current character
	if player.Character then
		SetupCharacterMonitoring(player.Character)
	end
	
	-- Monitor future characters
	_characterConnections[player] = player.CharacterAdded:Connect(function(character)
		SetupCharacterMonitoring(character)
	end)
end

--[=[
	Cleanup all monitoring for a player
	@param player Player
]=]
local function CleanupPlayerMonitoring(player: Player)
	-- Disconnect character connection
	if _characterConnections[player] then
		_characterConnections[player]:Disconnect()
		_characterConnections[player] = nil
	end
	
	-- Cleanup tool connections for this player's tools
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				CleanupToolListeners(child)
			end
		end
	end
	
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				CleanupToolListeners(child)
			end
		end
	end
end

function NativeToolHandler.Start()
	-- Setup monitoring for existing players
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			SetupPlayerMonitoring(player)
		end)
	end
	
	-- Setup monitoring for new players
	Players.PlayerAdded:Connect(function(player)
		SetupPlayerMonitoring(player)
	end)
	
	-- Cleanup on player leaving
	Players.PlayerRemoving:Connect(function(player)
		CleanupPlayerMonitoring(player)
	end)
	
	print("[NativeToolHandler] Started - monitoring native tool events")
end

--[=[
	Clear the client module cache for a specific tool or all tools
	Useful for hot-reloading during development
	@param toolId string? - If nil, clears entire cache
]=]
function NativeToolHandler:ClearClientModuleCache(toolId: string?)
	if toolId then
		_clientModuleExistsCache[toolId] = nil
		print("[NativeToolHandler] Cleared client module cache for:", toolId)
	else
		_clientModuleExistsCache = {}
		print("[NativeToolHandler] Cleared all client module cache")
	end
end

function NativeToolHandler.Init()
	-- Initialize references
	ToolService = Knit.GetService("ToolService")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)
	
	-- Get other components
	ActivationManager = ToolService.Components.ActivationManager
	CooldownManager = ToolService.Components.CooldownManager
	ValidationManager = ToolService.Components.ValidationManager
	
	-- Get client tools folder for deduplication checks
	-- Path: ReplicatedStorage/ClientSource/Client/ToolController/Tools/Categories
	local ClientSource = ReplicatedStorage:FindFirstChild("ClientSource")
	if ClientSource then
		local Client = ClientSource:FindFirstChild("Client")
		if Client then
			local ToolController = Client:FindFirstChild("ToolController")
			if ToolController then
				local Tools = ToolController:FindFirstChild("Tools")
				if Tools then
					ClientToolsFolder = Tools:FindFirstChild("Categories")
				end
			end
		end
	end
	
	if ClientToolsFolder then
		print("[NativeToolHandler] Client tools folder found - deduplication enabled")
	else
		warn("[NativeToolHandler] Client tools folder not found - all tools will use Server-Only mode")
	end
end

return NativeToolHandler
