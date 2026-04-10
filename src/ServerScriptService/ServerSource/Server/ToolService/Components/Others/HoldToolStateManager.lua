--!strict
-- HoldToolStateManager
-- Manages hold tool mouse position state for players
-- Used by hold-to-fire tools (like Blow Dryer) to track where players are aiming

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local HoldToolStateManager = {}

---- Internal State
local _mousePositions: { [Player]: Vector3 } = {}

---- Knit Services
local ToolService

---- Registered Signals
local HoldToolMousePositionSignal

--[=[
	Get the latest mouse position for a player (for hold tools)
	@param player Player
	@return Vector3?
]=]
function HoldToolStateManager:GetMousePosition(player: Player): Vector3?
	return _mousePositions[player]
end

--[=[
	Set the mouse position for a player
	@param player Player
	@param position Vector3
]=]
function HoldToolStateManager:SetMousePosition(player: Player, position: Vector3)
	_mousePositions[player] = position
end

--[=[
	Clear hold tool mouse position for a player
	@param player Player
]=]
function HoldToolStateManager:ClearMousePosition(player: Player)
	_mousePositions[player] = nil
end

--[=[
	Clean up all state for a player (called on PlayerRemoving)
	@param player Player
]=]
function HoldToolStateManager:CleanupPlayer(player: Player)
	_mousePositions[player] = nil
end

function HoldToolStateManager.Start()
	-- Connect to HoldToolMousePosition signal
	HoldToolMousePositionSignal:Connect(function(player: Player, toolId: string, position: Vector3)
		if typeof(toolId) ~= "string" then return end
		if typeof(position) ~= "Vector3" then return end
		
		HoldToolStateManager:SetMousePosition(player, position)
	end)
end

function HoldToolStateManager.Init()
	ToolService = Knit.GetService("ToolService")
	
	-- Register client signal for mouse position updates
	HoldToolMousePositionSignal = Knit.RegisterClientSignal(ToolService, "HoldToolMousePosition")
end

return HoldToolStateManager
