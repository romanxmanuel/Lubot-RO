--!strict

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')

local MinimapController = {}
local UiDragUtil = require(script.Parent.UiDragUtil)
local UiTheme = require(script.Parent.UiTheme)

local player = Players.LocalPlayer
local state = nil
local mapFrame = nil
local zoneLabel = nil
local dotContainer = nil
local dotPool = {}

local function normalizeZoneId(zoneId: string?): string
    local normalized = string.lower(tostring(zoneId or '')):gsub('%s+', '_'):gsub('[^%w_]', '')
    if normalized == '' then
        return 'zoltraak'
    elseif normalized == 'town' or normalized == 'start' or normalized == 'starterworld' or normalized == 'prontera' then
        return 'zoltraak'
    elseif normalized == 'startingtown' then
        return 'startingtown'
    elseif normalized == 'pronterafield' or normalized == 'field' or normalized == 'field1' or normalized == 'pron' then
        return 'prontera_field'
    elseif normalized == 'anthell' or normalized == 'ant' or normalized == 'dungeon1' then
        return 'ant_hell_floor_1'
    elseif normalized == 'towerofascension' or normalized == 'tower' or normalized == 'toa' then
        return 'tower_of_ascension'
    elseif normalized == 'niflheim' or normalized == 'niff' then
        return 'niffheim'
    end
    return normalized
end

local function getMapBoxPriority(mapBox: BasePart): number
    return tonumber(mapBox:GetAttribute('Priority')) or 0
end

local function isInsideZoneVolume(position: Vector3, zonePart: BasePart): boolean
    local localPosition = zonePart.CFrame:PointToObjectSpace(position)
    local halfSize = zonePart.Size * 0.5
    local zoneShape = string.lower(tostring(zonePart:GetAttribute('ZoneShape') or 'box'))

    if zoneShape == 'cylinder' then
        local axis = string.upper(tostring(zonePart:GetAttribute('ZoneAxis') or 'X'))
        local radius = 0
        local heightCheck = 0
        local radialA = 0
        local radialB = 0

        if axis == 'Y' then
            radius = math.min(halfSize.X, halfSize.Z)
            heightCheck = math.abs(localPosition.Y)
            radialA = localPosition.X
            radialB = localPosition.Z
        elseif axis == 'Z' then
            radius = math.min(halfSize.X, halfSize.Y)
            heightCheck = math.abs(localPosition.Z)
            radialA = localPosition.X
            radialB = localPosition.Y
        else
            radius = math.min(halfSize.Y, halfSize.Z)
            heightCheck = math.abs(localPosition.X)
            radialA = localPosition.Y
            radialB = localPosition.Z
        end

        local radialDistance = math.sqrt((radialA * radialA) + (radialB * radialB))
        return radialDistance <= radius
            and heightCheck <= (axis == 'Y' and halfSize.Y or axis == 'Z' and halfSize.Z or halfSize.X)
    end

    return math.abs(localPosition.X) <= halfSize.X
        and math.abs(localPosition.Y) <= halfSize.Y
        and math.abs(localPosition.Z) <= halfSize.Z
end

local function buildZoneConfigs()
    local configs = {}
    local maps = Workspace:FindFirstChild('Maps')
    if not maps then
        return configs
    end

    for _, mapFolder in ipairs(maps:GetChildren()) do
        if mapFolder:IsA('Folder') and mapFolder.Name ~= 'TEMPLATE_MAP' then
            for _, descendant in ipairs(mapFolder:GetDescendants()) do
                if descendant:IsA('BasePart') and descendant.Name == 'MapBox' then
                    table.insert(configs, {
                        box = descendant,
                        id = normalizeZoneId(descendant:GetAttribute('ZoneId') or mapFolder.Name),
                        name = tostring(descendant:GetAttribute('ZoneLabel') or mapFolder.Name),
                        center = descendant.Position,
                        size = Vector2.new(math.max(descendant.Size.X, 80), math.max(descendant.Size.Z, 80)),
                        priority = getMapBoxPriority(descendant),
                        sortArea = descendant.Size.X * descendant.Size.Z,
                    })
                end
            end
        end
    end

    table.sort(configs, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.sortArea < b.sortArea
    end)

    return configs
end

local function getDot(index)
    local existing = dotPool[index]
    if existing then
        existing.Visible = true
        return existing
    end

    local dot = Instance.new('Frame')
    dot.Name = 'MinimapDot' .. tostring(index)
    dot.Size = UDim2.fromOffset(6, 6)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BorderSizePixel = 0
    dot.Parent = dotContainer

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot

    dotPool[index] = dot
    return dot
end

local function hideUnusedDots(startIndex)
    for index = startIndex, #dotPool do
        dotPool[index].Visible = false
    end
end

local function isWithinZone(position, zoneConfig)
    return math.abs(position.X - zoneConfig.center.X) <= (zoneConfig.size.X / 2)
        and math.abs(position.Z - zoneConfig.center.Z) <= (zoneConfig.size.Y / 2)
end

