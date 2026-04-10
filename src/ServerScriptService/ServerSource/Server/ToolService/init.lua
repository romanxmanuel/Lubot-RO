--!strict
-- ToolService
-- Server-side tool management system
-- Handles tool registry, validation, equipping, and activation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ToolService = Knit.CreateService({
	Name = "ToolService",
	Instance = script, -- Automatically initializes components
	
	Client = {
		-- RemoteEvents (Signals)
		ToolEquipped = Knit.CreateSignal(), -- Fired when tool is equipped
		ToolUnequipped = Knit.CreateSignal(), -- Fired when tool is unequipped
		ToolActivated = Knit.CreateSignal(), -- Fired when tool is activated
		ToolCooldownStart = Knit.CreateSignal(), -- Fired when cooldown starts
		ToolStateChanged = Knit.CreateSignal(), -- Fired when tool state changes
		
		-- Note: HoldToolButtonState and HoldToolMousePosition are registered
		-- dynamically by ActivationManager and HoldToolStateManager components
	},
	
	-- Internal state tracking
	_equippedTools = {}, -- [player] = { toolId, toolInstance }
	_cooldowns = {}, -- [player][toolId] = tick()
	_activationCounts = {}, -- [player] = { lastReset, count } for rate limiting
})

---- Utilities
local ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)
local ToolFactory = require(ReplicatedStorage.SharedSource.Utilities.ToolFactory)

---- Knit Services
-- (None required for initial implementation)

--[=[
	Get tool data for a specific tool
	Delegates to GetComponent
]=]
function ToolService:GetToolData(toolId: string)
	return self.GetComponent:GetToolData(toolId)
end

--[=[
	Get currently equipped tool for a player
	Delegates to GetComponent
]=]
function ToolService:GetEquippedTool(player: Player)
	return self.GetComponent:GetEquippedTool(player)
end

--[=[
	Get cooldown status for a tool
	Delegates to GetComponent
]=]
function ToolService:GetToolCooldown(player: Player, toolId: string)
	return self.GetComponent:GetToolCooldown(player, toolId)
end

--[=[
	Equip a tool for a player
	Delegates to SetComponent
]=]
function ToolService:EquipTool(player: Player, toolId: string)
	return self.SetComponent:EquipTool(player, toolId)
end

--[=[
	Unequip current tool from player
	Delegates to SetComponent
]=]
function ToolService:UnequipTool(player: Player)
	return self.SetComponent:UnequipTool(player)
end

--[=[
	Activate tool (process tool use)
	Delegates to SetComponent
]=]
function ToolService:ActivateTool(player: Player, targetData: any)
	return self.SetComponent:ActivateTool(player, targetData)
end

--[=[
	Update tool state
	Delegates to SetComponent
]=]
function ToolService:UpdateToolState(player: Player, toolId: string, newState: any)
	return self.SetComponent:UpdateToolState(player, toolId, newState)
end

-- ============================================
-- CLIENT REMOTE FUNCTIONS
-- ============================================

--[=[
	Client requests to equip a tool
]=]
function ToolService.Client:RequestEquipTool(player: Player, toolId: string)
	return self.Server:EquipTool(player, toolId)
end

--[=[
	Client requests to unequip current tool
]=]
function ToolService.Client:RequestUnequipTool(player: Player)
	return self.Server:UnequipTool(player)
end

--[=[
	Client requests to activate tool
]=]
function ToolService.Client:RequestActivateTool(player: Player, targetData: any)
	return self.Server:ActivateTool(player, targetData)
end

--[=[
	Client requests tool data
]=]
function ToolService.Client:GetToolData(player: Player, toolId: string)
	return self.Server:GetToolData(toolId)
end

-- ============================================
-- HOLD TOOL SUPPORT
-- ============================================

--[=[
	Get the latest mouse position for a player (for hold tools)
	Delegates to HoldToolStateManager
	@param player Player
	@return Vector3?
]=]
function ToolService:GetHoldToolMousePosition(player: Player): Vector3?
	return self.Components.HoldToolStateManager:GetMousePosition(player)
end

--[=[
	Clear hold tool mouse position for a player
	Delegates to HoldToolStateManager
	@param player Player
]=]
function ToolService:ClearHoldToolMousePosition(player: Player)
	self.Components.HoldToolStateManager:ClearMousePosition(player)
end

-- ============================================
-- LIFECYCLE METHODS
-- ============================================

function ToolService:KnitStart()
	-- Listen for player removing (cleanup)
	Players.PlayerRemoving:Connect(function(player)
		-- Clean up player data
		self._equippedTools[player] = nil
		self._cooldowns[player] = nil
		self._activationCounts[player] = nil
		self.Components.HoldToolStateManager:CleanupPlayer(player)
	end)
	
	-- Note: HoldToolButtonState handled by ActivationManager
	-- Note: HoldToolMousePosition handled by HoldToolStateManager
	
	print("[ToolService] Started successfully")
end

function ToolService:KnitInit()
	-- Components are automatically initialized
	print("[ToolService] Initialized")
end

return ToolService
