--!strict

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)
local WarpsData = require(ReplicatedStorage.GameData.Warps.WarpsData)
local WorldData = require(ReplicatedStorage.GameData.Worlds.WorldData)

local WorldServiceV2 = {
    Name = 'WorldService',
}

local dependencies = nil
local aliasToWarpId = {}
local randomTeleportStates: { [Player]: number } = {}

local function ensureFolder(parent: Instance, name: string): Folder
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA('Folder') then
        return existing
    end

    local folder = Instance.new('Folder')
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function buildAliasIndex()
    table.clear(aliasToWarpId)
    for warpId, warpDef in pairs(WarpsData) do
        aliasToWarpId[string.lower(warpId)] = warpId
        for _, alias in ipairs(warpDef.aliases or {}) do
            aliasToWarpId[string.lower(alias)] = warpId
        end
    end
end

local function resolveWarpId(query: string): string?
    if query == '' then
        return nil
    end
    return aliasToWarpId[string.lower(query)]
end

local function findWarpCFrame(warpId: string): CFrame?
    local warpDef = WarpsData[warpId]
    if not warpDef then
        return nil
    end
    return warpDef.spawnCFrame
end

local function getMapsFolder(): Folder?
    local mapsFolder = Workspace:FindFirstChild('Maps')
    if mapsFolder and mapsFolder:IsA('Folder') then
        return mapsFolder
    end
    return nil
end

local function getPlayerUseFolder(mapFolder: Folder): Folder
    return ensureFolder(mapFolder, 'PlayerUse')
end

local function cleanupLegacyWorldArtifacts()
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA('Model') and child.Name == 'Voidborn Leviathan' then
            child:Destroy()
        end
    end
end

local function clearLegacyTownGateArtifacts(zoltraakPlayerUse: Folder)
    local legacyNames = {
        FieldGate = true,
        FieldPortalGlow = true,
        FieldPortalFrameLeft = true,
        FieldPortalFrameRight = true,
        FieldPortalCap = true,
        FieldPortalBase = true,
        FieldPortalPreview = true,
        FieldGateArchTop = true,
        FieldGateArchLeft = true,
        FieldGateArchRight = true,
        DungeonEntrance = true,
        DungeonArchTop = true,
        DungeonArchLeft = true,
        DungeonArchRight = true,
    }

    local townModel = zoltraakPlayerUse:FindFirstChild('TownPlayerUse')
    if townModel and townModel:IsA('Model') then
        for _, child in ipairs(townModel:GetChildren()) do
            if legacyNames[child.Name] then
                child:Destroy()
            end
        end
    end

    local ring = zoltraakPlayerUse:FindFirstChild('WarpGateRing')
    if ring then
        ring:Destroy()
    end
end

