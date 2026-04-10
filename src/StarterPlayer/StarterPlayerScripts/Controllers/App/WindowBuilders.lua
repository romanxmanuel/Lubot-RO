--!strict

local WindowBuilders = {}

function WindowBuilders.createInventoryPanel(gui: Instance, deps)
	local inventoryFrame = Instance.new('Frame')
	inventoryFrame.Name = 'InventoryFrame'
	inventoryFrame.Size = UDim2.fromOffset(404, 468)
	inventoryFrame.AnchorPoint = Vector2.new(0, 1)
	inventoryFrame.Position = UDim2.new(0, 308, 1, -12)
	inventoryFrame.Visible = false
	deps.stylePanel(inventoryFrame, Color3.fromRGB(235, 240, 249), deps.UI_ACCENTS.inventory)
	inventoryFrame.Parent = gui

	local inventoryTitle = Instance.new('TextLabel')
	inventoryTitle.Name = 'InventoryTitle'
	inventoryTitle.Size = UDim2.fromOffset(250, 16)
	inventoryTitle.Position = UDim2.fromOffset(10, 7)
	inventoryTitle.BackgroundTransparency = 1
	inventoryTitle.Font = Enum.Font.ArialBold
	inventoryTitle.TextSize = 12
	inventoryTitle.Text = 'Inventory'
	inventoryTitle.TextColor3 = deps.UiTheme.palette.parchment
	inventoryTitle.TextXAlignment = Enum.TextXAlignment.Left
	inventoryTitle.Parent = inventoryFrame

	local inventorySubtitle = Instance.new('TextLabel')
	inventorySubtitle.Name = 'InventorySubtitle'
	inventorySubtitle.Size = UDim2.fromOffset(300, 12)
	inventorySubtitle.Position = UDim2.fromOffset(10, 23)
	inventorySubtitle.BackgroundTransparency = 1
	inventorySubtitle.Font = Enum.Font.Arial
	inventorySubtitle.TextSize = 9
	inventorySubtitle.TextColor3 = deps.UiTheme.palette.textMuted
	inventorySubtitle.TextXAlignment = Enum.TextXAlignment.Left
	inventorySubtitle.Text = 'Classic slot bag.'
	inventorySubtitle.Parent = inventoryFrame

	deps.UiDragUtil.makeDraggable(inventoryFrame, inventoryTitle)
	deps.UiDragUtil.makeResizable(inventoryFrame, Vector2.new(404, 468), Vector2.new(480, 560))

	local closeButton = deps.makeCloseButton(inventoryFrame, function()
		inventoryFrame.Visible = false
	end)
	closeButton.Name = 'CloseButton'

	deps.InventoryController.bind(inventoryFrame, {
		requestAction = deps.requestAction,
		showTooltip = deps.showTooltip,
		hideTooltip = deps.hideTooltip,
		handleInventoryDrop = deps.handleInventoryDrop,
		getState = deps.getState,
	})

	return inventoryFrame
end

function WindowBuilders.createEquipmentPanel(gui: Instance, deps)
	return deps.EquipmentPanelFactory.create(gui, {
		stylePanel = deps.stylePanel,
		UI_ACCENTS = deps.UI_ACCENTS,
		UiTheme = deps.UiTheme,
		UiDragUtil = deps.UiDragUtil,
		makeCloseButton = deps.makeCloseButton,
	})
end

