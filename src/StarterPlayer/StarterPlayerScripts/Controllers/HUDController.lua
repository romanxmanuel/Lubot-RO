--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatConfig = require(ReplicatedStorage.Shared.Config.StatConfig)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local HUDController = {
	Name = "HUDController",
}

local localPlayer = Players.LocalPlayer
local dependencies = nil
local started = false
local rootGui: ScreenGui? = nil
local refs = {}
local expanded = false
local desiredInventoryVisible: boolean? = nil
local slotCooldownEnds: { [number]: number } = {}

local COLLAPSED_SIZE = UDim2.fromOffset(336, 148)
local EXPANDED_SIZE = UDim2.fromOffset(336, 360)
local ROOT_POSITION = UDim2.fromOffset(12, 72)
local HOTBAR_SLOT_COUNT = 10
local DEFAULT_SKILL_COOLDOWN = 1.5

local SLOT_KEYCODES: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

local COOLDOWN_ATTRIBUTE_NAMES = {
	'CooldownSeconds',
	'Cooldown',
	'SkillCooldown',
	'CastCooldown',
	'ActivationCooldown',
}

local TOKENS = {
	window = Color3.fromRGB(19, 25, 41),
	windowInset = Color3.fromRGB(26, 33, 52),
	panel = Color3.fromRGB(24, 31, 49),
	panelInset = Color3.fromRGB(33, 41, 63),
	line = Color3.fromRGB(90, 116, 162),
	lineSoft = Color3.fromRGB(68, 90, 132),
	bevelLight = Color3.fromRGB(176, 209, 255),
	bevelDark = Color3.fromRGB(12, 16, 30),
	title = Color3.fromRGB(236, 244, 255),
	body = Color3.fromRGB(171, 198, 236),
	muted = Color3.fromRGB(130, 157, 198),
	gold = Color3.fromRGB(247, 218, 126),
	blueTop = Color3.fromRGB(104, 178, 255),
	blueBottom = Color3.fromRGB(64, 108, 201),
	button = Color3.fromRGB(66, 98, 166),
	buttonHover = Color3.fromRGB(89, 129, 214),
	buttonText = Color3.fromRGB(243, 248, 255),
	hp = Color3.fromRGB(243, 92, 126),
	sp = Color3.fromRGB(76, 170, 248),
	exp = Color3.fromRGB(95, 224, 168),
	jexp = Color3.fromRGB(165, 124, 255),
	bossBack = Color3.fromRGB(44, 19, 38),
	bossFill = Color3.fromRGB(224, 67, 114),
}

local function prettyClassName(classId: string): string
	local words = {}
	for word in string.gmatch(classId, "[^_]+") do
		table.insert(words, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
	end
	return #words > 0 and table.concat(words, " ") or "Knight"
end

local function makeCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent: Instance, color: Color3, transparency: number, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function applyBevel(parent: GuiObject, lightT: number?, darkT: number?)
	local top = Instance.new("Frame")
	top.Name = "BevelTop"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.fromScale(0.5, 0)
	top.Size = UDim2.new(1, -2, 0, 1)
	top.BackgroundColor3 = TOKENS.bevelLight
	top.BackgroundTransparency = lightT or 0.35
	top.BorderSizePixel = 0
	top.ZIndex = parent.ZIndex + 1
	top.Parent = parent

	local left = Instance.new("Frame")
	left.Name = "BevelLeft"
	left.Position = UDim2.fromOffset(0, 1)
	left.Size = UDim2.new(0, 1, 1, -2)
	left.BackgroundColor3 = TOKENS.bevelLight
	left.BackgroundTransparency = lightT or 0.35
	left.BorderSizePixel = 0
	left.ZIndex = parent.ZIndex + 1
	left.Parent = parent

	local bottom = Instance.new("Frame")
	bottom.Name = "BevelBottom"
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.fromScale(0.5, 1)
	bottom.Size = UDim2.new(1, -2, 0, 1)
	bottom.BackgroundColor3 = TOKENS.bevelDark
	bottom.BackgroundTransparency = darkT or 0.45
	bottom.BorderSizePixel = 0
	bottom.ZIndex = parent.ZIndex + 1
	bottom.Parent = parent

	local right = Instance.new("Frame")
	right.Name = "BevelRight"
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Size = UDim2.new(0, 1, 1, -2)
	right.BackgroundColor3 = TOKENS.bevelDark
	right.BackgroundTransparency = darkT or 0.45
	right.BorderSizePixel = 0
	right.ZIndex = parent.ZIndex + 1
	right.Parent = parent
end

local function createPanel(parent: Instance, name: string, size: UDim2, position: UDim2, color: Color3, radius: number)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	makeCorner(frame, radius)
	return frame
end

local function createText(parent: Instance, props)
	local label = Instance.new(props.className or "TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = props.font or Enum.Font.ArialBold
	label.TextSize = props.textSize or 14
	label.TextColor3 = props.textColor3 or TOKENS.title
	label.TextXAlignment = props.textXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = props.textYAlignment or Enum.TextYAlignment.Center
	label.TextWrapped = props.textWrapped == true
	label.Text = props.text or ""
	label.Size = props.size or UDim2.fromScale(1, 1)
	label.Position = props.position or UDim2.fromScale(0, 0)
	label.ZIndex = props.zIndex or 2
	label.Parent = parent
	return label
end

local function createButton(parent: Instance, text: string, size: UDim2, position: UDim2)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.Text = text
	button.Font = Enum.Font.ArialBold
	button.TextSize = 11
	button.TextColor3 = TOKENS.buttonText
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = TOKENS.button
	button.BorderSizePixel = 0
	button.ZIndex = 3
	button.Parent = parent
	makeCorner(button, 6)
	makeStroke(button, TOKENS.line, 0.18, 1)
	applyBevel(button, 0.45, 0.6)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), {
			BackgroundColor3 = TOKENS.buttonHover,
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), {
			BackgroundColor3 = TOKENS.button,
		}):Play()
	end)

	return button
