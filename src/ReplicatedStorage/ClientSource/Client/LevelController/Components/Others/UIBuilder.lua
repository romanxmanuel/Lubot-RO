local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local module = {}

---- References
local player = Players.LocalPlayer

---- UI Building Utilities
local UI_DEFAULTS = {
	CornerRadius = 8,
	Padding = 10,
	TextSize = 16,
	Colors = {
		Primary = Color3.fromRGB(25, 25, 25),
		Secondary = Color3.fromRGB(45, 45, 45),
		Accent = Color3.fromRGB(100, 200, 100),
		Text = Color3.fromRGB(255, 255, 255),
		TextSecondary = Color3.fromRGB(200, 200, 200),
	},
}

function module.Start()
	-- No-op
end

function module.Init()
	-- No-op
end

-- Create a styled frame with common properties
function module:CreateStyledFrame(properties)
	properties = properties or {}

	local frame = Instance.new("Frame")
	frame.Name = properties.Name or "StyledFrame"
	frame.Size = properties.Size or UDim2.new(0.15, 0, 0.15, 0)
	frame.Position = properties.Position or UDim2.new(0, 0, 0, 0)
	frame.BackgroundColor3 = properties.BackgroundColor3 or UI_DEFAULTS.Colors.Secondary
	frame.BorderSizePixel = properties.BorderSizePixel or 0
	frame.BackgroundTransparency = properties.BackgroundTransparency or 0

	-- Add corner radius if requested
	if properties.CornerRadius ~= false then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, properties.CornerRadius or UI_DEFAULTS.CornerRadius)
		corner.Parent = frame
	end

	-- Add padding if requested
	if properties.Padding then
		local padding = Instance.new("UIPadding")
		local p = properties.Padding
		if type(p) == "number" then
			padding.PaddingLeft = UDim.new(0, p)
			padding.PaddingRight = UDim.new(0, p)
			padding.PaddingTop = UDim.new(0, p)
			padding.PaddingBottom = UDim.new(0, p)
		else
			padding.PaddingLeft = UDim.new(0, p.Left or 0)
			padding.PaddingRight = UDim.new(0, p.Right or 0)
			padding.PaddingTop = UDim.new(0, p.Top or 0)
			padding.PaddingBottom = UDim.new(0, p.Bottom or 0)
		end
		padding.Parent = frame
	end

	return frame
end

-- Create a styled text label
function module:CreateStyledLabel(properties)
	properties = properties or {}

	local label = Instance.new("TextLabel")
	label.Name = properties.Name or "StyledLabel"
	label.Size = properties.Size or UDim2.new(1, 0, 1, 0)
	label.Position = properties.Position or UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = properties.BackgroundTransparency or 1
	label.Text = properties.Text or ""
	label.TextColor3 = properties.TextColor3 or UI_DEFAULTS.Colors.Text
	label.TextSize = properties.TextSize or UI_DEFAULTS.TextSize
	label.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Center
	label.TextYAlignment = properties.TextYAlignment or Enum.TextYAlignment.Center
	label.Font = properties.Font or Enum.Font.SourceSans
	label.TextScaled = properties.TextScaled or false
	label.RichText = properties.RichText or false

	return label
end

-- Create a progress bar with background
function module:CreateProgressBar(properties)
	properties = properties or {}

	local container = Instance.new("Frame")
	container.Name = properties.Name or "ProgressBarContainer"
	container.Size = properties.Size or UDim2.new(1, 0, 0.03, 0)
	container.Position = properties.Position or UDim2.new(0, 0, 0, 0)
	container.BackgroundTransparency = 1

	-- Background bar
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.Position = UDim2.new(0, 0, 0, 0)
	background.BackgroundColor3 = properties.BackgroundColor or Color3.fromRGB(50, 50, 50)
	background.BorderSizePixel = 0
	background.Parent = container

	-- Background corner
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, properties.CornerRadius or 4)
	bgCorner.Parent = background

	-- Progress bar
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(properties.Progress or 0, 0, 1, 0)
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.BackgroundColor3 = properties.FillColor or UI_DEFAULTS.Colors.Accent
	progressBar.BorderSizePixel = 0
	progressBar.Parent = background

	-- Progress corner
	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, properties.CornerRadius or 4)
	progressCorner.Parent = progressBar

	-- Optional text overlay
	if properties.ShowText then
		local textLabel = self:CreateStyledLabel({
			Name = "ProgressText",
			Text = properties.Text or "0%",
			TextSize = properties.TextSize or 14,
			Parent = container,
		})
		textLabel.Parent = container
	end

	return container
end

