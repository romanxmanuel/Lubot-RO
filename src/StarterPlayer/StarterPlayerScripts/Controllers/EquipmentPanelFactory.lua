--!strict

local EquipmentPanelFactory = {}
local DOUBLE_CLICK_WINDOW = 0.35

function EquipmentPanelFactory.render(deps)
    local panels = deps.panels
    local state = deps.state
    local equipmentFrame = panels.equipment
    if not equipmentFrame or not state then
        return
    end

    panels._equipmentDropZones = {}
    panels._equipmentCardDropZones = {}

    deps.clearUiChildren(equipmentFrame, {
        EquipmentTitle = true,
        EquipmentSubtitle = true,
        CloseButton = true,
        ResizeHandle = true,
    })

    local equipmentDefs = require(deps.ReplicatedStorage.Shared.DataDefs.Items.EquipmentDefs)
    local cardDefs = require(deps.ReplicatedStorage.Shared.DataDefs.Cards.CardDefs)

    local summaryCard = Instance.new('Frame')
    summaryCard.Size = UDim2.new(1, -28, 0, 62)
    summaryCard.Position = UDim2.fromOffset(14, 56)
    summaryCard.Parent = equipmentFrame
    deps.styleCard(summaryCard, Color3.fromRGB(241, 245, 251), deps.UI_ACCENTS.equipment)

    local equippedCount = 0
    for _, equippedInstanceId in pairs(state.profile and state.profile.equipment or {}) do
        if equippedInstanceId then
            equippedCount += 1
        end
    end

    local summaryTitle = Instance.new('TextLabel')
    summaryTitle.Size = UDim2.new(1, -24, 0, 18)
    summaryTitle.Position = UDim2.fromOffset(12, 10)
    summaryTitle.BackgroundTransparency = 1
    summaryTitle.Font = Enum.Font.ArialBold
    summaryTitle.TextSize = 12
    summaryTitle.TextColor3 = deps.UiTheme.palette.text
    summaryTitle.TextXAlignment = Enum.TextXAlignment.Left
    summaryTitle.Text = string.format('Equipped slots %d / 10', equippedCount)
    summaryTitle.Parent = summaryCard

    local summaryBody = Instance.new('TextLabel')
    summaryBody.Size = UDim2.new(1, -24, 0, 14)
    summaryBody.Position = UDim2.fromOffset(12, 32)
    summaryBody.BackgroundTransparency = 1
    summaryBody.Font = Enum.Font.Arial
    summaryBody.TextSize = 8
    summaryBody.TextColor3 = deps.UiTheme.palette.textMuted
    summaryBody.TextXAlignment = Enum.TextXAlignment.Left
    summaryBody.Text = 'Drag armor and weapons onto matching slots. Drag cards onto equipped gear with open sockets.'
    summaryBody.Parent = summaryCard

    local paperDoll = Instance.new('Frame')
    paperDoll.Name = 'PaperDoll'
    paperDoll.Size = UDim2.fromOffset(156, 284)
    paperDoll.Position = UDim2.fromOffset(14, 122)
    paperDoll.Parent = equipmentFrame
    deps.styleCard(paperDoll, Color3.fromRGB(244, 247, 252), deps.UI_ACCENTS.equipment)

    local dollTitle = Instance.new('TextLabel')
    dollTitle.Size = UDim2.fromOffset(116, 18)
    dollTitle.Position = UDim2.fromOffset(14, 10)
    dollTitle.BackgroundTransparency = 1
    dollTitle.Font = Enum.Font.ArialBold
    dollTitle.TextSize = 11
    dollTitle.TextColor3 = deps.UiTheme.palette.text
    dollTitle.Text = 'Character'
    dollTitle.TextXAlignment = Enum.TextXAlignment.Center
    dollTitle.Parent = paperDoll

    local silhouette = Instance.new('Frame')
    silhouette.Size = UDim2.fromOffset(78, 156)
    silhouette.Position = UDim2.fromOffset(33, 44)
    silhouette.Parent = paperDoll
    deps.styleInset(silhouette, Color3.fromRGB(233, 238, 248), deps.UI_ACCENTS.equipment)

    local silhouetteHead = Instance.new('Frame')
    silhouetteHead.Size = UDim2.fromOffset(42, 42)
    silhouetteHead.Position = UDim2.fromOffset(18, 10)
    silhouetteHead.Parent = silhouette
    deps.UiTheme.stylePill(silhouetteHead, deps.UI_ACCENTS.equipment, Color3.fromRGB(66, 87, 118))

    local silhouetteCore = Instance.new('Frame')
    silhouetteCore.Size = UDim2.fromOffset(46, 82)
    silhouetteCore.Position = UDim2.fromOffset(16, 56)
    silhouetteCore.Parent = silhouette
    deps.styleInset(silhouetteCore, Color3.fromRGB(52, 70, 96), deps.UI_ACCENTS.equipment)

    local silhouetteHint = Instance.new('TextLabel')
    silhouetteHint.Size = UDim2.fromOffset(116, 20)
    silhouetteHint.Position = UDim2.fromOffset(14, 252)
    silhouetteHint.BackgroundTransparency = 1
    silhouetteHint.Font = Enum.Font.Arial
    silhouetteHint.TextSize = 8
    silhouetteHint.TextColor3 = deps.UiTheme.palette.textMuted
    silhouetteHint.TextWrapped = true
    silhouetteHint.TextXAlignment = Enum.TextXAlignment.Center
    silhouetteHint.Text = 'Visual gear reflects your current path.'
    silhouetteHint.Parent = paperDoll

    local slotsFrame = Instance.new('Frame')
    slotsFrame.Name = 'SlotsFrame'
    slotsFrame.Size = UDim2.new(1, -198, 0, 308)
    slotsFrame.Position = UDim2.fromOffset(166, 122)
    slotsFrame.Parent = equipmentFrame
    deps.styleCard(slotsFrame, Color3.fromRGB(244, 247, 252), deps.UI_ACCENTS.equipment)

    local slotsTitle = Instance.new('TextLabel')
    slotsTitle.Size = UDim2.new(1, -24, 0, 18)
    slotsTitle.Position = UDim2.fromOffset(12, 10)
    slotsTitle.BackgroundTransparency = 1
    slotsTitle.Font = Enum.Font.ArialBold
    slotsTitle.TextSize = 11
    slotsTitle.TextColor3 = deps.UiTheme.palette.text
    slotsTitle.TextXAlignment = Enum.TextXAlignment.Left
    slotsTitle.Text = 'Equip Slots'
    slotsTitle.Parent = slotsFrame

    local slotOrder = {
        { key = 'HeadTop', label = 'Upper Headgear' },
        { key = 'HeadMid', label = 'Middle Headgear' },
        { key = 'HeadLow', label = 'Lower Headgear' },
        { key = 'Armor', label = 'Armor' },
        { key = 'Weapon', label = 'Weapon' },
        { key = 'Ammo', label = 'Ammo' },
        { key = 'Shield', label = 'Shield' },
        { key = 'Garment', label = 'Garment' },
        { key = 'Shoes', label = 'Footgear' },
        { key = 'Accessory1', label = 'Accessory 1' },
        { key = 'Accessory2', label = 'Accessory 2' },
    }

    for index, slotInfo in ipairs(slotOrder) do
        local row = Instance.new('Frame')
        row.Size = UDim2.new(1, -16, 0, 22)
        row.Position = UDim2.fromOffset(8, 36 + ((index - 1) * 24))
        row.Parent = slotsFrame
        deps.styleInset(row, Color3.fromRGB(238, 243, 251), deps.UI_ACCENTS.equipment)
        panels._equipmentDropZones[slotInfo.key] = row

        local slotLabel = Instance.new('TextLabel')
        slotLabel.Size = UDim2.fromOffset(96, 22)
        slotLabel.Position = UDim2.fromOffset(8, 0)
        slotLabel.BackgroundTransparency = 1
        slotLabel.Font = Enum.Font.ArialBold
        slotLabel.TextSize = 9
        slotLabel.TextColor3 = Color3.fromRGB(202, 221, 242)
        slotLabel.TextXAlignment = Enum.TextXAlignment.Left
        slotLabel.Text = slotInfo.label
        slotLabel.Parent = row

        local ammoItemId = if slotInfo.key == 'Ammo' and state.profile and state.profile.settings then tostring(state.profile.settings.equippedAmmoItemId or '') else ''
        local equippedInstanceId = if slotInfo.key == 'Ammo' then nil else (state.profile and state.profile.equipment and state.profile.equipment[slotInfo.key] or nil)
        local equippedItem = equippedInstanceId and state.itemInstances and state.itemInstances[equippedInstanceId] or nil
        local equippedItemId = if slotInfo.key == 'Ammo' then (if ammoItemId ~= '' then ammoItemId else nil) else (equippedItem and equippedItem.itemId or nil)
        local equipmentDef = equippedItemId and equipmentDefs[equippedItemId] or nil
        local availableCardSlots = equipmentDef and equipmentDef.cardSlots or 0
        local socketedCards = equippedItem and equippedItem.socketedCards or nil
        local itemText = if slotInfo.key == 'Ammo'
            then (if equippedItemId then string.format('%s x%d', deps.getItemDisplayName(equippedItemId), tonumber((state.profile and state.profile.inventory and state.profile.inventory[equippedItemId]) or 0) or 0) else 'Empty  [Drag]')
            else (equippedItem and string.format('%s +%d', deps.getItemDisplayName(equippedItem.itemId), equippedItem.enhancementLevel or 0) or 'Empty')

        local itemLabel = Instance.new('TextLabel')
        itemLabel.Size = UDim2.new(1, -168, 0, 22)
        itemLabel.Position = UDim2.fromOffset(102, 0)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Font = Enum.Font.Arial
        itemLabel.TextSize = 9
        itemLabel.TextColor3 = equippedItem and deps.UiTheme.palette.parchment or deps.UiTheme.palette.textMuted
        itemLabel.TextXAlignment = Enum.TextXAlignment.Right
        itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
        itemLabel.Text = if slotInfo.key == 'Ammo' then itemText else (itemText .. (equippedItem and '' or '  [Drop]'))
        itemLabel.Parent = row

        if equippedInstanceId and slotInfo.key ~= 'Ammo' then
            local lastClick = 0
            row.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return
                end
                local now = os.clock()
                if now - lastClick <= DOUBLE_CLICK_WINDOW then
                    lastClick = 0
                    if deps.requestAction and deps.GameplayNetDefs then
                        deps.requestAction(deps.GameplayNetDefs.Actions.UnequipItemInstance, {
                            itemInstanceId = equippedInstanceId,
                        })
                    end
                else
                    lastClick = now
                end
            end)
        end

        local socketTray = Instance.new('Frame')
        socketTray.Name = 'SocketTray'
        socketTray.Size = UDim2.fromOffset(52, 18)
        socketTray.Position = UDim2.new(1, -58, 0, 2)
        socketTray.BackgroundTransparency = 1
        socketTray.Parent = row

        if slotInfo.key ~= 'Ammo' and availableCardSlots > 0 then
            for socketIndex = 1, availableCardSlots do
                local socketFrame = Instance.new('Frame')
                socketFrame.Name = string.format('Socket%d', socketIndex)
                socketFrame.Size = UDim2.fromOffset(20, 18)
                socketFrame.Position = UDim2.fromOffset((socketIndex - 1) * 24, 0)
                socketFrame.Parent = socketTray

                local cardId = type(socketedCards) == 'table' and socketedCards[socketIndex] or nil
                local cardDef = cardId and cardDefs[cardId] or nil
                local isOccupied = cardId ~= nil
                if isOccupied then
                    deps.styleInset(socketFrame, Color3.fromRGB(250, 240, 214), deps.UiTheme.palette.gold)
                else
                    deps.styleInset(socketFrame, Color3.fromRGB(242, 246, 252), deps.UI_ACCENTS.equipment)
                end

                local socketText = Instance.new('TextLabel')
                socketText.Size = UDim2.new(1, 0, 1, 0)
                socketText.BackgroundTransparency = 1
                socketText.Font = Enum.Font.GothamBold
                socketText.TextSize = 9
                socketText.TextColor3 = isOccupied and deps.UiTheme.palette.gold or deps.UiTheme.palette.textMuted
                socketText.Text = if isOccupied then deps.buildIconText(cardDef and cardDef.name or deps.humanizeId(cardId)) else '+'
                socketText.Parent = socketFrame

                panels._equipmentCardDropZones[#panels._equipmentCardDropZones + 1] = {
                    gui = socketFrame,
                    slotKey = slotInfo.key,
                    itemInstanceId = equippedInstanceId,
                    slotIndex = socketIndex,
                    occupied = isOccupied,
                }
            end
        elseif slotInfo.key ~= 'Ammo' then
            local noSocketLabel = Instance.new('TextLabel')
            noSocketLabel.Size = UDim2.fromOffset(52, 18)
            noSocketLabel.BackgroundTransparency = 1
                    noSocketLabel.Font = Enum.Font.Arial
            noSocketLabel.TextSize = 8
            noSocketLabel.TextColor3 = deps.UiTheme.palette.textMuted
            noSocketLabel.Text = equippedItem and '--' or ''
            noSocketLabel.Parent = socketTray
        end
    end
