--!strict
-- ToolbarUI.lua
-- Shows "Hold to Activate" indicator above Roblox's default hotbar
-- Dynamically positioned based on CoreGui.RobloxGui.Backpack.Hotbar

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ToolbarUI = {}

local player = Players.LocalPlayer

---- UI References
local screenGui: ScreenGui
local holdIndicator: Frame
local holdLabel: TextLabel

---- Knit Controllers
local ToolController

---- Other Components
local ToolModuleManager

---- Constants
local INDICATOR_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local PULSE_TWEEN_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

---- State
local _isIndicatorVisible = false
local _pulseTween: Tween? = nil
local _hotbarConnection: RBXScriptConnection? = nil

---- Hotbar Reference
local _hotbar: Frame? = nil

--[=[
	Get the Roblox default hotbar reference
	@return Frame?
]=]
local function getHotbar(): Frame?
	if _hotbar then return _hotbar end
	
	local success, result = pcall(function()
		local robloxGui = CoreGui:FindFirstChild("RobloxGui")
		if not robloxGui then return nil end
		
		local backpack = robloxGui:FindFirstChild("Backpack")
		if not backpack then return nil end
		
		return backpack:FindFirstChild("Hotbar")
	end)
	
	if success and result then
		_hotbar = result
		return result
	end
	
	return nil
end

--[=[
	Update the indicator position based on hotbar's absolute position
]=]
local function updateIndicatorPosition()
	if not holdIndicator then return end
	
	local hotbar = getHotbar()
	if not hotbar then
		-- Fallback position if hotbar not found
		holdIndicator.Position = UDim2.new(0.5, 0, 0.84, 0)
		return
	end
	
	-- Get screen size
	local screenSize = screenGui.AbsoluteSize
	if screenSize.X == 0 or screenSize.Y == 0 then return end
	
	-- Get hotbar position (top of the hotbar)
	local hotbarAbsPos = hotbar.AbsolutePosition
	local hotbarAbsSize = hotbar.AbsoluteSize
	
	-- Calculate center X of hotbar relative to screen
	local hotbarCenterX = (hotbarAbsPos.X + hotbarAbsSize.X / 2) / screenSize.X
	
	-- Calculate Y position just above the hotbar (with small gap)
	local gap = 8 -- pixels gap between indicator and hotbar
	local indicatorY = (hotbarAbsPos.Y - gap) / screenSize.Y
	
	-- Update position (anchor is bottom center)
	holdIndicator.Position = UDim2.new(hotbarCenterX, 0, indicatorY, 0)
end

--[=[
	Create the hold indicator UI positioned above Roblox's default hotbar
]=]
local function createHoldIndicatorUI()
	-- Create ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HoldToolIndicator"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true -- Important: align with CoreGui positioning
	screenGui.DisplayOrder = 10 -- Above most UI but below critical elements
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	-- Create hold indicator container
	-- Will be dynamically positioned above the actual hotbar
	holdIndicator = Instance.new("Frame")
	holdIndicator.Name = "HoldIndicator"
	holdIndicator.Size = UDim2.new(0.18, 0, 0.032, 0)
	holdIndicator.Position = UDim2.new(0.5, 0, 0.84, 0) -- Initial fallback position
	holdIndicator.AnchorPoint = Vector2.new(0.5, 1) -- Anchor to bottom center
	holdIndicator.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
	holdIndicator.BackgroundTransparency = 0.15
	holdIndicator.BorderSizePixel = 0
	holdIndicator.Visible = false
	holdIndicator.Parent = screenGui
	
	-- Hold indicator corner
	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0.35, 0)
	indicatorCorner.Parent = holdIndicator
	
	-- Hold indicator stroke
	local indicatorStroke = Instance.new("UIStroke")
	indicatorStroke.Name = "IndicatorStroke"
	indicatorStroke.Color = Color3.fromRGB(180, 120, 255)
	indicatorStroke.Thickness = 1.5
	indicatorStroke.Transparency = 0.3
	indicatorStroke.Parent = holdIndicator
	
	-- Background gradient
	local bgGradient = Instance.new("UIGradient")
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 45, 85)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 30, 60)),
	})
	bgGradient.Rotation = 90
	bgGradient.Parent = holdIndicator
	
	-- Padding for content
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.08, 0)
	padding.PaddingRight = UDim.new(0.08, 0)
	padding.Parent = holdIndicator
	
	-- Hold indicator icon (mouse icon)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0.12, 0, 0.7, 0)
	iconLabel.Position = UDim2.new(0, 0, 0.15, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "🖱️"
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.TextScaled = true
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Parent = holdIndicator
	
	-- Hold indicator text
	holdLabel = Instance.new("TextLabel")
	holdLabel.Name = "HoldLabel"
	holdLabel.Size = UDim2.new(0.85, 0, 0.7, 0)
	holdLabel.Position = UDim2.new(0.15, 0, 0.15, 0)
	holdLabel.BackgroundTransparency = 1
	holdLabel.Text = "HOLD CLICK TO USE"
	holdLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
	holdLabel.TextScaled = true
	holdLabel.Font = Enum.Font.GothamBold
	holdLabel.TextXAlignment = Enum.TextXAlignment.Left
	holdLabel.Parent = holdIndicator
	
	-- Text size constraint for better readability
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MaxTextSize = 16
	textConstraint.MinTextSize = 8
	textConstraint.Parent = holdLabel
	
	-- Update position based on actual hotbar location
	updateIndicatorPosition()
	
	-- Listen for hotbar position changes (e.g., screen resize)
	local hotbar = getHotbar()
	if hotbar then
		_hotbarConnection = hotbar:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			updateIndicatorPosition()
		end)
	end
	
	-- Also update on screen size change
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updateIndicatorPosition()
	end)
	
	print("[ToolbarUI] Hold indicator UI created")
