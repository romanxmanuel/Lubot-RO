--!strict
-- ToolController Get Component
-- Read-only operations for client-side tool data

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local GetComponent = {}

local plr = game.Players.LocalPlayer

---- Utilities
local ToolHelpers

---- Knit Controllers
local ToolController

--[=[
	Get currently equipped tool data
	@return table? { toolId: string, toolInstance: Tool, toolData: table }
]=]
function GetComponent:GetEquippedTool()
	if not ToolController._currentTool then
		return nil
	end
	
	return ToolController._currentTool
end

--[=[
	Get cooldown remaining for a tool
	@param toolId string
	@return number Seconds remaining on cooldown (0 if ready)
]=]
function GetComponent:GetToolCooldownRemaining(toolId: string): number
	local cooldownEnd = ToolController._cooldowns[toolId]
	if not cooldownEnd then
		return 0
	end
	
	local remaining = cooldownEnd - tick()
	return math.max(0, remaining)
end

--[=[
	Check if a tool is on cooldown
	@param toolId string
	@return boolean True if on cooldown
]=]
function GetComponent:IsOnCooldown(toolId: string): boolean
	return self:GetToolCooldownRemaining(toolId) > 0
end

--[=[
	Check if current tool is ready to use (equipped and not on cooldown)
	@return boolean True if ready
]=]
function GetComponent:IsToolReady(): boolean
	local currentTool = self:GetEquippedTool()
	if not currentTool then
		return false
	end
	
	local isOnCooldown = self:IsOnCooldown(currentTool.toolId)
	return not isOnCooldown
end

--[=[
	Get tool instance from character
	@return Tool? Tool instance or nil
]=]
function GetComponent:GetToolInstance(): Tool?
	local character = plr.Character
	if not character then return nil end
	
	-- Find tool in character
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end
	
	return nil
end

--[=[
	Get tool data by toolId
	@param toolId string
	@return table? Tool data from registry
]=]
function GetComponent:GetToolData(toolId: string)
	return ToolHelpers.GetToolData(toolId)
end

function GetComponent.Start()
	-- Component start logic
end

function GetComponent.Init()
	-- Initialize references
	ToolController = Knit.GetController("ToolController")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)
end

return GetComponent