end

function EquipmentPanelFactory.create(gui, deps)
    local equipmentFrame = Instance.new('Frame')
    equipmentFrame.Name = 'EquipmentFrame'
    equipmentFrame.Size = UDim2.fromOffset(404, 420)
    equipmentFrame.AnchorPoint = Vector2.new(1, 0)
    equipmentFrame.Position = UDim2.new(1, -12, 0, 320)
    equipmentFrame.Visible = false
    deps.stylePanel(equipmentFrame, Color3.fromRGB(235, 240, 249), deps.UI_ACCENTS.equipment)
    equipmentFrame.Parent = gui

    local equipmentTitle = Instance.new('TextLabel')
    equipmentTitle.Name = 'EquipmentTitle'
    equipmentTitle.Size = UDim2.fromOffset(260, 16)
    equipmentTitle.Position = UDim2.fromOffset(10, 7)
    equipmentTitle.BackgroundTransparency = 1
    equipmentTitle.Font = Enum.Font.ArialBold
    equipmentTitle.TextSize = 12
    equipmentTitle.Text = 'Equipment'
    equipmentTitle.TextColor3 = deps.UiTheme.palette.parchment
    equipmentTitle.TextXAlignment = Enum.TextXAlignment.Left
    equipmentTitle.Parent = equipmentFrame

    local equipmentSubtitle = Instance.new('TextLabel')
    equipmentSubtitle.Name = 'EquipmentSubtitle'
    equipmentSubtitle.Size = UDim2.fromOffset(320, 12)
    equipmentSubtitle.Position = UDim2.fromOffset(10, 23)
    equipmentSubtitle.BackgroundTransparency = 1
    equipmentSubtitle.Font = Enum.Font.Arial
    equipmentSubtitle.TextSize = 9
    equipmentSubtitle.Text = 'Double-click equipped gear to unequip. Drag gear here. Drag cards onto open sockets.'
    equipmentSubtitle.TextColor3 = Color3.fromRGB(221, 232, 255)
    equipmentSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    equipmentSubtitle.Parent = equipmentFrame

    deps.UiDragUtil.makeDraggable(equipmentFrame, equipmentTitle)
    deps.UiDragUtil.makeResizable(equipmentFrame, Vector2.new(404, 420), Vector2.new(520, 560))

    local closeButton = deps.makeCloseButton(equipmentFrame, function()
        equipmentFrame.Visible = false
    end)
    closeButton.Name = 'CloseButton'

    return equipmentFrame
end

return EquipmentPanelFactory