function WindowBuilders.createSkillWindow(gui: Instance, deps)
	local skillWindow = Instance.new('Frame')
	skillWindow.Name = 'SkillWindow'
	skillWindow.Size = UDim2.fromOffset(382, 428)
	skillWindow.Position = UDim2.fromOffset(224, 56)
	skillWindow.Visible = false
	deps.stylePanel(skillWindow, Color3.fromRGB(235, 240, 249), deps.UI_ACCENTS.skills)
	skillWindow.Parent = gui

	local title = Instance.new('TextLabel')
	title.Size = UDim2.fromOffset(240, 16)
	title.Position = UDim2.fromOffset(10, 7)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.ArialBold
	title.TextSize = 12
	title.TextColor3 = deps.UiTheme.palette.parchment
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = 'Skill Tree'
	title.Parent = skillWindow

	deps.UiDragUtil.makeDraggable(skillWindow, title)
	deps.UiDragUtil.makeResizable(skillWindow, Vector2.new(382, 428), Vector2.new(500, 580))

	deps.makeCloseButton(skillWindow, function()
		skillWindow.Visible = false
	end)

	local subtitle = Instance.new('TextLabel')
	subtitle.Size = UDim2.fromOffset(300, 12)
	subtitle.Position = UDim2.fromOffset(10, 23)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Arial
	subtitle.TextSize = 9
	subtitle.TextColor3 = Color3.fromRGB(221, 232, 255)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = 'Learn skills and assign them.'
	subtitle.Parent = skillWindow

	local summaryCard = Instance.new('Frame')
	summaryCard.Name = 'SkillSummaryCard'
	summaryCard.Size = UDim2.fromOffset(350, 58)
	summaryCard.Position = UDim2.fromOffset(16, 44)
	deps.styleCard(summaryCard, Color3.fromRGB(241, 245, 251), deps.UI_ACCENTS.skills)
	summaryCard.Parent = skillWindow

	local skillSelectionLabel = Instance.new('TextLabel')
	skillSelectionLabel.Name = 'SkillSelectionLabel'
	skillSelectionLabel.Size = UDim2.fromOffset(220, 32)
	skillSelectionLabel.Position = UDim2.fromOffset(10, 8)
	skillSelectionLabel.BackgroundTransparency = 1
	skillSelectionLabel.Font = Enum.Font.Arial
	skillSelectionLabel.TextSize = 9
	skillSelectionLabel.TextWrapped = true
	skillSelectionLabel.TextColor3 = deps.UiTheme.palette.text
	skillSelectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	skillSelectionLabel.TextYAlignment = Enum.TextYAlignment.Top
	skillSelectionLabel.Text = 'Select a skill, then click a hotbar slot to assign it.'
	skillSelectionLabel.Parent = summaryCard

	local skillPointLabel = Instance.new('TextLabel')
	skillPointLabel.Name = 'SkillPointLabel'
	skillPointLabel.Size = UDim2.fromOffset(100, 16)
	skillPointLabel.Position = UDim2.new(1, -110, 0, 8)
	skillPointLabel.BackgroundTransparency = 1
	skillPointLabel.Font = Enum.Font.ArialBold
	skillPointLabel.TextSize = 9
	skillPointLabel.TextColor3 = Color3.fromRGB(239, 221, 149)
	skillPointLabel.TextXAlignment = Enum.TextXAlignment.Right
	skillPointLabel.Text = 'Skill Points: 0'
	skillPointLabel.Parent = summaryCard

	local summaryHint = Instance.new('TextLabel')
	summaryHint.Size = UDim2.fromOffset(100, 22)
	summaryHint.Position = UDim2.new(1, -110, 0, 24)
	summaryHint.BackgroundTransparency = 1
	summaryHint.Font = Enum.Font.Arial
	summaryHint.TextSize = 8
	summaryHint.TextColor3 = deps.UiTheme.palette.textMuted
	summaryHint.TextWrapped = true
	summaryHint.TextXAlignment = Enum.TextXAlignment.Right
	summaryHint.TextYAlignment = Enum.TextYAlignment.Top
	summaryHint.Text = 'Assign mode stays armed until you bind a key or hotbar slot.'
	summaryHint.Parent = summaryCard

	local skillListFrame = Instance.new('ScrollingFrame')
	skillListFrame.Name = 'SkillListFrame'
	skillListFrame.Size = UDim2.fromOffset(350, 308)
	skillListFrame.Position = UDim2.fromOffset(16, 110)
	skillListFrame.BackgroundColor3 = Color3.fromRGB(244, 247, 252)
	skillListFrame.BorderSizePixel = 0
	skillListFrame.ScrollBarThickness = 6
	skillListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	skillListFrame.Parent = skillWindow
	deps.styleScrollFrame(skillListFrame, deps.UI_ACCENTS.skills, Color3.fromRGB(12, 22, 33))

	return {
		frame = skillWindow,
		skillListFrame = skillListFrame,
		skillPointLabel = skillPointLabel,
		skillSelectionLabel = skillSelectionLabel,
	}
end

function WindowBuilders.createHotbar(gui: Instance, deps)
	local hotbarSlots = {}
	local hotbarFrame = Instance.new('Frame')
	local defaultHotbarPosition = UDim2.new(0.5, 0, 1, 0)
	hotbarFrame.Name = 'HotbarFrame'
	hotbarFrame.Size = UDim2.fromOffset(418, 62)
	hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
	hotbarFrame.Position = defaultHotbarPosition
	hotbarFrame.BackgroundTransparency = 1
	hotbarFrame.Parent = gui

	local slotsFrame = Instance.new('Frame')
	slotsFrame.Name = 'SlotsFrame'
	slotsFrame.Size = UDim2.fromOffset(418, 56)
	slotsFrame.Position = UDim2.fromOffset(0, 0)
	slotsFrame.BackgroundTransparency = 1
	slotsFrame.Parent = hotbarFrame

	local dragHandle = Instance.new('TextButton')
	dragHandle.Name = 'DragHandle'
	dragHandle.Size = UDim2.fromOffset(42, 12)
	dragHandle.AnchorPoint = Vector2.new(1, 0)
	dragHandle.Position = UDim2.new(1, -2, 0, 50)
	dragHandle.BackgroundColor3 = Color3.fromRGB(240, 244, 252)
	dragHandle.BackgroundTransparency = 0.02
	dragHandle.BorderSizePixel = 0
	dragHandle.Font = Enum.Font.ArialBold
	dragHandle.TextSize = 7
	dragHandle.TextColor3 = deps.UiTheme.palette.text
	dragHandle.Text = 'Move'
	dragHandle.Parent = hotbarFrame
	deps.UiTheme.styleButton(dragHandle, 'secondary')

	deps.UiDragUtil.makeDraggable(hotbarFrame, dragHandle)

	local hotbarLayout = Instance.new('UIListLayout')
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hotbarLayout.Padding = UDim.new(0, 4)
	hotbarLayout.Parent = slotsFrame

	for _, slotInfo in ipairs(deps.SkillInputConfig.hotbarOrder) do
		deps.HotbarUiFactory.createSlotButton(slotsFrame, slotInfo, {
			palette = deps.UiTheme.palette,
			styleSlot = deps.UiTheme.styleSlot,
			getSelectedSkillId = deps.getSelectedSkillId,
			canAssignSkill = deps.canAssignSkill,
			assignSkill = function(visibleSlotIndex)
				deps.onAssignSkill(slotInfo, visibleSlotIndex)
			end,
			triggerSlot = deps.triggerHotbarSlot,
			registerSlot = function(visibleSlotIndex, slotButton)
				hotbarSlots[visibleSlotIndex] = slotButton
			end,
		})
	end

	return {
		frame = hotbarFrame,
		hotbarSlots = hotbarSlots,
	}
end

return WindowBuilders
