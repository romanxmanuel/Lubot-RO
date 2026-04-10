--!strict

local Debris = game:GetService('Debris')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local SoundService = game:GetService('SoundService')
local TweenService = game:GetService('TweenService')

local ItemDefs = require(ReplicatedStorage.Shared.DataDefs.Items.ItemDefs)
local CombatAudioConfig = require(ReplicatedStorage.Shared.Config.CombatAudioConfig)
local UiDragUtil = require(script.Parent.UiDragUtil)
local UiTheme = require(script.Parent.UiTheme)

local ShopController = {}

local panel = nil
local listFrame = nil
local summaryLabel = nil
local merchantLabel = nil
local currentShopPayload = nil
local currentState = nil
local context = nil
local displayedZeny = nil
local zenyToken = 0
local activeSummaryTween = nil

local SHOP_ACCENT = UiTheme.palette.gold
local SUMMARY_DEFAULT_COLOR = UiTheme.palette.parchment

local function playSellSound()
    local soundConfig = CombatAudioConfig.uiSounds and CombatAudioConfig.uiSounds.sell_confirm
    if not soundConfig or not soundConfig.soundId or soundConfig.soundId == '' then
        return
    end

    local sound = Instance.new('Sound')
    sound.Name = 'SellConfirmSound'
    sound.SoundId = soundConfig.soundId
    sound.Volume = soundConfig.volume or 0.82
    sound.PlaybackSpeed = soundConfig.playbackSpeed or 1
    sound.Parent = SoundService
    sound:Play()
    Debris:AddItem(sound, 3)
end

local function setSummaryText(zenyValue)
    if summaryLabel then
        summaryLabel.Text = string.format('Zeny %d', math.floor(zenyValue))
    end
end

local function pulseSummaryGlow()
    if not summaryLabel then
        return
    end

    if activeSummaryTween then
        activeSummaryTween:Cancel()
        activeSummaryTween = nil
    end

    summaryLabel.TextColor3 = Color3.fromRGB(255, 229, 138)
    local tween = TweenService:Create(
        summaryLabel,
        TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { TextColor3 = SUMMARY_DEFAULT_COLOR }
    )
    activeSummaryTween = tween
    tween:Play()
    tween.Completed:Connect(function()
        if activeSummaryTween == tween then
            activeSummaryTween = nil
        end
    end)
end

local function animateSummaryZeny(targetZeny)
    zenyToken += 1
    local token = zenyToken
    local startZeny = displayedZeny or targetZeny
    local delta = targetZeny - startZeny
    local steps = math.clamp(math.abs(delta), 8, 22)

    task.spawn(function()
        for step = 1, steps do
            if token ~= zenyToken then
                return
            end
            local alpha = step / steps
            local value = math.floor(startZeny + (delta * alpha) + 0.5)
            setSummaryText(value)
            task.wait(0.03)
        end

        if token ~= zenyToken then
            return
        end
        displayedZeny = targetZeny
        setSummaryText(targetZeny)
        pulseSummaryGlow()
    end)
end

