--!strict

local PartyController = {}
local UiDragUtil = require(script.Parent.UiDragUtil)
local UiTheme = require(script.Parent.UiTheme)

local GameplayNetDefs = nil
local state = nil
local panel = nil
local snapWindow = nil
local memberListFrame = nil
local context = nil
local summaryLabel = nil
local leaderLabel = nil
local inviteButton = nil
local leaveButton = nil

local PARTY_ACCENT = UiTheme.palette.jade

local function clearChildren(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA('GuiObject') then
            child:Destroy()
        end
    end
end

function PartyController.bind(gui, bindContext)
    context = bindContext
    GameplayNetDefs = bindContext.gameplayNetDefs
    snapWindow = bindContext.snapWindow

    panel = Instance.new('Frame')
    panel.Name = 'PartyWindow'
    panel.Size = UDim2.fromOffset(286, 304)
    panel.Position = UDim2.fromOffset(960, 62)
    panel.Visible = false
    panel.Parent = gui
    UiTheme.styleWindow(panel, PARTY_ACCENT, Color3.fromRGB(234, 239, 248))

    local title = Instance.new('TextLabel')
    title.Size = UDim2.fromOffset(180, 16)
    title.Position = UDim2.fromOffset(10, 7)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.ArialBold
    title.TextSize = 12
    title.TextColor3 = UiTheme.palette.parchment
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = 'Party'
    title.Parent = panel

    local subtitle = Instance.new('TextLabel')
    subtitle.Size = UDim2.fromOffset(240, 12)
    subtitle.Position = UDim2.fromOffset(10, 23)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.Arial
    subtitle.TextSize = 9
    subtitle.TextColor3 = Color3.fromRGB(221, 232, 255)
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Text = 'Party members and HP.'
    subtitle.Parent = panel

    UiDragUtil.makeDraggable(panel, title)
    UiDragUtil.makeResizable(panel, Vector2.new(286, 304), Vector2.new(380, 420))

    local closeButton = Instance.new('TextButton')
    closeButton.Size = UDim2.fromOffset(20, 18)
    closeButton.Position = UDim2.new(1, -28, 0, 6)
    closeButton.Text = 'x'
    closeButton.Parent = panel
    UiTheme.styleButton(closeButton, 'danger')
    closeButton.MouseButton1Click:Connect(function()
        panel.Visible = false
    end)

    local summaryCard = Instance.new('Frame')
    summaryCard.Size = UDim2.new(1, -20, 0, 70)
    summaryCard.Position = UDim2.fromOffset(10, 42)
    summaryCard.Parent = panel
    UiTheme.styleSection(summaryCard, PARTY_ACCENT, Color3.fromRGB(241, 245, 251))

    summaryLabel = Instance.new('TextLabel')
    summaryLabel.Size = UDim2.new(1, -24, 0, 18)
    summaryLabel.Position = UDim2.fromOffset(12, 10)
    summaryLabel.BackgroundTransparency = 1
    summaryLabel.Font = Enum.Font.ArialBold
    summaryLabel.TextSize = 11
    summaryLabel.TextColor3 = UiTheme.palette.text
    summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
    summaryLabel.Text = 'No party formed'
    summaryLabel.Parent = summaryCard

    leaderLabel = Instance.new('TextLabel')
    leaderLabel.Size = UDim2.new(1, -24, 0, 14)
    leaderLabel.Position = UDim2.fromOffset(12, 30)
    leaderLabel.BackgroundTransparency = 1
    leaderLabel.Font = Enum.Font.Arial
    leaderLabel.TextSize = 8
    leaderLabel.TextColor3 = UiTheme.palette.textMuted
    leaderLabel.TextXAlignment = Enum.TextXAlignment.Left
    leaderLabel.Text = 'Invite the nearest player to start adventuring together.'
    leaderLabel.Parent = summaryCard

    inviteButton = Instance.new('TextButton')
    inviteButton.Size = UDim2.fromOffset(120, 22)
    inviteButton.Position = UDim2.fromOffset(12, 46)
    inviteButton.Text = 'Invite Nearest'
    inviteButton.Parent = summaryCard
    UiTheme.styleButton(inviteButton, 'success')
    inviteButton.MouseButton1Click:Connect(function()
        context.requestAction(GameplayNetDefs.Actions.InviteNearestPlayerToParty, {})
    end)

    leaveButton = Instance.new('TextButton')
    leaveButton.Size = UDim2.fromOffset(120, 22)
    leaveButton.Position = UDim2.new(1, -132, 0, 46)
    leaveButton.Text = 'Leave Party'
    leaveButton.Parent = summaryCard
    UiTheme.styleButton(leaveButton, 'danger')
    leaveButton.MouseButton1Click:Connect(function()
        context.requestAction(GameplayNetDefs.Actions.LeaveParty, {})
    end)

    memberListFrame = Instance.new('ScrollingFrame')
    memberListFrame.Size = UDim2.new(1, -20, 1, -122)
    memberListFrame.Position = UDim2.fromOffset(10, 118)
    memberListFrame.ScrollBarThickness = 6
    memberListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    memberListFrame.Parent = panel
    UiTheme.styleScrollFrame(memberListFrame, PARTY_ACCENT, Color3.fromRGB(244, 247, 252))
end

function PartyController.toggle()
    if panel then
        local willOpen = not panel.Visible
        panel.Visible = willOpen
        if willOpen and snapWindow then
            task.defer(function()
                if panel and panel.Visible then
                    snapWindow(panel)
                end
            end)
        end
    end
end

function PartyController.hide()
    if panel then
        panel.Visible = false
    end
end

function PartyController.render(newState)
    state = newState
    if not panel or not memberListFrame then
        return
    end

    clearChildren(memberListFrame)
    local partyState = state.party
    local y = 8

    if not partyState or not partyState.members or #partyState.members == 0 then
        if summaryLabel then
            summaryLabel.Text = 'No party formed'
        end
        if leaderLabel then
            leaderLabel.Text = 'Invite the nearest player to start adventuring together.'
        end
        if leaveButton then
            leaveButton.Active = false
            leaveButton.AutoButtonColor = false
            UiTheme.styleButton(leaveButton, 'ghost')
        end

        local emptyLabel = Instance.new('TextLabel')
        emptyLabel.Size = UDim2.new(1, -18, 0, 44)
        emptyLabel.Position = UDim2.fromOffset(9, y)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextSize = 11
        emptyLabel.TextColor3 = UiTheme.palette.textMuted
        emptyLabel.TextWrapped = true
        emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
        emptyLabel.TextYAlignment = Enum.TextYAlignment.Top
        emptyLabel.Text = 'No active members yet. Invite a nearby adventurer, then watch this roster fill with HP and zone info.'
        emptyLabel.Parent = memberListFrame
        memberListFrame.CanvasSize = UDim2.new(0, 0, 0, 64)
        return
    end

    local leaderName = 'Unknown'
    for _, member in ipairs(partyState.members) do
        if member.isLeader then
            leaderName = member.name
            break
        end
    end

    if summaryLabel then
        summaryLabel.Text = string.format('%d member%s roaming together', #partyState.members, if #partyState.members == 1 then '' else 's')
    end
    if leaderLabel then
        leaderLabel.Text = string.format('Leader: %s', leaderName)
    end
    if leaveButton then
        leaveButton.Active = true
        leaveButton.AutoButtonColor = true
        UiTheme.styleButton(leaveButton, 'danger')
    end

    for _, member in ipairs(partyState.members) do
        local row = Instance.new('Frame')
        row.Size = UDim2.new(1, -18, 0, 62)
        row.Position = UDim2.fromOffset(9, y)
        row.Parent = memberListFrame
        UiTheme.styleSection(row, if member.isLeader then UiTheme.palette.gold else PARTY_ACCENT, Color3.fromRGB(18, 36, 40))

        local nameLabel = Instance.new('TextLabel')
        nameLabel.Size = UDim2.new(1, -116, 0, 18)
        nameLabel.Position = UDim2.fromOffset(12, 8)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamSemibold
        nameLabel.TextSize = 11
        nameLabel.TextColor3 = UiTheme.palette.text
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Text = member.name
        nameLabel.Parent = row

        local zoneLabel = Instance.new('TextLabel')
        zoneLabel.Size = UDim2.new(1, -116, 0, 12)
        zoneLabel.Position = UDim2.fromOffset(12, 25)
        zoneLabel.BackgroundTransparency = 1
        zoneLabel.Font = Enum.Font.Gotham
        zoneLabel.TextSize = 9
        zoneLabel.TextColor3 = UiTheme.palette.textMuted
        zoneLabel.TextXAlignment = Enum.TextXAlignment.Left
        zoneLabel.Text = tostring(member.zoneId or 'Unknown zone')
        zoneLabel.Parent = row

        local leaderPill = Instance.new('TextLabel')
        leaderPill.Size = UDim2.fromOffset(82, 18)
        leaderPill.Position = UDim2.new(1, -94, 0, 10)
        leaderPill.BackgroundTransparency = 0
        leaderPill.Font = Enum.Font.GothamBold
        leaderPill.TextSize = 8
        leaderPill.TextColor3 = if member.isLeader then Color3.fromRGB(34, 22, 8) else UiTheme.palette.parchment
        leaderPill.Text = if member.isLeader then 'Leader' else 'Member'
        leaderPill.Parent = row
        UiTheme.stylePill(
            leaderPill,
            if member.isLeader then UiTheme.palette.gold else PARTY_ACCENT,
            if member.isLeader then Color3.fromRGB(133, 102, 48) else Color3.fromRGB(43, 71, 64)
        )

        local hpTrack = Instance.new('Frame')
        hpTrack.Size = UDim2.new(1, -24, 0, 12)
        hpTrack.Position = UDim2.fromOffset(12, 42)
        hpTrack.Parent = row
        UiTheme.styleInset(hpTrack, PARTY_ACCENT, Color3.fromRGB(20, 27, 31))

        local hpFill = Instance.new('Frame')
        hpFill.Size = UDim2.new(math.clamp((member.health or 0) / math.max(member.maxHealth or 1, 1), 0, 1), 0, 1, 0)
        hpFill.Parent = hpTrack
        UiTheme.stylePill(hpFill, PARTY_ACCENT, Color3.fromRGB(68, 138, 114))

        local hpLabel = Instance.new('TextLabel')
        hpLabel.Size = UDim2.fromScale(1, 1)
        hpLabel.BackgroundTransparency = 1
        hpLabel.Font = Enum.Font.GothamSemibold
        hpLabel.TextSize = 9
        hpLabel.TextColor3 = UiTheme.palette.parchment
        hpLabel.Text = string.format('HP %d / %d', math.floor(member.health or 0), math.floor(member.maxHealth or 0))
        hpLabel.Parent = hpTrack

        y += 70
    end

    memberListFrame.CanvasSize = UDim2.new(0, 0, 0, y + 4)
end

return PartyController
