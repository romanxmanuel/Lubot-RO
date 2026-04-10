--!strict
-- InputHandler.lua
-- Handles input detection for tool activation (mouse click, mobile touch)
-- Primary client-side input handler for the Tool Framework
-- Supports both single-click and hold-to-fire tools

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local InputHandler = {}

local plr = game.Players.LocalPlayer
local mouse = plr:GetMouse()

---- Knit Controllers
local ToolController

---- Knit Services
local ToolService

-- Input state
local _isListening = false
local _lastActivationTime = 0
local _debounceTime = 0.1 -- Prevent accidental double-clicks

-- Hold tool state
local _isButtonDown = false
local _mousePositionConnection: RBXScriptConnection? = nil

--[=[
	Start listening for input
]=]
function InputHandler:StartListening()
	if _isListening then
		warn("[InputHandler] Already listening for input")
		return
	end
	
	_isListening = true
	
	-- Listen for mouse button 1 down (for both single-click and hold tools)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end -- Ignore if clicking on UI
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:OnButtonDown()
		end
	end)
	
	-- Listen for mouse button 1 up (for hold tools)
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:OnButtonUp()
		end
	end)
	
	-- Listen for mobile touch began (down)
	UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
		if gameProcessed then return end
		self:OnButtonDown()
	end)
	
	-- Listen for mobile touch ended (up)
	UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
		self:OnButtonUp()
	end)
	
	print("[InputHandler] Started listening for input (single-click and hold support)")
end

--[=[
	Stop listening for input
]=]
function InputHandler:StopListening()
	_isListening = false
	self:StopMousePositionTracking()
	print("[InputHandler] Stopped listening for input")
end

--[=[
	Start tracking mouse position for hold tools
	Sends position to server continuously while button is held
]=]
function InputHandler:StartMousePositionTracking()
	if _mousePositionConnection then return end
	
	_mousePositionConnection = RunService.RenderStepped:Connect(function()
		if not _isButtonDown then
			self:StopMousePositionTracking()
			return
		end
		
		-- Get current tool
		local currentTool = ToolController:GetEquippedTool()
		if not currentTool then
			self:StopMousePositionTracking()
			return
		end
		
		-- Send mouse position to server
		if ToolService and ToolService.HoldToolMousePosition then
			ToolService.HoldToolMousePosition:Fire(currentTool.toolId, mouse.Hit.Position)
		end
	end)
end

--[=[
	Stop tracking mouse position
]=]
function InputHandler:StopMousePositionTracking()
	if _mousePositionConnection then
		_mousePositionConnection:Disconnect()
		_mousePositionConnection = nil
	end
end

--[=[
	Check if button is currently held down
	@return boolean
]=]
function InputHandler:IsButtonDown(): boolean
	return _isButtonDown
end

--[=[
	Handle button down input (for both single-click and hold tools)
]=]
function InputHandler:OnButtonDown()
	if not _isListening then return end
	if not ToolController._isInputEnabled then return end
	
	-- Check if tool is equipped
	local currentTool = ToolController:GetEquippedTool()
	if not currentTool then
		return -- No tool equipped
	end
	
	-- Get target data from mouse
	local targetData = self:GetTargetData()
	
	-- Check if this is a hold tool (has OnButtonDown callback)
	local ToolModuleManager = ToolController.Components.ToolModuleManager
	local isHoldTool = ToolModuleManager and ToolModuleManager:IsHoldTool(currentTool.toolId, currentTool.toolData)
	
	if isHoldTool then
		-- Hold tool: track button state and notify
		_isButtonDown = true
		
		-- Notify tool module (client-side)
		if ToolModuleManager then
			ToolModuleManager:OnButtonDown(currentTool.toolId, currentTool.toolData, targetData)
		end
		
		-- Notify server
		if ToolService and ToolService.HoldToolButtonState then
			ToolService.HoldToolButtonState:Fire(currentTool.toolId, true)
		end
		
		-- Start mouse position tracking for server
		self:StartMousePositionTracking()
	else
		-- Single-click tool: use debounce and activation
		self:OnActivationInput()
	end
end

--[=[
	Handle button up input (for hold tools)
]=]
function InputHandler:OnButtonUp()
	if not _isButtonDown then return end
	
	_isButtonDown = false
	
	-- Stop mouse position tracking
	self:StopMousePositionTracking()
	
	-- Check if tool is still equipped
	local currentTool = ToolController:GetEquippedTool()
	if not currentTool then return end
	
	-- Get target data from mouse
	local targetData = self:GetTargetData()
	
	-- Notify tool module (client-side)
	local ToolModuleManager = ToolController.Components.ToolModuleManager
	if ToolModuleManager then
		ToolModuleManager:OnButtonUp(currentTool.toolId, currentTool.toolData, targetData)
	end
	
	-- Notify server
	if ToolService and ToolService.HoldToolButtonState then
		ToolService.HoldToolButtonState:Fire(currentTool.toolId, false)
	end
end

--[=[
	Handle single-click activation input (for non-hold tools)
]=]
function InputHandler:OnActivationInput()
	if not _isListening then return end
	if not ToolController._isInputEnabled then return end
	
	-- Debounce check
	local currentTime = tick()
	if currentTime - _lastActivationTime < _debounceTime then
		return
	end
	_lastActivationTime = currentTime
	
	-- Check if tool is equipped
	local currentTool = ToolController:GetEquippedTool()
	if not currentTool then
		return -- No tool equipped
	end
	
	-- Check if tool is ready (not on cooldown)
	if not ToolController:IsToolReady() then
		warn("[InputHandler] Tool not ready (on cooldown)")
		return
	end
	
	-- Get target data from mouse
	local targetData = self:GetTargetData()
	
	-- Activate tool
	ToolController:ActivateToolLocal(targetData)
end

--[=[
	Get target data from mouse/camera
	@return table { Target: Instance?, Position: Vector3, Direction: Vector3 }
]=]
function InputHandler:GetTargetData()
	local target = mouse.Target
	local position = mouse.Hit.Position
	
	-- Calculate direction from character to target
	local character = plr.Character
	local direction = Vector3.new(0, 0, -1) -- Default forward
	
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			direction = (position - humanoidRootPart.Position).Unit
		end
	end
	
	return {
		Target = target,
		Position = position,
		Direction = direction,
	}
end

--[=[
	Set input enabled state
	@param enabled boolean
]=]
function InputHandler:SetEnabled(enabled: boolean)
	ToolController._isInputEnabled = enabled
end

function InputHandler.Start()
	-- Component will start listening via SetComponent
end

function InputHandler.Init()
	-- Initialize references
	ToolController = Knit.GetController("ToolController")
	
	-- Try to get ToolService for hold tool signals
	local success, result = pcall(function()
		return Knit.GetService("ToolService")
	end)
	
	if success then
		ToolService = result
	else
		warn("[InputHandler] ToolService not available - hold tool server sync disabled")
	end
end

return InputHandler

		warn("[InputHandler] ToolService not available - hold tool server sync disabled")
	end
end

return InputHandler