end

local function createChromeFrame(parent: Instance, name: string, size: UDim2, position: UDim2, baseColor: Color3, radius: number)
	local frame = createPanel(parent, name, size, position, baseColor, radius)
	makeStroke(frame, TOKENS.line, 0.06, 1.2)
	applyBevel(frame, 0.25, 0.55)
	return frame
end

local function createCompactBar(parent: Instance, name: string, fillColor: Color3, position: UDim2)
	local holder = createPanel(parent, name .. "Bar", UDim2.fromOffset(132, 17), position, TOKENS.panelInset, 6)
	makeStroke(holder, TOKENS.lineSoft, 0.18, 1)
	applyBevel(holder, 0.4, 0.65)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = holder
	makeCorner(fill, 6)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, fillColor:Lerp(Color3.new(1, 1, 1), 0.18)),
		ColorSequenceKeypoint.new(1, fillColor),
	})
	gradient.Parent = fill

	local label = createText(holder, {
		text = name,
		size = UDim2.fromScale(1, 1),
		textSize = 9,
		textColor3 = Color3.fromRGB(255, 255, 255),
		textXAlignment = Enum.TextXAlignment.Center,
		font = Enum.Font.ArialBold,
		zIndex = 4,
	})

	return holder, fill, label
end

local function getStatRatio(current: number, maximum: number): number
	if maximum <= 0 then
		return 0
	end
	return math.clamp(current / maximum, 0, 1)
end

local function getStatValue(statName: string): number
	return localPlayer:GetAttribute(statName) or StatConfig.StartingStats[statName] or 1
end

local function getStatPoints(): number
	return localPlayer:GetAttribute("StatPoints") or 0
end

local function fireStatRequest(payload)
	dependencies.Runtime.StatRequest:FireServer(payload)
end

local function getEquippedTool(): Tool?
	local character = localPlayer.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end

	return nil
end

local function resolveToolCooldownSeconds(tool: Tool?): number
	if not tool then
		return DEFAULT_SKILL_COOLDOWN
	end

	for _, attributeName in ipairs(COOLDOWN_ATTRIBUTE_NAMES) do
		local value = tool:GetAttribute(attributeName)
		if typeof(value) == "number" and value > 0 then
			return value
		end
		if typeof(value) == "string" then
			local parsed = tonumber(value)
			if parsed and parsed > 0 then
				return parsed
			end
		end
	end

	return DEFAULT_SKILL_COOLDOWN
end

local function beginSlotCooldown(slotIndex: number, durationSeconds: number)
	if durationSeconds <= 0 then
		return
	end

	local nextReady = os.clock() + durationSeconds
	local existingReady = slotCooldownEnds[slotIndex] or 0
	slotCooldownEnds[slotIndex] = math.max(existingReady, nextReady)
