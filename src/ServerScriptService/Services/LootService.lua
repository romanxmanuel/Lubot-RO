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
    kind: string,
    itemId: string?,
    amount: number,
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

local function createBaseModel(label: string, kind: string, itemId: string?): Model
    local style = getDropStyle(kind, itemId)
    local model = Instance.new('Model')
    model.Name = 'LootDrop'

    local root = Instance.new('Part')
    root.Name = 'PickupRoot'
    root.Size = Vector3.new(1.4, 0.2, 1.4)
    root.Anchored = true
    root.CanCollide = false
    root.Transparency = 1
    root.Parent = model
    model.PrimaryPart = root

    local ring = Instance.new('Part')
    ring.Name = 'GroundRing'
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.12, 2.75, 2.75)
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = style.beam
    ring.Parent = model

    local shell = Instance.new('Part')
    shell.Name = 'Shell'
    shell.Shape = Enum.PartType.Ball
    shell.Size = Vector3.new(1.5, 1.5, 1.5)
    shell.Anchored = true
    shell.CanCollide = false
    shell.Material = Enum.Material.ForceField
    shell.Color = style.shell
    shell.Transparency = 0.28
    shell.Parent = model

    local core = Instance.new('Part')
    core.Name = 'Core'
    core.Shape = Enum.PartType.Ball
    core.Size = Vector3.new(0.9, 0.9, 0.9)
    core.Anchored = true
    core.CanCollide = false
    core.Material = Enum.Material.Neon
    core.Color = style.glow
    core.Parent = model

    local pointLight = Instance.new('PointLight')
    pointLight.Range = 12
    pointLight.Brightness = kind == 'card' and 3.4 or 2
    pointLight.Color = style.glow
    pointLight.Parent = core

    local attachment = Instance.new('Attachment')
    attachment.Parent = core

    local sparkle = Instance.new('ParticleEmitter')
    sparkle.Name = 'Sparkle'
    sparkle.Texture = kind == 'card' and 'rbxasset://textures/particles/sparkles_main.dds' or 'rbxassetid://243660364'
    sparkle.Rate = kind == 'card' and 18 or 8
    sparkle.Lifetime = NumberRange.new(0.35, 0.8)
    sparkle.Speed = NumberRange.new(0.2, 0.7)
    sparkle.SpreadAngle = Vector2.new(360, 360)
    sparkle.RotSpeed = NumberRange.new(-90, 90)
    sparkle.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, kind == 'card' and 0.32 or 0.18),
        NumberSequenceKeypoint.new(1, 0),
    })
    sparkle.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.08),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparkle.Color = ColorSequence.new(style.shell, style.glow)
    sparkle.Parent = attachment

    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'LootBillboard'
    billboard.Size = UDim2.fromOffset(kind == 'card' and 176 or 150, kind == 'card' and 140 or 36)
    billboard.StudsOffset = Vector3.new(0, kind == 'card' and 3.25 or 2.1, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = GameConfig.LootBillboardDistance
    billboard.Parent = root

    if kind == 'card' then
        local frame = Instance.new('Frame')
        frame.Size = UDim2.fromOffset(88, 120)
        frame.Position = UDim2.fromScale(0.5, 0.5)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundColor3 = Color3.fromRGB(29, 21, 18)
        frame.BorderSizePixel = 0
        frame.Parent = billboard

        local frameCorner = Instance.new('UICorner')
        frameCorner.CornerRadius = UDim.new(0, 10)
        frameCorner.Parent = frame

        local frameStroke = Instance.new('UIStroke')
        frameStroke.Color = style.glow
        frameStroke.Thickness = 2
        frameStroke.Parent = frame

        local art = Instance.new('ImageLabel')
        art.Name = 'CardArt'
        art.Size = UDim2.fromOffset(68, 68)
        art.Position = UDim2.new(0.5, 0, 0, 10)
        art.AnchorPoint = Vector2.new(0.5, 0)
        art.BackgroundTransparency = 1
        art.Image = 'rbxasset://textures/particles/sparkles_main.dds'
        art.ImageColor3 = style.glow
        art.Parent = frame

        local tag = Instance.new('TextLabel')
        tag.BackgroundTransparency = 1
        tag.Size = UDim2.new(1, -10, 0, 18)
        tag.Position = UDim2.new(0, 5, 1, -44)
        tag.Font = Enum.Font.GothamBlack
        tag.TextScaled = true
        tag.TextColor3 = Color3.fromRGB(255, 246, 200)
        tag.Text = 'CARD'
        tag.Parent = frame

        local nameLabel = Instance.new('TextLabel')
        nameLabel.BackgroundTransparency = 1
        nameLabel.Size = UDim2.new(1, -10, 0, 22)
        nameLabel.Position = UDim2.new(0, 5, 1, -24)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextWrapped = true
        nameLabel.TextScaled = true
        nameLabel.TextColor3 = Color3.fromRGB(255, 245, 226)
        nameLabel.Text = label
        nameLabel.Parent = frame
    else
        local labelNode = Instance.new('TextLabel')
        labelNode.Size = UDim2.fromScale(1, 1)
        labelNode.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
        labelNode.BackgroundTransparency = 0.22
        labelNode.BorderSizePixel = 0
        labelNode.Font = Enum.Font.GothamBold
        labelNode.TextScaled = true
        labelNode.TextColor3 = Color3.fromRGB(255, 245, 214)
        labelNode.TextStrokeTransparency = 0.55
        labelNode.Text = label
        labelNode.Parent = billboard

        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = labelNode

        local stroke = Instance.new('UIStroke')
        stroke.Color = style.beam
        stroke.Thickness = 1.1
        stroke.Transparency = 0.3
        stroke.Parent = labelNode
    end

    return model
end

local function buildZenyDrop(zenyAmount: number): Model
    return createBaseModel(string.format('%d Zeny', zenyAmount), 'zeny', nil)
end

local function buildItemDrop(itemId: string, amount: number): Model
    local itemDef = ItemData[itemId]
    local label = itemDef and string.format('%s x%d', itemDef.displayName, amount) or string.format('%s x%d', itemId, amount)
    local kind = itemDef and itemDef.toolKind == 'card' and 'card' or 'item'
    local model = createBaseModel(label, kind, itemId)

    if itemDef and itemDef.toolKind ~= 'card' then
        local icon = Instance.new('Part')
        icon.Name = 'Icon'
        icon.Shape = Enum.PartType.Ball
        icon.Size = Vector3.new(0.52, 0.52, 0.52)
        icon.Anchored = true
        icon.CanCollide = false
        icon.Material = Enum.Material.Neon
        icon.Color = itemDef.handleColor or Color3.fromRGB(255, 255, 255)
        icon.Parent = model
    end

    return model
end

local function positionDropVisual(model: Model, position: Vector3)
    local root = model.PrimaryPart
    local ring = model:FindFirstChild('GroundRing')
    local shell = model:FindFirstChild('Shell')
    local core = model:FindFirstChild('Core')
    local icon = model:FindFirstChild('Icon')
    if not root or not root:IsA('BasePart') then
        return
    end

    local floorY = position.Y + 0.08
    root.CFrame = CFrame.new(position.X, floorY, position.Z)

    if ring and ring:IsA('BasePart') then
        ring.CFrame = CFrame.new(position.X, floorY + 0.03, position.Z) * CFrame.Angles(0, 0, math.rad(90))
    end
    if shell and shell:IsA('BasePart') then
        shell.CFrame = CFrame.new(position.X, floorY + 0.78, position.Z)
    end
    if core and core:IsA('BasePart') then
        core.CFrame = CFrame.new(position.X, floorY + 0.62, position.Z)
    end
    if icon and icon:IsA('BasePart') then
        icon.CFrame = CFrame.new(position.X, floorY + 0.58, position.Z)
    end
end

local function animateDropVisual(model: Model, kind: string)
    local ring = model:FindFirstChild('GroundRing')
    local shell = model:FindFirstChild('Shell')
    local core = model:FindFirstChild('Core')
    if ring and ring:IsA('BasePart') then
        local pulse = TweenInfo.new(kind == 'card' and 0.55 or 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        TweenService:Create(ring, pulse, { Size = Vector3.new(ring.Size.X, ring.Size.Y + 0.32, ring.Size.Z + 0.32) }):Play()
    end
    if shell and shell:IsA('BasePart') then
        local pulse = TweenInfo.new(kind == 'card' and 0.45 or 0.95, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        TweenService:Create(shell, pulse, { Size = shell.Size + Vector3.new(0.18, 0.18, 0.18) }):Play()
    end
    if core and core:IsA('BasePart') then
        local pulse = TweenInfo.new(kind == 'card' and 0.35 or 0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        TweenService:Create(core, pulse, { Size = core.Size + Vector3.new(0.12, 0.12, 0.12) }):Play()
    end
end

local function claimDrop(dropModel: Model, player: Player)
    local state = activeDrops[dropModel]
    if not state or state.claimed then
        return
    end
    state.claimed = true

    if state.kind == 'zeny' then
        dependencies.PersistenceService.addZeny(player, state.zenyAmount)
    elseif state.itemId then
        dependencies.InventoryService.addItem(player, state.itemId, state.amount)
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
    prompt.ActionText = 'Pick Up'
    prompt.ObjectText = state.label
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = GameConfig.LootPromptDistance
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

    local offsets = {
        Vector3.new(0, 0, 0),
        Vector3.new(1.8, 0, 0.6),
        Vector3.new(-1.7, 0, 0.7),
        Vector3.new(0.8, 0, -1.8),
        Vector3.new(-0.9, 0, -1.7),
        Vector3.new(2.2, 0, -0.9),
        Vector3.new(-2.1, 0, -1.0),
    }

    local offsetIndex = 1
    if zenyAmount > 0 then
        local zenyDrop = buildZenyDrop(zenyAmount)
        positionDropVisual(zenyDrop, position + offsets[offsetIndex])
        animateDropVisual(zenyDrop, 'zeny')
        registerDrop(zenyDrop, {
            claimed = false,
            kind = 'zeny',
            itemId = nil,
            amount = 0,
            zenyAmount = zenyAmount,
            label = string.format('%d Zeny', zenyAmount),
        }, sourceName)
        offsetIndex += 1
    end

    for _, itemDrop in ipairs(items) do
        local itemDef = ItemData[itemDrop.itemId]
        local itemLabel = itemDef and string.format('%s x%d', itemDef.displayName, itemDrop.amount) or string.format('%s x%d', itemDrop.itemId, itemDrop.amount)
        local itemModel = buildItemDrop(itemDrop.itemId, itemDrop.amount)
        positionDropVisual(itemModel, position + offsets[math.min(offsetIndex, #offsets)])
        animateDropVisual(itemModel, itemDef and itemDef.rarity == 'card' and 'card' or 'item')
        registerDrop(itemModel, {
            claimed = false,
            kind = 'item',
            itemId = itemDrop.itemId,
            amount = itemDrop.amount,
            zenyAmount = 0,
            label = itemLabel,
        }, sourceName)
        offsetIndex += 1
    end
end

return LootService
