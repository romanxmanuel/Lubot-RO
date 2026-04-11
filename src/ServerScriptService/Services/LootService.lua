--!strict

local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ItemData = require(ReplicatedStorage.GameData.Items.ItemData)
local LootData = require(ReplicatedStorage.GameData.Loot.LootData)

local LootService = {
    Name = 'LootService',
}

type DropItem = {
    itemId: string,
    amount: number,
}

type DropState = {
    claimed: boolean,
    items: { DropItem },
    zenyAmount: number,
    label: string,
}

local RARITY_STYLE = {
    common = {
        glow = Color3.fromRGB(166, 208, 255),
        shell = Color3.fromRGB(220, 237, 255),
        beam = Color3.fromRGB(112, 170, 255),
    },
    uncommon = {
        glow = Color3.fromRGB(113, 232, 143),
        shell = Color3.fromRGB(218, 255, 227),
        beam = Color3.fromRGB(89, 213, 123),
    },
    rare = {
        glow = Color3.fromRGB(121, 217, 255),
        shell = Color3.fromRGB(225, 250, 255),
        beam = Color3.fromRGB(88, 198, 255),
    },
    epic = {
        glow = Color3.fromRGB(197, 136, 255),
        shell = Color3.fromRGB(241, 223, 255),
        beam = Color3.fromRGB(174, 92, 255),
    },
    card = {
        glow = Color3.fromRGB(255, 194, 86),
        shell = Color3.fromRGB(255, 236, 170),
        beam = Color3.fromRGB(255, 122, 66),
    },
    zeny = {
        glow = Color3.fromRGB(255, 218, 108),
        shell = Color3.fromRGB(255, 240, 174),
        beam = Color3.fromRGB(255, 194, 88),
    },
}

local dependencies = nil
local dropFolder: Folder? = nil
local activeDrops: { [Model]: DropState } = {}

local function ensureDropFolder(): Folder
    local spawnedRoot = Workspace:FindFirstChild('SpawnedDuringPlay')
    if not spawnedRoot then
        spawnedRoot = Instance.new('Folder')
        spawnedRoot.Name = 'SpawnedDuringPlay'
        spawnedRoot.Parent = Workspace
    end

    local drops = spawnedRoot:FindFirstChild('Drops')
    if drops and drops:IsA('Folder') then
        return drops
    end

    drops = Instance.new('Folder')
    drops.Name = 'Drops'
    drops.Parent = spawnedRoot
    return drops
end

local function getDropStyle(kind: string, itemId: string?): { glow: Color3, shell: Color3, beam: Color3 }
    if kind == 'zeny' then
        return RARITY_STYLE.zeny
    end

    local itemDef = itemId and ItemData[itemId]
    local rarity = itemDef and itemDef.rarity or 'common'
    return RARITY_STYLE[rarity] or RARITY_STYLE.common
end

local function rollDropTable(dropTableId: string): (number, { DropItem })
    local dropTable = LootData[dropTableId]
    if not dropTable then
        return 0, {}
    end

    local zenyAmount = math.random(dropTable.zeny.min, dropTable.zeny.max)
    local items = {}

    for _, dropDef in ipairs(dropTable.drops) do
        if math.random() <= dropDef.chance then
            table.insert(items, {
                itemId = dropDef.itemId,
                amount = dropDef.amount,
            })
        end
    end

    return zenyAmount, items
end

local function playPickupSound(player: Player)
    local character = player.Character
    local rootPart = character and character:FindFirstChild('HumanoidRootPart')
    if not rootPart or not rootPart:IsA('BasePart') then
        return
    end

    local sound = Instance.new('Sound')
    sound.Name = 'LootPickupOneShot'
    sound.SoundId = GameConfig.LootPickupSoundId
    sound.Volume = GameConfig.LootPickupSoundVolume
    sound.RollOffMaxDistance = 36
    sound.Parent = rootPart
    sound:Play()
    Debris:AddItem(sound, 2)
end

local function createBaseModel(label: string, itemId: string?, kind: string?): Model
    local resolvedKind = kind or 'item'
    local style = getDropStyle(resolvedKind, itemId)
    local model = Instance.new('Model')
    model.Name = 'LootDrop'

    local root = Instance.new('Part')
    root.Name = 'PickupRoot'
    root.Size = Vector3.new(0.86, 0.24, 0.86)
    root.Anchored = true
    root.CanCollide = false
    root.Transparency = 1
    root.Parent = model
    model.PrimaryPart = root

    local core = Instance.new('Part')
    core.Name = 'Core'
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(0.58, 0.58, 0.58)
    core.Anchored = true
    core.CanCollide = false
    core.Material = Enum.Material.SmoothPlastic
    core.Color = style.shell
    core.Transparency = 0.34
    core.Parent = model

    local attachment = Instance.new('Attachment')
    attachment.Parent = core

    local sparkle = Instance.new('ParticleEmitter')
    sparkle.Name = 'Sparkle'
    sparkle.Texture = 'rbxassetid://243660364'
    sparkle.Rate = 2
    sparkle.Lifetime = NumberRange.new(0.2, 0.4)
    sparkle.Speed = NumberRange.new(0.05, 0.16)
    sparkle.SpreadAngle = Vector2.new(360, 360)
    sparkle.RotSpeed = NumberRange.new(-30, 30)
    sparkle.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparkle.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparkle.Color = ColorSequence.new(style.shell, style.beam)
    sparkle.Parent = attachment

    return model
