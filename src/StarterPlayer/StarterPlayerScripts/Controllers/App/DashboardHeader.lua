--!strict

local DashboardHeader = {}

local function makeDashboardButton(parent: Instance, text: string, shortcut: string, position: UDim2, callback, options)
	options = options or {}
	local variantAccent = {
		primary = Color3.fromRGB(109, 241, 255),
		secondary = Color3.fromRGB(136, 189, 255),
		success = Color3.fromRGB(96, 255, 204),
		gold = Color3.fromRGB(255, 216, 110),
		admin = Color3.fromRGB(255, 132, 196),
	}
	local accentColor = variantAccent[options.variant or 'secondary'] or variantAccent.secondary
	local button = Instance.new('TextButton')
	button.Size = options.size or UDim2.fromOffset(70, 24)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(9, 18, 34)
	button.BackgroundTransparency = 0.18
	button.BorderSizePixel = 0
	button.Text = ''
	button.Parent = parent

	local buttonCorner = Instance.new('UICorner')
	buttonCorner.CornerRadius = UDim.new(0, 7)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new('UIStroke')
	buttonStroke.Color = accentColor
	buttonStroke.Thickness = 1.1
	buttonStroke.Transparency = 0.24
	buttonStroke.Parent = button

	local buttonGradient = Instance.new('UIGradient')
	buttonGradient.Rotation = 90
	buttonGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 47, 78)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(15, 26, 46)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 14, 28)),
	})
	buttonGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.06),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	buttonGradient.Parent = button

	local accentStrip = Instance.new('Frame')
	accentStrip.Size = UDim2.new(1, -8, 0, 2)
	accentStrip.Position = UDim2.fromOffset(4, 3)
	accentStrip.BorderSizePixel = 0
	accentStrip.BackgroundColor3 = accentColor
	accentStrip.Parent = button

	local accentGlow = Instance.new('UIGradient')
	accentGlow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.35)),
		ColorSequenceKeypoint.new(1, accentColor),
	})
	accentGlow.Parent = accentStrip

	local titleLabel = Instance.new('TextLabel')
	titleLabel.Size = UDim2.new(1, -8, 0, 12)
	titleLabel.Position = UDim2.fromOffset(4, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 10
	titleLabel.TextColor3 = Color3.fromRGB(238, 247, 255)
	titleLabel.TextStrokeTransparency = 0.78
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Text = text
	titleLabel.Parent = button

	local shortcutLabel = Instance.new('TextLabel')
	shortcutLabel.Size = UDim2.new(1, -6, 0, 10)
	shortcutLabel.Position = UDim2.fromOffset(3, 14)
	shortcutLabel.BackgroundTransparency = 1
	shortcutLabel.Font = Enum.Font.GothamMedium
	shortcutLabel.TextSize = 8
	shortcutLabel.TextColor3 = accentColor:Lerp(Color3.fromRGB(240, 248, 255), 0.28)
	shortcutLabel.TextXAlignment = Enum.TextXAlignment.Center
	shortcutLabel.Text = shortcut
	shortcutLabel.Parent = button

	button.MouseButton1Click:Connect(callback)
	return button
end

local function applyDashboardGlass(frame: Frame | TextButton, accentColor: Color3, fillColor: Color3, fillTransparency: number)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = fillColor
	frame.BackgroundTransparency = fillTransparency

	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new('UIStroke')
	stroke.Color = accentColor
	stroke.Thickness = 1.2
	stroke.Transparency = 0.24
	stroke.Parent = frame

	local gradient = Instance.new('UIGradient')
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, fillColor:Lerp(Color3.fromRGB(42, 84, 124), 0.18)),
		ColorSequenceKeypoint.new(0.48, fillColor),
		ColorSequenceKeypoint.new(1, fillColor:Lerp(Color3.fromRGB(4, 11, 22), 0.25)),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, math.clamp(fillTransparency - 0.05, 0, 1)),
		NumberSequenceKeypoint.new(1, math.clamp(fillTransparency + 0.08, 0, 1)),
	})
	gradient.Parent = frame
end

