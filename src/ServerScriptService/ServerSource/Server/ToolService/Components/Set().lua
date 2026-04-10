--!strict
-- ToolService Set Component
-- Write operations for tool state modification

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SetComponent = {}

---- Utilities
local ToolHelpers
local ToolFactory

---- Knit Services
local ToolService

---- Other Components
local ValidationManager
local EquipManager
local CooldownManager
local ActivationManager

--[=[
	Equip a tool for a player
	@param player Player
	@param toolId string
	@return boolean Success status
]=]
function SetComponent:EquipTool(player: Player, toolId: string): boolean
	-- Validate request
	local isValid, errorMsg = ValidationManager:ValidateEquip(player, toolId)
	if not isValid then
		warn("[ToolService.Set] Equip validation failed:", errorMsg)
		return false
	end
	
	-- Unequip current tool if any
	local currentTool = ToolService.GetComponent:GetEquippedTool(player)
	if currentTool then
		self:UnequipTool(player)
	end
	
	-- Equip new tool
	local success = EquipManager:Equip(player, toolId)
	
	if success then
		-- Notify client
		ToolService.Client.ToolEquipped:Fire(player, toolId)
		print("[ToolService.Set] Equipped tool:", toolId, "for player:", player.Name)
	end
	
	return success
end

--[=[
	Unequip current tool from player
	@param player Player
	@return boolean Success status
]=]
function SetComponent:UnequipTool(player: Player): boolean
	local currentTool = ToolService.GetComponent:GetEquippedTool(player)
	
	if not currentTool then
		warn("[ToolService.Set] No tool equipped to unequip")
		return false
	end
	
	-- Unequip
	local success = EquipManager:Unequip(player)
	
	if success then
		-- Notify client
		ToolService.Client.ToolUnequipped:Fire(player)
		print("[ToolService.Set] Unequipped tool for player:", player.Name)
	end
	
	return success
end

--[=[
	Activate a tool (player uses the tool)
	@param player Player
	@param targetData table { Target: Instance?, Position: Vector3?, Direction: Vector3? }
	@return boolean Success status
]=]
function SetComponent:ActivateTool(player: Player, targetData: any): boolean
	-- Get equipped tool
	local equippedTool = ToolService.GetComponent:GetEquippedTool(player)
	if not equippedTool then
		warn("[ToolService.Set] No tool equipped to activate")
		return false
	end
	
	local toolId = equippedTool.toolId
	
	-- Validate activation
	local isValid, errorMsg = ValidationManager:ValidateActivation(player, toolId, targetData)
	if not isValid then
		warn("[ToolService.Set] Activation validation failed:", errorMsg)
		return false
	end
	
	-- Check cooldown
	if ToolService.GetComponent:IsOnCooldown(player, toolId) then
		warn("[ToolService.Set] Tool is on cooldown")
		return false
	end
	
	-- Activate tool
	local success = ActivationManager:Activate(player, toolId, targetData)
	
	if success then
		-- Start cooldown
		CooldownManager:StartCooldown(player, toolId)
		
		-- Notify client
		ToolService.Client.ToolActivated:Fire(player, toolId, targetData)
		print("[ToolService.Set] Activated tool:", toolId, "for player:", player.Name)
	end
	
	return success
end

--[=[
	Update tool state (for toggleable tools, durability, etc.)
	@param player Player
	@param toolId string
	@param newState any
	@return boolean Success status
]=]
function SetComponent:UpdateToolState(player: Player, toolId: string, newState: any): boolean
	-- TODO: Implement state management
	-- This will be used for things like:
	-- - Toggle flashlight on/off
	-- - Update durability
	-- - Track ammo count
	
	ToolService.Client.ToolStateChanged:Fire(player, toolId, newState)
	return true
end

function SetComponent.Start()
	-- Component start logic
end

function SetComponent.Init()
	-- Initialize references
	ToolService = Knit.GetService("ToolService")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)
	ToolFactory = require(ReplicatedStorage.SharedSource.Utilities.ToolFactory)
	
	-- Get other components
	ValidationManager = ToolService.Components.ValidationManager
	EquipManager = ToolService.Components.EquipManager
	CooldownManager = ToolService.Components.CooldownManager
	ActivationManager = ToolService.Components.ActivationManager
end

return SetComponent
