--!strict

local TooltipUi = {}

export type TooltipRefs = {
	frame: Frame,
	label: TextLabel,
	richRefs: { [string]: Instance },
}

function TooltipUi.create(gui: Instance, deps): TooltipRefs
	local UiTheme = deps.UiTheme

	local tooltipFrame = Instance.new('Frame')
	tooltipFrame.Name = 'TooltipFrame'
	tooltipFrame.Size = UDim2.fromOffset(316, 92)
	tooltipFrame.BackgroundColor3 = Color3.fromRGB(242, 246, 252)
	tooltipFrame.BackgroundTransparency = 0.08
	tooltipFrame.BorderSizePixel = 0
	tooltipFrame.Visible = false
	tooltipFrame.ZIndex = 50
	tooltipFrame.Parent = gui
	UiTheme.styleWindow(tooltipFrame, UiTheme.palette.gold, Color3.fromRGB(242, 246, 252))

	local tooltipLabel = Instance.new('TextLabel')
	tooltipLabel.Name = 'TooltipLabel'
	tooltipLabel.Size = UDim2.new(1, -16, 1, -14)
	tooltipLabel.Position = UDim2.fromOffset(8, 7)
	tooltipLabel.BackgroundTransparency = 1
	tooltipLabel.Font = Enum.Font.Arial
	tooltipLabel.TextSize = 10
	tooltipLabel.TextWrapped = true
	tooltipLabel.TextColor3 = UiTheme.palette.text
	tooltipLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipLabel.TextYAlignment = Enum.TextYAlignment.Top
	tooltipLabel.ZIndex = 51
	tooltipLabel.Parent = tooltipFrame

	local tooltipRichRefs = {}

	tooltipRichRefs.iconFrame = Instance.new('Frame')
	tooltipRichRefs.iconFrame.Name = 'TooltipIconFrame'
	tooltipRichRefs.iconFrame.Size = UDim2.fromOffset(84, 84)
	tooltipRichRefs.iconFrame.Position = UDim2.fromOffset(14, 16)
	tooltipRichRefs.iconFrame.BackgroundTransparency = 0
	tooltipRichRefs.iconFrame.Visible = false
	tooltipRichRefs.iconFrame.ZIndex = 51
	tooltipRichRefs.iconFrame.Parent = tooltipFrame
	UiTheme.styleSection(tooltipRichRefs.iconFrame, UiTheme.palette.gold, Color3.fromRGB(246, 249, 253))

	tooltipRichRefs.iconImage = Instance.new('ImageLabel')
	tooltipRichRefs.iconImage.Name = 'TooltipIconImage'
	tooltipRichRefs.iconImage.Size = UDim2.new(1, -10, 1, -10)
	tooltipRichRefs.iconImage.Position = UDim2.fromOffset(5, 5)
	tooltipRichRefs.iconImage.BackgroundTransparency = 1
	tooltipRichRefs.iconImage.ScaleType = Enum.ScaleType.Fit
	tooltipRichRefs.iconImage.Visible = false
	tooltipRichRefs.iconImage.ZIndex = 52
	tooltipRichRefs.iconImage.Parent = tooltipRichRefs.iconFrame

	tooltipRichRefs.iconLabel = Instance.new('TextLabel')
	tooltipRichRefs.iconLabel.Name = 'TooltipIconLabel'
	tooltipRichRefs.iconLabel.Size = UDim2.new(1, -10, 1, -10)
	tooltipRichRefs.iconLabel.Position = UDim2.fromOffset(5, 5)
	tooltipRichRefs.iconLabel.BackgroundTransparency = 1
	tooltipRichRefs.iconLabel.Font = Enum.Font.ArialBold
	tooltipRichRefs.iconLabel.TextSize = 24
	tooltipRichRefs.iconLabel.TextWrapped = true
	tooltipRichRefs.iconLabel.TextColor3 = UiTheme.palette.text
	tooltipRichRefs.iconLabel.Visible = false
	tooltipRichRefs.iconLabel.ZIndex = 52
	tooltipRichRefs.iconLabel.Parent = tooltipRichRefs.iconFrame

	tooltipRichRefs.titleLabel = Instance.new('TextLabel')
	tooltipRichRefs.titleLabel.Name = 'TooltipTitleLabel'
	tooltipRichRefs.titleLabel.Size = UDim2.new(1, -126, 0, 22)
	tooltipRichRefs.titleLabel.Position = UDim2.fromOffset(112, 16)
	tooltipRichRefs.titleLabel.BackgroundTransparency = 1
	tooltipRichRefs.titleLabel.Font = Enum.Font.ArialBold
	tooltipRichRefs.titleLabel.TextSize = 12
	tooltipRichRefs.titleLabel.TextColor3 = UiTheme.palette.text
	tooltipRichRefs.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipRichRefs.titleLabel.Visible = false
	tooltipRichRefs.titleLabel.ZIndex = 52
	tooltipRichRefs.titleLabel.Parent = tooltipFrame

	tooltipRichRefs.subtitleLabel = Instance.new('TextLabel')
	tooltipRichRefs.subtitleLabel.Name = 'TooltipSubtitleLabel'
	tooltipRichRefs.subtitleLabel.Size = UDim2.new(1, -126, 0, 18)
	tooltipRichRefs.subtitleLabel.Position = UDim2.fromOffset(112, 38)
	tooltipRichRefs.subtitleLabel.BackgroundTransparency = 1
	tooltipRichRefs.subtitleLabel.Font = Enum.Font.ArialBold
	tooltipRichRefs.subtitleLabel.TextSize = 9
	tooltipRichRefs.subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipRichRefs.subtitleLabel.Visible = false
	tooltipRichRefs.subtitleLabel.ZIndex = 52
	tooltipRichRefs.subtitleLabel.Parent = tooltipFrame

	tooltipRichRefs.bodyLabel = Instance.new('TextLabel')
	tooltipRichRefs.bodyLabel.Name = 'TooltipBodyLabel'
	tooltipRichRefs.bodyLabel.Size = UDim2.new(1, -126, 1, -68)
	tooltipRichRefs.bodyLabel.Position = UDim2.fromOffset(112, 58)
	tooltipRichRefs.bodyLabel.BackgroundTransparency = 1
	tooltipRichRefs.bodyLabel.Font = Enum.Font.Arial
	tooltipRichRefs.bodyLabel.TextSize = 9
	tooltipRichRefs.bodyLabel.TextColor3 = UiTheme.palette.text
	tooltipRichRefs.bodyLabel.TextWrapped = true
	tooltipRichRefs.bodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	tooltipRichRefs.bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
	tooltipRichRefs.bodyLabel.Visible = false
	tooltipRichRefs.bodyLabel.ZIndex = 52
	tooltipRichRefs.bodyLabel.Parent = tooltipFrame

	return {
		frame = tooltipFrame,
		label = tooltipLabel,
		richRefs = tooltipRichRefs,
	}