end

local function getNativeBackpackFrames()
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if not ok or not coreGui then
		return nil, nil
	end

	local robloxGui = coreGui:FindFirstChild("RobloxGui")
	if not robloxGui then
		return nil, nil
	end

	local backpackGui = robloxGui:FindFirstChild("Backpack")
	if not backpackGui then
		return nil, nil
	end

	local inventoryFrame = backpackGui:FindFirstChild("Inventory")
	local hotbarFrame = backpackGui:FindFirstChild("Hotbar")
	if not (inventoryFrame and hotbarFrame) then
		return nil, nil
	end

	if not inventoryFrame:IsA("GuiObject") or not hotbarFrame:IsA("GuiObject") then
		return nil, nil
	end

	return inventoryFrame, hotbarFrame
end

local function toggleNativeInventoryWindow()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end)

	local inventoryFrame, hotbarFrame = getNativeBackpackFrames()
	if not inventoryFrame then
		warn("[HUDController] Native backpack inventory frame not found; cannot toggle window.")
		return
	end

	desiredInventoryVisible = not inventoryFrame.Visible

	task.spawn(function()
		for _ = 1, 20 do
			local currentInventoryFrame, currentHotbarFrame = getNativeBackpackFrames()
			if not currentInventoryFrame then
				break
			end
			currentInventoryFrame.Visible = desiredInventoryVisible == true
			if currentHotbarFrame then
				currentHotbarFrame.Visible = true
			end
			task.wait()
		end
	end)

	if hotbarFrame then
		hotbarFrame.Visible = true
	end
end

local function refreshStatsSection()
	if not refs.pointsValue then
		return
	end

	local points = getStatPoints()
	refs.pointsValue.Text = tostring(points)

	for _, statName in ipairs(StatConfig.Order) do
		local row = refs.rows[statName]
		if row then
			row.value.Text = tostring(getStatValue(statName))
			row.addButton.Active = points > 0
			row.addButton.TextTransparency = points > 0 and 0 or 0.45
		end
	end
end

local function applyExpansionVisualState()
	if not refs.dashboard then
		return
	end

	refs.dashboard.Size = expanded and EXPANDED_SIZE or COLLAPSED_SIZE
	refs.expandButton.Text = expanded and "-" or "+"
	refs.expandedSection.Visible = expanded
end

local function setExpanded(nextExpanded: boolean)
	if expanded == nextExpanded or not refs.dashboard then
		applyExpansionVisualState()
		return
	end

	expanded = nextExpanded
	refs.expandedSection.Visible = true

	TweenService:Create(refs.dashboard, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = expanded and EXPANDED_SIZE or COLLAPSED_SIZE,
	}):Play()

	if not expanded then
		task.delay(0.16, function()
			if refs.expandedSection and not expanded then
				refs.expandedSection.Visible = false
			end
		end)
	end

	applyExpansionVisualState()
end

local function buildStatRow(parent: Instance, statName: string, order: number)
	local row = createPanel(parent, statName .. "Row", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 0), TOKENS.panelInset, 5)
	row.LayoutOrder = order
	row.AutomaticSize = Enum.AutomaticSize.None
	makeStroke(row, TOKENS.lineSoft, 0.18, 1)
	applyBevel(row, 0.45, 0.62)

	local statLabel = createText(row, {
		text = statName,
		position = UDim2.fromOffset(10, 0),
		size = UDim2.fromOffset(42, 24),
		textSize = 13,
		font = Enum.Font.ArialBold,
	})

	local addButton = createButton(row, ">", UDim2.fromOffset(24, 14), UDim2.fromOffset(108, 5))
	addButton.TextSize = 10
	addButton.MouseButton1Click:Connect(function()
		fireStatRequest({
			kind = "allocate",
			stat = statName,
		})
	end)

	local value = createText(row, {
		text = "1",
		position = UDim2.fromOffset(225, 0),
		size = UDim2.fromOffset(24, 24),
		textSize = 17,
		font = Enum.Font.ArialBold,
		textColor3 = TOKENS.button,
		textXAlignment = Enum.TextXAlignment.Center,
	})

	refs.rows[statName] = {
		frame = row,
		value = value,
		addButton = addButton,
		statLabel = statLabel,
	}

	return row
