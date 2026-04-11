--!strict

local CoreGui = game:GetService('CoreGui')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')

local QuickCastController = {
    Name = 'QuickCastController',
}

local localPlayer = Players.LocalPlayer
local dependencies = nil
local started = false

local overlayGui: ScreenGui? = nil
local slotCooldownEnds: { [number]: number } = {}
local slotCooldownDurations: { [number]: number } = {}
local slotWidgets: { [number]: { container: Frame, fill: Frame, text: TextLabel } } = {}
local latestCastToken = 0

local HOTBAR_SLOT_SIZE = 58
local HOTBAR_SLOT_GAP = 5
local HOTBAR_SLOT_COUNT = 10
local DEFAULT_COOLDOWN_SECONDS = 1.5
local COOLDOWNS_DISABLED = true
local QUICK_CAST_RETRY_SECONDS = 0.18
local QUICK_CAST_RETRY_STEP = 0.03
local AUTO_TARGET_RANGE = 120
local DEFAULT_MOVEMENT_PROFILE = 'nudge'
local IMPORTED_TOOL_DEFAULT_MOVEMENT_PROFILE = 'none'

local MOVEMENT_PROFILE_ATTRIBUTE = 'QuickCastMovementProfile'
local MOVEMENT_STEP_ATTRIBUTE = 'QuickCastStepDistance'
local MOVEMENT_STOP_RANGE_ATTRIBUTE = 'QuickCastStopRange'
local MOVEMENT_TRIGGER_RANGE_ATTRIBUTE = 'QuickCastTriggerRange'
local MOVEMENT_VERTICAL_LIFT_ATTRIBUTE = 'QuickCastVerticalLift'

local MOVEMENT_PROFILES = {
    none = {
        enabled = false,
    },
    nudge = {
        enabled = true,
        stepDistance = 4.5,
        stopRange = 8,
        triggerRange = 22,
        verticalLift = 0,
    },
    lunge = {
        enabled = true,
        stepDistance = 8.5,
        stopRange = 6,
        triggerRange = 30,
        verticalLift = 0.8,
    },
    dash = {
        enabled = true,
        stepDistance = 12,
        stopRange = 4,
        triggerRange = 36,
        verticalLift = 1.5,
    },
}

local TOOL_NAME_MOVEMENT_PROFILE = {
    ['Power Slash'] = 'lunge',
    ['Arc Flare'] = 'lunge',
    ['Nova Strike'] = 'nudge',
    ['Vortex Spin'] = 'lunge',
    ['Comet Drop'] = 'dash',
    ['Razor Orbit'] = 'nudge',
}

local COOLDOWN_ATTRIBUTE_NAMES = {
    'CooldownSeconds',
    'Cooldown',
    'SkillCooldown',
    'CastCooldown',
    'ActivationCooldown',
}