end

function TooltipUi.show(refs: TooltipRefs, deps, content)
	local UiTheme = deps.UiTheme
	local tooltipFrame = refs.frame
	local tooltipLabel = refs.label
	local tooltipRichRefs = refs.richRefs

	if type(content) == 'table' then
		local accentColor = content.accentColor or UiTheme.palette.gold
		UiTheme.styleWindow(tooltipFrame, accentColor, Color3.fromRGB(20, 25, 35))
		tooltipFrame.Size = UDim2.fromOffset(368, 176)
		tooltipLabel.Visible = false

		if tooltipRichRefs.titleLabel then
			(tooltipRichRefs.titleLabel :: TextLabel).Visible = true
			(tooltipRichRefs.titleLabel :: TextLabel).Text = content.title or 'Unknown Item'
		end
		if tooltipRichRefs.subtitleLabel then
			(tooltipRichRefs.subtitleLabel :: TextLabel).Visible = true
			(tooltipRichRefs.subtitleLabel :: TextLabel).Text = content.subtitle or ''
			(tooltipRichRefs.subtitleLabel :: TextLabel).TextColor3 = accentColor
		end
		if tooltipRichRefs.bodyLabel then
			(tooltipRichRefs.bodyLabel :: TextLabel).Visible = true
			(tooltipRichRefs.bodyLabel :: TextLabel).Text = content.body or ''
		end
		if tooltipRichRefs.iconFrame and tooltipRichRefs.iconLabel and tooltipRichRefs.iconImage then
			(tooltipRichRefs.iconFrame :: Frame).Visible = true
			UiTheme.styleSection(tooltipRichRefs.iconFrame :: Frame, accentColor, (content.iconBackgroundColor or accentColor):Lerp(Color3.fromRGB(22, 26, 34), 0.52))
			local hasImage = type(content.image) == 'string' and content.image ~= ''
			(tooltipRichRefs.iconImage :: ImageLabel).Visible = hasImage
			(tooltipRichRefs.iconImage :: ImageLabel).Image = if hasImage then content.image else ''
			(tooltipRichRefs.iconLabel :: TextLabel).Visible = not hasImage
			(tooltipRichRefs.iconLabel :: TextLabel).Text = content.iconText or '?'
			(tooltipRichRefs.iconLabel :: TextLabel).TextColor3 = content.iconTextColor or UiTheme.palette.parchment
		end

		tooltipFrame.Visible = true
		return
	end

	if not content or content == '' then
		return
	end

	UiTheme.styleWindow(tooltipFrame, UiTheme.palette.gold, Color3.fromRGB(20, 25, 35))
	tooltipFrame.Size = UDim2.fromOffset(316, 92)
	tooltipLabel.Text = content
	tooltipLabel.Visible = true
	if tooltipRichRefs.titleLabel then
		(tooltipRichRefs.titleLabel :: TextLabel).Visible = false
	end
	if tooltipRichRefs.subtitleLabel then
		(tooltipRichRefs.subtitleLabel :: TextLabel).Visible = false
	end
	if tooltipRichRefs.bodyLabel then
		(tooltipRichRefs.bodyLabel :: TextLabel).Visible = false
	end
	if tooltipRichRefs.iconFrame then
		(tooltipRichRefs.iconFrame :: Frame).Visible = false
	end
	tooltipFrame.Visible = true
end

function TooltipUi.hide(refs: TooltipRefs)
	refs.frame.Visible = false
end

function TooltipUi.attach(guiObject: GuiObject, getText, showFn, hideFn)
	guiObject.MouseEnter:Connect(function()
		local text = getText()
		if text and text ~= '' then
			showFn(text)
		end
	end)

	guiObject.MouseLeave:Connect(function()
		hideFn()
	end)
end

return TooltipUi
