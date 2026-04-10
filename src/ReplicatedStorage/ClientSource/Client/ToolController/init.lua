--!strict
-- ToolController
-- Client-side tool management
-- Handles input, visual feedback, animations, and prediction

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ToolController = Knit.CreateController({
	Name = "ToolController",
	Instance = script, -- Automatically initializes components
	
	-- Client state
	_currentTool = nil, -- { toolId, toolInstance, toolData }
	_cooldowns = {}, -- [toolId] = cooldownEnd
	_isInputEnabled = true,
})

---- Utilities
local ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)

--- Knit Services
local ToolService

--[=[
	Get currently equipped tool data
	Delegates to GetComponent
]=]
function ToolController:GetEquippedTool()
	return self.GetComponent:GetEquippedTool()
end

--[=[
	Get cooldown remaining for a tool
	Delegates to GetComponent
]=]
function ToolController:GetToolCooldownRemaining(toolId: string)
	return self.GetComponent:GetToolCooldownRemaining(toolId)
end

--[=[
	Check if tool is ready to use
	Delegates to GetComponent
]=]
function ToolController:IsToolReady()
	return self.GetComponent:IsToolReady()
end

--[=[
	Equip a tool locally
	Delegates to SetComponent
]=]
function ToolController:EquipToolLocal(toolId: string)
	return self.SetComponent:EquipToolLocal(toolId)
end

--[=[
	Unequip current tool
	Delegates to SetComponent
]=]
function ToolController:UnequipToolLocal()
	return self.SetComponent:UnequipToolLocal()
end

--[=[
	Activate tool (use tool)
	Delegates to SetComponent
]=]
function ToolController:ActivateToolLocal(targetData: any)
	return self.SetComponent:ActivateToolLocal(targetData)
end

--[=[
	Enable/disable input handling
]=]
function ToolController:SetInputEnabled(enabled: boolean)
	self._isInputEnabled = enabled
	print("[ToolController] Input enabled:", enabled)
end

--[=[
	Toggle the Tool Tester GUI
	Useful for debugging and testing tools during development
]=]
function ToolController:ToggleToolTester()
	return self.SetComponent:ToggleToolTester()
end

--[=[
	Show the Tool Tester GUI
]=]
function ToolController:ShowToolTester()
	return self.SetComponent:ShowToolTester()
end

--[=[
	Hide the Tool Tester GUI
]=]
function ToolController:HideToolTester()
	return self.SetComponent:HideToolTester()
end

--[=[
	Refresh the Tool Tester GUI's list of tools
]=]
function ToolController:RefreshToolTester()
	return self.SetComponent:RefreshToolTester()
end

function ToolController:KnitStart()
	-- Server signals are SUPPLEMENTARY to client-side input handling
	-- Primary tool events are handled by InputHandler component
	-- Server signals provide: cooldowns, state changes, and reconciliation
	
	if not ToolService then
		print("[ToolController] Running in client-only mode (no ToolService)")
		print("[ToolController] Started successfully")
		return
	end
	
	-- ToolEquipped/ToolUnequipped are handled client-side
	-- Server signals used for reconciliation (e.g., server forced equip)
	ToolService.ToolEquipped:Connect(function(toolId)
		-- Only update if not already equipped via native event
		local currentTool = self._currentTool
		if not currentTool or currentTool.toolId ~= toolId then
			print("[ToolController] Server equip signal (reconciliation):", toolId)
			self.SetComponent:OnToolEquipped(toolId)
		end
	end)
	
	ToolService.ToolUnequipped:Connect(function()
		-- Only update if still equipped locally
		if self._currentTool then
			print("[ToolController] Server unequip signal (reconciliation)")
			self.SetComponent:OnToolUnequipped()
		end
	end)
	
	-- ToolActivated: Server confirmation/reconciliation
	-- Client prediction already handled visual feedback via InputHandler
	ToolService.ToolActivated:Connect(function(toolId, targetData)
		-- Server confirmed activation - used for reconciliation if prediction was wrong
		-- Visual feedback already played via client prediction
		self.SetComponent:OnToolActivatedConfirmed(toolId, targetData)
	end)
	
	-- Cooldown from server - authoritative
	ToolService.ToolCooldownStart:Connect(function(toolId, duration)
		print("[ToolController] Cooldown started:", toolId, "duration:", duration)
		self.SetComponent:OnCooldownStart(toolId, duration)
	end)

	-- State changes from server - authoritative
	ToolService.ToolStateChanged:Connect(function(toolId, newState)
		print("[ToolController] Tool state changed:", toolId)
		self.SetComponent:OnToolStateChanged(toolId, newState)
	end)

	print("[ToolController] Started successfully")
end

function ToolController:KnitInit()
	-- Try to get ToolService (may not exist in client-only mode)
	local success, result = pcall(function()
		return Knit.GetService("ToolService")
	end)
	
	if success then
		ToolService = result
	else
		warn("[ToolController] ToolService not available - running in client-only mode")
		ToolService = nil
	end
	
	print("[ToolController] Initialized")
end

return ToolController
