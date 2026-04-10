--!strict
-- ToolHelpers.lua
-- Utility module for easily accessing tool data from the registry

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolHelpers = {}

-- Cache the ToolRegistry
local ToolRegistry = require(ReplicatedStorage.SharedSource.Datas.ToolDefinitions.ToolRegistry)
local ToolConstants = require(ReplicatedStorage.SharedSource.Datas.ToolDefinitions.ToolConstants)

--[=[
	Get tool data by ToolId (searches all categories/subcategories)
	
	@param toolId string -- The unique identifier of the tool
	@return table? -- Tool data table, or nil if not found
]=]
function ToolHelpers.GetToolData(toolId: string)
	for categoryName, category in pairs(ToolRegistry) do
		for subcategoryName, subcategory in pairs(category) do
			if subcategory[toolId] then
				return subcategory[toolId]
			end
		end
	end
	
	warn("[ToolHelpers] Tool not found:", toolId)
	return nil
end

--[=[
	Get tool data by Category and Subcategory path (faster than searching all)
	
	@param category string -- The category name (e.g., "Weapons")
	@param subcategory string -- The subcategory name (e.g., "Swords")
	@param toolId string -- The tool identifier
	@return table? -- Tool data table, or nil if not found
]=]
function ToolHelpers.GetToolDataByPath(category: string, subcategory: string, toolId: string)
	if ToolRegistry[category] and ToolRegistry[category][subcategory] then
		local tool = ToolRegistry[category][subcategory][toolId]
		if tool then
			return tool
		end
	end
	
	warn("[ToolHelpers] Tool not found at path:", category .. "/" .. subcategory .. "/" .. toolId)
	return nil
end

--[=[
	Get all tools in a category
	
	@param category string -- The category name
	@return table -- Dictionary of subcategories containing tools
]=]
function ToolHelpers.GetToolsByCategory(category: string)
	if ToolRegistry[category] then
		return ToolRegistry[category]
	end
	
	warn("[ToolHelpers] Category not found:", category)
	return {}
end

--[=[
	Get all tools in a subcategory
	
	@param category string -- The category name
	@param subcategory string -- The subcategory name
	@return table -- Dictionary of tools in the subcategory
]=]
function ToolHelpers.GetToolsBySubcategory(category: string, subcategory: string)
	if ToolRegistry[category] and ToolRegistry[category][subcategory] then
		return ToolRegistry[category][subcategory]
	end
	
	warn("[ToolHelpers] Subcategory not found:", category .. "/" .. subcategory)
	return {}
end

--[=[
	Get Tool instance from Assets folder
	
	@param category string -- The category name
	@param subcategory string -- The subcategory name
	@param toolName string -- The Tool instance name
	@return Tool? -- Tool instance, or nil if not found
]=]
function ToolHelpers.GetToolAsset(category: string, subcategory: string, toolName: string)
	local toolsFolder = ReplicatedStorage:WaitForChild("Assets", 5):WaitForChild("Tools", 5)
	local categoryFolder = toolsFolder:FindFirstChild(category)
	
	if categoryFolder then
		local subcategoryFolder = categoryFolder:FindFirstChild(subcategory)
		if subcategoryFolder then
			local toolInstance = subcategoryFolder:FindFirstChild(toolName)
			if toolInstance and toolInstance:IsA("Tool") then
				return toolInstance
			end
		end
	end
	
	warn("[ToolHelpers] Tool asset not found:", category .. "/" .. subcategory .. "/" .. toolName)
	return nil
end

--[=[
	Validate tool data structure
	
	@param toolData table -- The tool data to validate
	@return boolean -- True if valid, false otherwise
	@return string? -- Error message if invalid
]=]
function ToolHelpers.ValidateToolData(toolData: any): (boolean, string?)
	if type(toolData) ~= "table" then
		return false, "Tool data must be a table"
	end
	
	-- Required fields
	if not toolData.ToolId then
		return false, "Missing required field: ToolId"
	end
	
	if not toolData.Category then
		return false, "Missing required field: Category"
	end
	
	if not toolData.Subcategory then
		return false, "Missing required field: Subcategory"
	end
	
	if not toolData.Stats then
		return false, "Missing required field: Stats"
	end
	
	if not toolData.BehaviorConfig then
		return false, "Missing required field: BehaviorConfig"
	end
	
	return true, nil
end

--[=[
	Get tool constant value
	
	@param constantName string -- Name of the constant
	@return any -- The constant value
]=]
function ToolHelpers.GetConstant(constantName: string): any
	return ToolConstants[constantName]
end

--[=[
	Get all tool constants
	
	@return table -- The ToolConstants table
]=]
function ToolHelpers.GetAllConstants(): any
	return ToolConstants
end

return ToolHelpers