end

local function ensureGui()
	if rootGui and rootGui.Parent then
		return
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existingGui = playerGui:FindFirstChild("MMOHud")
	if existingGui then
		existingGui:Destroy()
	end

	refs = {}
	expanded = false

	rootGui = Instance.new("ScreenGui")
	rootGui.Name = "MMOHud"
	rootGui.ResetOnSpawn = false
	rootGui.IgnoreGuiInset = false
	rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	rootGui.Parent = playerGui

	local dashboard = createChromeFrame(rootGui, "Dashboard", COLLAPSED_SIZE, ROOT_POSITION, TOKENS.window, 10)

	local header = createPanel(dashboard, "Header", UDim2.new(1, -8, 0, 62), UDim2.fromOffset(4, 4), TOKENS.windowInset, 8)
	makeStroke(header, TOKENS.lineSoft, 0.2, 1)
	applyBevel(header, 0.28, 0.58)

	local titleBar = createPanel(header, "TitleBar", UDim2.new(1, -4, 0, 14), UDim2.fromOffset(2, 2), TOKENS.blueBottom, 4)
	local titleBarGradient = Instance.new("UIGradient")
	titleBarGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, TOKENS.blueTop),
		ColorSequenceKeypoint.new(1, TOKENS.blueBottom),
	})
	titleBarGradient.Rotation = 90
	titleBarGradient.Parent = titleBar

	local avatarFrame = createPanel(header, "AvatarFrame", UDim2.fromOffset(42, 42), UDim2.fromOffset(8, 18), TOKENS.panelInset, 21)
	makeStroke(avatarFrame, TOKENS.lineSoft, 0.1, 1)
	applyBevel(avatarFrame, 0.3, 0.65)

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "AvatarImage"
	avatarImage.BackgroundTransparency = 1
	avatarImage.Size = UDim2.fromOffset(38, 38)
	avatarImage.Position = UDim2.fromOffset(2, 2)
	avatarImage.ScaleType = Enum.ScaleType.Crop
	avatarImage.Parent = avatarFrame
	makeCorner(avatarImage, 19)
	local okThumb, thumb = pcall(function()
		return Players:GetUserThumbnailAsync(localPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	if okThumb and thumb then
		avatarImage.Image = thumb
	end

	createText(header, {
		text = "Player Profile",
		position = UDim2.fromOffset(58, 18),
		size = UDim2.fromOffset(170, 16),
		textSize = 16,
		font = Enum.Font.GothamBold,
		textColor3 = TOKENS.title,
	})

	createText(header, {
		text = "Core stats and progress",
		position = UDim2.fromOffset(58, 35),
		size = UDim2.fromOffset(170, 12),
		textSize = 10,
		font = Enum.Font.Gotham,
		textColor3 = TOKENS.muted,
	})

	local expandButton = createButton(header, "+", UDim2.fromOffset(26, 22), UDim2.new(1, -30, 0.5, -8))
	expandButton.TextSize = 14
	expandButton.MouseButton1Click:Connect(function()
		setExpanded(not expanded)
	end)

	local zenyLabel = createText(dashboard, {
		text = "Zeny 0",
		position = UDim2.fromOffset(10, 70),
		size = UDim2.fromOffset(130, 16),
		textSize = 13,
		font = Enum.Font.GothamBold,
		textColor3 = TOKENS.gold,
	})

	local classLabel = createText(dashboard, {
		text = "Knight  Lv.1 / Job 1",
		position = UDim2.fromOffset(10, 87),
		size = UDim2.fromOffset(230, 13),
		textSize = 11,
		font = Enum.Font.Gotham,
		textColor3 = TOKENS.body,
	})

	local barsCard = createPanel(dashboard, "BarsCard", UDim2.new(1, -8, 0, 42), UDim2.fromOffset(4, 102), TOKENS.panel, 6)
	makeStroke(barsCard, TOKENS.lineSoft, 0.18, 1)
	applyBevel(barsCard, 0.3, 0.6)

	local _, hpFill, hpLabel = createCompactBar(barsCard, "HP", TOKENS.hp, UDim2.fromOffset(4, 4))
	local _, spFill, spLabel = createCompactBar(barsCard, "SP", TOKENS.sp, UDim2.fromOffset(170, 4))
	local _, expFill, expLabel = createCompactBar(barsCard, "EXP", TOKENS.exp, UDim2.fromOffset(4, 22))
	local _, jexpFill, jexpLabel = createCompactBar(barsCard, "LV", TOKENS.jexp, UDim2.fromOffset(170, 22))

	local expandedSection = Instance.new("Frame")
	expandedSection.Name = "ExpandedSection"
	expandedSection.BackgroundTransparency = 1
	expandedSection.Position = UDim2.fromOffset(4, 148)
	expandedSection.Size = UDim2.new(1, -8, 0, 202)
	expandedSection.Visible = false
	expandedSection.Parent = dashboard

	local statsCard = createPanel(expandedSection, "StatsCard", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), TOKENS.panel, 6)
	makeStroke(statsCard, TOKENS.line, 0.12, 1)
	applyBevel(statsCard, 0.3, 0.58)

	local statsHeader = createPanel(statsCard, "StatsHeader", UDim2.new(1, -8, 0, 34), UDim2.fromOffset(4, 4), TOKENS.panelInset, 6)
	makeStroke(statsHeader, TOKENS.lineSoft, 0.18, 1)
	applyBevel(statsHeader, 0.35, 0.62)

	createText(statsHeader, {
		text = "Stats",
		position = UDim2.fromOffset(8, 3),
		size = UDim2.fromOffset(56, 14),
		textSize = 14,
		font = Enum.Font.GothamBold,
	})

	createText(statsHeader, {
		text = "Allocate points",
		position = UDim2.fromOffset(8, 16),
		size = UDim2.fromOffset(90, 10),
		textSize = 9,
		font = Enum.Font.Gotham,
		textColor3 = TOKENS.muted,
	})

	local resetButton = createButton(statsHeader, "Reset", UDim2.fromOffset(42, 17), UDim2.new(1, -118, 0.5, -8))
	resetButton.TextSize = 10
	resetButton.MouseButton1Click:Connect(function()
		fireStatRequest({
			kind = "reset",
		})
	end)

	local pointsCard = createPanel(statsHeader, "PointsCard", UDim2.fromOffset(64, 23), UDim2.new(1, -70, 0.5, -11), TOKENS.windowInset, 5)
	makeStroke(pointsCard, TOKENS.lineSoft, 0.18, 1)
	applyBevel(pointsCard, 0.35, 0.62)

	createText(pointsCard, {
		text = "POINTS",
		position = UDim2.fromOffset(2, 1),
		size = UDim2.fromOffset(60, 8),
		textSize = 8,
		font = Enum.Font.GothamBold,
		textColor3 = TOKENS.muted,
		textXAlignment = Enum.TextXAlignment.Center,
	})

	local pointsValue = createText(pointsCard, {
		text = "0",
		position = UDim2.fromOffset(2, 7),
		size = UDim2.fromOffset(60, 14),
		textSize = 15,
		font = Enum.Font.GothamBold,
		textColor3 = TOKENS.button,
		textXAlignment = Enum.TextXAlignment.Center,
	})

	local rowsHolder = Instance.new("Frame")
	rowsHolder.Name = "RowsHolder"
	rowsHolder.BackgroundTransparency = 1
	rowsHolder.Position = UDim2.fromOffset(8, 44)
	rowsHolder.Size = UDim2.new(1, -16, 0, 156)
	rowsHolder.Parent = statsCard

	local rowList = Instance.new("UIListLayout")
	rowList.Padding = UDim.new(0, 2)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.FillDirection = Enum.FillDirection.Vertical
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rowList.VerticalAlignment = Enum.VerticalAlignment.Top
	rowList.Parent = rowsHolder

	refs.rows = {}
	for index, statName in ipairs(StatConfig.Order) do
		local row = buildStatRow(rowsHolder, statName, index)
		row.Size = UDim2.new(1, 0, 0, 24)
	end

	local bossFrame = createPanel(rootGui, "BossFrame", UDim2.fromOffset(360, 40), UDim2.new(0.5, -180, 0, 12), TOKENS.bossBack, 12)
	bossFrame.Visible = false
	makeStroke(bossFrame, Color3.fromRGB(179, 96, 116), 0.08, 1)

	local bossName = createText(bossFrame, {
		text = "Boss",
		position = UDim2.fromOffset(10, 4),
		size = UDim2.fromOffset(340, 16),
		textSize = 14,
		textColor3 = Color3.fromRGB(255, 240, 244),
	})

	local bossBarBack = createPanel(bossFrame, "BossBarBack", UDim2.fromOffset(340, 10), UDim2.fromOffset(10, 22), Color3.fromRGB(97, 54, 64), 6)
	local bossFill = createPanel(bossBarBack, "BossFill", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), TOKENS.bossFill, 6)
	local bossValue = createText(bossBarBack, {
		text = "100%",
		position = UDim2.fromScale(0, 0),
		size = UDim2.fromScale(1, 1),
		textSize = 10,
		font = Enum.Font.GothamBold,
		textColor3 = Color3.fromRGB(255, 250, 251),
		textXAlignment = Enum.TextXAlignment.Center,
	})

	refs.dashboard = dashboard
	refs.expandButton = expandButton
	refs.zenyLabel = zenyLabel
	refs.classLabel = classLabel
	refs.hpFill = hpFill
	refs.hpLabel = hpLabel
	refs.spFill = spFill
	refs.spLabel = spLabel
	refs.expFill = expFill
	refs.expLabel = expLabel
	refs.jexpFill = jexpFill
	refs.jexpLabel = jexpLabel
	refs.expandedSection = expandedSection
	refs.pointsValue = pointsValue
	refs.resetButton = resetButton
	refs.bossFrame = bossFrame
	refs.bossName = bossName
	refs.bossFill = bossFill
	refs.bossValue = bossValue

	local utilityFrame = Instance.new("Frame")
	utilityFrame.Name = "UtilityButtons"
	utilityFrame.BackgroundTransparency = 1
	utilityFrame.Size = UDim2.fromOffset(118, 26)
	utilityFrame.Position = UDim2.new(0, 350, 0, 72)
	utilityFrame.ZIndex = 5
	utilityFrame.Parent = rootGui

	local inventoryToggleButton = createButton(utilityFrame, "Show", UDim2.fromOffset(56, 24), UDim2.fromOffset(0, 0))
	inventoryToggleButton.Name = "InventoryToggleButton"
	inventoryToggleButton.TextSize = 10
	inventoryToggleButton.MouseButton1Click:Connect(function()
		toggleNativeInventoryWindow()
	end)

	local stashButton = createButton(utilityFrame, "Store", UDim2.fromOffset(56, 24), UDim2.fromOffset(60, 0))
	stashButton.Name = "StashButton"
	stashButton.TextSize = 10
	stashButton.MouseButton1Click:Connect(function()
		dependencies.Runtime.ActionRequest:FireServer({
			action = MMONet.Actions.StashInventoryTools,
		})
		local inventoryFrame = getNativeBackpackFrames()
		if inventoryFrame and not inventoryFrame.Visible then
			toggleNativeInventoryWindow()
		end
	end)

	refs.utilityFrame = utilityFrame
	refs.inventoryToggleButton = inventoryToggleButton
	refs.stashButton = stashButton

	local cooldownStrip = Instance.new("Frame")
	cooldownStrip.Name = "CooldownStrip"
	cooldownStrip.BackgroundTransparency = 1
	cooldownStrip.Size = UDim2.fromOffset(560, 20)
	cooldownStrip.AnchorPoint = Vector2.new(0.5, 1)
	cooldownStrip.Position = UDim2.new(0.5, 0, 1, -148)
	cooldownStrip.ZIndex = 7
	cooldownStrip.Parent = rootGui

	local cooldownLabels = {}
	for slotIndex = 1, HOTBAR_SLOT_COUNT do
		local label = Instance.new("TextLabel")
		label.Name = string.format("Cooldown%d", slotIndex)
		label.Size = UDim2.fromOffset(34, 18)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromOffset(44 + ((slotIndex - 1) * 55), 10)
		label.BackgroundColor3 = Color3.fromRGB(10, 16, 29)
		label.BackgroundTransparency = 0.12
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 246, 172)
		label.TextSize = 12
		label.Text = ""
		label.Visible = false
		label.ZIndex = 8
		label.Parent = cooldownStrip
		makeCorner(label, 5)
		makeStroke(label, Color3.fromRGB(120, 168, 255), 0, 1)
		cooldownLabels[slotIndex] = label
	end
	refs.cooldownLabels = cooldownLabels

	applyExpansionVisualState()