end

--[=[
	Start subtle pulse animation on the indicator stroke
]=]
local function startPulseAnimation()
	if _pulseTween then
		_pulseTween:Cancel()
	end
	
	local stroke = holdIndicator:FindFirstChild("IndicatorStroke")
	if not stroke then return end
	
	-- Create looping pulse effect
	local function pulse()
		if not _isIndicatorVisible then return end
		
		local fadeOut = TweenService:Create(stroke, PULSE_TWEEN_INFO, {
			Transparency = 0.6
		})
		
		fadeOut.Completed:Connect(function()
			if not _isIndicatorVisible then return end
			
			local fadeIn = TweenService:Create(stroke, PULSE_TWEEN_INFO, {
				Transparency = 0.2
			})
			
			fadeIn.Completed:Connect(function()
				if _isIndicatorVisible then
					pulse()
				end
			end)
			
			_pulseTween = fadeIn
			fadeIn:Play()
		end)
		
		_pulseTween = fadeOut
		fadeOut:Play()
	end
	
	pulse()
end

--[=[
	Stop the pulse animation
]=]
local function stopPulseAnimation()
	if _pulseTween then
		_pulseTween:Cancel()
		_pulseTween = nil
	end
end

--[=[
	Show the hold indicator with animation
]=]
function ToolbarUI:ShowHoldIndicator()
	if _isIndicatorVisible then return end
	_isIndicatorVisible = true
	
	-- Get target position from hotbar
	local hotbar = getHotbar()
	local screenSize = screenGui.AbsoluteSize
	local targetY = 0.84 -- Fallback
	local targetX = 0.5 -- Fallback
	
	if hotbar and screenSize.X > 0 and screenSize.Y > 0 then
		local hotbarAbsPos = hotbar.AbsolutePosition
		local hotbarAbsSize = hotbar.AbsoluteSize
		local gap = 8
		targetX = (hotbarAbsPos.X + hotbarAbsSize.X / 2) / screenSize.X
		targetY = (hotbarAbsPos.Y - gap) / screenSize.Y
	end
	
	-- Reset state for animation (start slightly lower and transparent)
	local startY = targetY + 0.03 -- Start slightly below target
	holdIndicator.Position = UDim2.new(targetX, 0, startY, 0)
	holdIndicator.BackgroundTransparency = 1
	holdIndicator.Visible = true
	
	-- Hide children initially
	for _, child in ipairs(holdIndicator:GetChildren()) do
		if child:IsA("TextLabel") then
			child.TextTransparency = 1
		elseif child:IsA("UIStroke") then
			child.Transparency = 1
		end
	end
	
	-- Animate in (slide up and fade in)
	local positionTween = TweenService:Create(holdIndicator, INDICATOR_TWEEN_INFO, {
		Position = UDim2.new(targetX, 0, targetY, 0),
		BackgroundTransparency = 0.15
	})
	
	positionTween:Play()
	
	-- Fade in children
	task.delay(0.1, function()
		for _, child in ipairs(holdIndicator:GetChildren()) do
			if child:IsA("TextLabel") then
				TweenService:Create(child, INDICATOR_TWEEN_INFO, {
					TextTransparency = 0
				}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, INDICATOR_TWEEN_INFO, {
					Transparency = 0.3
				}):Play()
			end
		end
	end)
	
	-- Start pulse animation after fade in
	task.delay(0.3, function()
		if _isIndicatorVisible then
			startPulseAnimation()
		end
	end)
	
	print("[ToolbarUI] Hold indicator shown")
