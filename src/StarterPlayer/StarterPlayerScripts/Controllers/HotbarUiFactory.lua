--!strict

local HotbarUiFactory = {}

type SlotInfo = {
    index: number,
    displayKey: string,
}

type Dependencies = {
    palette: {
        parchment: Color3,
        text: Color3,
        textMuted: Color3,
        edge: Color3,
        gold: Color3,
        azure: Color3,
    },
    styleSlot: (guiObject: GuiObject, accentColor: Color3?, baseColor: Color3?) -> (),
    getSelectedSkillId: () -> string?,
    canAssignSkill: () -> boolean,
    assignSkill: (visibleSlotIndex: number) -> (),
    triggerSlot: (visibleSlotIndex: number) -> (),
    registerSlot: (visibleSlotIndex: number, slotButton: TextButton) -> (),
}

local function createCooldownOverlay(background: Instance)
    local cooldownOverlay = Instance.new('Frame')
    cooldownOverlay.Name = 'CooldownOverlay'
    cooldownOverlay.Size = UDim2.fromScale(1, 1)
    cooldownOverlay.BackgroundColor3 = Color3.fromRGB(32, 47, 78)
    cooldownOverlay.BackgroundTransparency = 0.28
    cooldownOverlay.BorderSizePixel = 0
    cooldownOverlay.Visible = false
    cooldownOverlay.ZIndex = 4
    cooldownOverlay.Parent = background

    local cooldownLabel = Instance.new('TextLabel')
    cooldownLabel.Name = 'CooldownLabel'
    cooldownLabel.Size = UDim2.fromScale(1, 1)
    cooldownLabel.BackgroundTransparency = 1
    cooldownLabel.Font = Enum.Font.ArialBold
    cooldownLabel.TextSize = 16
    cooldownLabel.TextColor3 = Color3.fromRGB(250, 252, 255)
    cooldownLabel.TextStrokeColor3 = Color3.fromRGB(45, 61, 99)
    cooldownLabel.TextStrokeTransparency = 0.3
    cooldownLabel.ZIndex = 5
    cooldownLabel.Parent = cooldownOverlay
end

local function createMetaLabels(background: Instance, slotInfo: SlotInfo, deps: Dependencies)
    local keyLabel = Instance.new('TextLabel')
    keyLabel.Name = 'KeyLabel'
    keyLabel.Size = UDim2.fromOffset(14, 12)
    keyLabel.Position = UDim2.fromOffset(3, 2)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Font = Enum.Font.ArialBold
    keyLabel.TextSize = 9
    keyLabel.TextColor3 = Color3.fromRGB(74, 84, 118)
    keyLabel.TextXAlignment = Enum.TextXAlignment.Left
    keyLabel.ZIndex = 3
    keyLabel.Text = slotInfo.displayKey
    keyLabel.Parent = background

    local bindLabel = Instance.new('TextLabel')
    bindLabel.Name = 'BindLabel'
    bindLabel.Size = UDim2.new(1, -18, 0, 10)
    bindLabel.Position = UDim2.fromOffset(18, 2)
    bindLabel.BackgroundTransparency = 1
    bindLabel.Font = Enum.Font.Arial
    bindLabel.TextSize = 8
    bindLabel.TextColor3 = deps.palette.textMuted
    bindLabel.TextXAlignment = Enum.TextXAlignment.Left
    bindLabel.TextTruncate = Enum.TextTruncate.AtEnd
    bindLabel.ZIndex = 3
    bindLabel.Text = 'Empty'
    bindLabel.Parent = background

    local kindLabel = Instance.new('TextLabel')
    kindLabel.Name = 'KindLabel'
    kindLabel.Size = UDim2.fromOffset(20, 10)
    kindLabel.Position = UDim2.new(1, -23, 0, 2)
    kindLabel.BackgroundTransparency = 1
    kindLabel.Font = Enum.Font.ArialBold
    kindLabel.TextSize = 7
    kindLabel.TextColor3 = Color3.fromRGB(97, 108, 136)
    kindLabel.TextXAlignment = Enum.TextXAlignment.Right
    kindLabel.Text = ''
    kindLabel.ZIndex = 3
    kindLabel.Parent = background