local KEY_TO_SLOT: { [Enum.KeyCode]: number } = {
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

local function getEquippedTool(): Tool?
    local character = localPlayer.Character
    if not character then
        return nil
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA('Tool') then
            return child
        end
    end

    return nil
end

local function getNativeHotbarFrame(): GuiObject?
    local ok, coreGui = pcall(function()
        return CoreGui
    end)
    if not ok or not coreGui then
        return nil
    end

    local robloxGui = coreGui:FindFirstChild('RobloxGui')
    if not robloxGui then
        return nil
    end

    local backpackGui = robloxGui:FindFirstChild('Backpack')
    if not backpackGui then
        return nil
    end

    local hotbarFrame = backpackGui:FindFirstChild('Hotbar')
    if not hotbarFrame or not hotbarFrame:IsA('GuiObject') then
        return nil
    end

    return hotbarFrame
end

local function getSlotFrame(hotbarFrame: GuiObject, slotIndex: number): GuiObject?
    local slotName = if slotIndex == 10 then '0' else tostring(slotIndex)
    local direct = hotbarFrame:FindFirstChild(slotName, true)
    if direct and direct:IsA('GuiObject') then
        return direct
    end

    local numericCandidates: { GuiObject } = {}
    for _, descendant in ipairs(hotbarFrame:GetDescendants()) do
        if descendant:IsA('GuiObject') and tonumber(descendant.Name) ~= nil then
            table.insert(numericCandidates, descendant)
        end
    end

    if #numericCandidates == 0 then
        return nil
    end

    table.sort(numericCandidates, function(a, b)
        local aOrder = a.LayoutOrder ~= 0 and a.LayoutOrder or (tonumber(a.Name) or 0)
        local bOrder = b.LayoutOrder ~= 0 and b.LayoutOrder or (tonumber(b.Name) or 0)
        if aOrder == bOrder then
            return a.Name < b.Name
        end
        return aOrder < bOrder
    end)

    return numericCandidates[slotIndex]
end

local function getFallbackSlotCenter(hotbarFrame: GuiObject, slotIndex: number): Vector2
    local slotWidth = HOTBAR_SLOT_SIZE
    local computedWidth = slotWidth * HOTBAR_SLOT_COUNT + HOTBAR_SLOT_GAP * (HOTBAR_SLOT_COUNT - 1)

    if computedWidth > hotbarFrame.AbsoluteSize.X then
        slotWidth = math.max(36, (hotbarFrame.AbsoluteSize.X - HOTBAR_SLOT_GAP * (HOTBAR_SLOT_COUNT - 1)) / HOTBAR_SLOT_COUNT)
        computedWidth = slotWidth * HOTBAR_SLOT_COUNT + HOTBAR_SLOT_GAP * (HOTBAR_SLOT_COUNT - 1)
    end

    local startX = hotbarFrame.AbsolutePosition.X + (hotbarFrame.AbsoluteSize.X - computedWidth) * 0.5
    local centerX = startX + (slotIndex - 1) * (slotWidth + HOTBAR_SLOT_GAP) + slotWidth * 0.5
    local centerY = hotbarFrame.AbsolutePosition.Y + hotbarFrame.AbsoluteSize.Y * 0.5
    return Vector2.new(centerX, centerY)
end

local function getViewportFallbackSlotCenter(slotIndex: number): Vector2
    local camera = workspace.CurrentCamera
    if not camera then
        return Vector2.new(0, 0)
    end

    local viewport = camera.ViewportSize
    local slotWidth = HOTBAR_SLOT_SIZE
    local totalWidth = slotWidth * HOTBAR_SLOT_COUNT + HOTBAR_SLOT_GAP * (HOTBAR_SLOT_COUNT - 1)
    local startX = (viewport.X - totalWidth) * 0.5
    local centerX = startX + (slotIndex - 1) * (slotWidth + HOTBAR_SLOT_GAP) + slotWidth * 0.5
    local centerY = viewport.Y - (slotWidth * 0.52)
    return Vector2.new(centerX, centerY)
end

local function ensureOverlayGui()
    if overlayGui and overlayGui.Parent then
        return true
    end

    local playerGui = localPlayer:FindFirstChildOfClass('PlayerGui')
    if not playerGui then
        return false
    end

    local gui = Instance.new('ScreenGui')
    gui.Name = 'MMOQuickCastCooldowns'
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 99
    gui.Parent = playerGui
    overlayGui = gui
    return true
end

local function ensureSlotWidget(slotIndex: number, slotFrame: GuiObject?)
    if not slotFrame and not ensureOverlayGui() then
        return nil
    end

    local existing = slotWidgets[slotIndex]
    local targetParent: Instance? = slotFrame or overlayGui
    if not targetParent then
        return nil
    end

    if existing and existing.container.Parent == targetParent then
        return existing
    end

    if existing and existing.container.Parent then
        existing.container:Destroy()
    end

    local container = Instance.new('Frame')
    container.Name = 'MMOCooldownCircle'
    container.Size = UDim2.fromOffset(34, 34)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.Position = UDim2.fromOffset(0, 0)
    container.BackgroundTransparency = 1
    container.ZIndex = 210
    container.Visible = false
    container.Parent = targetParent

    local base = Instance.new('Frame')
    base.Name = 'Base'
    base.Size = UDim2.fromScale(1, 1)
    base.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
    base.BackgroundTransparency = 0.12
    base.BorderSizePixel = 0
    base.ZIndex = 210
    base.Parent = container

    local baseCorner = Instance.new('UICorner')
    baseCorner.CornerRadius = UDim.new(1, 0)
    baseCorner.Parent = base

    local baseStroke = Instance.new('UIStroke')
    baseStroke.Color = Color3.fromRGB(120, 168, 255)
    baseStroke.Transparency = 0
    baseStroke.Thickness = 1.6
    baseStroke.Parent = base

    local fill = Instance.new('Frame')
    fill.Name = 'Fill'
    fill.Size = UDim2.fromScale(1, 1)
    fill.Position = UDim2.fromScale(0, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 245, 168)
    fill.BackgroundTransparency = 0.16
    fill.BorderSizePixel = 0
    fill.ZIndex = 211
    fill.Parent = container

    local fillCorner = Instance.new('UICorner')
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local text = Instance.new('TextLabel')
    text.Name = 'Text'
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    text.TextStrokeTransparency = 0.22
    text.TextScaled = true
    text.Text = ''
    text.ZIndex = 212
    text.Parent = container

    local created = {
        container = container,
        fill = fill,
        text = text,
    }
    slotWidgets[slotIndex] = created
    return created
end

local function resolveToolCooldownSeconds(tool: Tool?): number
    if COOLDOWNS_DISABLED then
        return 0
    end

    if not tool then
        return DEFAULT_COOLDOWN_SECONDS
    end

    for _, attributeName in ipairs(COOLDOWN_ATTRIBUTE_NAMES) do
        local value = tool:GetAttribute(attributeName)
        if typeof(value) == 'number' and value > 0 then
            return value
        end
        if typeof(value) == 'string' then
            local parsed = tonumber(value)
            if parsed and parsed > 0 then
                return parsed
            end
        end
    end

    return DEFAULT_COOLDOWN_SECONDS
end

local function readPositiveNumberAttribute(tool: Tool, attributeName: string): number?
    local raw = tool:GetAttribute(attributeName)
    if typeof(raw) == 'number' and raw > 0 then
        return raw
    end
    if typeof(raw) == 'string' then
        local parsed = tonumber(raw)
        if parsed and parsed > 0 then
            return parsed
        end
    end
    return nil
end

local function resolveMovementProfileName(tool: Tool): string
    local configured = tool:GetAttribute(MOVEMENT_PROFILE_ATTRIBUTE)
    if typeof(configured) == 'string' then
        local normalized = string.lower(configured)
        if MOVEMENT_PROFILES[normalized] then
            return normalized
        end
    end

    if tool:GetAttribute('ImportedAssetId') ~= nil then
        return IMPORTED_TOOL_DEFAULT_MOVEMENT_PROFILE
    end

    local byName = TOOL_NAME_MOVEMENT_PROFILE[tool.Name]
    if byName and MOVEMENT_PROFILES[byName] then
        return byName
    end

    return DEFAULT_MOVEMENT_PROFILE
end

local function resolveToolMovementProfile(tool: Tool)
    local profileName = resolveMovementProfileName(tool)
    local baseProfile = MOVEMENT_PROFILES[profileName] or MOVEMENT_PROFILES.none
    local resolvedProfile = {
        enabled = baseProfile.enabled == true,
        stepDistance = baseProfile.stepDistance or 0,
        stopRange = baseProfile.stopRange or 0,
        triggerRange = baseProfile.triggerRange or 0,
        verticalLift = baseProfile.verticalLift or 0,
    }

    local stepOverride = readPositiveNumberAttribute(tool, MOVEMENT_STEP_ATTRIBUTE)
    if stepOverride then
        resolvedProfile.stepDistance = stepOverride
        resolvedProfile.enabled = stepOverride > 0
    end

    local stopOverride = readPositiveNumberAttribute(tool, MOVEMENT_STOP_RANGE_ATTRIBUTE)
    if stopOverride then
        resolvedProfile.stopRange = stopOverride
    end

    local triggerOverride = readPositiveNumberAttribute(tool, MOVEMENT_TRIGGER_RANGE_ATTRIBUTE)
    if triggerOverride then
        resolvedProfile.triggerRange = triggerOverride
    end

    local liftOverride = readPositiveNumberAttribute(tool, MOVEMENT_VERTICAL_LIFT_ATTRIBUTE)
    if liftOverride then
        resolvedProfile.verticalLift = liftOverride
    end

    return resolvedProfile
end

local function getTargetPositionFromTrackedTarget(): Vector3?
    if not dependencies or not dependencies.TargetingController then
        return nil
    end

    local targetModel = dependencies.TargetingController.getTrackedTarget and dependencies.TargetingController.getTrackedTarget() or nil
    if not targetModel then
        return nil
    end

    local root = targetModel.PrimaryPart or targetModel:FindFirstChild('Root') or targetModel:FindFirstChild('HumanoidRootPart')
    if root and root:IsA('BasePart') then
        return root.Position
    end

    return nil
end

local function getNearestEnemyPosition(origin: Vector3): Vector3?
    local trackedTargetPosition = getTargetPositionFromTrackedTarget()
    if trackedTargetPosition and (trackedTargetPosition - origin).Magnitude <= AUTO_TARGET_RANGE then
        return trackedTargetPosition
    end

    local spawned = workspace:FindFirstChild('SpawnedDuringPlay')
    local enemyFolder = spawned and spawned:FindFirstChild('Enemies')
    if not enemyFolder then
        return nil
    end

    local nearestDistance = AUTO_TARGET_RANGE
    local nearestPosition = nil

    for _, enemyModel in ipairs(enemyFolder:GetChildren()) do
        if enemyModel:IsA('Model') then
            local currentHp = enemyModel:GetAttribute('CurrentHP') or 0
            if currentHp > 0 then
                local root = enemyModel.PrimaryPart or enemyModel:FindFirstChild('Root') or enemyModel:FindFirstChild('HumanoidRootPart')
                if root and root:IsA('BasePart') then
                    local distance = (root.Position - origin).Magnitude
                    if distance <= nearestDistance then
                        nearestDistance = distance
                        nearestPosition = root.Position
                    end
                end
            end
        end
    end

    return nearestPosition
end

local function faceNearestEnemy(): (BasePart?, Vector3?, number)
    local character = localPlayer.Character
    if not character then
        return nil, nil, 0
    end

    local root = character:FindFirstChild('HumanoidRootPart')
    if not root or not root:IsA('BasePart') then
        return nil, nil, 0
    end

    local targetPosition = getNearestEnemyPosition(root.Position)
    if not targetPosition then
        return root, nil, 0
    end

    local planarTarget = Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z)
    local direction = planarTarget - root.Position
    if direction.Magnitude <= 0.001 then
        return root, planarTarget, 0
    end

    root.CFrame = CFrame.lookAt(root.Position, planarTarget)
    return root, planarTarget, direction.Magnitude
