--!strict

local UserInputService = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local CardDefs = require(ReplicatedStorage.Shared.DataDefs.Cards.CardDefs)
local GameplayNetDefs = require(ReplicatedStorage.Shared.Net.GameplayNetDefs)
local ItemDefs = require(ReplicatedStorage.Shared.DataDefs.Items.ItemDefs)
local LootPresentationConfig = require(ReplicatedStorage.Shared.Config.LootPresentationConfig)
local UiTheme = require(script.Parent.UiTheme)

local InventoryController = {}
local inventoryFrame = nil
local appContext = nil
local currentTab = 'Use'
local scrollPositions = {}
local dragGhost = nil
local dragConnections = {}
local DOUBLE_CLICK_WINDOW = 0.35

local INVENTORY_ACCENT = Color3.fromRGB(124, 146, 200)
local SLOT_SIZE = 58
local SLOT_SPACING = 6
local GRID_COLUMNS = 5

local function getItemDef(itemId)
    return ItemDefs[itemId]
end

local function getCardDef(cardId)
    return CardDefs[cardId]
end

local function getItemDisplayName(itemId)
    local itemDef = getItemDef(itemId)
    return itemDef and itemDef.name or itemId
end

local function getCardDisplayName(cardId)
    local cardDef = getCardDef(cardId)
    return cardDef and cardDef.name or cardId
end

local function getRarityColor(rarity)
    return LootPresentationConfig.getRarityColor(rarity)
end

local function getRarityBaseColor(rarity)
    local accent = LootPresentationConfig.getRarityColor(rarity)
    return accent:Lerp(Color3.fromRGB(252, 253, 255), 0.82)
end

local function buildIconText(name)
    local pieces = {}
    for word in string.gmatch(name or '', '[^%s]+') do
        table.insert(pieces, string.upper(string.sub(word, 1, 1)))
        if #pieces >= 3 then
            break
        end
    end
    return if #pieces > 0 then table.concat(pieces, '') else '?'
end

local function clearChildren(frame)
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA('GuiObject')
            and child.Name ~= 'InventoryTitle'
            and child.Name ~= 'InventorySubtitle'
            and child.Name ~= 'CloseButton'
            and child.Name ~= 'ResizeHandle'
        then
            child:Destroy()
        end
    end
end

local function captureScrollPosition()
    if not inventoryFrame then
        return
    end
    local existing = inventoryFrame:FindFirstChild('InventoryScrollFrame')
    if existing and existing:IsA('ScrollingFrame') then
        scrollPositions[currentTab] = existing.CanvasPosition
    end
end

local function disconnectDragConnections()
    for _, connection in ipairs(dragConnections) do
        connection:Disconnect()
    end
    table.clear(dragConnections)
end

local function clearDrag()
    disconnectDragConnections()
    if dragGhost then
        dragGhost:Destroy()
        dragGhost = nil
    end
end

local function bindTooltip(guiObject, payload)
    if not appContext or not appContext.showTooltip or not payload then
        return
    end
    guiObject.MouseEnter:Connect(function()
        appContext.showTooltip(payload)
    end)
    guiObject.MouseLeave:Connect(function()
        if appContext.hideTooltip then
            appContext.hideTooltip()
        end
    end)
end

local function startDrag(payload, dragText, accentColor)
    if not inventoryFrame or not appContext or not appContext.handleInventoryDrop then
        return
    end

    clearDrag()

    local ghost = Instance.new('Frame')
    ghost.Size = UDim2.fromOffset(136, 42)
    ghost.ZIndex = 60
    ghost.Parent = inventoryFrame.Parent
    UiTheme.styleSection(ghost, accentColor or INVENTORY_ACCENT, Color3.fromRGB(235, 241, 252))

    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(1, -10, 1, -10)
    label.Position = UDim2.fromOffset(5, 5)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.ArialBold
    label.TextSize = 11
    label.TextWrapped = true
    label.TextColor3 = UiTheme.palette.text
    label.Text = dragText
    label.ZIndex = 61
    label.Parent = ghost

    local function updateGhost(position: Vector2)
        ghost.Position = UDim2.fromOffset(math.floor(position.X + 14), math.floor(position.Y + 14))
    end

    updateGhost(UserInputService:GetMouseLocation())
    dragGhost = ghost

    table.insert(dragConnections, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            updateGhost(input.Position)
        end
    end))

    table.insert(dragConnections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        appContext.handleInventoryDrop(payload, input.Position)
        clearDrag()
    end))
