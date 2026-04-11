--!strict

local Debris = game:GetService('Debris')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')

local CardDefs = require(ReplicatedStorage.Shared.DataDefs.Cards.CardDefs)
local ItemDefs = require(ReplicatedStorage.Shared.DataDefs.Items.ItemDefs)
local LootPresentationConfig = require(ReplicatedStorage.Shared.Config.LootPresentationConfig)

local InventoryService = require(script.Parent.InventoryService)

local WorldDropService = {}

local dropsFolder = nil
local runtimeDrops = {}
local runtimeDropCounter = 0
local dropScatterRng = Random.new()

local function getRuntimeService()
    return require(script.Parent.SliceRuntimeService)
end

local function ensureDropsFolder()
    if dropsFolder and dropsFolder.Parent then
        return dropsFolder
    end

    local spawnedFolder = Workspace:FindFirstChild('SpawnedDuringPlay')
    if spawnedFolder and spawnedFolder:IsA('Folder') then
        local spawnedDropsFolder = spawnedFolder:FindFirstChild('Drops')
        if spawnedDropsFolder and spawnedDropsFolder:IsA('Folder') then
            dropsFolder = spawnedDropsFolder
            return spawnedDropsFolder
        end
    end

    local ensuredSpawnedFolder = spawnedFolder
    if not (ensuredSpawnedFolder and ensuredSpawnedFolder:IsA('Folder')) then
        ensuredSpawnedFolder = Instance.new('Folder')
        ensuredSpawnedFolder.Name = 'SpawnedDuringPlay'
        ensuredSpawnedFolder.Parent = Workspace
    end

    local folder = Instance.new('Folder')
    folder.Name = 'Drops'
    folder.Parent = ensuredSpawnedFolder
    dropsFolder = folder
    return folder
end

local function nextRuntimeDropId()
    runtimeDropCounter += 1
    return string.format('drop_%d_%d', os.time(), runtimeDropCounter)
end

local function getDropDisplayName(drop)
    if drop.kind == 'card' then
        local cardDef = CardDefs[drop.id]
        return if cardDef and cardDef.name then cardDef.name else tostring(drop.id)
    end

    local itemDef = ItemDefs[drop.id]
    return if itemDef and itemDef.name then itemDef.name else tostring(drop.id)
end

local function getDropItemType(drop)
    if drop.kind == 'card' then
        return 'Card'
    end

    local itemDef = ItemDefs[drop.id]
    return if itemDef and itemDef.itemType then itemDef.itemType else 'Item'
end

local function buildDropMessage(drop)
    local quantity = math.max(math.floor(tonumber(drop.quantity) or 1), 1)
    return string.format('Picked up: [%s] %s x%d', tostring(drop.rarity or 'Common'), getDropDisplayName(drop), quantity)
end

local function buildRareDropAnnouncement(drop, context)
    local quantity = math.max(math.floor(tonumber(drop.quantity) or 1), 1)
    local defeatedBy = context and context.defeatedByName or 'Someone'
    local sourceHint = context and context.sourceHint or drop.sourceHint or drop.sourceMonsterId or 'an enemy'
    return string.format(
        '%s made [%s] %s x%d drop from %s. It is now on the ground.',
        tostring(defeatedBy),
        tostring(drop.rarity or 'Common'),
        getDropDisplayName(drop),
        quantity,
        tostring(sourceHint)
    )
end

local function clearRuntimeDrop(runtimeId: string)
    local runtimeDrop = runtimeDrops[runtimeId]
    if not runtimeDrop then
        return
    end

    runtimeDrops[runtimeId] = nil
    if runtimeDrop.part and runtimeDrop.part.Parent then
        runtimeDrop.part:Destroy()
    end
end

