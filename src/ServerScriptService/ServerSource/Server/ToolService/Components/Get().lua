--!strict
-- ToolService Get Component
-- Read-only operations for tool data retrieval

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local GetComponent = {}

---- Utilities
local ToolHelpers

---- Knit Services
local ToolService

--[=[
	Get tool data by toolId
	@param toolId string
	@return table? Tool data or nil
]=]
function GetComponent:GetToolData(toolId: string)
	return ToolHelpers.GetToolData(toolId)
end

--[=[
	Get currently equipped tool for a player
	@param player Player
	@return table? { toolId: string, toolInstance: Tool }
]=]
function GetComponent:GetEquippedTool(player: Player)
	if not ToolService._equippedTools[player] then
		return nil
	end
	
	return ToolService._equippedTools[player]
end

--[=[
	Get cooldown remaining for a tool
	@param player Player
	@param toolId string
	@return number Seconds remaining on cooldown (0 if ready)
]=]
function GetComponent:GetToolCooldown(player: Player, toolId: string): number
	if not ToolService._cooldowns[player] then
		return 0
	end
	
	local cooldownEnd = ToolService._cooldowns[player][toolId]
	if not cooldownEnd then
		return 0
	end
	
	local remaining = cooldownEnd - tick()
	return math.max(0, remaining)
end

--[=[
	Check if a tool is on cooldown
	@param player Player
	@param toolId string
	@return boolean True if on cooldown
]=]
function GetComponent:IsOnCooldown(player: Player, toolId: string): boolean
	return self:GetToolCooldown(player, toolId) > 0
end

--[=[
	Get all tools a player owns (stub - requires inventory integration)
	@param player Player
	@return table Array of toolIds
]=]
function GetComponent:GetPlayerToolInventory(player: Player)
	-- TODO: Integrate with inventory system
	warn("[ToolService.Get] GetPlayerToolInventory not yet implemented")
	return {}
end

function GetComponent.Start()
	-- Component start logic
end

function GetComponent.Init()
	-- Initialize references
	ToolService = Knit.GetService("ToolService")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)
end

return GetComponent