end

local function buildZenyDrop(zenyAmount: number): Model
    return createBaseModel(string.format('%d Zeny', zenyAmount), nil, 'zeny')
end

local function buildItemDrop(itemId: string, amount: number): Model
    local itemDef = ItemData[itemId]
    local label = itemDef and string.format('%s x%d', itemDef.displayName, amount) or string.format('%s x%d', itemId, amount)
    local model = createBaseModel(label, itemId, itemDef and itemDef.toolKind == 'card' and 'card' or 'item')

    if itemDef then
        local icon = Instance.new('Part')
        icon.Name = 'Icon'
        icon.Shape = Enum.PartType.Ball
        icon.Size = Vector3.new(0.34, 0.34, 0.34)
        icon.Anchored = true
        icon.CanCollide = false
        icon.Material = Enum.Material.SmoothPlastic
        icon.Color = itemDef.handleColor or Color3.fromRGB(255, 255, 255)
        icon.Transparency = 0.18
        icon.Parent = model
    end

    return model
end

local function positionDropVisual(model: Model, position: Vector3)
    local root = model.PrimaryPart
    local core = model:FindFirstChild('Core')
    local icon = model:FindFirstChild('Icon')
    if not root or not root:IsA('BasePart') then
        return
    end

    local floorY = position.Y + 0.08
    root.CFrame = CFrame.new(position.X, floorY, position.Z)

    if core and core:IsA('BasePart') then
        core.CFrame = CFrame.new(position.X, floorY + 0.46, position.Z)
    end
    if icon and icon:IsA('BasePart') then
        icon.CFrame = CFrame.new(position.X, floorY + 0.44, position.Z)
    end
end

local function animateDropVisual(model: Model)
    local core = model:FindFirstChild('Core')
    if core and core:IsA('BasePart') then
        local pulse = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        TweenService:Create(core, pulse, { Size = core.Size + Vector3.new(0.06, 0.06, 0.06) }):Play()
    end
end

local function claimDrop(dropModel: Model, player: Player)
    local state = activeDrops[dropModel]
    if not state or state.claimed then
        return
    end
    state.claimed = true

    if state.zenyAmount > 0 then
        dependencies.PersistenceService.addZeny(player, state.zenyAmount)
    end

    for _, bundleItem in ipairs(state.items) do
        dependencies.InventoryService.addItem(player, bundleItem.itemId, bundleItem.amount)
    end

    playPickupSound(player)
    dependencies.Runtime.SystemMessage:FireClient(player, 'Picked up: ' .. state.label)

    activeDrops[dropModel] = nil
    dropModel:Destroy()
end

local function registerDrop(model: Model, state: DropState, sourceName: string?)
    model:SetAttribute('SourceName', sourceName or 'Enemy')
    model.Parent = dropFolder
    activeDrops[model] = state

    local prompt = Instance.new('ProximityPrompt')
    prompt.Name = 'PickupPrompt'
    prompt.ActionText = 'Loot'
    prompt.ObjectText = 'Drop'
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = math.min(GameConfig.LootPromptDistance, 6)
    prompt.Parent = model.PrimaryPart

    prompt.Triggered:Connect(function(player)
        claimDrop(model, player)
    end)

    Debris:AddItem(model, GameConfig.LootLifetime)
end

function LootService.init(deps)
    dependencies = deps
end

function LootService.start()
    dropFolder = ensureDropFolder()
    for _, child in ipairs(dropFolder:GetChildren()) do
        child:Destroy()
    end
    table.clear(activeDrops)
end

function LootService.spawnDropBundle(position: Vector3, dropTableId: string, _: Player?, sourceName: string?)
    if not dropFolder then
        dropFolder = ensureDropFolder()
    end

    local zenyAmount, items = rollDropTable(dropTableId)
    if zenyAmount <= 0 and #items == 0 then
        return
    end

    local mergedItems: { [string]: number } = {}
    for _, itemDrop in ipairs(items) do
        mergedItems[itemDrop.itemId] = (mergedItems[itemDrop.itemId] or 0) + math.max(itemDrop.amount or 1, 1)
    end

    local bundleItems: { DropItem } = {}
    for itemId, amount in pairs(mergedItems) do
        table.insert(bundleItems, {
            itemId = itemId,
            amount = amount,
        })
    end
    table.sort(bundleItems, function(a, b)
        return a.itemId < b.itemId
    end)

    local label = 'Loot Cache'
    if #bundleItems == 1 then
        local itemDef = ItemData[bundleItems[1].itemId]
        local base = itemDef and itemDef.displayName or bundleItems[1].itemId
        label = string.format('%s x%d', base, bundleItems[1].amount)
    elseif #bundleItems > 1 then
        label = string.format('Loot Cache (%d)', #bundleItems)
    elseif zenyAmount > 0 then
        label = string.format('%d Zeny', zenyAmount)
    end

    local primaryItem = bundleItems[1]
    local bundleModel = if primaryItem then buildItemDrop(primaryItem.itemId, primaryItem.amount) else buildZenyDrop(zenyAmount)
    positionDropVisual(bundleModel, position)
    animateDropVisual(bundleModel)
    registerDrop(bundleModel, {
        claimed = false,
        items = bundleItems,
        zenyAmount = zenyAmount,
        label = label,
    }, sourceName)
end

return LootService