-- Create a button with hover effects
function module:CreateButton(properties)
	properties = properties or {}

	local button = Instance.new("TextButton")
	button.Name = properties.Name or "StyledButton"
	button.Size = properties.Size or UDim2.new(0.075, 0, 0.06, 0)
	button.Position = properties.Position or UDim2.new(0, 0, 0, 0)
	button.BackgroundColor3 = properties.BackgroundColor3 or UI_DEFAULTS.Colors.Secondary
	button.BorderSizePixel = 0
	button.Text = properties.Text or "Button"
	button.TextColor3 = properties.TextColor3 or UI_DEFAULTS.Colors.Text
	button.TextScaled = properties.TextScaled or true
	button.Font = properties.Font or Enum.Font.SourceSans

	-- Add corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, properties.CornerRadius or UI_DEFAULTS.CornerRadius)
	corner.Parent = button

	-- Add hover effects
	if properties.HoverEffects ~= false then
		local originalColor = button.BackgroundColor3
		local hoverColor = properties.HoverColor
			or Color3.fromRGB(
					math.min(originalColor.R * 255 + 20, 255),
					math.min(originalColor.G * 255 + 20, 255),
					math.min(originalColor.B * 255 + 20, 255)
				)
				/ 255

		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = hoverColor
		end)

		button.MouseLeave:Connect(function()
			button.BackgroundColor3 = originalColor
		end)
	end

	return button
end

-- Create a collapsible section
function module:CreateCollapsibleSection(properties)
	properties = properties or {}

	local container = self:CreateStyledFrame({
		Name = properties.Name or "CollapsibleSection",
		Size = properties.Size or UDim2.new(1, 0, 0.06, 0),
		Position = properties.Position,
		BackgroundColor3 = properties.BackgroundColor3,
	})

	-- Header button
	local headerButton = self:CreateButton({
		Name = "HeaderButton",
		Size = UDim2.new(1, 0, 0.06, 0),
		Text = properties.Title or "Section",
		BackgroundColor3 = properties.HeaderColor or UI_DEFAULTS.Colors.Primary,
		HoverEffects = true,
	})
	headerButton.Parent = container

	-- Content frame (initially hidden)
	local contentFrame = self:CreateStyledFrame({
		Name = "ContentFrame",
		Size = UDim2.new(1, 0, properties.ContentHeight or 0.15, 0),
		Position = UDim2.new(0, 0, 0.06, 0),
		BackgroundColor3 = properties.ContentColor or UI_DEFAULTS.Colors.Secondary,
		Padding = properties.ContentPadding or UI_DEFAULTS.Padding,
	})
	contentFrame.Parent = container
	contentFrame.Visible = false

	-- Toggle functionality
	local isExpanded = false
	headerButton.Activated:Connect(function()
		isExpanded = not isExpanded
		contentFrame.Visible = isExpanded

		if isExpanded then
			container.Size =
				UDim2.new(container.Size.X.Scale, 0, 0.06 + (properties.ContentHeight or 0.15), 0)
			headerButton.Text = "▼ " .. (properties.Title or "Section")
		else
			container.Size = UDim2.new(container.Size.X.Scale, 0, 0.06, 0)
			headerButton.Text = "▶ " .. (properties.Title or "Section")
		end

		-- Fire expand/collapse callback
		if properties.OnToggle then
			properties.OnToggle(isExpanded)
		end
	end)

	-- Initial arrow
	headerButton.Text = "▶ " .. (properties.Title or "Section")

	return container, contentFrame
end

-- Create a tooltip for an element
function module:CreateTooltip(element, tooltipText, properties)
	properties = properties or {}

	local tooltip = self:CreateStyledFrame({
		Name = "Tooltip",
		Size = UDim2.new(0.15, 0, 0.075, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.2,
		CornerRadius = 4,
	})

	local label = self:CreateStyledLabel({
		Text = tooltipText,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	})
	label.Parent = tooltip

	tooltip.Visible = false
	tooltip.Parent = element.Parent

	-- Show on hover
	element.MouseEnter:Connect(function()
		local mouse = player:GetMouse()
		local viewportSize = workspace.CurrentCamera.ViewportSize
		tooltip.Position = UDim2.new(0, (mouse.X + 10) / viewportSize.X, 0, (mouse.Y - 25) / viewportSize.Y)
		tooltip.Visible = true
	end)

	element.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)

	-- Update position with mouse movement
	local connection
	element.MouseEnter:Connect(function()
		connection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				local viewportSize = workspace.CurrentCamera.ViewportSize
				tooltip.Position = UDim2.new(0, (input.Position.X + 10) / viewportSize.X, 0, (input.Position.Y - 25) / viewportSize.Y)
			end
		end)
	end)

	element.MouseLeave:Connect(function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)

	return tooltip
end

-- Create a notification popup
function module:CreateNotification(properties)
	properties = properties or {}

	local playerGui = player:WaitForChild("PlayerGui")

	local notification = self:CreateStyledFrame({
		Name = "Notification",
		Size = UDim2.new(0.22, 0, 0.12, 0),
		Position = UDim2.new(0.765, 0, 0.86, 0),
		BackgroundColor3 = properties.BackgroundColor3 or Color3.fromRGB(50, 50, 50),
	})
	notification.Parent = playerGui

	-- Notification text
	local textLabel = self:CreateStyledLabel({
		Name = "NotificationText",
		Text = properties.Text or "Notification",
		TextScaled = true,
		Padding = 10,
	})
	textLabel.Parent = notification

	-- Auto-dismiss timer
	local duration = properties.Duration or 3
	task.spawn(function()
		task.wait(duration)
		notification:Destroy()
	end)

	return notification
end

return module
