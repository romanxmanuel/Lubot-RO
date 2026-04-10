--!strict
-- ValidationManager.lua
-- Validates tool operations and prevents exploits

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ValidationManager = {}

---- Types
-- Tool user can be a Player or an NPC Model instance
-- NPCs are tracked via NPC_Service.ActiveNPCs[npcModel]
export type ToolUser = Player | Model

---- Utilities
local ToolHelpers
local ToolConstants

---- Knit Services
local ToolService
local NPC_Service -- TODO: Reference to NPC service for validation

--[=[
	Checks if the tool user is a Player instance
	@param toolUser ToolUser - The tool user to check
	@return boolean - True if the tool user is a Player
]=]
function ValidationManager:IsPlayer(toolUser: ToolUser): boolean
	return typeof(toolUser) == "Instance" and (toolUser :: Instance):IsA("Player")
end

--[=[
	Checks if the tool user is an NPC (Model instance)
	@param toolUser ToolUser - The tool user to check
	@return boolean - True if the tool user is an NPC Model
]=]
function ValidationManager:IsNPC(toolUser: ToolUser): boolean
	if typeof(toolUser) ~= "Instance" then
		return false
	end
	local instance = toolUser :: Instance
	-- NPC is a Model that is NOT a Player's character
	return instance:IsA("Model") and not instance:IsA("Player")
end

--[=[
	Validates if an NPC Model can use tools.
	Checks against NPC_Service.ActiveNPCs to verify the NPC is active.

	TODO: Implement NPC validation logic here:
	- Verify npcModel exists in NPC_Service.ActiveNPCs[npcModel]
	- Check if NPC is alive (Humanoid health > 0)
	- Validate NPC permissions for specific tools

	@param npcModel Model - The NPC Model instance
	@return boolean - True if NPC is valid
]=]
function ValidationManager:ValidateNPC(npcModel: Model): boolean
	-- TODO: Implement NPC validation against NPC_Service
	-- NPC_Service.ActiveNPCs[npcModel] should return the NPC data if active
	-- Marketplace ID for NPC system: 07473040-45dc-4afa-bb24-462e187d10ee

	-- Basic validation: check if model exists and has humanoid
	if not npcModel or not npcModel.Parent then
		return false
	end

	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	-- TODO: Check NPC_Service.ActiveNPCs[npcModel] for active status
	-- if not NPC_Service or not NPC_Service.ActiveNPCs[npcModel] then
	--     return false
	-- end

	return true
end

--[=[
	Validate if a tool user (player or NPC) can equip a tool
	@param toolUser ToolUser - Player or NPC Model
	@param toolId string
	@return boolean, string? (isValid, errorMessage)
]=]
function ValidationManager:ValidateEquip(toolUser: ToolUser, toolId: string): (boolean, string?)
	-- Check if tool user is valid (Player with character OR valid NPC Model)
	if self:IsPlayer(toolUser) then
		local player = toolUser :: Player
		if not player.Character then
			return false, "Invalid player or no character"
		end
	elseif self:IsNPC(toolUser) then
		if not self:ValidateNPC(toolUser :: Model) then
			return false, "Invalid NPC"
		end
	else
		return false, "Invalid tool user type"
	end

	-- Check if tool data exists
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then
		return false, "Tool data not found: " .. toolId
	end

	-- Check level requirement (if applicable)
	if toolData.RequiredLevel then
		-- TODO: Integrate with player level system
		-- For now, assume player meets requirement
	end

	-- Check ownership (TODO: Integrate with inventory system)
	-- For now, allow all tools

	return true, nil
end

--[=[
	Validate if a tool user (player or NPC) can activate a tool
	@param toolUser ToolUser - Player or NPC Model
	@param toolId string
	@param targetData any
	@return boolean, string? (isValid, errorMessage)
]=]
function ValidationManager:ValidateActivation(toolUser: ToolUser, toolId: string, targetData: any): (boolean, string?)
	-- Check if tool user is valid (Player with character OR valid NPC Model)
	if self:IsPlayer(toolUser) then
		local player = toolUser :: Player
		if not player.Character then
			return false, "Invalid player or no character"
		end
	elseif self:IsNPC(toolUser) then
		if not self:ValidateNPC(toolUser :: Model) then
			return false, "Invalid NPC"
		end
	else
		return false, "Invalid tool user type"
	end

	-- Check if tool data exists
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then
		return false, "Tool data not found: " .. toolId
	end

	-- Check rate limiting (anti-spam) - only for Players
	-- TODO: Consider if NPCs need rate limiting (probably not, as they're server-controlled)
	if self:IsPlayer(toolUser) then
		local isRateLimited = self:CheckRateLimit(toolUser :: Player)
		if isRateLimited then
			return false, "Rate limit exceeded - too many activations"
		end
	end

	-- Validate target data (basic checks)
	if targetData then
		if targetData.Position and typeof(targetData.Position) ~= "Vector3" then
			return false, "Invalid target position"
		end

		if targetData.Direction and typeof(targetData.Direction) ~= "Vector3" then
			return false, "Invalid target direction"
		end
	end

	-- NOTE: Range validation removed for melee weapons
	-- Melee weapons should always allow activation - hit detection happens via Handle.Touched
	-- Range validation can be added back for projectile/ranged weapons if needed

	return true, nil
end

--[=[
	Check if player is rate limited
	Prevents spam/exploit attempts
	@param player Player
	@return boolean True if rate limited
]=]
function ValidationManager:CheckRateLimit(player: Player): boolean
	local currentTime = tick()

	if not ToolService._activationCounts[player] then
		ToolService._activationCounts[player] = {
			lastReset = currentTime,
			count = 0,
		}
	end

	local playerData = ToolService._activationCounts[player]

	-- Reset counter every second
	if currentTime - playerData.lastReset >= 1 then
		playerData.lastReset = currentTime
		playerData.count = 0
	end

	-- Increment counter
	playerData.count += 1

	-- Check if exceeded limit
	local maxActivations = ToolConstants.MAX_ACTIVATIONS_PER_SECOND or 20
	if playerData.count > maxActivations then
		warn("[ValidationManager] Rate limit exceeded for player:", player.Name)
		return true
	end

	return false
end

--[=[
	Validate tool ownership (stub for inventory integration)
	@param toolUser ToolUser - Player or NPC Model
	@param toolId string
	@return boolean True if tool user owns/can use the tool
]=]
function ValidationManager:ValidateOwnership(toolUser: ToolUser, toolId: string): boolean
	if self:IsPlayer(toolUser) then
		-- TODO: Integrate with player inventory system
		return true
	elseif self:IsNPC(toolUser) then
		-- TODO: Integrate with NPC tool/loadout system via NPC_Service
		-- NPCs may have predefined tool loadouts or dynamic tool assignment
		-- Check NPC_Service.ActiveNPCs[npcModel] for tool permissions
		return true
	end
	return false
end

function ValidationManager.Start()
	-- Component start logic
end

function ValidationManager.Init()
	-- Initialize references
	ToolService = Knit.GetService("ToolService")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)
	ToolConstants = require(ReplicatedStorage.SharedSource.Datas.ToolDefinitions.ToolConstants)
end

return ValidationManager