end

local function bindDragHandle(guiObject, payload, dragText, accentColor)
    if not appContext or not appContext.handleInventoryDrop then
        return
    end
    guiObject.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            startDrag(payload, dragText, accentColor)
        end
    end)
end

local function createPill(parent, text, position, size, accentColor)
    local pill = Instance.new('TextLabel')
    pill.Size = size
    pill.Position = position
    pill.BackgroundTransparency = 0
    pill.Font = Enum.Font.ArialBold
    pill.TextSize = 9
    pill.TextColor3 = UiTheme.palette.text
    pill.Text = text
    pill.Parent = parent
    UiTheme.stylePill(pill, accentColor, Color3.fromRGB(242, 246, 252))
end

local function createTabButton(parent, label, tabKey, position)
    local selected = currentTab == tabKey
    local button = Instance.new('TextButton')
    button.Size = UDim2.fromOffset(if tabKey == 'Equipment' then 90 else 78, 24)
    button.Position = position
    button.Text = label
    button.Font = Enum.Font.ArialBold
    button.TextSize = 11
    button.TextColor3 = if selected then Color3.fromRGB(28, 41, 73) else UiTheme.palette.text
    button.Parent = parent
    UiTheme.styleButton(button, if selected then 'primary' else 'secondary')
    button.MouseButton1Click:Connect(function()
        captureScrollPosition()
        currentTab = tabKey
        InventoryController.render(appContext and appContext.getState and appContext.getState() or nil)
    end)
end

local function createSectionHeader(parent, title, subtitle, y, accentColor)
    local card = Instance.new('Frame')
    card.Size = UDim2.new(1, -12, 0, 34)
    card.Position = UDim2.fromOffset(6, y)
    card.Parent = parent
    UiTheme.styleSection(card, accentColor, Color3.fromRGB(231, 237, 248))

    local titleLabel = Instance.new('TextLabel')
    titleLabel.Size = UDim2.new(1, -16, 0, 14)
    titleLabel.Position = UDim2.fromOffset(8, 4)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.ArialBold
    titleLabel.TextSize = 11
    titleLabel.TextColor3 = UiTheme.palette.text
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = title
    titleLabel.Parent = card

    local subtitleLabel = Instance.new('TextLabel')
    subtitleLabel.Size = UDim2.new(1, -16, 0, 12)
    subtitleLabel.Position = UDim2.fromOffset(8, 18)
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Font = Enum.Font.Arial
    subtitleLabel.TextSize = 9
    subtitleLabel.TextColor3 = UiTheme.palette.textMuted
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    subtitleLabel.Text = subtitle
    subtitleLabel.Parent = card

    return 40
end

local function createEmptyCard(parent, text, y)
    local card = Instance.new('Frame')
    card.Size = UDim2.new(1, -12, 0, 44)
    card.Position = UDim2.fromOffset(6, y)
    card.Parent = parent
    UiTheme.styleInset(card, INVENTORY_ACCENT, Color3.fromRGB(240, 244, 251))

    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(1, -16, 1, -10)
    label.Position = UDim2.fromOffset(8, 5)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Arial
    label.TextSize = 10
    label.TextColor3 = UiTheme.palette.textMuted
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = text
    label.Parent = card
    return 50
end