end

local function updateBossBar()
	local bossModel = dependencies.TargetingController.getTrackedBoss()
	if not bossModel then
		refs.bossFrame.Visible = false
		return
	end

	local currentHp = bossModel:GetAttribute("CurrentHP") or 0
	local maxHp = bossModel:GetAttribute("MaxHP") or 0
	refs.bossFrame.Visible = currentHp > 0 and maxHp > 0
	if not refs.bossFrame.Visible then
		return
	end

	refs.bossName.Text = tostring(bossModel:GetAttribute("DisplayName") or bossModel.Name)
	refs.bossFill.Size = UDim2.fromScale(getStatRatio(currentHp, maxHp), 1)
	refs.bossValue.Text = string.format("%d / %d", currentHp, maxHp)
end

local function updateSummary()
	local hp = localPlayer:GetAttribute("HP") or 0
	local maxHp = localPlayer:GetAttribute("MaxHP") or 1
	local sp = localPlayer:GetAttribute("SP") or 0
	local maxSp = localPlayer:GetAttribute("MaxSP") or 1
	local exp = localPlayer:GetAttribute("Experience") or 0
	local expMax = localPlayer:GetAttribute("ExperienceMax") or 1
	local zeny = localPlayer:GetAttribute("Zeny") or 0
	local classId = tostring(localPlayer:GetAttribute("ClassId") or "knight")
	local level = localPlayer:GetAttribute("Level") or 1

	refs.zenyLabel.Text = string.format("Zeny %s", tostring(zeny))
	refs.classLabel.Text = string.format("%s  Lv.%s", prettyClassName(classId), tostring(level))

	refs.hpFill.Size = UDim2.fromScale(getStatRatio(hp, maxHp), 1)
	refs.hpLabel.Text = string.format("HP %d/%d", hp, maxHp)

	refs.spFill.Size = UDim2.fromScale(getStatRatio(sp, maxSp), 1)
	refs.spLabel.Text = string.format("SP %d/%d", sp, maxSp)

	refs.expFill.Size = UDim2.fromScale(getStatRatio(exp, expMax), 1)
	refs.expLabel.Text = string.format("EXP %d/%d", exp, expMax)

	refs.jexpFill.Size = UDim2.fromScale(1, 1)
	refs.jexpLabel.Text = string.format("LV %d", level)

	local inventoryFrame, hotbarFrame = getNativeBackpackFrames()
	if inventoryFrame and desiredInventoryVisible ~= nil and inventoryFrame.Visible ~= desiredInventoryVisible then
		inventoryFrame.Visible = desiredInventoryVisible
	end
	if hotbarFrame then
		hotbarFrame.Visible = true
	end

	if refs.inventoryToggleButton then
		if inventoryFrame then
			refs.inventoryToggleButton.Text = inventoryFrame.Visible and "Hide" or "Show"
		else
			refs.inventoryToggleButton.Text = "Bag"
		end
	end

	refs.stashButton.Text = "Store"

	local now = os.clock()
	if refs.cooldownLabels then
		for slotIndex = 1, HOTBAR_SLOT_COUNT do
			local label = refs.cooldownLabels[slotIndex]
			if label then
				local remaining = (slotCooldownEnds[slotIndex] or 0) - now
				if remaining <= 0 then
					slotCooldownEnds[slotIndex] = nil
					label.Visible = false
				else
					label.Text = string.format('%.1f', remaining)
					label.Visible = true
				end
			end
		end
	end

	refreshStatsSection()
end

function HUDController.init(deps)
	dependencies = deps
end

function HUDController.start()
	if started then
		return
	end
	started = true

	ensureGui()

	for _, statName in ipairs(StatConfig.Order) do
		localPlayer:GetAttributeChangedSignal(statName):Connect(refreshStatsSection)
	end
	localPlayer:GetAttributeChangedSignal("StatPoints"):Connect(refreshStatsSection)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if UserInputService:GetFocusedTextBox() then
			return
		end

		local slotIndex = SLOT_KEYCODES[input.KeyCode]
		if slotIndex then
			task.defer(function()
				task.wait(0.06)
				beginSlotCooldown(slotIndex, resolveToolCooldownSeconds(getEquippedTool()))
			end)
		end

		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.C then
			setExpanded(not expanded)
		end
	end)

	RunService.RenderStepped:Connect(function()
		updateSummary()
		updateBossBar()
	end)
end

return HUDController