end

local function applyMovementAssist(tool: Tool, root: BasePart?, planarTarget: Vector3?, currentDistance: number)
    if not root or not planarTarget then
        return
    end

    local profile = resolveToolMovementProfile(tool)
    if not profile.enabled then
        return
    end

    if currentDistance <= profile.stopRange or currentDistance > profile.triggerRange then
        return
    end

    local toTarget = planarTarget - root.Position
    local planarDistance = toTarget.Magnitude
    if planarDistance <= 0.001 then
        return
    end

    local approachDistance = math.min(profile.stepDistance, planarDistance - profile.stopRange)
    if approachDistance <= 0.05 then
        return
    end

    local direction = toTarget.Unit
    local character = root.Parent
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = if character then { character } else {}
    raycastParams.IgnoreWater = true
    local rayResult = workspace:Raycast(root.Position + Vector3.new(0, 1.4, 0), direction * approachDistance, raycastParams)
    if rayResult then
        approachDistance = math.max(rayResult.Distance - 1.5, 0)
    end
    if approachDistance <= 0.05 then
        return
    end

    local destination = root.Position + direction * approachDistance
    local humanoid = if character then character:FindFirstChildOfClass('Humanoid') else nil
    local lift = profile.verticalLift
    if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
        lift = 0
    end
    destination = Vector3.new(destination.X, root.Position.Y + lift, destination.Z)
    local lookTarget = Vector3.new(planarTarget.X, destination.Y, planarTarget.Z)
    root.CFrame = CFrame.lookAt(destination, lookTarget)
