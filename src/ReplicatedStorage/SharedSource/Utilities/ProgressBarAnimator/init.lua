--[[
    ProgressBarAnimator.lua
    
    Utility for animating progress bars smoothly.
    Animates from current progress to new progress instead of instant updates.
]]

local TweenService = game:GetService("TweenService")

local ProgressBarAnimator = {}

---- Animation settings
local ANIMATION_DURATION = 0.5 -- seconds
local ANIMATION_STYLE = Enum.EasingStyle.Quad
local ANIMATION_DIRECTION = Enum.EasingDirection.Out

---- Active tweens tracking
local activeTweens = {} -- Store active tweens by instance

--[[
    Animates a progress bar from its current value to a new value
    
    @param progressFrame Instance - The progress bar frame to animate
    @param newProgress number - The new progress value (0 to 1)
    @param duration number - Optional animation duration (default: 0.5)
]]
function ProgressBarAnimator.AnimateProgress(progressFrame, newProgress, duration)
	if not progressFrame or not progressFrame:IsA("GuiObject") then
		warn("[ProgressBarAnimator] Invalid progress frame")
		return
	end
	
	duration = duration or ANIMATION_DURATION
	
	-- Clamp progress between 0 and 1
	newProgress = math.clamp(newProgress, 0, 1)
	
	-- Get current progress from Size (X scale value)
	local currentProgress = progressFrame.Size.X.Scale
	
	-- If already at target, no need to animate
	if math.abs(currentProgress - newProgress) < 0.001 then
		return
	end
	
	-- Cancel any existing tween on this frame
	if activeTweens[progressFrame] then
		activeTweens[progressFrame]:Cancel()
		activeTweens[progressFrame] = nil
	end
	
	-- Create tween info
	local tweenInfo = TweenInfo.new(
		duration,
		ANIMATION_STYLE,
		ANIMATION_DIRECTION
	)
	
	-- Create and play tween
	local goal = {
		Size = UDim2.new(newProgress, 0, 1, 0)
	}
	
	local tween = TweenService:Create(progressFrame, tweenInfo, goal)
	
	-- Store tween reference
	activeTweens[progressFrame] = tween
	
	-- Clean up when tween completes
	tween.Completed:Connect(function()
		if activeTweens[progressFrame] == tween then
			activeTweens[progressFrame] = nil
		end
	end)
	
	tween:Play()
	
	return tween
end

--[[
    Animates a progress bar with custom settings
    
    @param progressFrame Instance - The progress bar frame to animate
    @param newProgress number - The new progress value (0 to 1)
    @param duration number - Animation duration in seconds
    @param easingStyle Enum.EasingStyle - Easing style for animation
    @param easingDirection Enum.EasingDirection - Easing direction for animation
]]
function ProgressBarAnimator.AnimateProgressCustom(progressFrame, newProgress, duration, easingStyle, easingDirection)
	if not progressFrame or not progressFrame:IsA("GuiObject") then
		warn("[ProgressBarAnimator] Invalid progress frame")
		return
	end
	
	-- Clamp progress between 0 and 1
	newProgress = math.clamp(newProgress, 0, 1)
	
	-- Cancel any existing tween on this frame
	if activeTweens[progressFrame] then
		activeTweens[progressFrame]:Cancel()
		activeTweens[progressFrame] = nil
	end
	
	-- Create tween info with custom settings
	local tweenInfo = TweenInfo.new(
		duration or ANIMATION_DURATION,
		easingStyle or ANIMATION_STYLE,
		easingDirection or ANIMATION_DIRECTION
	)
	
	-- Create and play tween
	local goal = {
		Size = UDim2.new(newProgress, 0, 1, 0)
	}
	
	local tween = TweenService:Create(progressFrame, tweenInfo, goal)
	
	-- Store tween reference
	activeTweens[progressFrame] = tween
	
	-- Clean up when tween completes
	tween.Completed:Connect(function()
		if activeTweens[progressFrame] == tween then
			activeTweens[progressFrame] = nil
		end
	end)
	
	tween:Play()
	
	return tween
end

--[[
    Sets progress instantly without animation (for initial setup)
    
    @param progressFrame Instance - The progress bar frame
    @param progress number - The progress value (0 to 1)
]]
function ProgressBarAnimator.SetProgressInstant(progressFrame, progress)
	if not progressFrame or not progressFrame:IsA("GuiObject") then
		warn("[ProgressBarAnimator] Invalid progress frame")
		return
	end
	
	progress = math.clamp(progress, 0, 1)
	
	-- Cancel any existing tween
	if activeTweens[progressFrame] then
		activeTweens[progressFrame]:Cancel()
		activeTweens[progressFrame] = nil
	end
	
	-- Set size directly
	progressFrame.Size = UDim2.new(progress, 0, 1, 0)
end

return ProgressBarAnimator
