--!strict
-- ToolModuleManager.lua
-- Client-side manager for loading and calling per-tool modules

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ToolModuleManager = {}

---- Utilities
local ToolHelpers

---- Knit Controllers
local ToolController

---- Tool Modules Cache
local _toolModules = {} -- [toolId] = module

---- Tools folder reference
local ToolsFolder

--[=[
	Get or load a tool module by toolId
	@param toolId string
	@param toolData table
	@return table? Tool module or nil
]=]
function ToolModuleManager:GetToolModule(toolId: string, toolData: any)
	-- Check cache first
	if _toolModules[toolId] then
		return _toolModules[toolId]
	end

	-- Build path: Tools/Categories/[Category]/[Subcategory]/[toolId].lua
	if not ToolsFolder then
		warn("[ToolModuleManager] Tools folder not found")
		return nil
	end

	local categoriesFolder = ToolsFolder:FindFirstChild("Categories")
	if not categoriesFolder then
		warn("[ToolModuleManager] Categories folder not found")
		return nil
	end

	local categoryFolder = categoriesFolder:FindFirstChild(toolData.Category)
	if not categoryFolder then
		-- Not an error - tool may not have client module
		return nil
	end

	local subcategoryFolder = categoryFolder:FindFirstChild(toolData.Subcategory)
	if not subcategoryFolder then
		return nil
	end

	local toolModule = subcategoryFolder:FindFirstChild(toolId)
	if not toolModule or not toolModule:IsA("ModuleScript") then
		return nil
	end

	-- Load and cache the module
	local success, result = pcall(require, toolModule)
	if not success then
		warn("[ToolModuleManager] Failed to load tool module:", toolId, result)
		return nil
	end

	-- Initialize module if it has Init function
	if result.Init then
		local initSuccess, initError = pcall(result.Init)
		if not initSuccess then
			warn("[ToolModuleManager] Failed to init tool module:", toolId, initError)
		end
	end

	_toolModules[toolId] = result
	print("[ToolModuleManager] Loaded client tool module:", toolId)

	return result
end

--[=[
	Called when tool is activated - calls tool module's OnActivate
	@param toolId string
	@param toolData table
	@param targetData any
]=]
function ToolModuleManager:OnToolActivated(toolId: string, toolData: any, targetData: any)
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnActivate then
		local success, err = pcall(function()
			toolModule:OnActivate(toolData, targetData)
		end)
		if not success then
			warn("[ToolModuleManager] OnActivate error for:", toolId, err)
		end
	end
end

--[=[
	Called when tool is equipped - calls tool module's OnEquip
	@param toolId string
	@param toolData table
]=]
function ToolModuleManager:OnToolEquipped(toolId: string, toolData: any)
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnEquip then
		local success, err = pcall(function()
			toolModule:OnEquip(toolData)
		end)
		if not success then
			warn("[ToolModuleManager] OnEquip error for:", toolId, err)
		end
	end
end

--[=[
	Called when tool is unequipped - calls tool module's OnUnequip
	@param toolId string
	@param toolData table
]=]
function ToolModuleManager:OnToolUnequipped(toolId: string, toolData: any)
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnUnequip then
		local success, err = pcall(function()
			toolModule:OnUnequip(toolData)
		end)
		if not success then
			warn("[ToolModuleManager] OnUnequip error for:", toolId, err)
		end
	end
end

--[=[
	Called when tool state changes - calls tool module's OnStateChanged
	@param toolId string
	@param toolData table
	@param newState any
]=]
function ToolModuleManager:OnToolStateChanged(toolId: string, toolData: any, newState: any)
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnStateChanged then
		local success, err = pcall(function()
			toolModule:OnStateChanged(newState)
		end)
		if not success then
			warn("[ToolModuleManager] OnStateChanged error for:", toolId, err)
		end
	end
end

--[=[
	Check if a tool is a "hold tool" (has OnButtonDown callback)
	@param toolId string
	@param toolData table
	@return boolean
]=]
function ToolModuleManager:IsHoldTool(toolId: string, toolData: any): boolean
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnButtonDown then
		return true
	end
	return false
end

--[=[
	Called when button is pressed (for hold tools) - calls tool module's OnButtonDown
	@param toolId string
	@param toolData table
	@param targetData any
]=]
function ToolModuleManager:OnButtonDown(toolId: string, toolData: any, targetData: any)
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnButtonDown then
		local success, err = pcall(function()
			toolModule:OnButtonDown(toolData, targetData)
		end)
		if not success then
			warn("[ToolModuleManager] OnButtonDown error for:", toolId, err)
		end
	end
end

--[=[
	Called when button is released (for hold tools) - calls tool module's OnButtonUp
	@param toolId string
	@param toolData table
	@param targetData any
]=]
function ToolModuleManager:OnButtonUp(toolId: string, toolData: any, targetData: any)
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnButtonUp then
		local success, err = pcall(function()
			toolModule:OnButtonUp(toolData, targetData)
		end)
		if not success then
			warn("[ToolModuleManager] OnButtonUp error for:", toolId, err)
		end
	end
end

--[=[
	Clear cached module
	@param toolId string
]=]
function ToolModuleManager:ClearModuleCache(toolId: string)
	_toolModules[toolId] = nil
	print("[ToolModuleManager] Cleared cache for:", toolId)
end

--[=[
	Clear all cached modules
]=]
function ToolModuleManager:ClearAllModuleCache()
	_toolModules = {}
	print("[ToolModuleManager] Cleared all module cache")
end

--[=[
	Get all loaded hold tools (for debugging)
	@return table
]=]
function ToolModuleManager:GetLoadedHoldTools(): { string }
	local holdTools = {}
	for toolId, toolModule in pairs(_toolModules) do
		if toolModule.OnButtonDown then
			table.insert(holdTools, toolId)
		end
	end
	return holdTools
end

function ToolModuleManager.Start()
	-- Nothing to do on start
end

function ToolModuleManager.Init()
	-- Initialize references
	ToolController = Knit.GetController("ToolController")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)

	-- Get Tools folder reference
	ToolsFolder = script.Parent.Parent.Parent:FindFirstChild("Tools")
	if not ToolsFolder then
		warn("[ToolModuleManager] Tools folder not found at expected location")
	end
end

return ToolModuleManager