local function createTile(parent, entry, position)
    local outer = Instance.new('Frame')
    outer.Size = UDim2.fromOffset(SLOT_SIZE, 76)
    outer.Position = position
    outer.BackgroundTransparency = 1
    outer.Parent = parent

    local slot = Instance.new('TextButton')
    slot.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
    slot.BackgroundTransparency = 0
    slot.Text = ''
    slot.AutoButtonColor = false
    slot.Parent = outer
    UiTheme.styleSlot(slot, entry.accentColor, entry.baseColor)

    local icon = Instance.new('ImageLabel')
    icon.Size = UDim2.new(1, -10, 1, -10)
    icon.Position = UDim2.fromOffset(5, 5)
    icon.BackgroundTransparency = 1
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = entry.image or ''
    icon.Visible = type(entry.image) == 'string' and entry.image ~= ''
    icon.Parent = slot

    local fallback = Instance.new('TextLabel')
    fallback.Size = UDim2.new(1, -8, 1, -8)
    fallback.Position = UDim2.fromOffset(4, 4)
    fallback.BackgroundTransparency = 1
    fallback.Font = Enum.Font.ArialBold
    fallback.TextSize = 16
    fallback.TextScaled = true
    fallback.TextColor3 = UiTheme.palette.text
    fallback.Text = entry.iconText
    fallback.Visible = not icon.Visible
    fallback.Parent = slot

    local qty = Instance.new('TextLabel')
    qty.Size = UDim2.fromOffset(30, 12)
    qty.Position = UDim2.new(1, -32, 1, -14)
    qty.BackgroundTransparency = 0
    qty.Font = Enum.Font.ArialBold
    qty.TextSize = 8
    qty.TextColor3 = UiTheme.palette.text
    qty.Text = entry.countText or ''
    qty.Visible = (entry.countText or '') ~= ''
    qty.Parent = slot
    UiTheme.stylePill(qty, entry.accentColor, Color3.fromRGB(252, 253, 255))

    local tag = Instance.new('TextLabel')
    tag.Size = UDim2.fromOffset(26, 10)
    tag.Position = UDim2.fromOffset(3, 3)
    tag.BackgroundTransparency = 0
    tag.Font = Enum.Font.ArialBold
    tag.TextSize = 7
    tag.TextColor3 = UiTheme.palette.text
    tag.Text = entry.tagText or ''
    tag.Visible = (entry.tagText or '') ~= ''
    tag.Parent = slot
    UiTheme.stylePill(tag, entry.accentColor, Color3.fromRGB(244, 248, 255))

    if entry.allowDrag and entry.dragPayload then
        local dragHandle = Instance.new('TextButton')
        dragHandle.Size = UDim2.fromOffset(14, 14)
        dragHandle.Position = UDim2.new(1, -17, 0, 3)
        dragHandle.Text = '+'
        dragHandle.Font = Enum.Font.ArialBold
        dragHandle.TextSize = 10
        dragHandle.Parent = slot
        UiTheme.styleButton(dragHandle, 'secondary')
        bindDragHandle(dragHandle, entry.dragPayload, entry.dragText or entry.nameText, entry.accentColor)
    end

    local lastPrimaryClick = 0
    slot.MouseButton1Click:Connect(function()
        local now = os.clock()
        if entry.onDoubleClick then
            if now - lastPrimaryClick <= DOUBLE_CLICK_WINDOW then
                lastPrimaryClick = 0
                entry.onDoubleClick()
                return
            end
            lastPrimaryClick = now
            if entry.onActivate then
                entry.onActivate()
            end
            return
        end

        if entry.onActivate then
            entry.onActivate()
        end
    end)

    local nameLabel = Instance.new('TextLabel')
    nameLabel.Size = UDim2.new(1, 0, 0, 16)
    nameLabel.Position = UDim2.fromOffset(0, 60)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.Arial
    nameLabel.TextSize = 8
    nameLabel.TextColor3 = UiTheme.palette.text
    nameLabel.TextWrapped = true
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.Text = entry.nameText
    nameLabel.Parent = outer

    bindTooltip(outer, entry.tooltipPayload)
end

