--!strict
-- ToolController Set Component
-- Client-side tool state management and server requests

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SetComponent = {}

local plr = game.Players.LocalPlayer
local mouse = plr:GetMouse()

---- Utilities
local ToolHelpers

---- Knit Controllers
local ToolController

---- Knit Services
local ToolService

---- Other Components
local InputHandler
local AnimationManager
local VisualFeedback
local ToolModuleManager
local ToolTester
local ToolbarUI

--[=[
	Request to equip a tool (sends to server)
	@param toolId string
	@return Promise
]=]
function SetComponent:EquipToolLocal(toolId: string)
	-- Check if running in client-only mode
	if not ToolService then
		warn("[ToolController.Set] Cannot request equip - running in client-only mode")
		return nil
	end
	
	-- Request from server
	return ToolService:RequestEquipTool(toolId)
		:andThen(function(success)
			if success then
				print("[ToolController.Set] Successfully equipped tool:", toolId)
			else
				warn("[ToolController.Set] Failed to equip tool:", toolId)
			end
			return success
		end)
		:catch(function(err)
			warn("[ToolController.Set] Error equipping tool:", err)
		end)
end

--[=[
	Request to unequip current tool (sends to server)
	@return Promise
]=]
function SetComponent:UnequipToolLocal()
	-- Check if running in client-only mode
	if not ToolService then
		warn("[ToolController.Set] Cannot request unequip - running in client-only mode")
		return nil
	end
	
	-- Request from server
	return ToolService:RequestUnequipTool()
		:andThen(function(success)
			if success then
				print("[ToolController.Set] Successfully unequipped tool")
			else
				warn("[ToolController.Set] Failed to unequip tool")
			end
			return success
		end)
		:catch(function(err)
			warn("[ToolController.Set] Error unequipping tool:", err)
		end)
end

--[=[
	Activate tool with target data (sends to server)
	@param targetData table { Target: Instance?, Position: Vector3?, Direction: Vector3? }
	@return Promise
]=]
function SetComponent:ActivateToolLocal(targetData: any)
	-- Check if tool is ready
	if not ToolController:IsToolReady() then
		warn("[ToolController.Set] Tool not ready to activate")
		return
	end

	-- Get current tool
	local currentTool = ToolController:GetEquippedTool()
	if not currentTool then
		return
	end

	-- Play immediate visual feedback via tool module (client prediction)
	if ToolModuleManager then
		ToolModuleManager:OnToolActivated(currentTool.toolId, currentTool.toolData, targetData)
	end

	-- Request activation from server (if available)
	if not ToolService then
		-- Client-only mode - activation already handled locally
		print("[ToolController.Set] Tool activated (client-only mode)")
		return nil
	end

	-- Request activation from server
	return ToolService:RequestActivateTool(targetData)
		:andThen(function(success)
			if success then
				print("[ToolController.Set] Tool activated successfully")
			else
				warn("[ToolController.Set] Tool activation failed")
			end
			return success
		end)
		:catch(function(err)
			warn("[ToolController.Set] Error activating tool:", err)
		end)
end

--[=[
	Handle tool equipped event from server
	@param toolId string
]=]
function SetComponent:OnToolEquipped(toolId: string)
	-- Get tool data
	local toolData = ToolHelpers.GetToolData(toolId)
	if not toolData then
		warn("[ToolController.Set] Tool data not found for:", toolId)
		return
	end

	-- Wait for tool instance in character
	local character = plr.Character
	if not character then return end

	task.spawn(function()
		-- Use AssetName if specified, otherwise fall back to toolId without underscores
		local assetName = toolData.AssetName or toolId:gsub("_", "")
		local toolInstance = character:WaitForChild(assetName, 3)
		if not toolInstance or not toolInstance:IsA("Tool") then
			warn("[ToolController.Set] Tool instance not found in character:", assetName)
			return
		end

		-- Update local state
		ToolController._currentTool = {
			toolId = toolId,
			toolInstance = toolInstance,
			toolData = toolData,
		}

		-- Notify tool module of equip
		if ToolModuleManager then
			ToolModuleManager:OnToolEquipped(toolId, toolData)
		end
		
		-- Notify toolbar UI of equip (for hold indicator)
		if ToolbarUI then
			ToolbarUI:OnToolEquipped(toolId, toolData)
		end

		print("[ToolController.Set] Local tool state updated for:", toolId)
	end)
