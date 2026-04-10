--!strict
-- ToolFactory.lua
-- Factory for creating and configuring Tool instances

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolFactory = {}

-- Require helper modules
local ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)

--[=[
	Create a Tool instance from tool data
	
	@param toolId string -- The tool identifier
	@return Tool? -- Cloned and configured Tool instance, or nil if failed
]=]
function ToolFactory.CreateTool(toolId: string): Tool?
	local toolData = ToolHelpers.GetToolData(toolId)
	
	if not toolData then
		warn("[ToolFactory] Cannot create tool - data not found:", toolId)
		return nil
	end
	
	-- Get the Tool asset from Assets folder
	-- Use AssetName if specified, otherwise fall back to ToolId without underscores
	local assetName = toolData.AssetName or toolData.ToolId:gsub("_", "")
	local toolAsset = ToolHelpers.GetToolAsset(
		toolData.Category,
		toolData.Subcategory,
		assetName
	)
	
	if not toolAsset then
		warn("[ToolFactory] Cannot create tool - asset not found:", toolId)
		return nil
	end
	
	-- Clone the tool
	local toolClone = toolAsset:Clone()
	
	-- Store tool data reference as attributes for easy access
	toolClone:SetAttribute("ToolId", toolData.ToolId)
	toolClone:SetAttribute("Category", toolData.Category)
	toolClone:SetAttribute("Subcategory", toolData.Subcategory)
	
	-- Store stats as attributes
	if toolData.Stats then
		for statName, statValue in pairs(toolData.Stats) do
			toolClone:SetAttribute(statName, statValue)
		end
	end
	
	return toolClone
end

--[=[
	Equip a tool to a player
	
	@param player Player -- The player to equip the tool to
	@param toolInstance Tool -- The Tool instance to equip
	@return boolean -- True if successfully equipped
]=]
function ToolFactory.EquipTool(player: Player, toolInstance: Tool): boolean
	if not player.Character then
		warn("[ToolFactory] Cannot equip tool - player has no character")
		return false
	end
	
	-- Parent the tool to the character (this equips it)
	toolInstance.Parent = player.Character
	
	return true
end

--[=[
	Unequip a tool from a player
	
	@param player Player -- The player to unequip from
	@param toolInstance Tool -- The Tool instance to unequip
	@return boolean -- True if successfully unequipped
]=]
function ToolFactory.UnequipTool(player: Player, toolInstance: Tool): boolean
	if not player.Character then
		warn("[ToolFactory] Cannot unequip tool - player has no character")
		return false
	end
	
	-- Remove the tool from character (unequips it)
	if toolInstance.Parent == player.Character then
		toolInstance.Parent = nil
	end
	
	return true
end

--[=[
	Get tool data from a Tool instance
	
	@param toolInstance Tool -- The Tool instance
	@return table? -- Tool data from registry, or nil if not found
]=]
function ToolFactory.GetToolDataFromInstance(toolInstance: Tool)
	local toolId = toolInstance:GetAttribute("ToolId")
	
	if not toolId then
		warn("[ToolFactory] Tool instance has no ToolId attribute")
		return nil
	end
	
	return ToolHelpers.GetToolData(toolId)
end

--[=[
	Check if a Tool instance is valid (has proper attributes)
	
	@param toolInstance any -- The instance to check
	@return boolean -- True if valid tool
]=]
function ToolFactory.IsValidTool(toolInstance: any): boolean
	if not toolInstance or not toolInstance:IsA("Tool") then
		return false
	end
	
	-- Check for required attributes
	local toolId = toolInstance:GetAttribute("ToolId")
	local category = toolInstance:GetAttribute("Category")
	local subcategory = toolInstance:GetAttribute("Subcategory")
	
	return toolId ~= nil and category ~= nil and subcategory ~= nil
end

return ToolFactory