local function styleBillboard(dropPart: BasePart, drop)
    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'DropBillboard'
    billboard.Size = UDim2.fromOffset(130, 28)
    billboard.StudsOffset = Vector3.new(0, 2.25, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = LootPresentationConfig.BillboardMaxDistance
    billboard.Parent = dropPart

    local label = Instance.new('TextLabel')
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextScaled = false
    label.TextSize = 10
    label.TextColor3 = LootPresentationConfig.getRarityColor(drop.rarity)
    label.TextStrokeColor3 = Color3.fromRGB(16, 18, 26)
    label.TextStrokeTransparency = 0.18
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = string.format('%s x%d', getDropDisplayName(drop), math.max(math.floor(tonumber(drop.quantity) or 1), 1))
    label.Parent = billboard
end

local function stylePickupPrompt(dropPart: BasePart, drop)
    local prompt = Instance.new('ProximityPrompt')
    prompt.Name = 'PickupPrompt'
    prompt.ActionText = LootPresentationConfig.PromptActionText or 'Loot'
    prompt.ObjectText = (LootPresentationConfig.PromptObjectText and LootPresentationConfig.PromptObjectText ~= '')
        and LootPresentationConfig.PromptObjectText
        or getDropDisplayName(drop)
    prompt.Style = Enum.ProximityPromptStyle.Default
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = LootPresentationConfig.PickupMaxDistance
    prompt.RequiresLineOfSight = false
    prompt.Parent = dropPart

    return prompt
end

local function styleClickDetector(dropPart: BasePart)
    local detector = Instance.new('ClickDetector')
    detector.MaxActivationDistance = LootPresentationConfig.PickupMaxDistance
    detector.Parent = dropPart
    return detector
end

local function styleDropSound(dropPart: BasePart, drop)
    local soundConfig = LootPresentationConfig.DropSound
    local sound = Instance.new('Sound')
    sound.Name = 'DropSpawnSound'
    sound.SoundId = soundConfig.soundId
    sound.Volume = soundConfig.volume + (drop.rarity == 'Legendary' and 0.12 or drop.rarity == 'Mythic' and 0.2 or 0)
    sound.PlaybackSpeed = soundConfig.playbackSpeed
        + (drop.rarity == 'Uncommon' and 0.04 or 0)
        + (drop.rarity == 'Rare' and 0.08 or 0)
        + (drop.rarity == 'Epic' and 0.12 or 0)
    sound.RollOffMaxDistance = soundConfig.rollOffMaxDistance
    sound.Parent = dropPart
    sound:Play()
    Debris:AddItem(sound, 3)
end

local function playPickupSound(runtimeDrop)
    local soundConfig = LootPresentationConfig.PickupSound
    if not soundConfig or not soundConfig.soundId or soundConfig.soundId == '' then
        return
    end

    local emitter = Instance.new('Part')
    emitter.Name = 'DropPickupSoundEmitter'
    emitter.Anchored = true
    emitter.CanCollide = false
    emitter.CanTouch = false
    emitter.CanQuery = false
    emitter.Transparency = 1
    emitter.Size = Vector3.new(0.2, 0.2, 0.2)
    emitter.CFrame = CFrame.new((runtimeDrop.part and runtimeDrop.part.Position) or runtimeDrop.position)
    emitter.Parent = Workspace

    local sound = Instance.new('Sound')
    sound.Name = 'DropPickupSound'
    sound.SoundId = soundConfig.soundId
    sound.Volume = soundConfig.volume + (runtimeDrop.drop.rarity == 'Legendary' and 0.08 or runtimeDrop.drop.rarity == 'Mythic' and 0.12 or 0)
    sound.PlaybackSpeed = soundConfig.playbackSpeed + (runtimeDrop.drop.rarity == 'Rare' and 0.02 or runtimeDrop.drop.rarity == 'Epic' and 0.04 or 0)
    sound.RollOffMaxDistance = soundConfig.rollOffMaxDistance
    sound.Parent = emitter
    sound:Play()

    Debris:AddItem(emitter, 3)
end

local function resolveGroundDropPosition(origin: Vector3, partSize: Vector3): Vector3
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude

    local filter = { ensureDropsFolder() }
    local runtimeEnemies = nil
    local spawnedFolder = Workspace:FindFirstChild('SpawnedDuringPlay')
    if spawnedFolder and spawnedFolder:IsA('Folder') then
        local spawnedEnemies = spawnedFolder:FindFirstChild('Enemies')
        if spawnedEnemies and spawnedEnemies:IsA('Folder') then
            runtimeEnemies = spawnedEnemies
        end
    end
    if runtimeEnemies then
        table.insert(filter, runtimeEnemies)
    end
    raycastParams.FilterDescendantsInstances = filter

    local rayOrigin = origin + Vector3.new(0, 8, 0)
    local rayDirection = Vector3.new(0, -40, 0)
    local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if result then
        return Vector3.new(origin.X, result.Position.Y + partSize.Y * 0.5 + 0.04, origin.Z)
    end

    return Vector3.new(origin.X, origin.Y + partSize.Y * 0.5, origin.Z)
end

local function createDropPart(runtimeId: string, drop, position: Vector3)
    local visual = LootPresentationConfig.getRarityVisual(drop.rarity)
    local itemType = getDropItemType(drop)
    local partSize = if itemType == 'Equipment'
        then Vector3.new(1.1, 1.1, 1.1)
        elseif itemType == 'Card'
        then Vector3.new(0.95, 0.95, 0.95)
        else Vector3.new(0.82, 0.82, 0.82)
    local groundedPosition = resolveGroundDropPosition(position, partSize)

    local dropPart = Instance.new('Part')
    dropPart.Name = runtimeId
    dropPart.Shape = if itemType == 'Equipment' then Enum.PartType.Block else Enum.PartType.Ball
    dropPart.Size = partSize
    dropPart.Anchored = true
    dropPart.CanCollide = false
    dropPart.CanTouch = false
    dropPart.CanQuery = true
    dropPart.Material = Enum.Material.SmoothPlastic
    dropPart.Color = visual.color
    dropPart.Transparency = visual.partTransparency
    dropPart.CFrame = CFrame.new(groundedPosition)
    dropPart:SetAttribute('WorldDropId', runtimeId)
    dropPart:SetAttribute('DropKind', drop.kind)
    dropPart:SetAttribute('DropItemId', drop.id)
    dropPart:SetAttribute('DropRarity', drop.rarity or 'Common')
    dropPart.Parent = ensureDropsFolder()

    local selectionBox = Instance.new('SelectionBox')
    selectionBox.Name = 'GlowBox'
    selectionBox.Adornee = dropPart
    selectionBox.Color3 = visual.color
    selectionBox.LineThickness = visual.lineThickness or if drop.rarity == 'Legendary' or drop.rarity == 'Mythic' then 0.03 else 0.018
    selectionBox.SurfaceTransparency = 1
    selectionBox.Transparency = visual.glowTransparency or 0.62
    if not LootPresentationConfig.shouldShowBillboard(drop) then
        selectionBox.Transparency = 0.92
        selectionBox.LineThickness = 0.01
    end
    selectionBox.Parent = dropPart

    if LootPresentationConfig.shouldShowBillboard(drop) then
        styleBillboard(dropPart, drop)
    end
    styleDropSound(dropPart, drop)

    return dropPart, stylePickupPrompt(dropPart, drop), styleClickDetector(dropPart)
end

local function tryPickup(player, runtimeId: string)
    local runtimeDrop = runtimeDrops[runtimeId]
    if not runtimeDrop or runtimeDrop.claimed then
        return false, 'Unavailable'
    end

    runtimeDrop.claimed = true
    local ok, reason = InventoryService.grantResolvedDrop(player, runtimeDrop.drop)
    if ok then
        local runtimeService = getRuntimeService()
        playPickupSound(runtimeDrop)
        clearRuntimeDrop(runtimeId)
        runtimeService.pushState(player)
        runtimeService.sendSystemChat(player, buildDropMessage(runtimeDrop.drop))
        return true, nil
    end

    runtimeDrop.claimed = false
    getRuntimeService().showMessage(player, 'Pickup failed: ' .. tostring(reason))
    return false, reason
end

local function scheduleExpiry(runtimeId: string)
    task.delay(LootPresentationConfig.DespawnSeconds, function()
        clearRuntimeDrop(runtimeId)
    end)
end

function WorldDropService.init()
    ensureDropsFolder()
end

function WorldDropService.start() end

function WorldDropService.spawnDrop(drop, position: Vector3, context)
    if type(drop) ~= 'table' or not drop.id or not position then
        return nil
    end

    local runtimeId = nextRuntimeDropId()
    local resolvedDrop = {
        kind = drop.kind or 'item',
        id = drop.id,
        quantity = math.max(math.floor(tonumber(drop.quantity) or 1), 1),
        rarity = drop.rarity or 'Common',
        category = drop.category,
        affixes = drop.affixes,
        chaseDrop = drop.chaseDrop,
        exclusive = drop.exclusive,
        sourceMonsterId = context and context.sourceMonsterId or nil,
        sourceHint = context and context.sourceHint or nil,
    }

    local dropPart, prompt, clickDetector = createDropPart(runtimeId, resolvedDrop, position)
    runtimeDrops[runtimeId] = {
        runtimeId = runtimeId,
        drop = resolvedDrop,
        position = position,
        expiresAt = os.clock() + LootPresentationConfig.DespawnSeconds,
        claimed = false,
        part = dropPart,
    }

    if LootPresentationConfig.shouldAnnounceDrop(resolvedDrop) then
        getRuntimeService().broadcastSystemChat(buildRareDropAnnouncement(resolvedDrop, context))
    end

    prompt.Triggered:Connect(function(player)
        tryPickup(player, runtimeId)
    end)
    clickDetector.MouseClick:Connect(function(player)
        tryPickup(player, runtimeId)
    end)

    scheduleExpiry(runtimeId)
    return runtimeDrops[runtimeId]
end

function WorldDropService.spawnDrops(drops, origin: Vector3, context)
    local spawned = {}
    for _, drop in ipairs(drops or {}) do
        local clusterOffset = Vector3.new(
            dropScatterRng:NextNumber(-2.2, 2.2),
            0,
            dropScatterRng:NextNumber(-2.2, 2.2)
        )
        local spreadOffset = Vector3.new(
            dropScatterRng:NextNumber(-3.4, 3.4),
            0,
            dropScatterRng:NextNumber(-3.4, 3.4)
        )
        local offset = clusterOffset + spreadOffset
        local runtimeDrop = WorldDropService.spawnDrop(drop, origin + offset, context)
        if runtimeDrop then
            table.insert(spawned, runtimeDrop)
        end
    end

    return spawned
end

function WorldDropService.getRuntimeDrops()
    return runtimeDrops
end

return WorldDropService
