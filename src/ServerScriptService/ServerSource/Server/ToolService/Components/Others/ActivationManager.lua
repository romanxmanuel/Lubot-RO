--!strict
-- ActivationManager.lua
-- Handles tool activation logic by loading tool-specific modules dynamically

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ActivationManager = {}

---- Utilities
local ToolHelpers

---- Knit Services
local ToolService

---- Tool Modules Cache
local _toolModules = {} -- [toolId] = module

---- Tools folder reference
local ToolsFolder

---- Registered Signals
local HoldToolButtonStateSignal

--[=[
	Get or load a tool module by toolId
	@param toolId string
	@param toolData table
	@return table? Tool module or nil
]=]
function ActivationManager:GetToolModule(toolId: string, toolData: any)
	-- Check cache first
	if _toolModules[toolId] then
		return _toolModules[toolId]
	end

	-- Build path: Tools/Categories/[Category]/[Subcategory]/[toolId].lua
	if not ToolsFolder then
		warn("[ActivationManager] Tools folder not found")
		return nil
	end

	local categoriesFolder = ToolsFolder:FindFirstChild("Categories")
	if not categoriesFolder then
		warn("[ActivationManager] Categories folder not found")
		return nil
	end

	local categoryFolder = categoriesFolder:FindFirstChild(toolData.Category)
	if not categoryFolder then
		-- Not an error - tool may not have server module (client-only tool)
		return nil
	end

	local subcategoryFolder = categoryFolder:FindFirstChild(toolData.Subcategory)
	if not subcategoryFolder then
		-- Not an error - tool may not have server module
		return nil
	end

	local toolModule = subcategoryFolder:FindFirstChild(toolId)
	if not toolModule or not toolModule:IsA("ModuleScript") then
		-- Not an error - tool may not have server module
		return nil
	end

	-- Load and cache the module
	local success, result = pcall(require, toolModule)
	if not success then
		warn("[ActivationManager] Failed to load tool module:", toolId, result)
		return nil
	end

	-- Initialize module if it has Init function
	if result.Init then
		local initSuccess, initError = pcall(result.Init)
		if not initSuccess then
			warn("[ActivationManager] Failed to init tool module:", toolId, initError)
		end
	end

	_toolModules[toolId] = result
	print("[ActivationManager] Loaded tool module:", toolId)

	return result
end

--[=[
	Activate a tool by loading its specific module
	@param player Player
	@param toolId string
	@param targetData table { Target: Instance?, Position: Vector3?, Direction: Vector3? }
	@return boolean Success status
]=]
function ActivationManager:Activate(player: Player, toolId: string, targetData: any): boolean
	-- Get tool data
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then
		warn("[ActivationManager] Tool data not found:", toolId)
		return false
	end

	-- Get tool module (optional - may not exist for client-only tools)
	local toolModule = self:GetToolModule(toolId, toolData)
	if not toolModule then
		-- No server module - this is valid for client-only tools
		-- Return true to allow activation to proceed (client handles visuals)
		print("[ActivationManager] No server module for:", toolId, "(client-only tool)")
		return true
	end

	-- Check if module has Activate function
	if not toolModule.Activate then
		-- Module exists but no Activate function - still valid
		print("[ActivationManager] Tool module has no Activate function:", toolId)
		return true
	end

	-- Call the tool's Activate function
	local success, result = pcall(function()
		return toolModule:Activate(player, toolData, targetData)
	end)

	if not success then
		warn("[ActivationManager] Tool activation error:", toolId, result)
		return false
	end

	return result == true
end

--[=[
	Called when a tool is equipped - notifies the tool module
	@param player Player
	@param toolId string
]=]
function ActivationManager:OnToolEquipped(player: Player, toolId: string)
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then return end

	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnEquip then
		local success, err = pcall(function()
			toolModule:OnEquip(player, toolData)
		end)
		if not success then
			warn("[ActivationManager] OnEquip error for:", toolId, err)
		end
	end
end

--[=[
	Called when a tool is unequipped - notifies the tool module
	@param player Player
	@param toolId string
]=]
function ActivationManager:OnToolUnequipped(player: Player, toolId: string)
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then return end

	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnUnequip then
		local success, err = pcall(function()
			toolModule:OnUnequip(player, toolData)
		end)
		if not success then
			warn("[ActivationManager] OnUnequip error for:", toolId, err)
		end
	end
end

--[=[
	Check if a tool is a "hold tool" (has OnButtonDown callback)
	@param toolId string
	@return boolean
]=]
function ActivationManager:IsHoldTool(toolId: string): boolean
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then return false end
	
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnButtonDown then
		return true
	end
	return false
end

--[=[
	Called when button is pressed (for hold tools) - calls tool module's OnButtonDown
	@param player Player
	@param toolId string
]=]
function ActivationManager:OnButtonDown(player: Player, toolId: string)
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then return end
	
	-- Verify player has this tool equipped
	local equippedTool = ToolService.GetComponent:GetEquippedTool(player)
	if not equippedTool or equippedTool.toolId ~= toolId then
		warn("[ActivationManager] OnButtonDown: Player doesn't have tool equipped:", toolId)
		return
	end
	
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnButtonDown then
		local success, err = pcall(function()
			toolModule:OnButtonDown(player, toolData)
		end)
		if not success then
			warn("[ActivationManager] OnButtonDown error for:", toolId, err)
		end
	end
end

--[=[
	Called when button is released (for hold tools) - calls tool module's OnButtonUp
	@param player Player
	@param toolId string
]=]
function ActivationManager:OnButtonUp(player: Player, toolId: string)
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then return end
	
	local toolModule = self:GetToolModule(toolId, toolData)
	if toolModule and toolModule.OnButtonUp then
		local success, err = pcall(function()
			toolModule:OnButtonUp(player, toolData)
		end)
		if not success then
			warn("[ActivationManager] OnButtonUp error for:", toolId, err)
		end
	end
end

--[=[
	Clear cached module (useful for hot-reloading during development)
	@param toolId string
]=]
function ActivationManager:ClearModuleCache(toolId: string)
	_toolModules[toolId] = nil
	print("[ActivationManager] Cleared cache for:", toolId)
end

--[=[
	Clear all cached modules
]=]
function ActivationManager:ClearAllModuleCache()
	_toolModules = {}
	print("[ActivationManager] Cleared all module cache")
end

--[=[
	Get all loaded hold tools (for debugging)
	@return table
]=]
function ActivationManager:GetLoadedHoldTools(): { string }
	local holdTools = {}
	for toolId, toolModule in pairs(_toolModules) do
		if toolModule.OnButtonDown then
			table.insert(holdTools, toolId)
		end
	end
	return holdTools
end

function ActivationManager.Start()
	-- Connect to HoldToolButtonState signal
	HoldToolButtonStateSignal:Connect(function(player: Player, toolId: string, isDown: boolean)
		if typeof(toolId) ~= "string" then return end
		if typeof(isDown) ~= "boolean" then return end
		
		if isDown then
			ActivationManager:OnButtonDown(player, toolId)
		else
			ActivationManager:OnButtonUp(player, toolId)
		end
	end)
end

function ActivationManager.Init()
	-- Initialize references
	ToolService = Knit.GetService("ToolService")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)

	-- Get Tools folder reference
	ToolsFolder = script.Parent.Parent.Parent:FindFirstChild("Tools")
	if not ToolsFolder then
		warn("[ActivationManager] Tools folder not found at expected location")
	end
	
	-- Register client signal for hold tool button state
	HoldToolButtonStateSignal = Knit.RegisterClientSignal(ToolService, "HoldToolButtonState")
end

return ActivationManager