local function buildGateLabel(parent: Instance, title: string, subtitle: string)
    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'GateLabel'
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = GameConfig.WarpGateLabelDistance
    billboard.Size = UDim2.fromOffset(190, 54)
    billboard.StudsOffset = Vector3.new(0, 7.8, 0)
    billboard.Parent = parent

    local frame = Instance.new('Frame')
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(10, 18, 32)
    frame.BackgroundTransparency = 0.18
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    local stroke = Instance.new('UIStroke')
    stroke.Color = Color3.fromRGB(216, 238, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.15
    stroke.Parent = frame

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local titleLabel = Instance.new('TextLabel')
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.fromOffset(12, 6)
    titleLabel.Size = UDim2.new(1, -24, 0, 24)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(244, 248, 255)
    titleLabel.TextScaled = false
    titleLabel.TextSize = 17
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.Parent = frame

    local subtitleLabel = Instance.new('TextLabel')
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Position = UDim2.fromOffset(12, 26)
    subtitleLabel.Size = UDim2.new(1, -24, 0, 18)
    subtitleLabel.Font = Enum.Font.GothamMedium
    subtitleLabel.Text = subtitle
    subtitleLabel.TextColor3 = Color3.fromRGB(183, 211, 235)
    subtitleLabel.TextSize = 12
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
    subtitleLabel.Parent = frame
end

local function createEpicGate(parent: Instance, spec, gateCFrame: CFrame, scale: number, isReturn: boolean)
    local gateModel = Instance.new('Model')
    gateModel.Name = spec.name
    gateModel:SetAttribute('DestinationWarpId', spec.destinationWarpId)
    gateModel.Parent = parent

    local color = spec.color or Color3.fromRGB(92, 244, 161)
    local accent = color:Lerp(Color3.new(1, 1, 1), 0.35)
    local darkMetal = Color3.fromRGB(23, 29, 40)
    local portalSize = isReturn and Vector3.new(4.8, 5.8, 0.45) or Vector3.new(6.6, 7.6, 0.55)
    local rootSize = isReturn and Vector3.new(5.4, 7.4, 4.8) or Vector3.new(7.2, 8.6, 5.6)

    local root = Instance.new('Part')
    root.Name = 'Root'
    root.Anchored = true
    root.Transparency = 1
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.Size = rootSize * scale
    root.CFrame = gateCFrame
    root.Parent = gateModel
    gateModel.PrimaryPart = root

    local function makePart(name: string, size: Vector3, offset: CFrame, material: Enum.Material, partColor: Color3, transparency: number?, shape: Enum.PartType?)
        local part = Instance.new('Part')
        part.Name = name
        part.Anchored = true
        part.CanCollide = false
        part.Material = material
        part.Color = partColor
        part.Transparency = transparency or 0
        if shape then
            part.Shape = shape
        end
        part.Size = size * scale
        part.CFrame = gateCFrame * offset
        part.Parent = gateModel
        return part
    end

    local base = makePart('Base', Vector3.new(8.4, 1.1, 3.8), CFrame.new(0, -3.25, 0), Enum.Material.Slate, darkMetal)
    local plinth = makePart('Plinth', Vector3.new(7.2, 0.45, 4.6), CFrame.new(0, -2.45, 0), Enum.Material.Metal, Color3.fromRGB(58, 72, 90))
    local sigil = makePart('Sigil', Vector3.new(8.8, 0.22, 8.8), CFrame.new(0, -3.54, 0) * CFrame.Angles(math.rad(90), 0, 0), Enum.Material.Neon, color, 0.18, Enum.PartType.Cylinder)
    local leftPillar = makePart('LeftPillar', Vector3.new(1.1, 6.8, 1.2), CFrame.new(-3.0, 0, 0), Enum.Material.Metal, darkMetal)
    local rightPillar = makePart('RightPillar', Vector3.new(1.1, 6.8, 1.2), CFrame.new(3.0, 0, 0), Enum.Material.Metal, darkMetal)
    local archTop = makePart('ArchTop', Vector3.new(6.8, 1.0, 1.2), CFrame.new(0, 3.4, 0), Enum.Material.Metal, darkMetal)
    local archGlow = makePart('ArchGlow', Vector3.new(6.1, 0.32, 0.55), CFrame.new(0, 3.4, -0.38), Enum.Material.Neon, accent, 0.1)
    local portal = makePart('Portal', portalSize, CFrame.new(0, 0, -0.25), Enum.Material.ForceField, color, 0.22)
    local inner = makePart('PortalInner', Vector3.new(portalSize.X * 0.84, portalSize.Y * 0.84, 0.18), CFrame.new(0, 0, -0.55), Enum.Material.Neon, accent, 0.28)
    local crown = makePart('Crown', Vector3.new(2.1, 0.55, 0.9), CFrame.new(0, 4.2, -0.12), Enum.Material.Neon, accent, 0.06)
    local leftShard = makePart('LeftShard', Vector3.new(0.4, 2.4, 0.4), CFrame.new(-3.55, 1.3, 0) * CFrame.Angles(0, 0, math.rad(18)), Enum.Material.Neon, accent, 0.08)
    local rightShard = makePart('RightShard', Vector3.new(0.4, 2.4, 0.4), CFrame.new(3.55, 1.3, 0) * CFrame.Angles(0, 0, math.rad(-18)), Enum.Material.Neon, accent, 0.08)

    local prompt = Instance.new('ProximityPrompt')
    prompt.Name = 'TravelPrompt'
    prompt.ActionText = isReturn and 'Return' or 'Warp'
    prompt.ObjectText = spec.promptText
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = isReturn and 13 or 15
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.RequiresLineOfSight = false
    prompt.Parent = root

    prompt.Triggered:Connect(function(player)
        WorldServiceV2.warpPlayer(player, spec.destinationWarpId)
    end)

    local light = Instance.new('PointLight')
    light.Range = isReturn and 20 or 24
    light.Brightness = isReturn and 1.8 or 2.4
    light.Color = color
    light.Parent = portal

    local attachment0 = Instance.new('Attachment')
    attachment0.Position = Vector3.new(0, portal.Size.Y * 0.45, 0)
    attachment0.Parent = portal

    local attachment1 = Instance.new('Attachment')
    attachment1.Position = Vector3.new(0, -portal.Size.Y * 0.45, 0)
    attachment1.Parent = portal

    local trail = Instance.new('Trail')
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    trail.FaceCamera = true
    trail.Lifetime = 0.22
    trail.MinLength = 0.05
    trail.Color = ColorSequence.new(color, accent)
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.25),
        NumberSequenceKeypoint.new(1, 0.95),
    })
    trail.Parent = portal

    local particles = Instance.new('ParticleEmitter')
    particles.Color = ColorSequence.new(color, accent)
    particles.LightEmission = 0.75
    particles.Lifetime = NumberRange.new(0.6, 0.95)
    particles.Rate = isReturn and 16 or 24
    particles.Speed = NumberRange.new(0.6, 1.5)
    particles.SpreadAngle = Vector2.new(40, 40)
    particles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.22),
        NumberSequenceKeypoint.new(0.5, 0.38),
        NumberSequenceKeypoint.new(1, 0),
    })
    particles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.6, 0.55),
        NumberSequenceKeypoint.new(1, 1),
    })
    particles.Parent = portal

    buildGateLabel(root, spec.labelText, spec.subtitleText)

    for _, part in ipairs({ base, plinth, sigil, leftPillar, rightPillar, archTop, archGlow, portal, inner, crown, leftShard, rightShard }) do
        part:SetAttribute('WarpGate', true)
    end

    return gateModel
