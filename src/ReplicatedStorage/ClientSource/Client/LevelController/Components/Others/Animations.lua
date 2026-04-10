local TweenService = game:GetService("TweenService")
local module = {}

---- Tween Configurations
local TWEEN_CONFIGS = {
	ProgressBar = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	LevelUp = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Flash = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, true),
	FadeIn = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	FadeOut = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
}

---- Colors
local COLORS = {
	LevelUp = Color3.fromRGB(255, 215, 0),
	ExpGain = Color3.fromRGB(100, 200, 100),
	Success = Color3.fromRGB(0, 255, 0),
	Warning = Color3.fromRGB(255, 165, 0),
}

function module.Start()
	-- No-op
end

function module.Init()
	-- No-op
end

-- Animate progress bar fill
function module:AnimateProgressBar(progressBar, targetProgress)
	if not progressBar then return end
	
	local tween = TweenService:Create(progressBar, 
		TWEEN_CONFIGS.ProgressBar,
		{Size = UDim2.new(targetProgress, 0, 1, 0)}
	)
	
	tween:Play()
	return tween
end

-- Create level up effect with customizable options
function module:CreateLevelUpEffect(parent, options)
	options = options or {}
	
	local notification = Instance.new("TextLabel")
	notification.Name = "LevelUpEffect"
	notification.Size = options.size or UDim2.new(1, 0, 1, 0)
	notification.Position = options.position or UDim2.new(0, 0, 0, 0)
	notification.BackgroundColor3 = options.color or COLORS.LevelUp
	notification.BackgroundTransparency = 1
	notification.Text = options.text or "LEVEL UP!"
	notification.TextColor3 = options.textColor or Color3.fromRGB(0, 0, 0)
	notification.TextScaled = true
	notification.TextTransparency = 1
	notification.Font = Enum.Font.SourceSansBold
	notification.Parent = parent
	
	-- Add corner radius if requested
	if options.cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, options.cornerRadius)
		corner.Parent = notification
	end
	
	return notification
end

-- Animate level up effect
function module:PlayLevelUpEffect(notification, duration)
	duration = duration or 2
	
	-- Show animation
	local showTween = TweenService:Create(notification,
		TWEEN_CONFIGS.LevelUp,
		{BackgroundTransparency = 0.2, TextTransparency = 0}
	)
	
	-- Hide animation
	local hideTween = TweenService:Create(notification,
		TWEEN_CONFIGS.FadeOut,
		{BackgroundTransparency = 1, TextTransparency = 1}
	)
	
	showTween:Play()
	showTween.Completed:Connect(function()
		task.wait(duration * 0.5) -- Display for half the duration
		hideTween:Play()
		hideTween.Completed:Connect(function()
			notification:Destroy()
		end)
	end)
	
	return showTween
end

-- Flash element with color
function module:FlashElement(element, flashColor, originalColor)
	if not element then return end
	
	originalColor = originalColor or element.BackgroundColor3
	flashColor = flashColor or COLORS.Success
	
	local flashTween = TweenService:Create(element,
		TWEEN_CONFIGS.Flash,
		{BackgroundColor3 = flashColor}
	)
	
	flashTween:Play()
	flashTween.Completed:Connect(function()
		element.BackgroundColor3 = originalColor
	end)
	
	return flashTween
end

-- Animate exp gain with floating text
function module:CreateExpGainEffect(parent, expAmount, expType)
	local floatingText = Instance.new("TextLabel")
	floatingText.Name = "ExpGainEffect"
	floatingText.Size = UDim2.new(0, 100, 0, 30)
	floatingText.Position = UDim2.new(0.5, -50, 0.5, -15)
	floatingText.BackgroundTransparency = 1
	floatingText.Text = string.format("+%d %s", expAmount, expType or "EXP")
	floatingText.TextColor3 = COLORS.ExpGain
	floatingText.TextScaled = true
	floatingText.Font = Enum.Font.SourceSansBold
	floatingText.Parent = parent
	
	-- Animate floating up and fading
	local moveTween = TweenService:Create(floatingText,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, -50, 0, -30)}
	)
	
	local fadeTween = TweenService:Create(floatingText,
		TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextTransparency = 1}
	)
	
	moveTween:Play()
	fadeTween:Play()
	
	fadeTween.Completed:Connect(function()
		floatingText:Destroy()
	end)
	
	return floatingText
end

-- Pulse animation for elements
function module:PulseElement(element, scale, duration)
	scale = scale or 1.1
	duration = duration or 1
	
	local originalSize = element.Size
	local targetSize = UDim2.new(
		originalSize.X.Scale * scale, originalSize.X.Offset,
		originalSize.Y.Scale * scale, originalSize.Y.Offset
	)
	
	local pulseIn = TweenService:Create(element,
		TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = targetSize}
	)
	
	local pulseOut = TweenService:Create(element,
		TweenInfo.new(duration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = originalSize}
	)
	
	pulseIn:Play()
	pulseIn.Completed:Connect(function()
		pulseOut:Play()
	end)
	
	return pulseIn
end

-- Shake animation for elements
function module:ShakeElement(element, intensity, duration)
	intensity = intensity or 5
	duration = duration or 0.5
	
	local originalPosition = element.Position
	local shakeCount = 10
	local shakeTime = duration / shakeCount
	
	for i = 1, shakeCount do
		local randomX = math.random(-intensity, intensity)
		local randomY = math.random(-intensity, intensity)
		local shakePos = UDim2.new(
			originalPosition.X.Scale, originalPosition.X.Offset + randomX,
			originalPosition.Y.Scale, originalPosition.Y.Offset + randomY
		)
		
		local shakeTween = TweenService:Create(element,
			TweenInfo.new(shakeTime, Enum.EasingStyle.Linear),
			{Position = shakePos}
		)
		
		shakeTween:Play()
		
		if i == shakeCount then
			shakeTween.Completed:Connect(function()
				local resetTween = TweenService:Create(element,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Position = originalPosition}
				)
				resetTween:Play()
			end)
		end
		
		task.wait(shakeTime)
	end
end

return module