end

local function beginSlotCooldown(slotIndex: number, durationSeconds: number)
    if COOLDOWNS_DISABLED then
        return
    end

    if durationSeconds <= 0 then
        return
    end

    local now = os.clock()
    local nextReady = now + durationSeconds
    local existingReady = slotCooldownEnds[slotIndex] or 0
    slotCooldownEnds[slotIndex] = math.max(existingReady, nextReady)
    slotCooldownDurations[slotIndex] = durationSeconds
end

local function updateCooldownUi()
    local hotbarFrame = getNativeHotbarFrame()
    local now = os.clock()

    for slotIndex = 1, HOTBAR_SLOT_COUNT do
        local remaining = (slotCooldownEnds[slotIndex] or 0) - now
        if remaining <= 0 then
            slotCooldownEnds[slotIndex] = nil
            slotCooldownDurations[slotIndex] = nil
            local widget = slotWidgets[slotIndex]
            if widget then
                widget.container.Visible = false
            end
            continue
        end

        local slotFrame = hotbarFrame and getSlotFrame(hotbarFrame, slotIndex) or nil

        local widget = ensureSlotWidget(slotIndex, slotFrame)
        if not widget then
            continue
        end
        widget.container.Visible = true

        if slotFrame then
            widget.container.Position = UDim2.fromScale(0.5, 0.5)
        else
            local center = if hotbarFrame
                then getFallbackSlotCenter(hotbarFrame, slotIndex)
                else getViewportFallbackSlotCenter(slotIndex)
            widget.container.Position = UDim2.fromOffset(math.floor(center.X), math.floor(center.Y - 20))
        end

        local total = slotCooldownDurations[slotIndex] or DEFAULT_COOLDOWN_SECONDS
        local ratio = math.clamp(remaining / math.max(total, 0.001), 0, 1)
        local diameter = math.max(0.1, ratio)
        widget.fill.Size = UDim2.fromScale(diameter, diameter)
        widget.fill.Position = UDim2.fromScale((1 - diameter) * 0.5, (1 - diameter) * 0.5)

        if remaining >= 10 then
            widget.text.Text = string.format('%d', math.ceil(remaining))
        else
            widget.text.Text = string.format('%.1f', remaining)
        end
    end