end

--[=[
	Handle tool unequipped event from server
]=]
function SetComponent:OnToolUnequipped()
	-- Get current tool info before clearing
	local currentTool = ToolController._currentTool

	if currentTool and ToolModuleManager then
		ToolModuleManager:OnToolUnequipped(currentTool.toolId, currentTool.toolData)
	end
	
	-- Notify toolbar UI of unequip (hide hold indicator)
	if ToolbarUI then
		ToolbarUI:OnToolUnequipped()
	end

	-- Clear local state
	ToolController._currentTool = nil

	print("[ToolController.Set] Local tool state cleared")
end

--[=[
	Handle tool activated event from server (DEPRECATED - use OnToolActivatedConfirmed)
	@param toolId string
	@param targetData any
]=]
function SetComponent:OnToolActivated(toolId: string, targetData: any)
	-- Deprecated - kept for backwards compatibility
	-- Use OnToolActivatedConfirmed instead
	self:OnToolActivatedConfirmed(toolId, targetData)
end

--[=[
	Handle server-confirmed tool activation
	Used for reconciliation when server confirms or rejects activation
	@param toolId string
	@param targetData any
]=]
function SetComponent:OnToolActivatedConfirmed(toolId: string, targetData: any)
	-- Visual feedback already played via client prediction
	-- This callback is for reconciliation if server rejected or modified the activation
	-- Currently no reconciliation logic needed - server is authoritative for game state
	-- Client prediction handles visual feedback
end

--[=[
	Handle cooldown start event from server
	@param toolId string
	@param duration number
]=]
function SetComponent:OnCooldownStart(toolId: string, duration: number)
	-- Update local cooldown tracking
	ToolController._cooldowns[toolId] = tick() + duration

	-- Update UI if needed
	-- TODO: Integrate with UI system

	print("[ToolController.Set] Cooldown started for:", toolId, "duration:", duration)
end

--[=[
	Handle tool state changed event from server
	@param toolId string
	@param newState any
]=]
function SetComponent:OnToolStateChanged(toolId: string, newState: any)
	local toolData = ToolHelpers.GetToolData(toolId)
	if toolData and ToolModuleManager then
		ToolModuleManager:OnToolStateChanged(toolId, toolData, newState)
	end
end

--[=[
	Toggle the Tool Tester GUI visibility
]=]
function SetComponent:ToggleToolTester()
	if ToolTester then
		ToolTester:ToggleGUI()
	else
		warn("[ToolController.Set] ToolTester component not available")
	end
end

--[=[
	Show the Tool Tester GUI
]=]
function SetComponent:ShowToolTester()
	if ToolTester then
		ToolTester:ShowGUI()
	else
		warn("[ToolController.Set] ToolTester component not available")
	end
end

--[=[
	Hide the Tool Tester GUI
]=]
function SetComponent:HideToolTester()
	if ToolTester then
		ToolTester:HideGUI()
	else
		warn("[ToolController.Set] ToolTester component not available")
	end
end

--[=[
	Refresh the Tool Tester GUI's tools list
]=]
function SetComponent:RefreshToolTester()
	if ToolTester then
		ToolTester:RefreshToolsList()
	else
		warn("[ToolController.Set] ToolTester component not available")
	end
end

function SetComponent.Start()
	-- Initialize input handling
	InputHandler:StartListening()
end

function SetComponent.Init()
	-- Initialize references
	ToolController = Knit.GetController("ToolController")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)

	-- Try to get ToolService (may not exist in client-only mode)
	local success, result = pcall(function()
		return Knit.GetService("ToolService")
	end)
	
	if success then
		ToolService = result
	else
		warn("[ToolController.Set] ToolService not available - running in client-only mode")
		ToolService = nil
	end

	-- Get other components
	InputHandler = ToolController.Components.InputHandler
	AnimationManager = ToolController.Components.AnimationManager
	VisualFeedback = ToolController.Components.VisualFeedback
	ToolModuleManager = ToolController.Components.ToolModuleManager
	ToolTester = ToolController.Components.ToolTester
	ToolbarUI = ToolController.Components.ToolbarUI
end

return SetComponent