function DashboardHeader.create(gui: Instance, deps)
	local stylePanel = deps.stylePanel
	local UiTheme = deps.UiTheme
	local UiDragUtil = deps.UiDragUtil
	local player = deps.player
	local togglePanel = deps.togglePanel
	local chatToggle = deps.chatToggle
	local isLikelyAdminLocal = deps.isLikelyAdminLocal

	local dashboardAccent = Color3.fromRGB(92, 233, 255)
	local dashboardGlass = Color3.fromRGB(7, 14, 28)
	local defaultDashboardPosition = UDim2.fromOffset(6, 6)
	local collapsedDashboardSize = UDim2.fromOffset(224, 92)
	local expandedDashboardSize = UDim2.fromOffset(282, 326)

	local root = Instance.new('Frame')
	root.Name = 'Root'
	root.Size = collapsedDashboardSize
	root.AnchorPoint = Vector2.new(0, 0)
	root.Position = defaultDashboardPosition
	root.ClipsDescendants = true
	stylePanel(root, dashboardGlass, dashboardAccent)
	root.Parent = gui
	applyDashboardGlass(root, dashboardAccent, dashboardGlass, 0.14)

	local rootShadow = Instance.new('ImageLabel')
	rootShadow.Name = 'DashboardShadow'
	rootShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	rootShadow.Position = UDim2.fromScale(0.5, 0.5)
	rootShadow.Size = UDim2.new(1, 28, 1, 28)
	rootShadow.BackgroundTransparency = 1
	rootShadow.Image = 'rbxassetid://1316045217'
	rootShadow.ImageColor3 = Color3.fromRGB(23, 198, 255)
	rootShadow.ImageTransparency = 0.76
	rootShadow.ScaleType = Enum.ScaleType.Slice
	rootShadow.SliceCenter = Rect.new(10, 10, 118, 118)
	rootShadow.ZIndex = 0
	rootShadow.Parent = root

	local rootGlow = Instance.new('Frame')
	rootGlow.Name = 'DashboardGlow'
	rootGlow.Size = UDim2.new(1, -18, 0, 2)
	rootGlow.Position = UDim2.fromOffset(9, 9)
	rootGlow.BackgroundColor3 = dashboardAccent
	rootGlow.BorderSizePixel = 0
	rootGlow.ZIndex = 2
	rootGlow.Parent = root

	local rootGlowGradient = Instance.new('UIGradient')
	rootGlowGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, dashboardAccent:Lerp(Color3.fromRGB(255, 255, 255), 0.4)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(106, 157, 255)),
	})
	rootGlowGradient.Parent = rootGlow

	local dashboardMinimized = true
	local dashboardInitialized = false

	local title = Instance.new('TextLabel')
	title.Name = 'DashboardTitle'
	title.Size = UDim2.fromOffset(230, 16)
	title.Position = UDim2.fromOffset(12, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.TextColor3 = Color3.fromRGB(240, 249, 255)
	title.TextStrokeTransparency = 0.82
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = player.Name
	title.Parent = root
	title.Visible = false

	local subtitle = Instance.new('TextLabel')
	subtitle.Size = UDim2.fromOffset(230, 12)
	subtitle.Position = UDim2.fromOffset(12, 23)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextSize = 8
	subtitle.TextColor3 = Color3.fromRGB(143, 215, 255)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = 'Dashboard'
	subtitle.Parent = root
	subtitle.Visible = false

	local collapseButton = Instance.new('TextButton')
	collapseButton.Name = 'CollapseButton'
	collapseButton.Size = UDim2.fromOffset(18, 18)
	collapseButton.Position = UDim2.new(1, -24, 0, 6)
	collapseButton.BackgroundColor3 = Color3.fromRGB(15, 27, 48)
	collapseButton.BackgroundTransparency = 0.08
	collapseButton.BorderSizePixel = 0
	collapseButton.Font = Enum.Font.GothamBold
	collapseButton.TextSize = 10
	collapseButton.TextColor3 = Color3.fromRGB(235, 246, 255)
	collapseButton.ZIndex = 10
	collapseButton.Text = '+'
	collapseButton.Parent = root
	applyDashboardGlass(collapseButton, dashboardAccent, Color3.fromRGB(10, 23, 43), 0.12)
	collapseButton.Visible = true

	local heroCard = Instance.new('Frame')
	heroCard.Size = UDim2.new(1, -12, 0, 26)
	heroCard.Position = UDim2.fromOffset(6, 8)
	heroCard.Parent = root
	applyDashboardGlass(heroCard, dashboardAccent, Color3.fromRGB(9, 22, 39), 0.2)

	local summary = Instance.new('TextLabel')
	summary.Name = 'SummaryLabel'
	summary.Size = UDim2.new(1, -16, 0, 12)
	summary.Position = UDim2.fromOffset(8, 4)
	summary.BackgroundTransparency = 1
	summary.Font = Enum.Font.GothamBold
	summary.TextSize = 10
	summary.TextColor3 = Color3.fromRGB(255, 226, 118)
	summary.TextStrokeTransparency = 0.84
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.Parent = heroCard

	local classInfo = Instance.new('TextLabel')
	classInfo.Name = 'ClassInfoLabel'
	classInfo.Size = UDim2.new(1, -16, 0, 11)
	classInfo.Position = UDim2.fromOffset(8, 14)
	classInfo.BackgroundTransparency = 1
	classInfo.Font = Enum.Font.GothamMedium
	classInfo.TextSize = 8
	classInfo.TextColor3 = Color3.fromRGB(198, 232, 255)
	classInfo.TextXAlignment = Enum.TextXAlignment.Left
	classInfo.Parent = heroCard

	local vitalsCard = Instance.new('Frame')
	vitalsCard.Size = UDim2.new(1, -12, 0, 48)
	vitalsCard.Position = UDim2.fromOffset(6, 38)
	vitalsCard.Parent = root
	applyDashboardGlass(vitalsCard, Color3.fromRGB(106, 157, 255), Color3.fromRGB(8, 19, 34), 0.2)

	local function createVitalCard(name: string, position: UDim2, accent: Color3, dark: Color3, textColor: Color3, fillStart: number)
		local back = Instance.new('Frame')
		back.Name = name .. 'Back'
		back.Size = UDim2.fromOffset(102, 12)
		back.Position = position
		back.Parent = vitalsCard
		applyDashboardGlass(back, accent, dark, 0.08)

		local fill = Instance.new('Frame')
		fill.Name = name .. 'Fill'
		fill.Size = UDim2.fromScale(fillStart, 1)
		fill.Parent = back
		UiTheme.stylePill(fill, accent, accent:Lerp(dark, 0.35))

		local textLabel = Instance.new('TextLabel')
		textLabel.Name = name .. 'Text'
		textLabel.Size = UDim2.fromScale(1, 1)
		textLabel.BackgroundTransparency = 1
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextSize = 8
		textLabel.TextColor3 = textColor
		textLabel.TextStrokeTransparency = 0.88
		textLabel.Parent = back

		return fill, textLabel
	end

	local hpFill, hpText = createVitalCard('Hp', UDim2.fromOffset(8, 8), Color3.fromRGB(255, 95, 125), Color3.fromRGB(28, 16, 28), Color3.fromRGB(255, 244, 250), 1)
	local spFill, spText = createVitalCard('Sp', UDim2.fromOffset(114, 8), Color3.fromRGB(94, 202, 255), Color3.fromRGB(12, 28, 44), Color3.fromRGB(239, 250, 255), 1)
	local expFill, expText = createVitalCard('Exp', UDim2.fromOffset(8, 26), Color3.fromRGB(255, 211, 92), Color3.fromRGB(36, 27, 12), Color3.fromRGB(255, 249, 232), 0)
	local jobExpFill, jobExpText = createVitalCard('JobExp', UDim2.fromOffset(114, 26), Color3.fromRGB(92, 255, 193), Color3.fromRGB(10, 32, 28), Color3.fromRGB(236, 255, 246), 0)

	local message = Instance.new('TextLabel')
	message.Name = 'MessageLabel'
	message.Size = UDim2.new(1, -20, 0, 10)
	message.Position = UDim2.fromOffset(10, 40)
	message.BackgroundTransparency = 1
	message.Font = Enum.Font.GothamMedium
	message.TextSize = 8
	message.TextColor3 = Color3.fromRGB(165, 226, 255)
	message.TextXAlignment = Enum.TextXAlignment.Left
	message.TextWrapped = true
	message.Visible = false
	message.Parent = vitalsCard

	local tacticsCard = Instance.new('Frame')
	tacticsCard.Size = UDim2.new(1, -16, 0, 38)
	tacticsCard.Position = UDim2.fromOffset(8, 198)
	tacticsCard.Parent = root
	applyDashboardGlass(tacticsCard, Color3.fromRGB(103, 222, 255), Color3.fromRGB(10, 22, 39), 0.18)

	local controlsLabel = Instance.new('TextLabel')
	controlsLabel.Name = 'ControlsLabel'
	controlsLabel.Size = UDim2.new(1, -20, 0, 12)
	controlsLabel.Position = UDim2.fromOffset(10, 6)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.Font = Enum.Font.GothamMedium
	controlsLabel.TextSize = 9
	controlsLabel.TextColor3 = Color3.fromRGB(220, 241, 255)
	controlsLabel.TextXAlignment = Enum.TextXAlignment.Left
	controlsLabel.Parent = tacticsCard

	local equippedLabel = Instance.new('TextLabel')
	equippedLabel.Name = 'EquippedLabel'
	equippedLabel.Size = UDim2.new(0.5, -12, 0, 12)
	equippedLabel.Position = UDim2.fromOffset(10, 20)
	equippedLabel.BackgroundTransparency = 1
	equippedLabel.Font = Enum.Font.GothamBold
	equippedLabel.TextSize = 8
	equippedLabel.TextColor3 = Color3.fromRGB(98, 255, 203)
	equippedLabel.TextXAlignment = Enum.TextXAlignment.Left
	equippedLabel.Parent = tacticsCard

	local targetingLabel = Instance.new('TextLabel')
	targetingLabel.Name = 'TargetingLabel'
	targetingLabel.Size = UDim2.new(0.5, -12, 0, 12)
	targetingLabel.Position = UDim2.new(0.5, 2, 0, 20)
	targetingLabel.BackgroundTransparency = 1
	targetingLabel.Font = Enum.Font.GothamMedium
	targetingLabel.TextSize = 8
	targetingLabel.TextColor3 = Color3.fromRGB(255, 219, 133)
	targetingLabel.TextXAlignment = Enum.TextXAlignment.Left
	targetingLabel.Parent = tacticsCard

	local windowCard = Instance.new('Frame')
	windowCard.Size = UDim2.new(1, -16, 0, 70)
	windowCard.Position = UDim2.fromOffset(8, 242)
	windowCard.Parent = root
	applyDashboardGlass(windowCard, dashboardAccent, Color3.fromRGB(9, 22, 40), 0.18)

	local windowHeader = Instance.new('TextLabel')
	windowHeader.Name = 'WindowHeader'
	windowHeader.Size = UDim2.new(1, -16, 0, 12)
	windowHeader.Position = UDim2.fromOffset(8, 4)
	windowHeader.BackgroundTransparency = 1
	windowHeader.Font = Enum.Font.GothamBold
	windowHeader.TextSize = 10
	windowHeader.TextColor3 = Color3.fromRGB(233, 246, 255)
	windowHeader.TextXAlignment = Enum.TextXAlignment.Left
	windowHeader.Text = 'Windows'
	windowHeader.Parent = windowCard

	local windowHintLabel = Instance.new('TextLabel')
	windowHintLabel.Name = 'WindowHintLabel'
	windowHintLabel.Size = UDim2.new(1, -16, 0, 10)
	windowHintLabel.Position = UDim2.fromOffset(8, 16)
	windowHintLabel.BackgroundTransparency = 1
	windowHintLabel.Font = Enum.Font.GothamMedium
	windowHintLabel.TextSize = 8
	windowHintLabel.TextColor3 = Color3.fromRGB(148, 210, 246)
	windowHintLabel.TextXAlignment = Enum.TextXAlignment.Left
	windowHintLabel.Parent = windowCard

	makeDashboardButton(windowCard, 'Stat', 'A', UDim2.fromOffset(8, 18), function() togglePanel('stats') end, { size = UDim2.fromOffset(40, 22), variant = 'primary' })
	makeDashboardButton(windowCard, 'Bag', 'E', UDim2.fromOffset(50, 18), function() togglePanel('inventory') end, { size = UDim2.fromOffset(40, 22), variant = 'secondary' })
	makeDashboardButton(windowCard, 'Eqp', 'Q', UDim2.fromOffset(92, 18), function() togglePanel('equipment') end, { size = UDim2.fromOffset(40, 22), variant = 'secondary' })
	makeDashboardButton(windowCard, 'Skill', 'S', UDim2.fromOffset(134, 18), function() togglePanel('skills') end, { size = UDim2.fromOffset(40, 22), variant = 'primary' })
	makeDashboardButton(windowCard, 'Town', 'O', UDim2.fromOffset(176, 18), function() togglePanel('actions') end, { size = UDim2.fromOffset(40, 22), variant = 'success' })
	makeDashboardButton(windowCard, 'Party', 'Z', UDim2.fromOffset(218, 18), function() togglePanel('party') end, { size = UDim2.fromOffset(40, 22), variant = 'success' })
	makeDashboardButton(windowCard, 'Chat', 'Ent', UDim2.fromOffset(8, 42), function() chatToggle() end, { size = UDim2.fromOffset(40, 22), variant = 'secondary' })
	makeDashboardButton(windowCard, 'Key', 'H', UDim2.fromOffset(50, 42), function() togglePanel('hotkeys') end, { size = UDim2.fromOffset(40, 22), variant = 'gold' })

	local adminToggleButton = makeDashboardButton(windowCard, 'GM', 'P', UDim2.fromOffset(92, 42), function()
		togglePanel('admin')
	end, {
		size = UDim2.fromOffset(40, 22),
		variant = 'admin',
	})
	adminToggleButton.Visible = isLikelyAdminLocal()

	local function applyDashboardExpandedState()
		local currentPosition = root.Position
		root.Size = expandedDashboardSize
		tacticsCard.Visible = true
		windowCard.Visible = true
		subtitle.Visible = true
		title.Visible = true
		collapseButton.Text = '-'
		heroCard.Position = UDim2.fromOffset(6, 32)
		vitalsCard.Position = UDim2.fromOffset(6, 62)
		root.Position = currentPosition
		local resizeHandle = root:FindFirstChild('ResizeHandle')
		if resizeHandle and resizeHandle:IsA('GuiObject') then
			resizeHandle.Visible = false
		end
	end

	local function applyDashboardCollapsedState()
		local currentPosition = root.Position
		root.Size = collapsedDashboardSize
		tacticsCard.Visible = false
		windowCard.Visible = false
		subtitle.Visible = false
		title.Visible = false
		collapseButton.Text = '+'
		heroCard.Position = UDim2.fromOffset(6, 8)
		vitalsCard.Position = UDim2.fromOffset(6, 38)
		if not dashboardInitialized then
			root.Position = defaultDashboardPosition
			dashboardInitialized = true
		else
			root.Position = currentPosition
		end
		local resizeHandle = root:FindFirstChild('ResizeHandle')
		if resizeHandle and resizeHandle:IsA('GuiObject') then
			resizeHandle.Visible = false
		end
	end

	UiDragUtil.makeDraggable(root, heroCard)
	UiDragUtil.makeResizable(root, Vector2.new(collapsedDashboardSize.X.Offset, collapsedDashboardSize.Y.Offset), Vector2.new(expandedDashboardSize.X.Offset, expandedDashboardSize.Y.Offset))
	collapseButton.Activated:Connect(function()
		dashboardMinimized = not dashboardMinimized
		if dashboardMinimized then
			applyDashboardCollapsedState()
		else
			applyDashboardExpandedState()
		end
	end)
	applyDashboardCollapsedState()

	return {
		root = root,
		adminToggleButton = adminToggleButton,
		controlsLabel = controlsLabel,
		equippedLabel = equippedLabel,
		targetingLabel = targetingLabel,
		windowHintLabel = windowHintLabel,
	}
end

return DashboardHeader
