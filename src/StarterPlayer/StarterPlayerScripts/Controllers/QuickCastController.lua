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
local slotLabels: { [number]: TextLabel } = {}
local slotCooldownEnds: { [number]: number } = {}
local latestCastToken = 0

local HOTBAR_SLOT_SIZE = 58
local HOTBAR_SLOT_GAP = 5
local HOTBAR_SLOT_COUNT = 10
local DEFAULT_COOLDOWN_SECONDS = 1.5
local QUICK_CAST_RETRY_SECONDS = 0.18
local QUICK_CAST_RETRY_STEP = 0.03
local AUTO_TARGET_RANGE = 120

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

local function ensureOverlayGui()
    if overlayGui and overlayGui.Parent then
        return
    end

    local playerGui = localPlayer:FindFirstChildOfClass('PlayerGui')
    if not playerGui then
        return
    end

    local gui = Instance.new('ScreenGui')
    gui.Name = 'MMOQuickCastCooldowns'
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 30
    gui.Parent = playerGui

    overlayGui = gui

    for slotIndex = 1, HOTBAR_SLOT_COUNT do
        local label = Instance.new('TextLabel')
        label.Name = string.format('Cooldown_%d', slotIndex)
        label.Size = UDim2.fromOffset(34, 20)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.BackgroundColor3 = Color3.fromRGB(20, 27, 42)
        label.BackgroundTransparency = 0.22
        label.BorderSizePixel = 0
        label.Font = Enum.Font.GothamBold
        label.TextColor3 = Color3.fromRGB(246, 250, 255)
        label.TextSize = 12
        label.Visible = false
        label.ZIndex = 5
        label.Parent = gui

        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = label

        local stroke = Instance.new('UIStroke')
        stroke.Color = Color3.fromRGB(94, 132, 208)
        stroke.Transparency = 0.1
        stroke.Thickness = 1
        stroke.Parent = label

        slotLabels[slotIndex] = label
    end
end

local function resolveToolCooldownSeconds(tool: Tool?): number
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

local function faceNearestEnemy()
    local character = localPlayer.Character
    if not character then
        return
    end

    local root = character:FindFirstChild('HumanoidRootPart')
    if not root or not root:IsA('BasePart') then
        return
    end

    local targetPosition = getNearestEnemyPosition(root.Position)
    if not targetPosition then
        return
    end

    local planarTarget = Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z)
    local direction = planarTarget - root.Position
    if direction.Magnitude <= 0.001 then
        return
    end

    root.CFrame = CFrame.lookAt(root.Position, planarTarget)
end

local function beginSlotCooldown(slotIndex: number, durationSeconds: number)
    if durationSeconds <= 0 then
        return
    end

    local now = os.clock()
    local nextReady = now + durationSeconds
    local existingReady = slotCooldownEnds[slotIndex] or 0
    slotCooldownEnds[slotIndex] = math.max(existingReady, nextReady)
end

local function updateCooldownUi()
    ensureOverlayGui()

    local hotbarFrame = getNativeHotbarFrame()
    local now = os.clock()

    for slotIndex = 1, HOTBAR_SLOT_COUNT do
        local label = slotLabels[slotIndex]
        if not label then
            continue
        end

        local remaining = (slotCooldownEnds[slotIndex] or 0) - now
        if remaining <= 0 then
            slotCooldownEnds[slotIndex] = nil
            label.Visible = false
            continue
        end

        if not hotbarFrame or not hotbarFrame.Visible then
            label.Visible = false
            continue
        end

        local slotFrame = getSlotFrame(hotbarFrame, slotIndex)
        local center = if slotFrame
            then slotFrame.AbsolutePosition + slotFrame.AbsoluteSize * 0.5
            else getFallbackSlotCenter(hotbarFrame, slotIndex)

        label.Position = UDim2.fromOffset(math.floor(center.X), math.floor(center.Y))
        label.Text = string.format('%.1f', math.max(remaining, 0))
        label.Visible = true
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

    faceNearestEnemy()

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

    ensureOverlayGui()

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if UserInputService:GetFocusedTextBox() then
            return
        end

        local slotIndex = KEY_TO_SLOT[input.KeyCode]
        if slotIndex then
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