end

local function createNameLabel(background: Instance, deps: Dependencies)
    local nameLabel = Instance.new('TextLabel')
    nameLabel.Name = 'NameLabel'
    nameLabel.Size = UDim2.new(1, -6, 0, 13)
    nameLabel.Position = UDim2.new(0, 3, 1, -16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.Arial
    nameLabel.TextSize = 8
    nameLabel.TextWrapped = true
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextColor3 = deps.palette.textMuted
    nameLabel.ZIndex = 3
    nameLabel.Text = ''
    nameLabel.Parent = background
end

local function createIconFrame(background: Instance, deps: Dependencies)
    local iconFrame = Instance.new('Frame')
    iconFrame.Name = 'IconFrame'
    iconFrame.Size = UDim2.fromOffset(26, 26)
    iconFrame.Position = UDim2.fromOffset(7, 14)
    iconFrame.BackgroundColor3 = Color3.fromRGB(252, 253, 255)
    iconFrame.BorderSizePixel = 0
    iconFrame.Visible = false
    iconFrame.ZIndex = 2
    iconFrame.Parent = background
    deps.styleSlot(iconFrame, deps.palette.edge, Color3.fromRGB(246, 249, 255))

    local iconImage = Instance.new('ImageLabel')
    iconImage.Name = 'IconImage'
    iconImage.Size = UDim2.new(1, -4, 1, -4)
    iconImage.Position = UDim2.fromOffset(2, 2)
    iconImage.BackgroundTransparency = 1
    iconImage.ScaleType = Enum.ScaleType.Fit
    iconImage.Visible = false
    iconImage.ZIndex = 3
    iconImage.Parent = iconFrame

    local iconFallback = Instance.new('TextLabel')
    iconFallback.Name = 'IconFallback'
    iconFallback.Size = UDim2.new(1, -4, 1, -4)
    iconFallback.Position = UDim2.fromOffset(2, 2)
    iconFallback.BackgroundTransparency = 1
    iconFallback.Font = Enum.Font.ArialBold
    iconFallback.TextSize = 10
    iconFallback.TextColor3 = deps.palette.text
    iconFallback.TextScaled = true
    iconFallback.Text = ''
    iconFallback.Visible = false
    iconFallback.ZIndex = 3
    iconFallback.Parent = iconFrame
end

function HotbarUiFactory.createSlotButton(slotsFrame: Instance, slotInfo: SlotInfo, deps: Dependencies)
    local slotButton = Instance.new('TextButton')
    slotButton.Name = 'Slot' .. tostring(slotInfo.index)
    slotButton.LayoutOrder = slotInfo.index
    slotButton.Size = UDim2.fromOffset(42, 56)
    slotButton.BackgroundTransparency = 1
    slotButton.Text = ''
    slotButton.Parent = slotsFrame

    local background = Instance.new('Frame')
    background.Name = 'Background'
    background.Size = UDim2.new(1, 0, 0, 42)
    background.Position = UDim2.fromOffset(0, 0)
    background.BorderSizePixel = 0
    background.Parent = slotButton
    deps.styleSlot(background, deps.palette.edge, Color3.fromRGB(236, 241, 250))

    createCooldownOverlay(background)
    createMetaLabels(background, slotInfo, deps)
    createNameLabel(slotButton, deps)
    createIconFrame(background, deps)

    slotButton.MouseButton1Click:Connect(function()
        if deps.canAssignSkill() and deps.getSelectedSkillId() then
            deps.assignSkill(slotInfo.index)
            return
        end

        deps.triggerSlot(slotInfo.index)
    end)

    deps.registerSlot(slotInfo.index, slotButton)
    return slotButton
end

return HotbarUiFactory