end

local function attemptQuickCast(slotIndex: number, token: number)
    local deadline = os.clock() + QUICK_CAST_RETRY_SECONDS
    local tool: Tool? = nil

    repeat
        if token ~= latestCastToken then
            return
        end

        tool = getEquippedTool()
        if tool then
            break
        end

        task.wait(QUICK_CAST_RETRY_STEP)
    until os.clock() >= deadline

    if token ~= latestCastToken then
        return
    end

    if not tool then
        return
    end

    if tool:GetAttribute('AllowsCombatStyleOnly') == true then
        return
    end

    local root, planarTarget, distance = faceNearestEnemy()
    applyMovementAssist(tool, root, planarTarget, distance)

    local activated = false
    local ok = pcall(function()
        tool:Activate()
        activated = true
    end)
    if not ok or not activated then
        return
    end

    beginSlotCooldown(slotIndex, resolveToolCooldownSeconds(tool))
end

function QuickCastController.init(deps)
    dependencies = deps
end

function QuickCastController.start()
    if started then
        return
    end
    started = true

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if UserInputService:GetFocusedTextBox() then
            return
        end

        local slotIndex = KEY_TO_SLOT[input.KeyCode]
        if slotIndex then
            if not COOLDOWNS_DISABLED then
                beginSlotCooldown(slotIndex, DEFAULT_COOLDOWN_SECONDS)
            end
            latestCastToken += 1
            local token = latestCastToken
            task.defer(function()
                attemptQuickCast(slotIndex, token)
            end)
            return
        end

        if gameProcessed then
            return
        end
    end)

    RunService.RenderStepped:Connect(function()
        updateCooldownUi()
    end)
end

return QuickCastController