local function renderGrid(parent, entries, y)
    for index, entry in ipairs(entries) do
        local col = (index - 1) % GRID_COLUMNS
        local row = math.floor((index - 1) / GRID_COLUMNS)
        createTile(parent, entry, UDim2.fromOffset(8 + col * (SLOT_SIZE + SLOT_SPACING), y + row * (76 + SLOT_SPACING)))
    end
    local rows = math.max(1, math.ceil(#entries / GRID_COLUMNS))
    return y + rows * (76 + SLOT_SPACING)
end

local function itemTooltip(name, subtitle, description, sourceHint, accentColor, image, iconText)
    return {
        title = name,
        subtitle = subtitle,
        body = string.format('%s\n\nSource: %s', description, sourceHint),
        accentColor = accentColor,
        image = image,
        iconText = iconText,
        iconBackgroundColor = Color3.fromRGB(236, 241, 250),
        iconTextColor = UiTheme.palette.parchment,
    }
end

local function buildEntries(state)
    local entries = { Use = {}, Equipment = {}, Misc = {} }
    local equipment = state.profile.equipment or {}

    for itemId, amount in pairs(state.profile.inventory or {}) do
        local itemDef = getItemDef(itemId)
        if itemDef and itemDef.itemType == 'Consumable' and amount > 0 then
            local rarity = itemDef.rarity or 'Common'
            local isAmmo = table.find(itemDef.tags or {}, 'ammo') ~= nil
            table.insert(entries.Use, {
                nameText = getItemDisplayName(itemId),
                iconText = buildIconText(getItemDisplayName(itemId)),
                image = itemDef.iconAssetId or '',
                countText = tostring(amount),
                tagText = if isAmmo then 'AM' else 'USE',
                accentColor = getRarityColor(rarity),
                baseColor = getRarityBaseColor(rarity),
                allowDrag = true,
                dragPayload = { dragType = 'consumable', itemId = itemId },
                dragText = string.format('Hotbar: %s', getItemDisplayName(itemId)),
                onActivate = function()
                    if not appContext or not appContext.requestAction then return end
                    if isAmmo then
                        appContext.requestAction(GameplayNetDefs.Actions.EquipAmmoItem, { itemId = itemId })
                    else
                        appContext.requestAction(GameplayNetDefs.Actions.UseInventoryItem, { itemId = itemId })
                    end
                end,
                tooltipPayload = itemTooltip(getItemDisplayName(itemId), string.format('Consumable | %s', rarity), itemDef.description or 'Quick-use item.', itemDef.sourceHint or 'Bag item', getRarityColor(rarity), itemDef.iconAssetId or '', buildIconText(getItemDisplayName(itemId))),
            })
        elseif itemDef and itemDef.itemType ~= 'Consumable' then
            local rarity = itemDef.rarity or 'Common'
            table.insert(entries.Misc, {
                nameText = getItemDisplayName(itemId),
                iconText = buildIconText(getItemDisplayName(itemId)),
                image = itemDef.iconAssetId or '',
                countText = tostring(amount),
                tagText = string.upper(string.sub(itemDef.itemType or 'ITM', 1, 3)),
                accentColor = getRarityColor(rarity),
                baseColor = getRarityBaseColor(rarity),
                tooltipPayload = itemTooltip(getItemDisplayName(itemId), string.format('%s | %s', itemDef.itemType or 'Item', rarity), itemDef.description or 'Inventory item.', itemDef.sourceHint or 'Inventory loot', getRarityColor(rarity), itemDef.iconAssetId or '', buildIconText(getItemDisplayName(itemId))),
            })
        end
    end

    for instanceId, item in pairs(state.itemInstances or {}) do
        local slotKey = item.slot or ''
        local itemDef = getItemDef(item.itemId)
        local rarity = item.rarity or (itemDef and itemDef.rarity) or 'Common'
        local isEquipped = equipment[slotKey] == instanceId
        table.insert(entries.Equipment, {
            nameText = getItemDisplayName(item.itemId),
            iconText = buildIconText(getItemDisplayName(item.itemId)),
            image = itemDef and itemDef.iconAssetId or '',
            countText = '+' .. tostring(item.enhancementLevel or 0),
            tagText = isEquipped and 'ON' or string.upper(string.sub(slotKey, 1, 3)),
            accentColor = getRarityColor(rarity),
            baseColor = getRarityBaseColor(rarity),
            allowDrag = not isEquipped,
            dragPayload = if isEquipped then nil else { dragType = 'equipment', itemId = item.itemId, itemInstanceId = instanceId, slotKey = slotKey },
            dragText = string.format('Equip: %s', getItemDisplayName(item.itemId)),
            onDoubleClick = function()
                if not appContext or not appContext.requestAction then
                    return
                end
                if isEquipped then
                    appContext.requestAction(GameplayNetDefs.Actions.UnequipItemInstance, { itemInstanceId = instanceId })
                else
                    appContext.requestAction(GameplayNetDefs.Actions.EquipItemInstance, { itemInstanceId = instanceId })
                end
            end,
            tooltipPayload = itemTooltip(
                string.format('%s +%d', getItemDisplayName(item.itemId), item.enhancementLevel or 0),
                string.format('%s | %s%s', slotKey, rarity, if isEquipped then ' | Equipped' else ''),
                itemDef and itemDef.description or 'Equipment piece.',
                item.sourceHint or (itemDef and itemDef.sourceHint) or 'Inventory gear',
                getRarityColor(rarity),
                itemDef and itemDef.iconAssetId or '',
                buildIconText(getItemDisplayName(item.itemId))
            ),
        })
    end

    for cardId, amount in pairs(state.profile.cards or {}) do
        local cardDef = getCardDef(cardId)
        local rarity = cardDef and cardDef.rarity or 'Legendary'
        table.insert(entries.Misc, 1, {
            nameText = getCardDisplayName(cardId),
            iconText = buildIconText(getCardDisplayName(cardId)),
            image = cardDef and cardDef.iconAssetId or '',
            countText = tostring(amount),
            tagText = 'CRD',
            accentColor = getRarityColor(rarity),
            baseColor = getRarityBaseColor(rarity),
            allowDrag = true,
            dragPayload = { dragType = 'card', cardId = cardId, supportedSlots = cardDef and cardDef.supportedSlots or nil },
            dragText = string.format('Socket: %s', getCardDisplayName(cardId)),
            tooltipPayload = itemTooltip(getCardDisplayName(cardId), string.format('Card | %s', rarity), cardDef and cardDef.description or 'Socketable card.', cardDef and (cardDef.sourceHint or 'Monster drop') or 'Monster drop', getRarityColor(rarity), cardDef and cardDef.iconAssetId or '', buildIconText(getCardDisplayName(cardId))),
        })
    end

    table.sort(entries.Use, function(a, b) return a.nameText < b.nameText end)
    table.sort(entries.Equipment, function(a, b) return a.nameText < b.nameText end)
    table.sort(entries.Misc, function(a, b) return a.nameText < b.nameText end)
    return entries
end

function InventoryController.bind(frame, context)
    inventoryFrame = frame
    appContext = context
end

function InventoryController.render(state)
    if not inventoryFrame then
        return
    end

    state = state or { profile = {}, derivedStats = {}, itemInstances = {} }
    if appContext then
        appContext.getState = function()
            return state
        end
    end

    captureScrollPosition()
    clearChildren(inventoryFrame)
    clearDrag()

    local profile = state.profile or {}
    local derivedStats = state.derivedStats or {}
    local entries = buildEntries(state)
    local equipment = profile.equipment or {}
    local equippedCount = 0
    for _, equippedInstanceId in pairs(equipment) do
        if equippedInstanceId then equippedCount += 1 end
    end

    local summaryCard = Instance.new('Frame')
    summaryCard.Size = UDim2.new(1, -24, 0, 62)
    summaryCard.Position = UDim2.fromOffset(12, 58)
    summaryCard.Parent = inventoryFrame
    UiTheme.styleSection(summaryCard, INVENTORY_ACCENT, Color3.fromRGB(233, 239, 248))

    local zenyLabel = Instance.new('TextLabel')
    zenyLabel.Size = UDim2.fromOffset(156, 16)
    zenyLabel.Position = UDim2.fromOffset(10, 8)
    zenyLabel.BackgroundTransparency = 1
    zenyLabel.Font = Enum.Font.ArialBold
    zenyLabel.TextSize = 13
    zenyLabel.TextColor3 = UiTheme.palette.text
    zenyLabel.TextXAlignment = Enum.TextXAlignment.Left
    zenyLabel.Text = string.format('Zeny %d', profile.zeny or 0)
    zenyLabel.Parent = summaryCard

    local weightLabel = Instance.new('TextLabel')
    weightLabel.Size = UDim2.fromOffset(120, 16)
    weightLabel.Position = UDim2.new(1, -130, 0, 8)
    weightLabel.BackgroundTransparency = 1
    weightLabel.Font = Enum.Font.ArialBold
    weightLabel.TextSize = 10
    weightLabel.TextColor3 = UiTheme.palette.textMuted
    weightLabel.TextXAlignment = Enum.TextXAlignment.Right
    weightLabel.Text = string.format('Weight %d/%d', math.floor(profile.currentWeight or 0), math.floor(derivedStats.carryWeight or 0))
    weightLabel.Parent = summaryCard

    local caption = Instance.new('TextLabel')
    caption.Size = UDim2.new(1, -20, 0, 12)
    caption.Position = UDim2.fromOffset(10, 24)
    caption.BackgroundTransparency = 1
    caption.Font = Enum.Font.Arial
    caption.TextSize = 9
    caption.TextColor3 = UiTheme.palette.textMuted
    caption.TextXAlignment = Enum.TextXAlignment.Left
    caption.Text = 'Classic bag layout. Click to use or equip. Drag with the + handle.'
    caption.Parent = summaryCard

    createPill(summaryCard, string.format('Use %d', #entries.Use), UDim2.fromOffset(10, 40), UDim2.fromOffset(54, 16), UiTheme.palette.azure)
    createPill(summaryCard, string.format('Gear %d', #entries.Equipment), UDim2.fromOffset(68, 40), UDim2.fromOffset(54, 16), Color3.fromRGB(140, 160, 208))
    createPill(summaryCard, string.format('Equipped %d', equippedCount), UDim2.fromOffset(126, 40), UDim2.fromOffset(68, 16), INVENTORY_ACCENT)
    createPill(summaryCard, string.format('Misc %d', #entries.Misc), UDim2.fromOffset(198, 40), UDim2.fromOffset(56, 16), UiTheme.palette.gold)

    local tabsCard = Instance.new('Frame')
    tabsCard.Size = UDim2.new(1, -24, 0, 36)
    tabsCard.Position = UDim2.fromOffset(12, 126)
    tabsCard.Parent = inventoryFrame
    UiTheme.styleSection(tabsCard, INVENTORY_ACCENT, Color3.fromRGB(232, 238, 248))

    createTabButton(tabsCard, 'Use', 'Use', UDim2.fromOffset(8, 5))
    createTabButton(tabsCard, 'Equipment', 'Equipment', UDim2.fromOffset(92, 5))
    createTabButton(tabsCard, 'Misc', 'Misc', UDim2.fromOffset(188, 5))

    local scrollFrame = Instance.new('ScrollingFrame')
    scrollFrame.Name = 'InventoryScrollFrame'
    scrollFrame.Size = UDim2.new(1, -24, 1, -174)
    scrollFrame.Position = UDim2.fromOffset(12, 168)
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.Parent = inventoryFrame
    UiTheme.styleScrollFrame(scrollFrame, INVENTORY_ACCENT, Color3.fromRGB(244, 247, 252))

    local y = 8
    local activeEntries = entries[currentTab] or {}
    local subtitle = if currentTab == 'Use'
        then 'Potions, food, wings, and ammo.'
        elseif currentTab == 'Equipment'
        then 'All owned gear. Double-click to equip or unequip.'
        else 'Cards, materials, and misc loot.'
    y += createSectionHeader(scrollFrame, currentTab, subtitle, y, if currentTab == 'Use' then UiTheme.palette.azure elseif currentTab == 'Equipment' then Color3.fromRGB(140, 160, 208) else UiTheme.palette.gold)

    if #activeEntries == 0 then
        y += createEmptyCard(scrollFrame, 'Nothing here yet.', y)
    else
        y = renderGrid(scrollFrame, activeEntries, y)
    end

    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, y + 8)

    local tabKey = currentTab
    scrollPositions[tabKey] = scrollPositions[tabKey] or Vector2.zero
    task.defer(function()
        if scrollFrame.Parent == nil then
            return
        end
        local stored = scrollPositions[tabKey] or Vector2.zero
        local maxX = math.max(scrollFrame.AbsoluteCanvasSize.X - scrollFrame.AbsoluteWindowSize.X, 0)
        local maxY = math.max(scrollFrame.AbsoluteCanvasSize.Y - scrollFrame.AbsoluteWindowSize.Y, 0)
        scrollFrame.CanvasPosition = Vector2.new(math.clamp(stored.X, 0, maxX), math.clamp(stored.Y, 0, maxY))
    end)
end

return InventoryController
