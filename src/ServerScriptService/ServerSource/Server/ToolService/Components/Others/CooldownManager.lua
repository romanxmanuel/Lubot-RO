--!strict
-- CooldownManager.lua
-- Manages tool cooldowns for players

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local CooldownManager = {}

---- Utilities
local ToolHelpers

---- Knit Services
local ToolService

--[=[
	Start cooldown for a tool
	@param player Player
	@param toolId string
]=]
function CooldownManager:StartCooldown(player: Player, toolId: string)
	-- Get tool data to find cooldown duration
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData or not toolData.Stats.Cooldown then
		warn("[CooldownManager] No cooldown data for tool:", toolId)
		return
	end
	
	local cooldownDuration = toolData.Stats.Cooldown
	
	-- Initialize cooldown table for player if needed
	if not ToolService._cooldowns[player] then
		ToolService._cooldowns[player] = {}
	end
	
	-- Set cooldown end time
	local cooldownEnd = tick() + cooldownDuration
	ToolService._cooldowns[player][toolId] = cooldownEnd
	
	-- Notify client of cooldown start
	ToolService.Client.ToolCooldownStart:Fire(player, toolId, cooldownDuration)
	
	print("[CooldownManager] Started cooldown for tool:", toolId, "duration:", cooldownDuration, "s")
end

--[=[
	Check if a tool is on cooldown
	@param player Player
	@param toolId string
	@return boolean True if on cooldown
]=]
function CooldownManager:IsOnCooldown(player: Player, toolId: string): boolean
	if not ToolService._cooldowns[player] then
		return false
	end
	
	local cooldownEnd = ToolService._cooldowns[player][toolId]
	if not cooldownEnd then
		return false
	end
	
	return tick() < cooldownEnd
end

--[=[
	Get remaining cooldown time
	@param player Player
	@param toolId string
	@return number Seconds remaining (0 if not on cooldown)
]=]
function CooldownManager:GetRemainingCooldown(player: Player, toolId: string): number
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
	Reset cooldown for a tool (admin/debug use)
	@param player Player
	@param toolId string
]=]
function CooldownManager:ResetCooldown(player: Player, toolId: string)
	if ToolService._cooldowns[player] then
		ToolService._cooldowns[player][toolId] = nil
		print("[CooldownManager] Reset cooldown for tool:", toolId)
	end
end

--[=[
	Clear all cooldowns for a player
	@param player Player
]=]
function CooldownManager:ClearAllCooldowns(player: Player)
	ToolService._cooldowns[player] = nil
	print("[CooldownManager] Cleared all cooldowns for player:", player.Name)
end

function CooldownManager.Start()
	-- Component start logic
end

function CooldownManager.Init()
	-- Initialize references
	ToolService = Knit.GetService("ToolService")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)
end

return CooldownManager
