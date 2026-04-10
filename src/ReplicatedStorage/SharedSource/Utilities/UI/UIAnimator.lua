--[[

	UIAnimator.lua
	Utility module for tweening UI elements in a clean, modular, and reusable way.

	✨ Features:
	- Prepare(): Create a tween without playing it yet.
	- Play(): Create and immediately play a tween (with optional onComplete callback).
	- Loop(): Create looping tweens for continuous animations (e.g., rotation, pulsing, aura effects).
	- Stop(): Cancel a tween and optionally reset properties to their original state.
	- ToggleFrame(): Smoothly slide a frame in/out of view with customizable tween parameters.
	- ApplyButtonEffect(): Adds hover and click feedback using UIScale-based animations.

	🧩 Usage Examples:
		UIAnimator.ToggleFrame(myFrame)                -- Toggle open/close with default behavior
		UIAnimator.ToggleFrame(myFrame, nil, true)     -- Force open
		UIAnimator.ToggleFrame(myFrame, nil, false)    -- Force close
		UIAnimator.ToggleFrame(myFrame, {
			TweenTime = 0.5,
			StartPosition = UDim2.new(0.5, 0, 1.5, 0),
			EndPosition = UDim2.new(0.5, 0, 0.5, 0),
		}) -- Custom slide settings

		UIAnimator.ApplyButtonEffect(myButton)         -- Adds hover/click scale feedback
		UIAnimator.Loop(myIcon, { Rotation = 360 }, 4) -- Infinite rotation loop example

	⚠️ Notes:
	- Designed for GUI-only tweening. Extend methods to support non-UI instances if needed.
	- For infinite loops, use `repeatCount = -1`.

	@author Mys7o
	@version 1.1.1

]]

-- Roblox Services
local TweenService = game:GetService("TweenService")

-- Module
local UIAnimator = {}

-- Prepare a tween without playing it
function UIAnimator.Prepare(
	object: GuiObject,
	properties: { [string]: any },
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?
): Tween

	local tweenInfo = TweenInfo.new(
		duration or 0.5,
		easingStyle or Enum.EasingStyle.Quad,
		easingDirection or Enum.EasingDirection.Out
	)

	return TweenService:Create(object, tweenInfo, properties)
end

-- Play a tween immediately (with optional onComplete callback)
function UIAnimator.Play(
	object: GuiObject,
	properties: { [string]: any },
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	onComplete: (() -> ())?
): Tween

	local tween = UIAnimator.Prepare(object, properties, duration, easingStyle, easingDirection)
	tween:Play()

	if onComplete then
		tween.Completed:Once(onComplete)
	end

	return tween
end

-- Create a looping tween (e.g., infinite rotation or pulsing effects)
function UIAnimator.Loop(
	object: GuiObject,
	properties: { [string]: any },
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	repeatCount: number?, -- use -1 for infinite loop
	reverses: boolean?,
	delayTime: number?,
	onComplete: (() -> ())?
): Tween

	local tweenInfo = TweenInfo.new(
		duration or 1,
		easingStyle or Enum.EasingStyle.Linear,
		easingDirection or Enum.EasingDirection.InOut,
		repeatCount or -1,  -- -1 means infinite loop
		reverses or false,
		delayTime or 0
	)

	local tween = TweenService:Create(object, tweenInfo, properties)
	tween:Play()

	if repeatCount ~= -1 and onComplete then
		tween.Completed:Once(onComplete)
	end

	return tween
end

-- Stop a tween, optionally resetting properties
function UIAnimator.Stop(tween: Tween?, resetProps: { [Instance]: { [string]: any } }?)
	if tween and tween.PlaybackState ~= Enum.PlaybackState.Completed then
		tween:Cancel()
	end

	if resetProps then
		for inst, props in pairs(resetProps) do
			for prop, value in pairs(props) do
				inst[prop] = value
			end
		end
	end
end