end

local function getTownGateCFrame(index: number, total: number): CFrame
    local center = WorldData.townGateCenter
    local startAngle = math.rad(WorldData.townGateStartAngleDegrees or 0)
    local angle = startAngle + ((math.pi * 2) * ((index - 1) / math.max(1, total)))
    local position = center + Vector3.new(math.cos(angle) * WorldData.townGateRadius, 0, math.sin(angle) * WorldData.townGateRadius)
    return CFrame.lookAt(position, center)
end

local function getReturnGateCFrame(warpId: string): CFrame?
    local warpCFrame = findWarpCFrame(warpId)
    if not warpCFrame then
        return nil
    end

    local right = warpCFrame.RightVector
    local offset = right * WorldData.returnGateDistance + Vector3.new(0, WorldData.returnGateHeightOffset, 0)
    local position = warpCFrame.Position + offset
    return CFrame.lookAt(position, warpCFrame.Position)
end

local function layoutTownNpcRing(zoltraakPlayerUse: Folder)
    local townModel = zoltraakPlayerUse:FindFirstChild('TownPlayerUse')
    if not townModel or not townModel:IsA('Model') then
        return
    end

    local prefixToParts: { [string]: { BasePart } } = {}
    for _, child in ipairs(townModel:GetChildren()) do
        if child:IsA('BasePart') then
            for _, group in ipairs(WorldData.townNpcRing or {}) do
                if string.sub(child.Name, 1, #group.prefix) == group.prefix then
                    prefixToParts[group.prefix] = prefixToParts[group.prefix] or {}
                    table.insert(prefixToParts[group.prefix], child)
                    break
                end
            end
        end
    end

    local center = WorldData.townNpcCenter
    for _, group in ipairs(WorldData.townNpcRing or {}) do
        local parts = prefixToParts[group.prefix]
        if parts and #parts > 0 then
            local pivot = Vector3.zero
            for _, part in ipairs(parts) do
                pivot += part.Position
            end
            pivot /= #parts

            local angle = math.rad(group.angleDegrees)
            local target = center + Vector3.new(math.cos(angle) * WorldData.townNpcRadius, 0, math.sin(angle) * WorldData.townNpcRadius)
            local delta = target - pivot

            for _, part in ipairs(parts) do
                part.CFrame += delta
            end
        end
    end
end

local function ensureWorldPrompts()
    local mapsFolder = getMapsFolder()
    if not mapsFolder then
        return
    end

    local zoltraak = mapsFolder:FindFirstChild(WorldData.startMapId)
    if zoltraak and zoltraak:IsA('Folder') then
        local playerUse = getPlayerUseFolder(zoltraak)
        clearLegacyTownGateArtifacts(playerUse)
        layoutTownNpcRing(playerUse)

        local ringFolder = ensureFolder(playerUse, 'WarpGateRing')
        ringFolder:ClearAllChildren()

        local gateSpecs = WorldData.townGateSpecs or {}
        for index, gateSpec in ipairs(gateSpecs) do
            local warpDef = WarpsData[gateSpec.warpId]
            if warpDef then
                createEpicGate(ringFolder, {
                    name = string.format('Gate_%s', gateSpec.warpId),
                    destinationWarpId = gateSpec.warpId,
                    promptText = warpDef.displayName,
                    labelText = gateSpec.label or warpDef.displayName,
                    subtitleText = 'Press E to warp',
                    color = gateSpec.color,
                }, getTownGateCFrame(index, #gateSpecs), 1, false)
            end
        end
    end

    for warpId, warpDef in pairs(WarpsData) do
        if warpId ~= WorldData.startWarpId then
            local mapName = nil
            for _, child in ipairs(mapsFolder:GetChildren()) do
                if child:IsA('Folder') and string.lower(child.Name) == string.lower(warpDef.displayName:gsub('%s+', '')) then
                    mapName = child.Name
                    break
                end
            end

            if not mapName then
                local fallback = ({
                    prontera_field = 'PronteraField',
                    ant_hell = 'AntHell',
                    ice_moon = 'IceMoon',
                    abyss_sanctuary = 'AbyssSanctuary',
                    tower_of_ascension = 'TowerOfAscension',
                    bloody_church = 'BloodyChurch',
                    abandoned_church = 'AbandonedChurch',
                    abandoned_gothic_church = 'AbandonedGothicChurch',
                    church_of_lost_souls = 'ChurchOfLostSouls',
                    niffheim = 'Niffheim',
                    lubidrium = 'Lubidrium',
                })[warpId]
                mapName = fallback
            end

            local mapFolder = mapName and mapsFolder:FindFirstChild(mapName)
            if mapFolder and mapFolder:IsA('Folder') then
                local playerUse = getPlayerUseFolder(mapFolder)
                local existing = playerUse:FindFirstChild('ReturnGate')
                if existing then
                    existing:Destroy()
                end

                local returnGateCFrame = getReturnGateCFrame(warpId)
                if returnGateCFrame then
                    createEpicGate(playerUse, {
                        name = 'ReturnGate',
                        destinationWarpId = WorldData.startWarpId,
                        promptText = 'Return to Zoltraak',
                        labelText = 'Return',
                        subtitleText = 'Press E for town',
                        color = Color3.fromRGB(120, 214, 255),
                    }, returnGateCFrame, 0.78, true)
                end
            end
        end
    end
end

local function getMapBoxes(mapFolder: Instance): { BasePart }
    local boxes = {}
    for _, descendant in ipairs(mapFolder:GetDescendants()) do
        if descendant:IsA('BasePart') and descendant.Name == 'MapBox' then
            table.insert(boxes, descendant)
        end
    end
    return boxes
end

local function containsPoint(box: BasePart, position: Vector3): boolean
    local localPoint = box.CFrame:PointToObjectSpace(position)
    local half = box.Size * 0.5
    return math.abs(localPoint.X) <= half.X
        and math.abs(localPoint.Y) <= half.Y
        and math.abs(localPoint.Z) <= half.Z
end

local function getBoxPriority(box: BasePart): number
    local value = box:GetAttribute('Priority')
    if typeof(value) == 'number' then
        return value
    end
    return 0
end

local function getBoxVolume(box: BasePart): number
    return box.Size.X * box.Size.Y * box.Size.Z
end

local function findCurrentMapFolder(position: Vector3): Folder?
    local mapsFolder = getMapsFolder()
    if not mapsFolder then
        return nil
    end

    local bestMap = nil
    local bestPriority = -math.huge
    local bestVolume = math.huge

    for _, child in ipairs(mapsFolder:GetChildren()) do
        if child:IsA('Folder') then
            for _, box in ipairs(getMapBoxes(child)) do
                if containsPoint(box, position) then
                    local priority = getBoxPriority(box)
                    local volume = getBoxVolume(box)
                    if priority > bestPriority or (priority == bestPriority and volume < bestVolume) then
                        bestMap = child
                        bestPriority = priority
                        bestVolume = volume
                    end
                end
            end
        end
    end

    return bestMap
end

local function chooseRandomMapBox(mapFolder: Folder): BasePart?
    local boxes = getMapBoxes(mapFolder)
    if #boxes == 0 then
        return nil
    end

    local totalWeight = 0
    for _, box in ipairs(boxes) do
        totalWeight += math.max(1, box.Size.X * box.Size.Z)
    end

    local roll = math.random() * totalWeight
    local running = 0
    for _, box in ipairs(boxes) do
        running += math.max(1, box.Size.X * box.Size.Z)
        if roll <= running then
            return box
        end
    end

    return boxes[#boxes]
end

local function getTeleportAnchors(mapFolder: Folder): { BasePart }
    local anchors = {}
    local folderNames = { 'Spawn', 'WarpPoints', 'MonsterSpawnPoints', 'BossSpawnPoints', 'NPCPoints' }

    for _, folderName in ipairs(folderNames) do
        local folder = mapFolder:FindFirstChild(folderName)
        if folder then
            for _, descendant in ipairs(folder:GetDescendants()) do
                if descendant:IsA('BasePart') and descendant.Name ~= 'MapBox' then
                    table.insert(anchors, descendant)
                end
            end
        end
    end

    return anchors
end

local function getRaycastParams(character: Model, mapBox: BasePart): RaycastParams
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local excludes = { character, mapBox }
    local spawned = Workspace:FindFirstChild('SpawnedDuringPlay')
    if spawned then
        table.insert(excludes, spawned)
    end

    params.FilterDescendantsInstances = excludes
    params.IgnoreWater = false
    return params
end

local function isSafeTeleportTarget(mapFolder: Folder, position: Vector3, character: Model): boolean
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = { character }

    local hits = Workspace:GetPartBoundsInBox(
        CFrame.new(position + Vector3.new(0, GameConfig.RandomTeleportClearanceHeight * 0.5, 0)),
        Vector3.new(4, GameConfig.RandomTeleportClearanceHeight, 4),
        overlapParams
    )

    local warpPoints = mapFolder:FindFirstChild('WarpPoints')
    for _, part in ipairs(hits) do
        local isWarpMarker = warpPoints and part:IsDescendantOf(warpPoints) or false
        if part.CanCollide and part.Transparency < 1 and not isWarpMarker then
            return false
        end
    end

    return true
end

local function findRandomTeleportCFrame(player: Player): CFrame?
    local character = player.Character
    if not character then
        return nil
    end

    local root = character:FindFirstChild('HumanoidRootPart')
    if not root or not root:IsA('BasePart') then
        return nil
    end

    local mapFolder = findCurrentMapFolder(root.Position)
    if not mapFolder then
        return nil
    end

    for _ = 1, GameConfig.RandomTeleportAttempts do
        local mapBox = chooseRandomMapBox(mapFolder)
        if not mapBox then
            break
        end

        local half = mapBox.Size * 0.5
        local padding = math.min(GameConfig.RandomTeleportProbePadding, half.X - 1, half.Z - 1)
        local x = (math.random() * 2 - 1) * math.max(1, half.X - math.max(0, padding))
        local z = (math.random() * 2 - 1) * math.max(1, half.Z - math.max(0, padding))
        local origin = mapBox.CFrame:PointToWorldSpace(Vector3.new(x, half.Y + 6, z))
        local direction = Vector3.new(0, -(mapBox.Size.Y + 24), 0)

        local result = Workspace:Raycast(origin, direction, getRaycastParams(character, mapBox))
        if result and result.Instance and result.Instance:IsDescendantOf(mapFolder) and result.Normal.Y >= 0.45 then
            local targetPosition = result.Position + Vector3.new(0, GameConfig.RandomTeleportSurfaceOffset, 0)
            if isSafeTeleportTarget(mapFolder, targetPosition, character) then
                local look = root.CFrame.LookVector
                local planarLook = Vector3.new(look.X, 0, look.Z)
                if planarLook.Magnitude <= 0.001 then
                    planarLook = Vector3.new(0, 0, -1)
                end
                return CFrame.lookAt(targetPosition, targetPosition + planarLook.Unit)
            end
        end
    end

    local anchors = getTeleportAnchors(mapFolder)
    if #anchors > 0 then
        for _ = 1, GameConfig.RandomTeleportAttempts do
            local anchor = anchors[math.random(1, #anchors)]
            local jitter = Vector3.new(math.random(-18, 18), 0, math.random(-18, 18))
            local origin = anchor.Position + Vector3.new(0, GameConfig.RandomTeleportClearanceHeight + 12, 0) + jitter
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { character }

            local result = Workspace:Raycast(origin, Vector3.new(0, -(GameConfig.RandomTeleportClearanceHeight + 36), 0), params)
            if result and result.Instance and result.Instance:IsDescendantOf(mapFolder) and result.Normal.Y >= 0.45 then
                local targetPosition = result.Position + Vector3.new(0, GameConfig.RandomTeleportSurfaceOffset, 0)
                if isSafeTeleportTarget(mapFolder, targetPosition, character) then
                    local look = root.CFrame.LookVector
                    local planarLook = Vector3.new(look.X, 0, look.Z)
                    if planarLook.Magnitude <= 0.001 then
                        planarLook = Vector3.new(0, 0, -1)
                    end
                    return CFrame.lookAt(targetPosition, targetPosition + planarLook.Unit)
                end
            end
        end

        local anchor = anchors[math.random(1, #anchors)]
        local anchorJitter = Vector3.new(
            math.random(-GameConfig.RandomTeleportAnchorJitter, GameConfig.RandomTeleportAnchorJitter),
            0,
            math.random(-GameConfig.RandomTeleportAnchorJitter, GameConfig.RandomTeleportAnchorJitter)
        )
        local anchorPosition = anchor.Position + anchorJitter + Vector3.new(0, GameConfig.RandomTeleportSurfaceOffset, 0)
        local look = root.CFrame.LookVector
        local planarLook = Vector3.new(look.X, 0, look.Z)
        if planarLook.Magnitude <= 0.001 then
            planarLook = Vector3.new(0, 0, -1)
        end
        return CFrame.lookAt(anchorPosition, anchorPosition + planarLook.Unit)
    end

    return nil
end

local function moveCharacterToWarp(player: Player, warpId: string)
    local warpCFrame = findWarpCFrame(warpId)
    if not warpCFrame then
        return false
    end

    local character = player.Character
    if not character then
        return false
    end

    character:PivotTo(warpCFrame)
    dependencies.PersistenceService.setLastWarpId(player, warpId)
    return true
end

function WorldServiceV2.init(deps)
    dependencies = deps
end

function WorldServiceV2.start()
    buildAliasIndex()
    cleanupLegacyWorldArtifacts()
    ensureWorldPrompts()
    task.delay(2, cleanupLegacyWorldArtifacts)

    local function onCharacterAdded(player: Player, character: Model)
        task.defer(function()
            local root = character:WaitForChild('HumanoidRootPart', 10)
            if not root then
                return
            end

            local profile = dependencies.PersistenceService.waitForProfile(player, 10)
            if not profile then
                return
            end

            local warpId = profile.lastWarpId
            if warpId == '' then
                warpId = GameConfig.StartingWarpId
            end
            moveCharacterToWarp(player, warpId)
        end)
    end

    local function bindPlayer(player: Player)
        player.CharacterAdded:Connect(function(character)
            onCharacterAdded(player, character)
        end)

        if player.Character then
            onCharacterAdded(player, player.Character)
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        bindPlayer(player)
    end
    Players.PlayerAdded:Connect(bindPlayer)

    dependencies.Runtime.ActionRequest.OnServerEvent:Connect(function(player, payload)
        if type(payload) ~= 'table' then
            return
        end
        if payload.action == MMONet.Actions.Warp then
            local query = tostring(payload.query or payload.warpId or '')
            local warpId = resolveWarpId(query)
            if not warpId then
                dependencies.Runtime.SystemMessage:FireClient(player, string.format('Unknown warp: %s', query))
                return
            end

            if not moveCharacterToWarp(player, warpId) then
                dependencies.Runtime.SystemMessage:FireClient(player, string.format('Could not warp to %s.', warpId))
                return
            end

            dependencies.Runtime.SystemMessage:FireClient(player, string.format('Warped to %s.', WarpsData[warpId].displayName))
            return
        end

        if payload.action == MMONet.Actions.RandomTeleport then
            local now = os.clock()
            local lastUsedAt = randomTeleportStates[player] or 0
            if now - lastUsedAt < GameConfig.RandomTeleportCooldown then
                return
            end

            local targetCFrame = findRandomTeleportCFrame(player)
            if not targetCFrame then
                dependencies.Runtime.SystemMessage:FireClient(player, 'Could not find a safe random spot in this map.')
                return
            end

            randomTeleportStates[player] = now
            local character = player.Character
            if not character then
                return
            end

            character:PivotTo(targetCFrame)
        end
    end)
end

function WorldServiceV2.warpPlayer(player: Player, warpId: string)
    return moveCharacterToWarp(player, warpId)
end

return WorldServiceV2
