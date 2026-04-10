--!strict
-- EquipManager.lua
-- Manages equipping and unequipping tools for players

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local EquipManager = {}

---- Utilities
local ToolFactory

---- Knit Services
local ToolService

---- Other Components
local ActivationManager

--[=[
	Equip a tool to a player
	@param player Player
	@param toolId string
	@return boolean Success status
]=]
function EquipManager:Equip(player: Player, toolId: string): boolean
	if not player.Character then
		warn("[EquipManager] Cannot equip - player has no character")
		return false
	end
	
	-- Create tool instance
	local toolInstance = ToolFactory.CreateTool(toolId)
	if not toolInstance then
		warn("[EquipManager] Failed to create tool instance:", toolId)
		return false
	end
	
	-- Equip to player (parent to character)
	local success = ToolFactory.EquipTool(player, toolInstance)
	if not success then
		warn("[EquipManager] Failed to equip tool to player")
		toolInstance:Destroy()
		return false
	end
	
	-- Track equipped tool
	ToolService._equippedTools[player] = {
		toolId = toolId,
		toolInstance = toolInstance,
	}

	-- Notify tool module of equip
	ActivationManager:OnToolEquipped(player, toolId)

	print("[EquipManager] Successfully equipped tool:", toolId, "to player:", player.Name)
	return true
end

--[=[
	Unequip current tool from player
	@param player Player
	@return boolean Success status
]=]
function EquipManager:Unequip(player: Player): boolean
	local equippedTool = ToolService._equippedTools[player]

	if not equippedTool then
		warn("[EquipManager] No tool equipped to unequip")
		return false
	end

	local toolId = equippedTool.toolId

	-- Notify tool module of unequip (before destroying)
	ActivationManager:OnToolUnequipped(player, toolId)

	-- Destroy tool instance
	if equippedTool.toolInstance then
		equippedTool.toolInstance:Destroy()
	end

	-- Clear tracking
	ToolService._equippedTools[player] = nil

	print("[EquipManager] Successfully unequipped tool for player:", player.Name)
	return true
end

--[=[
	Get equipped tool instance for a player
	@param player Player
	@return Tool? Tool instance or nil
]=]
function EquipManager:GetEquippedInstance(player: Player): Tool?
	local equippedTool = ToolService._equippedTools[player]
	return equippedTool and equippedTool.toolInstance
end

function EquipManager.Start()
	-- Component start logic
end

function EquipManager.Init()
	-- Initialize references
	ToolService = Knit.GetService("ToolService")
	ToolFactory = require(ReplicatedStorage.SharedSource.Utilities.ToolFactory)

	-- Get ActivationManager component
	ActivationManager = ToolService.Components.ActivationManager
end

return EquipManager