-- Toggle a frame with slide-in / slide-out animation
function UIAnimator.ToggleFrame(
	frame: GuiObject,
	tweenProperties: { [string]: any }?,
	forceState: boolean?
)
	-- Fallbacks if tweenProperties is not given
	tweenProperties = tweenProperties or {}

	local tweenTime = tweenProperties.TweenTime or 0.3
	local startPosition = tweenProperties.StartPosition or UDim2.new(0.5, 0, 1.5, 0) -- below screen
	local endPosition = tweenProperties.EndPosition or UDim2.new(0.5, 0, 0.5, 0)   -- center screen
	local startSize = tweenProperties.StartSize
	local endSize = tweenProperties.EndSize

	-- Decide if frame should be shown or hidden
	local targetVisible = if typeof(forceState) == "boolean" then forceState else not frame.Visible
	if targetVisible then
		-- Prepare entrance
		frame.Visible = true
		frame.Position = startPosition
		if startSize then frame.Size = startSize end

		-- Tween to visible position
		UIAnimator.Play(
			frame,
			{ Position = endPosition, Size = endSize or frame.Size },
			tweenTime,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
	else
		-- Tween to exit position, then hide
		UIAnimator.Play(
			frame,
			{ Position = startPosition, Size = startSize or frame.Size },
			tweenTime,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			function()
				frame.Visible = false
			end
		)
	end
end

-- Adds hover and click scaling feedback to a button using UIScale tweens
function UIAnimator.ApplyButtonEffect(button: GuiButton)
	if not button:IsA("GuiButton") then
		warn(("[UIAnimator] %s is not a GuiButton!"):format(button:GetFullName()))
		return
	end

	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = button
	end

	local normalScale = 1
	local hoverScale = 1.1
	local clickScale = 0.95

	local hoverDuration = 0.075
	local revertDuration = 0.075
	local clickDuration = 0.05

	local easingStyle = Enum.EasingStyle.Sine
	local easingDirection = Enum.EasingDirection.Out

	-- Creates a fresh tween every time (prevents stuck animations when spamming)
	local function tweenScale(targetScale: number, tweenDuration: number)
		UIAnimator.Play(
			uiScale,
			{ Scale = targetScale },
			tweenDuration,
			easingStyle,
			easingDirection
		)
	end

	button.AutoButtonColor = false

	button.MouseEnter:Connect(function()
		tweenScale(hoverScale, hoverDuration)
	end)

	button.MouseLeave:Connect(function()
		tweenScale(normalScale, revertDuration)
	end)

	button.MouseButton1Down:Connect(function()
		tweenScale(clickScale, clickDuration)
	end)

	button.MouseButton1Up:Connect(function()
		tweenScale(hoverScale, hoverDuration)
	end)
end

-- Applies a temporary screen-shake effect to a UI element with smooth decay
function UIAnimator.ShakeEffect(
	targetObject: GuiObject,
	totalDuration: number,
	maximumOffset: number,
	stepDuration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?
)
	if not targetObject then
		warn("[UIAnimator] ShakeEffect failed — missing target object.")
		return
	end

	stepDuration = stepDuration or 0.05
	easingStyle = easingStyle or Enum.EasingStyle.Quad
	easingDirection = easingDirection or Enum.EasingDirection.Out

	local originalPosition = targetObject.Position
	local shakeStartTime = tick()
	local isShakingActive = true

	task.spawn(function()
		while isShakingActive and targetObject and targetObject.Parent do
			local elapsedTime = tick() - shakeStartTime
			if elapsedTime >= totalDuration then break end

			local normalizedTime = elapsedTime / totalDuration
			local decayFactor = 1 - (normalizedTime * normalizedTime)

			local randomOffset = Vector2.new(
				(math.random() - 0.5) * maximumOffset * decayFactor,
				(math.random() - 0.5) * maximumOffset * decayFactor
			)

			local shakeGoalProperties = {
				Position = UDim2.new(
					originalPosition.X.Scale,
					originalPosition.X.Offset + randomOffset.X,
					originalPosition.Y.Scale,
					originalPosition.Y.Offset + randomOffset.Y
				),
			}

			local shakeTween = TweenService:Create(
				targetObject,
				TweenInfo.new(stepDuration, easingStyle, easingDirection),
				shakeGoalProperties
			)
			shakeTween:Play()
			task.wait(stepDuration)
		end

		-- Smoothly return to original position
		if targetObject and targetObject.Parent then
			UIAnimator.Play(
				targetObject,
				{ Position = originalPosition },
				stepDuration * 2,
				easingStyle,
				easingDirection
			)
		end
	end)

	-- Auto-cancel when object is removed
	targetObject.AncestryChanged:Connect(function(_, parent)
		if not parent then
			isShakingActive = false
		end
	end)
end

return UIAnimator