local function getCurrentZoneConfig()
    local zoneConfigs = buildZoneConfigs()
    local rootPart = player.Character and player.Character:FindFirstChild('HumanoidRootPart')
    if rootPart then
        local position = rootPart.Position
        for _, zoneConfig in ipairs(zoneConfigs) do
            if zoneConfig.box and isInsideZoneVolume(position, zoneConfig.box) then
                return zoneConfig
            end
        end
    end

    for _, zoneConfig in ipairs(zoneConfigs) do
        if zoneConfig.id == 'zoltraak' then
            return zoneConfig
        end
    end

    return zoneConfigs[1] or {
        id = 'zoltraak',
        name = 'Zoltraak',
        center = Vector3.new(-304, 0, 227),
        size = Vector2.new(220, 220),
    }
end

local function worldToMapPoint(position, zoneConfig)
    local normalizedX = ((position.X - zoneConfig.center.X) / math.max(zoneConfig.size.X / 2, 1)) * 0.5 + 0.5
    local normalizedY = ((position.Z - zoneConfig.center.Z) / math.max(zoneConfig.size.Y / 2, 1)) * 0.5 + 0.5
    return Vector2.new(math.clamp(normalizedX, 0, 1), math.clamp(normalizedY, 0, 1))
end

function MinimapController.bind(gui)
    local frame = Instance.new('Frame')
    frame.Name = 'MinimapFrame'
    frame.Size = UDim2.fromOffset(178, 184)
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -24, 0, 24)
    frame.Parent = gui
    UiTheme.styleWindow(frame, UiTheme.palette.azure, Color3.fromRGB(234, 239, 248))

    zoneLabel = Instance.new('TextLabel')
    zoneLabel.Name = 'ZoneLabel'
    zoneLabel.Size = UDim2.new(1, -40, 0, 16)
    zoneLabel.Position = UDim2.fromOffset(10, 7)
    zoneLabel.BackgroundTransparency = 1
    zoneLabel.Font = Enum.Font.ArialBold
    zoneLabel.TextSize = 11
    zoneLabel.TextColor3 = UiTheme.palette.parchment
    zoneLabel.TextXAlignment = Enum.TextXAlignment.Left
    zoneLabel.Parent = frame

    UiDragUtil.makeDraggable(frame, zoneLabel)
    UiDragUtil.makeResizable(frame, Vector2.new(180, 180))

    local closeButton = Instance.new('TextButton')
    closeButton.Size = UDim2.fromOffset(20, 18)
    closeButton.Position = UDim2.new(1, -28, 0, 6)
    closeButton.Font = Enum.Font.ArialBold
    closeButton.TextSize = 11
    closeButton.Text = 'x'
    closeButton.Parent = frame
    UiTheme.styleButton(closeButton, 'danger')
    closeButton.MouseButton1Click:Connect(function()
        frame.Visible = false
    end)

    mapFrame = Instance.new('Frame')
    mapFrame.Name = 'MapFrame'
    mapFrame.Size = UDim2.new(1, -16, 1, -34)
    mapFrame.Position = UDim2.fromOffset(8, 26)
    mapFrame.Parent = frame
    UiTheme.styleInset(mapFrame, UiTheme.palette.azure, Color3.fromRGB(244, 247, 252))

    dotContainer = Instance.new('Frame')
    dotContainer.Name = 'DotContainer'
    dotContainer.Size = UDim2.fromScale(1, 1)
    dotContainer.BackgroundTransparency = 1
    dotContainer.Parent = mapFrame
end

function MinimapController.render(newState)
    state = newState
end

function MinimapController.toggle()
    if mapFrame and mapFrame.Parent then
        mapFrame.Parent.Visible = not mapFrame.Parent.Visible
    end
end

function MinimapController.update()
    if not state or not mapFrame or not dotContainer or not zoneLabel then
        return
    end

    local zoneConfig = getCurrentZoneConfig()
    zoneLabel.Text = zoneConfig.name

    local dotIndex = 1
    local rootPart = player.Character and player.Character:FindFirstChild('HumanoidRootPart')
    if rootPart then
        local playerDot = getDot(dotIndex)
        playerDot.BackgroundColor3 = Color3.fromRGB(255, 245, 132)
        local point = worldToMapPoint(rootPart.Position, zoneConfig)
        playerDot.Position = UDim2.fromScale(point.X, point.Y)
        dotIndex += 1
    end

    for _, enemyState in ipairs(state.enemies or {}) do
        if enemyState.position and isWithinZone(enemyState.position, zoneConfig) then
            local enemyDot = getDot(dotIndex)
            enemyDot.BackgroundColor3 = Color3.fromRGB(255, 118, 118)
            local point = worldToMapPoint(enemyState.position, zoneConfig)
            enemyDot.Position = UDim2.fromScale(point.X, point.Y)
            dotIndex += 1
        end
    end

    local maps = Workspace:FindFirstChild('Maps')
    if maps then
        for _, mapFolder in ipairs(maps:GetChildren()) do
            if mapFolder:IsA('Folder') then
                local playerUse = mapFolder:FindFirstChild('PlayerUse')
                if playerUse then
                    for _, child in ipairs(playerUse:GetChildren()) do
                        if child:IsA('BasePart') and isWithinZone(child.Position, zoneConfig) then
                            local interactiveDot = getDot(dotIndex)
                            interactiveDot.BackgroundColor3 = Color3.fromRGB(107, 199, 255)
                            local point = worldToMapPoint(child.Position, zoneConfig)
                            interactiveDot.Position = UDim2.fromScale(point.X, point.Y)
                            dotIndex += 1
                        end
                    end
                end
            end
        end
    end

    hideUnusedDots(dotIndex)
end

return MinimapController