end

--[=[
	Hide the hold indicator with animation
]=]
function ToolbarUI:HideHoldIndicator()
	if not _isIndicatorVisible then return end
	_isIndicatorVisible = false
	
	stopPulseAnimation()
	
	-- Fade out children first
	for _, child in ipairs(holdIndicator:GetChildren()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, INDICATOR_TWEEN_INFO, {
				TextTransparency = 1
			}):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, INDICATOR_TWEEN_INFO, {
				Transparency = 1
			}):Play()
		end
	end
	
	-- Get current position and animate down
	local currentPos = holdIndicator.Position
	local hideY = currentPos.Y.Scale + 0.03 -- Move slightly down
	
	-- Animate out (slide down and fade out)
	local hideTween = TweenService:Create(holdIndicator, INDICATOR_TWEEN_INFO, {
		Position = UDim2.new(currentPos.X.Scale, 0, hideY, 0),
		BackgroundTransparency = 1
	})
	
	hideTween.Completed:Connect(function()
		if not _isIndicatorVisible then
			holdIndicator.Visible = false
		end
	end)
	
	hideTween:Play()
	
	print("[ToolbarUI] Hold indicator hidden")
end

--[=[
	Update indicator based on currently equipped tool
]=]
function ToolbarUI:UpdateHoldIndicator()
	local currentTool = ToolController:GetEquippedTool()
	
	if not currentTool then
		self:HideHoldIndicator()
		return
	end
	
	-- Check if it's a hold tool
	local isHoldTool = ToolModuleManager:IsHoldTool(currentTool.toolId, currentTool.toolData)
	
	if isHoldTool then
		self:ShowHoldIndicator()
	else
		self:HideHoldIndicator()
	end
end

--[=[
	Called when a tool is equipped
	@param toolId string
	@param toolData table
]=]
function ToolbarUI:OnToolEquipped(toolId: string, toolData: any)
	-- Small delay to ensure tool module is loaded
	task.delay(0.1, function()
		self:UpdateHoldIndicator()
	end)
end

--[=[
	Called when a tool is unequipped
]=]
function ToolbarUI:OnToolUnequipped()
	self:HideHoldIndicator()
end

--[=[
	Get the ScreenGui reference
	@return ScreenGui
]=]
function ToolbarUI:GetScreenGui(): ScreenGui
	return screenGui
end

--[=[
	Get the hold indicator frame reference
	@return Frame
]=]
function ToolbarUI:GetHoldIndicator(): Frame
	return holdIndicator
end

--[=[
	Destroy the UI
]=]
function ToolbarUI:Destroy()
	stopPulseAnimation()
	
	if _hotbarConnection then
		_hotbarConnection:Disconnect()
		_hotbarConnection = nil
	end
	
	if screenGui then
		screenGui:Destroy()
	end
end

function ToolbarUI.Start()
	-- Create the hold indicator UI on start
	createHoldIndicatorUI()
	
	-- Initial check for any already equipped tool
	task.delay(0.5, function()
		ToolbarUI:UpdateHoldIndicator()
	end)
end

function ToolbarUI.Init()
	-- Initialize references
	ToolController = Knit.GetController("ToolController")
	ToolModuleManager = ToolController.Components.ToolModuleManager
end

return ToolbarUI