local function clearChildren(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA('GuiObject') then
            child:Destroy()
        end
    end
end

local function getItemDef(itemId)
    return ItemDefs[itemId]
end

local function addSectionHeader(parent, text, positionY, accentColor)
    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(1, -20, 0, 20)
    label.Position = UDim2.fromOffset(10, positionY)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Garamond
    label.TextSize = 18
    label.TextColor3 = accentColor or UiTheme.palette.parchment
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = parent
end

local function render()
    if not panel or not listFrame or not currentShopPayload or not currentState then
        return
    end

    clearChildren(listFrame)
    local y = 10

    local targetZeny = currentState.profile.zeny or 0
    if displayedZeny == nil then
        displayedZeny = targetZeny
        setSummaryText(targetZeny)
    elseif targetZeny > displayedZeny then
        animateSummaryZeny(targetZeny)
    else
        displayedZeny = targetZeny
        setSummaryText(targetZeny)
        if activeSummaryTween then
            activeSummaryTween:Cancel()
            activeSummaryTween = nil
        end
        if summaryLabel then
            summaryLabel.TextColor3 = SUMMARY_DEFAULT_COLOR
        end
    end
    if merchantLabel then
        merchantLabel.Text = 'Buy provisions, then cash out monster loot on the way home.'
    end

    addSectionHeader(listFrame, 'Buy Stock', y, UiTheme.palette.parchment)
    y += 24

    for _, entry in ipairs(currentShopPayload.buyItems or {}) do
        local row = Instance.new('Frame')
        row.Size = UDim2.new(1, -20, 0, 52)
        row.Position = UDim2.fromOffset(10, y)
        row.Parent = listFrame
        UiTheme.styleSection(row, SHOP_ACCENT, Color3.fromRGB(46, 37, 20))

        local nameLabel = Instance.new('TextLabel')
        nameLabel.Size = UDim2.new(1, -102, 0, 18)
        nameLabel.Position = UDim2.fromOffset(12, 10)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 11
        nameLabel.TextColor3 = UiTheme.palette.text
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Text = entry.name
        nameLabel.Parent = row

        local detailLabel = Instance.new('TextLabel')
        detailLabel.Size = UDim2.new(1, -102, 0, 12)
        detailLabel.Position = UDim2.fromOffset(12, 28)
        detailLabel.BackgroundTransparency = 1
        detailLabel.Font = Enum.Font.Gotham
        detailLabel.TextSize = 9
        detailLabel.TextColor3 = UiTheme.palette.textMuted
        detailLabel.TextXAlignment = Enum.TextXAlignment.Left
        detailLabel.Text = string.format('Buy for %d zeny', entry.buyPrice)
        detailLabel.Parent = row

        local button = Instance.new('TextButton')
        button.Size = UDim2.fromOffset(72, 24)
        button.Position = UDim2.new(1, -84, 0.5, -12)
        button.Text = 'Buy 1'
        button.Parent = row
        UiTheme.styleButton(button, 'gold')
        button.MouseButton1Click:Connect(function()
            context.requestAction(context.gameplayNetDefs.Actions.BuyShopItem, {
                itemId = entry.itemId,
                amount = 1,
            })
        end)

        y += 60
    end

    addSectionHeader(listFrame, 'Sell Loot', y, UiTheme.palette.jade)
    y += 24

    local sellEntries = {}
    for itemId, amount in pairs(currentState.profile.inventory or {}) do
        local itemDef = getItemDef(itemId)
        if itemDef and (itemDef.sellPrice or 0) > 0 then
            table.insert(sellEntries, {
                itemId = itemId,
                amount = amount,
                itemDef = itemDef,
            })
        end
    end
    table.sort(sellEntries, function(left, right)
        return left.itemDef.name < right.itemDef.name
    end)

    if #sellEntries == 0 then
        local emptySell = Instance.new('TextLabel')
        emptySell.Size = UDim2.new(1, -20, 0, 30)
        emptySell.Position = UDim2.fromOffset(10, y)
        emptySell.BackgroundTransparency = 1
        emptySell.Font = Enum.Font.Gotham
        emptySell.TextSize = 10
        emptySell.TextColor3 = UiTheme.palette.textMuted
        emptySell.TextWrapped = true
        emptySell.TextXAlignment = Enum.TextXAlignment.Left
        emptySell.Text = 'Your bag is clean right now. Farm a little more before cashing out.'
        emptySell.Parent = listFrame
        y += 36
    else
        for _, entry in ipairs(sellEntries) do
            local row = Instance.new('Frame')
            row.Size = UDim2.new(1, -20, 0, 60)
            row.Position = UDim2.fromOffset(10, y)
            row.Parent = listFrame
            UiTheme.styleSection(row, UiTheme.palette.jade, Color3.fromRGB(23, 41, 32))

            local nameLabel = Instance.new('TextLabel')
            nameLabel.Size = UDim2.new(1, -158, 0, 18)
            nameLabel.Position = UDim2.fromOffset(12, 10)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Font = Enum.Font.GothamSemibold
            nameLabel.TextSize = 11
            nameLabel.TextColor3 = UiTheme.palette.text
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Text = string.format('%s x%d', entry.itemDef.name, entry.amount)
            nameLabel.Parent = row

            local detailLabel = Instance.new('TextLabel')
            detailLabel.Size = UDim2.new(1, -158, 0, 12)
            detailLabel.Position = UDim2.fromOffset(12, 28)
            detailLabel.BackgroundTransparency = 1
            detailLabel.Font = Enum.Font.Gotham
            detailLabel.TextSize = 9
            detailLabel.TextColor3 = UiTheme.palette.textMuted
            detailLabel.TextXAlignment = Enum.TextXAlignment.Left
            detailLabel.Text = string.format('Sell for %d zeny each', entry.itemDef.sellPrice or 0)
            detailLabel.Parent = row

            local sellOneButton = Instance.new('TextButton')
            sellOneButton.Size = UDim2.fromOffset(64, 22)
            sellOneButton.Position = UDim2.new(1, -142, 0.5, -11)
            sellOneButton.Text = 'Sell 1'
            sellOneButton.Parent = row
            UiTheme.styleButton(sellOneButton, 'success')
            sellOneButton.MouseButton1Click:Connect(function()
                playSellSound()
                context.requestAction(context.gameplayNetDefs.Actions.SellInventoryItem, {
                    itemId = entry.itemId,
                    amount = 1,
                })
            end)

            local sellAllButton = Instance.new('TextButton')
            sellAllButton.Size = UDim2.fromOffset(64, 22)
            sellAllButton.Position = UDim2.new(1, -72, 0.5, -11)
            sellAllButton.Text = 'Sell All'
            sellAllButton.Parent = row
            UiTheme.styleButton(sellAllButton, 'gold')
            sellAllButton.MouseButton1Click:Connect(function()
                playSellSound()
                context.requestAction(context.gameplayNetDefs.Actions.SellInventoryItem, {
                    itemId = entry.itemId,
                    amount = entry.amount,
                })
            end)

            y += 68
        end
    end

    listFrame.CanvasSize = UDim2.new(0, 0, 0, y + 8)
end

function ShopController.bind(gui, bindContext)
    context = bindContext

    panel = Instance.new('Frame')
    panel.Name = 'ShopWindow'
    panel.Size = UDim2.fromOffset(382, 454)
    panel.Position = UDim2.new(1, -394, 0, 104)
    panel.Visible = false
    panel.Parent = gui
    UiTheme.styleWindow(panel, SHOP_ACCENT, Color3.fromRGB(22, 28, 36))

    local title = Instance.new('TextLabel')
    title.Name = 'TitleLabel'
    title.Size = UDim2.fromOffset(250, 28)
    title.Position = UDim2.fromOffset(18, 12)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.Garamond
    title.TextSize = 22
    title.TextColor3 = UiTheme.palette.parchment
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = 'Baazar Merchant'
    title.Parent = panel

    UiDragUtil.makeDraggable(panel, title)
    UiDragUtil.makeResizable(panel, Vector2.new(382, 454), Vector2.new(460, 600))

    local closeButton = Instance.new('TextButton')
    closeButton.Size = UDim2.fromOffset(28, 28)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.Text = 'X'
    closeButton.Parent = panel
    UiTheme.styleButton(closeButton, 'danger')
    closeButton.MouseButton1Click:Connect(function()
        panel.Visible = false
    end)

    local summaryCard = Instance.new('Frame')
    summaryCard.Size = UDim2.new(1, -32, 0, 70)
    summaryCard.Position = UDim2.fromOffset(16, 66)
    summaryCard.Parent = panel
    UiTheme.styleSection(summaryCard, SHOP_ACCENT, Color3.fromRGB(45, 37, 20))

    summaryLabel = Instance.new('TextLabel')
    summaryLabel.Name = 'SummaryLabel'
    summaryLabel.Size = UDim2.new(1, -24, 0, 18)
    summaryLabel.Position = UDim2.fromOffset(12, 10)
    summaryLabel.BackgroundTransparency = 1
    summaryLabel.Font = Enum.Font.Garamond
    summaryLabel.TextSize = 18
    summaryLabel.TextColor3 = UiTheme.palette.parchment
    summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
    summaryLabel.Parent = summaryCard

    merchantLabel = Instance.new('TextLabel')
    merchantLabel.Size = UDim2.new(1, -24, 0, 28)
    merchantLabel.Position = UDim2.fromOffset(12, 30)
    merchantLabel.BackgroundTransparency = 1
    merchantLabel.Font = Enum.Font.Gotham
    merchantLabel.TextSize = 10
    merchantLabel.TextColor3 = UiTheme.palette.textMuted
    merchantLabel.TextWrapped = true
    merchantLabel.TextXAlignment = Enum.TextXAlignment.Left
    merchantLabel.TextYAlignment = Enum.TextYAlignment.Top
    merchantLabel.Parent = summaryCard

    listFrame = Instance.new('ScrollingFrame')
    listFrame.Size = UDim2.new(1, -32, 1, -154)
    listFrame.Position = UDim2.fromOffset(16, 146)
    listFrame.ScrollBarThickness = 6
    listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    listFrame.Parent = panel
    UiTheme.styleScrollFrame(listFrame, SHOP_ACCENT, Color3.fromRGB(14, 18, 24))
end

function ShopController.open(shopPayload)
    currentShopPayload = shopPayload
    if panel then
        panel.Visible = true
    end
    render()
end

function ShopController.close()
    if panel then
        panel.Visible = false
    end
end

function ShopController.renderState(state)
    currentState = state
    render()
end

return ShopController
