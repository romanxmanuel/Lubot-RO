--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')

local EnemyService = require(script.Parent.EnemyService)

local WorldService = {}

local worldRefs = {}
local TOWN_BILLBOARD_MAX_DISTANCE = 280
local TOWER_OF_ASCENSION_POSITION = Vector3.new(-172, 101, -96)
local TOWER_OF_ASCENSION_FALLBACK_TARGET = Vector3.new(-258, 150, -187)
local NIFFHEIM_CENTER = Vector3.new(1680, 0, 1280)
local NIFFHEIM_SPAWN_POSITION = Vector3.new(1428, 4, 1258)
local NIFFHEIM_GATE_TOWN_POSITION = Vector3.new(0, 5, -92)
local NIFFHEIM_RETURN_GATE_POSITION = Vector3.new(1488, 5, 1284)
local teleportRng = Random.new()
local WARP_LIFT = Vector3.new(0, 3.5, 0)

type WarpDestination = {
    aliases: { string },
    center: Vector3,
    cframe: CFrame,
    displayName: string,
    mapFolder: Folder,
    number: number?,
    primaryAlias: string,
    size: Vector2,
    zoneId: string,
}

type MapBoxZone = {
    center: Vector3,
    displayName: string,
    mapFolder: Folder,
    part: BasePart,
    priority: number,
    size: Vector2,
    sortArea: number,
    zoneId: string,
}

local function findNamedDescendant(parent: Instance, name: string, className: string?)
    for _, descendant in ipairs(parent:GetDescendants()) do
        if descendant.Name == name and (not className or descendant.ClassName == className) then
            return descendant
        end
    end

    return nil
end

local function ensureFolder(parent: Instance, name: string)
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing
    end

    local folder = Instance.new('Folder')
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
    local part = parent:FindFirstChild(name)
    if not part then
        part = findNamedDescendant(parent, name, 'Part')
    end
    if not (part and part:IsA('Part')) then
        part = Instance.new('Part')
        part.Name = name
        part.Parent = parent
    end

    part.Size = size
    part.CFrame = cframe
    part.Anchored = true
    part.CanCollide = true
    part.Material = material or Enum.Material.SmoothPlastic
    part.Color = color
    part.Shape = shape or Enum.PartType.Block
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    return part
end

local function createSpawnLocation(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3)
    local spawn = parent:FindFirstChild(name)
    if not spawn then
        spawn = findNamedDescendant(parent, name, 'SpawnLocation')
    end
    if not (spawn and spawn:IsA('SpawnLocation')) then
        spawn = Instance.new('SpawnLocation')
        spawn.Name = name
        spawn.Parent = parent
    end

    spawn.Size = size
    spawn.Position = position
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Material = Enum.Material.Neon
    spawn.Color = color
    return spawn
end

local function createPrompt(part: BasePart, actionText: string, objectText: string, name: string)
    local prompt = part:FindFirstChild(name)
    if prompt and prompt:IsA('ProximityPrompt') then
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        return prompt
    end

    prompt = Instance.new('ProximityPrompt')
    prompt.Name = name
    prompt.ActionText = actionText
    prompt.ObjectText = objectText
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 12
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.Parent = part
    return prompt
end

local function createClickDetector(part: BasePart, name: string)
    local detector = part:FindFirstChild(name)
    if detector and detector:IsA('ClickDetector') then
        detector.MaxActivationDistance = 16
        return detector
    end

    detector = Instance.new('ClickDetector')
    detector.Name = name
    detector.MaxActivationDistance = 16
    detector.Parent = part
    return detector
end

local function addBillboard(part: BasePart, title: string)
    local existing = part:FindFirstChild('RoleBillboard')
    if existing and existing:IsA('BillboardGui') then
        existing.MaxDistance = TOWN_BILLBOARD_MAX_DISTANCE
        local label = existing:FindFirstChild('RoleLabel')
        if label and label:IsA('TextLabel') then
            label.Text = title
        end
        return
    end

    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'RoleBillboard'
    billboard.Size = UDim2.fromOffset(130, 34)
    billboard.StudsOffset = Vector3.new(0, 4.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = TOWN_BILLBOARD_MAX_DISTANCE
    billboard.Parent = part

    local label = Instance.new('TextLabel')
    label.Name = 'RoleLabel'
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.TextColor3 = Color3.fromRGB(255, 248, 232)
    label.TextStrokeTransparency = 0.2
    label.Text = title
    label.Parent = billboard
end

local function normalizeWarpKey(value: string?): string
    return string.lower(tostring(value or '')):gsub('[^%w]', '')
end

local function normalizeZoneId(zoneId: string?): string
    local normalized = string.lower(tostring(zoneId or '')):gsub('%s+', '_'):gsub('[^%w_]', '')
    if normalized == '' then
        return 'zoltraak'
    elseif normalized == 'town' or normalized == 'start' or normalized == 'starterworld' or normalized == 'prontera' then
        return 'zoltraak'
    elseif normalized == 'startingtown' then
        return 'startingtown'
    elseif normalized == 'pronterafield' or normalized == 'field1' or normalized == 'field' or normalized == 'pron' then
        return 'prontera_field'
    elseif normalized == 'anthell' or normalized == 'anthellfloor1' or normalized == 'dungeon1' or normalized == 'ant' then
        return 'ant_hell_floor_1'
    elseif normalized == 'towerofascension' or normalized == 'tower' or normalized == 'toa' then
        return 'tower_of_ascension'
    elseif normalized == 'niflheim' or normalized == 'niff' then
        return 'niffheim'
    end

    return normalized
end

local DEFAULT_WARP_NUMBERS = {
    prontera = 1,
    prontera_field = 2,
    ant_hell_floor_1 = 3,
    tower_of_ascension = 4,
    niffheim = 5,
    icemoon = 6,
    abysssanctuary = 7,
    lubidrium = 8,
    zoltraak = 9,
}

local function addAlias(aliasSet, aliases: { string }, value: string?)
    local key = normalizeWarpKey(value)
    if key ~= '' and not aliasSet[key] then
        aliasSet[key] = true
        table.insert(aliases, key)
    end
end

local function splitAliases(value: string?): { string }
    local aliases = {}
    local aliasSet = {}
    for token in string.gmatch(tostring(value or ''), '[^,]+') do
        addAlias(aliasSet, aliases, token)
    end
    return aliases
end

local function readStringValue(parent: Instance?, childName: string): string?
    if not parent then
        return nil
    end

    local child = parent:FindFirstChild(childName)
    if child and child:IsA('StringValue') and child.Value ~= '' then
        return child.Value
    end

    return nil
end

local function readNumberValue(parent: Instance?, childName: string): number?
    if not parent then
        return nil
    end

    local child = parent:FindFirstChild(childName)
    if child and child:IsA('IntValue') then
        return child.Value
    end
    if child and child:IsA('NumberValue') then
        return child.Value
    end

    return nil
end

local function readVector3Value(parent: Instance?, childName: string): Vector3?
    if not parent then
        return nil
    end

    local child = parent:FindFirstChild(childName)
    if child and child:IsA('Vector3Value') then
        return child.Value
    end

    return nil
end

local function getWarpRegistryFolder(): Folder?
    local gameData = ReplicatedStorage:FindFirstChild('GameData')
    if not gameData or not gameData:IsA('Folder') then
        return nil
    end

    local warps = gameData:FindFirstChild('Warps')
    if warps and warps:IsA('Folder') then
        return warps
    end

    return nil
end

local function getMapsFolder(): Folder?
    local maps = Workspace:FindFirstChild('Maps')
    if maps and maps:IsA('Folder') then
        return maps
    end
    return nil
end

local function getPlayerUseFolder(mapFolder: Folder): Instance?
    return mapFolder:FindFirstChild('PlayerUse')
end

local function getMapFolders(): { Folder }
    local maps = getMapsFolder()
    local mapFolders = {}
    if not maps then
        return mapFolders
    end

    for _, child in ipairs(maps:GetChildren()) do
        if child:IsA('Folder') and child.Name ~= 'TEMPLATE_MAP' then
            table.insert(mapFolders, child)
        end
    end

    return mapFolders
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

local function buildMapBoxZones(): { MapBoxZone }
    local zones = {}

    for _, mapFolder in ipairs(getMapFolders()) do
        for _, descendant in ipairs(mapFolder:GetDescendants()) do
            if descendant:IsA('BasePart') and descendant.Name == 'MapBox' then
                table.insert(zones, {
                    center = descendant.Position,
                    displayName = tostring(descendant:GetAttribute('ZoneLabel') or mapFolder.Name),
                    mapFolder = mapFolder,
                    part = descendant,
                    priority = getMapBoxPriority(descendant),
                    size = Vector2.new(math.max(descendant.Size.X, 80), math.max(descendant.Size.Z, 80)),
                    sortArea = descendant.Size.X * descendant.Size.Z,
                    zoneId = normalizeZoneId(descendant:GetAttribute('ZoneId') or mapFolder.Name),
                })
            end
        end
    end

    table.sort(zones, function(left, right)
        if left.priority ~= right.priority then
            return left.priority > right.priority
        end
        if left.sortArea ~= right.sortArea then
            return left.sortArea < right.sortArea
        end
        return left.displayName < right.displayName
    end)

    return zones
end

local function getMapBoxZoneById(zoneId: string?): MapBoxZone?
    local normalizedZoneId = normalizeZoneId(zoneId)
    for _, zone in ipairs(buildMapBoxZones()) do
        if zone.zoneId == normalizedZoneId then
            return zone
        end
    end

    return nil
end

local function resolveMapBoxZoneFromPosition(position: Vector3): MapBoxZone?
    for _, zone in ipairs(buildMapBoxZones()) do
        if isInsideZoneVolume(position, zone.part) then
            return zone
        end
    end

    return nil
end

local function getWarpRegistryEntry(mapFolder: Folder): Folder?
    local warps = getWarpRegistryFolder()
    if not warps then
        return nil
    end

    local exact = warps:FindFirstChild(mapFolder.Name)
    if exact and exact:IsA('Folder') then
        return exact
    end

    local normalizedMapName = normalizeWarpKey(mapFolder.Name)
    for _, child in ipairs(warps:GetChildren()) do
        if child:IsA('Folder') and child.Name ~= 'TEMPLATE_Warp' then
            local mapName = readStringValue(child, 'MapName')
            if normalizeWarpKey(mapName) == normalizedMapName then
                return child
            end
        end
    end

    return nil
end

local function getMapBox(mapFolder: Folder): BasePart?
    local mapBox = mapFolder:FindFirstChild('MapBox')
    if mapBox and mapBox:IsA('BasePart') then
        return mapBox
    end
    return nil
end

local function getWarpPart(mapFolder: Folder): BasePart?
    local warpPoints = mapFolder:FindFirstChild('WarpPoints')
    if not warpPoints then
        return nil
    end

    local mainWarp = warpPoints:FindFirstChild('MainWarp')
    if mainWarp and mainWarp:IsA('BasePart') then
        return mainWarp
    end

    for _, descendant in ipairs(warpPoints:GetDescendants()) do
        if descendant:IsA('BasePart') then
            return descendant
        end
    end

    return nil
end

local function getFacingDirection(direction: Vector3?): Vector3
    local horizontal = Vector3.new(direction and direction.X or 0, 0, direction and direction.Z or -1)
    if horizontal.Magnitude <= 0.05 then
        return Vector3.new(0, 0, -1)
    end
    return horizontal.Unit
end

local function getBasePartCFrame(part: BasePart): CFrame
    local spawnPosition = part.Position + WARP_LIFT
    local horizontalLook = getFacingDirection(part.CFrame.LookVector)
    return CFrame.lookAt(spawnPosition, spawnPosition + horizontalLook)
end

local function getWarpPartCFrame(warpPart: BasePart): CFrame
    return getBasePartCFrame(warpPart)
end

local function buildWarpCFrameFromRegistry(spawnPosition: Vector3, facingDirection: Vector3?): CFrame
    local horizontalLook = getFacingDirection(facingDirection)
    return CFrame.lookAt(spawnPosition, spawnPosition + horizontalLook)
end

local function getMapZoneId(mapFolder: Folder): string
    local registryEntry = getWarpRegistryEntry(mapFolder)
    local registryZoneId = readStringValue(registryEntry, 'ZoneId')
    if registryZoneId then
        return normalizeZoneId(registryZoneId)
    end

    return normalizeZoneId(mapFolder.Name)
end

local function addLegacyAliases(zoneId: string, aliasSet, aliases: { string })
    if zoneId == 'zoltraak' then
        for _, alias in ipairs({ '1', '9', 'town', 'start', 'startingtown', 'st', 'prontera', 'zol', 'zoltraak', 'zt' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'startingtown' then
        for _, alias in ipairs({ 'oldtown', 'legacytown', 'startingtown' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'prontera_field' then
        for _, alias in ipairs({ '2', '14', 'field', 'field1', 'pron', 'pronterafield', 'pf' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'ant_hell_floor_1' then
        for _, alias in ipairs({ '3', 'dungeon1', 'ant', 'anthell', 'ah', 'sewer' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'tower_of_ascension' then
        for _, alias in ipairs({ '4', '17', 'tower', 'towerofascension', 'toa' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'niffheim' then
        for _, alias in ipairs({ '5', '18', 'niff', 'niffheim', 'niflheim', 'nh' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'icemoon' then
        for _, alias in ipairs({ '6', 'ice', 'icemoon', 'im' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'abysssanctuary' then
        for _, alias in ipairs({ '7', 'abyss', 'abysssanctuary', 'as' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'lubidrium' then
        for _, alias in ipairs({ '8', 'lubi', 'lubidrium', 'ludi', 'lb' }) do
            addAlias(aliasSet, aliases, alias)
        end
    elseif zoneId == 'zoltraak' then
        for _, alias in ipairs({ '9', 'zol', 'zoltraak', 'zt' }) do
            addAlias(aliasSet, aliases, alias)
        end
    end
end

local function buildWarpDestinations(): { WarpDestination }
    local destinations = {}

    for _, mapFolder in ipairs(getMapFolders()) do
        local registryEntry = getWarpRegistryEntry(mapFolder)
        if registryEntry then
            local zoneId = getMapZoneId(mapFolder)
            local aliases = {}
            local aliasSet = {}
            local configuredAliases = splitAliases(readStringValue(registryEntry, 'Aliases'))
            local primaryAlias = normalizeWarpKey(readStringValue(registryEntry, 'PrimaryAlias'))
            local displayName = readStringValue(registryEntry, 'DisplayName') or mapFolder.Name
            local warpNumber = readNumberValue(registryEntry, 'WarpNumber')
            local registrySpawnPosition = readVector3Value(registryEntry, 'SpawnPosition')
            local registryFacingDirection = readVector3Value(registryEntry, 'FacingDirection')
            local registryZoneCenter = readVector3Value(registryEntry, 'ZoneCenter')
            local registryZoneSize = readVector3Value(registryEntry, 'ZoneSize')
            local center = registryZoneCenter or Vector3.zero
            local sizeVector = registryZoneSize or Vector3.new(140, 20, 140)
            local spawnPosition = registrySpawnPosition or (center + Vector3.new(0, 6, 0))
            local cframe = buildWarpCFrameFromRegistry(spawnPosition, registryFacingDirection)

            if type(warpNumber) ~= 'number' or warpNumber < 1 then
                warpNumber = DEFAULT_WARP_NUMBERS[zoneId]
            end

            addAlias(aliasSet, aliases, readStringValue(registryEntry, 'MapName'))
            addAlias(aliasSet, aliases, mapFolder.Name)
            addAlias(aliasSet, aliases, displayName)
            addAlias(aliasSet, aliases, zoneId)
            for _, alias in ipairs(configuredAliases) do
                addAlias(aliasSet, aliases, alias)
            end
            addLegacyAliases(zoneId, aliasSet, aliases)
            if warpNumber then
                addAlias(aliasSet, aliases, tostring(warpNumber))
            end

            if primaryAlias == '' then
                primaryAlias = configuredAliases[1] or aliases[1] or normalizeWarpKey(mapFolder.Name)
            end

            table.insert(destinations, {
                aliases = aliases,
                center = center,
                cframe = cframe,
                displayName = displayName,
                mapFolder = mapFolder,
                number = warpNumber,
                primaryAlias = primaryAlias,
                size = Vector2.new(math.max(sizeVector.X, 80), math.max(sizeVector.Z, 80)),
                zoneId = zoneId,
            })
        end
    end

    table.sort(destinations, function(a, b)
        local aNumber = a.number or math.huge
        local bNumber = b.number or math.huge
        if aNumber == bNumber then
            return a.displayName < b.displayName
        end
        return aNumber < bNumber
    end)

    return destinations
end

local function createLantern(parent: Instance, name: string, basePosition: Vector3, glowColor: Color3)
    createPart(parent, name .. '_Pole', Vector3.new(0.8, 6.4, 0.8), CFrame.new(basePosition + Vector3.new(0, 3.2, 0)), Color3.fromRGB(77, 58, 45), Enum.Material.WoodPlanks)
    createPart(parent, name .. '_Lamp', Vector3.new(1.4, 1.4, 1.4), CFrame.new(basePosition + Vector3.new(0, 6.4, 0)), glowColor, Enum.Material.Neon, Enum.PartType.Ball)
end

local function createDeadTree(parent: Instance, name: string, basePosition: Vector3, scale: number)
    local trunkHeight = 10 * scale
    createPart(parent, name .. '_Trunk', Vector3.new(1.8 * scale, trunkHeight, 1.8 * scale), CFrame.new(basePosition + Vector3.new(0, trunkHeight * 0.5, 0)), Color3.fromRGB(67, 58, 54), Enum.Material.WoodPlanks, Enum.PartType.Cylinder)
    createPart(parent, name .. '_BranchLeft', Vector3.new(5.4 * scale, 0.8 * scale, 0.8 * scale), CFrame.new(basePosition + Vector3.new(-1.8 * scale, trunkHeight * 0.78, 0)) * CFrame.Angles(0, 0, math.rad(32)), Color3.fromRGB(67, 58, 54), Enum.Material.WoodPlanks)
    createPart(parent, name .. '_BranchRight', Vector3.new(4.8 * scale, 0.8 * scale, 0.8 * scale), CFrame.new(basePosition + Vector3.new(1.6 * scale, trunkHeight * 0.62, 0.4 * scale)) * CFrame.Angles(0, 0, math.rad(-26)), Color3.fromRGB(67, 58, 54), Enum.Material.WoodPlanks)
end

local function createCrookedHouse(parent: Instance, name: string, pivot: CFrame, width: number, depth: number, height: number, bodyColor: Color3, roofColor: Color3)
    createPart(parent, name .. '_Body', Vector3.new(width, height, depth), pivot * CFrame.new(0, height * 0.5, 0), bodyColor, Enum.Material.WoodPlanks)
    createPart(parent, name .. '_Roof', Vector3.new(width + 2, 2.2, depth + 2), pivot * CFrame.new(0, height + 0.8, 0) * CFrame.Angles(0, 0, math.rad(6)), roofColor, Enum.Material.Slate)
    createPart(parent, name .. '_Door', Vector3.new(2.4, 4.6, 0.3), pivot * CFrame.new(0, 2.3, depth * -0.5 - 0.16), Color3.fromRGB(58, 42, 37), Enum.Material.WoodPlanks)
    createPart(parent, name .. '_WindowLeft', Vector3.new(2.1, 2.1, 0.25), pivot * CFrame.new(-width * 0.24, height * 0.55, depth * -0.5 - 0.14), Color3.fromRGB(132, 196, 255), Enum.Material.Glass)
    createPart(parent, name .. '_WindowRight', Vector3.new(2.1, 2.1, 0.25), pivot * CFrame.new(width * 0.24, height * 0.55, depth * -0.5 - 0.14), Color3.fromRGB(132, 196, 255), Enum.Material.Glass)
end

local function createGraveMarker(parent: Instance, name: string, basePosition: Vector3)
    createPart(parent, name .. '_Base', Vector3.new(2.6, 0.35, 1.8), CFrame.new(basePosition + Vector3.new(0, 0.18, 0)), Color3.fromRGB(90, 94, 108), Enum.Material.Slate)
    createPart(parent, name .. '_Stone', Vector3.new(1.45, 2.6, 0.55), CFrame.new(basePosition + Vector3.new(0, 1.5, 0)), Color3.fromRGB(132, 136, 151), Enum.Material.Slate)
    createPart(parent, name .. '_CrossBar', Vector3.new(1.2, 0.3, 0.45), CFrame.new(basePosition + Vector3.new(0, 2.2, 0)), Color3.fromRGB(148, 152, 164), Enum.Material.Slate)
end

local function createFenceLine(parent: Instance, namePrefix: string, startPos: Vector3, endPos: Vector3, postCount: number)
    local delta = endPos - startPos
    local step = delta / math.max(postCount - 1, 1)
    for index = 0, postCount - 1 do
        local position = startPos + step * index
        createPart(parent, string.format('%s_Post_%d', namePrefix, index + 1), Vector3.new(0.45, 2.6, 0.45), CFrame.new(position + Vector3.new(0, 1.3, 0)), Color3.fromRGB(74, 74, 84), Enum.Material.Metal)
    end
    createPart(parent, namePrefix .. '_RailUpper', Vector3.new(delta.Magnitude + 0.6, 0.2, 0.2), CFrame.lookAt((startPos + endPos) * 0.5 + Vector3.new(0, 2.05, 0), endPos + Vector3.new(0, 2.05, 0)), Color3.fromRGB(96, 96, 106), Enum.Material.Metal)
    createPart(parent, namePrefix .. '_RailLower', Vector3.new(delta.Magnitude + 0.6, 0.2, 0.2), CFrame.lookAt((startPos + endPos) * 0.5 + Vector3.new(0, 1.32, 0), endPos + Vector3.new(0, 1.32, 0)), Color3.fromRGB(96, 96, 106), Enum.Material.Metal)
end

local function buildNiffheimFallback(maps: Instance, playerUse: Instance)
    local niffheim = ensureFolder(maps, 'Niffheim')
    local niffheimMap = ensureFolder(niffheim, 'Map')
    local region = ensureFolder(niffheimMap, 'NiffheimRegion')
    local murk = Color3.fromRGB(42, 46, 62)
    local stone = Color3.fromRGB(77, 80, 96)
    local deadWood = Color3.fromRGB(70, 56, 53)
    local moonGlow = Color3.fromRGB(164, 134, 255)

    createPart(region, 'EntryBridge', Vector3.new(118, 1, 20), CFrame.new(NIFFHEIM_CENTER + Vector3.new(-228, 0, -20)), Color3.fromRGB(100, 82, 66), Enum.Material.WoodPlanks)
    createPart(region, 'HangingRoad', Vector3.new(92, 1, 18), CFrame.new(NIFFHEIM_CENTER + Vector3.new(-150, 0, -12)), Color3.fromRGB(82, 74, 66), Enum.Material.WoodPlanks)
    createPart(region, 'TownCenter', Vector3.new(120, 1, 92), CFrame.new(NIFFHEIM_CENTER + Vector3.new(-48, 0, 0)), stone, Enum.Material.Cobblestone)
    createPart(region, 'TownStreetNorth', Vector3.new(170, 1, 22), CFrame.new(NIFFHEIM_CENTER + Vector3.new(8, 0, -72)), stone, Enum.Material.Cobblestone)
    createPart(region, 'TownStreetSouth', Vector3.new(176, 1, 22), CFrame.new(NIFFHEIM_CENTER + Vector3.new(12, 0, 74)), stone, Enum.Material.Cobblestone)
    createPart(region, 'TownStreetEast', Vector3.new(22, 1, 156), CFrame.new(NIFFHEIM_CENTER + Vector3.new(42, 0, 4)), stone, Enum.Material.Cobblestone)
    createPart(region, 'GraveyardHill', Vector3.new(190, 1, 124), CFrame.new(NIFFHEIM_CENTER + Vector3.new(118, 3, -154)), Color3.fromRGB(64, 69, 74), Enum.Material.Ground)
    createPart(region, 'RiverBankWest', Vector3.new(146, 1, 62), CFrame.new(NIFFHEIM_CENTER + Vector3.new(180, 0, 86)), Color3.fromRGB(70, 74, 76), Enum.Material.Mud)
    createPart(region, 'RiverBankEast', Vector3.new(146, 1, 62), CFrame.new(NIFFHEIM_CENTER + Vector3.new(312, 0, 86)), Color3.fromRGB(70, 74, 76), Enum.Material.Mud)
    createPart(region, 'RiverWater', Vector3.new(72, 0.6, 74), CFrame.new(NIFFHEIM_CENTER + Vector3.new(246, -0.15, 88)), Color3.fromRGB(31, 43, 59), Enum.Material.Slate)
    createPart(region, 'RiverBridge', Vector3.new(90, 1, 18), CFrame.new(NIFFHEIM_CENTER + Vector3.new(246, 0.3, 86)), Color3.fromRGB(88, 72, 58), Enum.Material.WoodPlanks)
    createPart(region, 'ManorRise', Vector3.new(164, 1, 126), CFrame.new(NIFFHEIM_CENTER + Vector3.new(208, 5, -108)), Color3.fromRGB(58, 60, 72), Enum.Material.Slate)
    createPart(region, 'BossCourt', Vector3.new(118, 1, 92), CFrame.new(NIFFHEIM_CENTER + Vector3.new(288, 7, -148)), Color3.fromRGB(52, 54, 68), Enum.Material.Slate)
    createPart(region, 'BossChapelPad', Vector3.new(82, 1, 52), CFrame.new(NIFFHEIM_CENTER + Vector3.new(264, 7.4, -204)), Color3.fromRGB(44, 45, 54), Enum.Material.Basalt)
    createPart(region, 'NiffheimFogPlane', Vector3.new(520, 1, 420), CFrame.new(NIFFHEIM_CENTER + Vector3.new(52, 0.3, -6)), murk, Enum.Material.SmoothPlastic).Transparency = 0.92

    createCrookedHouse(region, 'HouseA', CFrame.new(NIFFHEIM_CENTER + Vector3.new(-98, 0, -36)) * CFrame.Angles(0, math.rad(8), 0), 16, 14, 12, Color3.fromRGB(66, 60, 74), Color3.fromRGB(44, 38, 52))
    createCrookedHouse(region, 'HouseB', CFrame.new(NIFFHEIM_CENTER + Vector3.new(-112, 0, 34)) * CFrame.Angles(0, math.rad(-12), 0), 15, 13, 11, Color3.fromRGB(72, 62, 66), Color3.fromRGB(48, 42, 54))
    createCrookedHouse(region, 'HouseC', CFrame.new(NIFFHEIM_CENTER + Vector3.new(-14, 0, -42)) * CFrame.Angles(0, math.rad(14), 0), 18, 15, 13, Color3.fromRGB(66, 68, 82), Color3.fromRGB(50, 44, 60))
    createCrookedHouse(region, 'HouseD', CFrame.new(NIFFHEIM_CENTER + Vector3.new(-6, 0, 40)) * CFrame.Angles(0, math.rad(-8), 0), 17, 14, 12, Color3.fromRGB(78, 66, 72), Color3.fromRGB(46, 38, 48))
    createCrookedHouse(region, 'HouseE', CFrame.new(NIFFHEIM_CENTER + Vector3.new(92, 0, 40)) * CFrame.Angles(0, math.rad(9), 0), 17, 14, 12, Color3.fromRGB(64, 62, 78), Color3.fromRGB(44, 42, 56))
    createCrookedHouse(region, 'ManorFront', CFrame.new(NIFFHEIM_CENTER + Vector3.new(234, 6.9, -170)) * CFrame.Angles(0, math.rad(6), 0), 30, 22, 22, Color3.fromRGB(52, 50, 66), Color3.fromRGB(32, 30, 44))

    for index, offset in ipairs({
        Vector3.new(-188, 0, -44),
        Vector3.new(-128, 0, -86),
        Vector3.new(-72, 0, -96),
        Vector3.new(18, 0, -104),
        Vector3.new(72, 0, -88),
        Vector3.new(118, 0, 88),
        Vector3.new(212, 0, 34),
        Vector3.new(310, 0, 8),
        Vector3.new(246, 6, -250),
    }) do
        createLantern(region, 'NiffLantern' .. tostring(index), NIFFHEIM_CENTER + offset, moonGlow)
    end

    for index, spec in ipairs({
        { pos = Vector3.new(-136, 0, -136), scale = 1.25 },
        { pos = Vector3.new(-40, 0, -126), scale = 1.1 },
        { pos = Vector3.new(88, 0, -210), scale = 1.38 },
        { pos = Vector3.new(168, 3, -196), scale = 1.22 },
        { pos = Vector3.new(116, 0, 132), scale = 1.18 },
        { pos = Vector3.new(286, 0, 146), scale = 1.3 },
        { pos = Vector3.new(326, 0, -92), scale = 1.24 },
    }) do
        createDeadTree(region, 'NiffTree' .. tostring(index), NIFFHEIM_CENTER + spec.pos, spec.scale)
    end

    for index, offset in ipairs({
        Vector3.new(32, 3, -112), Vector3.new(48, 3, -124), Vector3.new(66, 3, -144), Vector3.new(84, 3, -158),
        Vector3.new(104, 3, -124), Vector3.new(126, 3, -144), Vector3.new(146, 3, -166), Vector3.new(162, 3, -128),
        Vector3.new(136, 3, -102), Vector3.new(92, 3, -182), Vector3.new(56, 3, -176), Vector3.new(174, 3, -184),
    }) do
        createGraveMarker(region, 'NiffGrave' .. tostring(index), NIFFHEIM_CENTER + offset)
    end

    createFenceLine(region, 'GraveFenceNorth', NIFFHEIM_CENTER + Vector3.new(6, 3, -220), NIFFHEIM_CENTER + Vector3.new(188, 3, -220), 11)
    createFenceLine(region, 'GraveFenceSouth', NIFFHEIM_CENTER + Vector3.new(6, 3, -86), NIFFHEIM_CENTER + Vector3.new(188, 3, -86), 11)
    createFenceLine(region, 'GraveFenceWest', NIFFHEIM_CENTER + Vector3.new(6, 3, -220), NIFFHEIM_CENTER + Vector3.new(6, 3, -86), 8)
    createFenceLine(region, 'BossCourtFence', NIFFHEIM_CENTER + Vector3.new(226, 7, -196), NIFFHEIM_CENTER + Vector3.new(344, 7, -196), 7)

    local niffheimGate = createPart(playerUse, 'NiffheimGate', Vector3.new(10, 12, 10), CFrame.new(NIFFHEIM_GATE_TOWN_POSITION), Color3.fromRGB(128, 94, 176), Enum.Material.Neon)
    local niffheimReturnGate = createPart(playerUse, 'NiffheimReturnGate', Vector3.new(10, 12, 10), CFrame.new(NIFFHEIM_RETURN_GATE_POSITION), Color3.fromRGB(94, 132, 182), Enum.Material.Neon)
    niffheimGate.CanCollide = false
    niffheimReturnGate.CanCollide = false
    addBillboard(niffheimGate, 'Niffheim Gate')
    addBillboard(niffheimReturnGate, 'Return to Town')
    worldRefs.niffheimGatePrompt = createPrompt(niffheimGate, 'Enter', 'Niffheim', 'NiffheimGatePrompt')
    worldRefs.niffheimReturnPrompt = createPrompt(niffheimReturnGate, 'Return', 'Prontera', 'NiffheimReturnPrompt')
    worldRefs.niffheimGateClickDetector = createClickDetector(niffheimGate, 'NiffheimGateClickDetector')
    worldRefs.niffheimReturnClickDetector = createClickDetector(niffheimReturnGate, 'NiffheimReturnClickDetector')
end

local function ensureMapFolder(maps: Instance, preferredName: string, legacyName: string?): Folder
    local existing = maps:FindFirstChild(preferredName)
    if existing and existing:IsA('Folder') then
        return existing
    end

    if legacyName then
        local legacy = maps:FindFirstChild(legacyName)
        if legacy and legacy:IsA('Folder') then
            legacy.Name = preferredName
            return legacy
        end
    end

    return ensureFolder(maps, preferredName)
end

function WorldService.init()
    table.clear(worldRefs)
end

function WorldService.start()
    local maps = ensureFolder(Workspace, 'Maps')
    local startingTown = ensureMapFolder(maps, 'StartingTown', 'StarterWorld')
    local mainTown = ensureFolder(maps, 'Zoltraak')
    local pronteraField = ensureFolder(maps, 'PronteraField')
    local startingTownMap = ensureFolder(startingTown, 'Map')
    local pronteraFieldMap = ensureFolder(pronteraField, 'Map')
    local mainTownSpawn = ensureFolder(mainTown, 'Spawn')
    local mainTownPlayerUse = ensureFolder(mainTown, 'PlayerUse')
    local startingTownDecor = ensureFolder(startingTown, 'Decor')
    local antHell = ensureFolder(maps, 'AntHell')
    local antHellMap = ensureFolder(antHell, 'Map')
    local startingTownRegion = ensureFolder(startingTownMap, 'StartingTownRegion')
    local pronteraFieldRegion = ensureFolder(pronteraFieldMap, 'PronteraFieldRegion')
    local fieldSigns = ensureFolder(pronteraFieldMap, 'FieldSigns')
    local antHellSigns = ensureFolder(antHellMap, 'Signs')

    worldRefs.townFloor = createPart(startingTownRegion, 'TownGrass', Vector3.new(210, 1, 210), CFrame.new(0, 0, 0), Color3.fromRGB(116, 171, 109), Enum.Material.Grass)
    local plaza = createPart(startingTownRegion, 'TownPlaza', Vector3.new(72, 1, 72), CFrame.new(0, 0.55, 0), Color3.fromRGB(155, 164, 171), Enum.Material.Slate)
    createPart(startingTownRegion, 'WestServiceWalk', Vector3.new(22, 1, 10), CFrame.new(-29, 0.56, 0), Color3.fromRGB(164, 150, 123), Enum.Material.Cobblestone)
    createPart(startingTownRegion, 'EastServiceWalk', Vector3.new(22, 1, 10), CFrame.new(29, 0.56, 0), Color3.fromRGB(164, 150, 123), Enum.Material.Cobblestone)
    createPart(startingTownRegion, 'NorthServiceWalk', Vector3.new(16, 1, 22), CFrame.new(0, 0.56, 28), Color3.fromRGB(164, 150, 123), Enum.Material.Cobblestone)
    createPart(startingTownRegion, 'SouthServiceWalk', Vector3.new(16, 1, 22), CFrame.new(0, 0.56, -28), Color3.fromRGB(164, 150, 123), Enum.Material.Cobblestone)
    createPart(startingTownRegion, 'FieldPath', Vector3.new(64, 1, 14), CFrame.new(61, 0.56, -10), Color3.fromRGB(164, 150, 123), Enum.Material.Cobblestone)
    createPart(startingTownRegion, 'DungeonPath', Vector3.new(14, 1, 54), CFrame.new(0, 0.56, 56), Color3.fromRGB(164, 150, 123), Enum.Material.Cobblestone)
    createPart(startingTownRegion, 'SouthPath', Vector3.new(14, 1, 42), CFrame.new(0, 0.56, -48), Color3.fromRGB(164, 150, 123), Enum.Material.Cobblestone)

    local townCenter = Vector3.new(-304.0001220703125, 0.41998291015625, 226.93533325195312)
    local townSpawnPosition = Vector3.new(-304.0001220703125, 3.6500244140625, 246.93533325195312)
    worldRefs.townSpawn = createSpawnLocation(mainTownSpawn, 'TownSpawn', Vector3.new(10, 1, 10), townSpawnPosition, Color3.fromRGB(255, 235, 160))
    worldRefs.townSpawn.Enabled = true

    createPart(startingTownDecor, 'FountainBase', Vector3.new(14, 2, 14), CFrame.new(0, 1.5, 0), Color3.fromRGB(166, 176, 185), Enum.Material.Slate, Enum.PartType.Cylinder)
    createPart(startingTownDecor, 'FountainCore', Vector3.new(4, 8, 4), CFrame.new(0, 5.5, 0), Color3.fromRGB(110, 195, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
    createPart(startingTownDecor, 'BenchWest', Vector3.new(12, 2, 3), CFrame.new(-20, 1.5, -6), Color3.fromRGB(111, 78, 55), Enum.Material.WoodPlanks)
    createPart(startingTownDecor, 'BenchEast', Vector3.new(12, 2, 3), CFrame.new(20, 1.5, -6), Color3.fromRGB(111, 78, 55), Enum.Material.WoodPlanks)
    createPart(startingTownDecor, 'BenchNorth', Vector3.new(3, 2, 12), CFrame.new(0, 1.5, 20), Color3.fromRGB(111, 78, 55), Enum.Material.WoodPlanks)
    createPart(startingTownDecor, 'BenchSouth', Vector3.new(3, 2, 12), CFrame.new(0, 1.5, -20), Color3.fromRGB(111, 78, 55), Enum.Material.WoodPlanks)

    worldRefs.fieldFloor = createPart(pronteraFieldRegion, 'PronteraField', Vector3.new(300, 1, 190), CFrame.new(660, 0, -20), Color3.fromRGB(116, 193, 108), Enum.Material.Grass)
    createPart(pronteraFieldRegion, 'PracticeYard', Vector3.new(38, 1, 28), CFrame.new(552, 0.56, -20), Color3.fromRGB(188, 173, 146), Enum.Material.Cobblestone)
    createPart(pronteraFieldRegion, 'FieldLaneNorth', Vector3.new(206, 1, 8), CFrame.new(672, 0.56, -46), Color3.fromRGB(149, 133, 106), Enum.Material.Ground)
    worldRefs.dungeonFloor = createPart(antHellMap, 'AntHellFloor1', Vector3.new(150, 1, 150), CFrame.new(0, 0, 238), Color3.fromRGB(107, 80, 53), Enum.Material.Ground)
    createPart(antHellMap, 'AntHellChamberNorth', Vector3.new(30, 12, 30), CFrame.new(-40, 6, 208), Color3.fromRGB(82, 61, 40), Enum.Material.Sandstone)
    createPart(antHellMap, 'AntHellChamberSouth', Vector3.new(36, 14, 36), CFrame.new(42, 7, 272), Color3.fromRGB(82, 61, 40), Enum.Material.Sandstone)

    local entrance = createPart(mainTownPlayerUse, 'DungeonEntrance', Vector3.new(8, 10, 8), CFrame.lookAt(townCenter + Vector3.new(0, 5.41998291015625, 98), townCenter + Vector3.new(0, 5.41998291015625, 98) + Vector3.new(0, 0, -1)), Color3.fromRGB(88, 70, 178), Enum.Material.Neon)
    local fieldGate = createPart(mainTownPlayerUse, 'FieldGate', Vector3.new(8, 10, 8), CFrame.lookAt(townCenter + Vector3.new(98, 5.41998291015625, 0), townCenter + Vector3.new(98, 5.41998291015625, 0) + Vector3.new(-1, 0, 0)), Color3.fromRGB(78, 162, 96), Enum.Material.Neon)
    local blacksmith = createPart(mainTownPlayerUse, 'BlacksmithNPC', Vector3.new(4, 7, 4), CFrame.lookAt(Vector3.new(-246.0001220703125, 3.91998291015625, 226.93533325195312), Vector3.new(-304.0001220703125, 3.91998291015625, 226.93533325195312)), Color3.fromRGB(186, 108, 52), Enum.Material.SmoothPlastic)
    local healer = createPart(mainTownPlayerUse, 'HealerNPC', Vector3.new(4, 7, 4), CFrame.lookAt(Vector3.new(-262.9879150390625, 3.91998291015625, 267.947509765625), Vector3.new(-304.0001220703125, 3.91998291015625, 226.93533325195312)), Color3.fromRGB(96, 198, 242), Enum.Material.SmoothPlastic)
    local warper = createPart(mainTownPlayerUse, 'WarperNPC', Vector3.new(4, 7, 4), CFrame.lookAt(Vector3.new(-304.0001220703125, 3.91998291015625, 284.9353332519531), Vector3.new(-304.0001220703125, 3.91998291015625, 226.93533325195312)), Color3.fromRGB(156, 126, 232), Enum.Material.SmoothPlastic)
    local rebirth = createPart(mainTownPlayerUse, 'RebirthNPC', Vector3.new(4, 7, 4), CFrame.lookAt(Vector3.new(-345.0123291015625, 3.91998291015625, 267.947509765625), Vector3.new(-304.0001220703125, 3.91998291015625, 226.93533325195312)), Color3.fromRGB(236, 181, 120), Enum.Material.SmoothPlastic)
    local jobChanger = createPart(mainTownPlayerUse, 'JobChangerNPC', Vector3.new(4, 7, 4), CFrame.lookAt(Vector3.new(-362.0001220703125, 3.91998291015625, 226.93533325195312), Vector3.new(-304.0001220703125, 3.91998291015625, 226.93533325195312)), Color3.fromRGB(148, 220, 126), Enum.Material.SmoothPlastic)
    local shopkeeper = createPart(mainTownPlayerUse, 'ShopkeeperNPC', Vector3.new(4, 7, 4), CFrame.lookAt(Vector3.new(-345.0123291015625, 3.91998291015625, 185.9231414794922), Vector3.new(-304.0001220703125, 3.91998291015625, 226.93533325195312)), Color3.fromRGB(204, 173, 111), Enum.Material.SmoothPlastic)
    local monetization = createPart(mainTownPlayerUse, 'StoreHookNPC', Vector3.new(4, 7, 4), CFrame.lookAt(Vector3.new(-304.0001220703125, 3.91998291015625, 168.93533325195312), Vector3.new(-304.0001220703125, 3.91998291015625, 226.93533325195312)), Color3.fromRGB(242, 133, 173), Enum.Material.SmoothPlastic)
    local dummySign = createPart(fieldSigns, 'DummyPracticeSign', Vector3.new(3, 7, 1), CFrame.new(552, 3.5, -50), Color3.fromRGB(223, 196, 146), Enum.Material.WoodPlanks)
    local poringSign = createPart(fieldSigns, 'PoringFieldSign', Vector3.new(3, 7, 1), CFrame.new(596, 3.5, -50), Color3.fromRGB(255, 205, 225), Enum.Material.WoodPlanks)
    local lunaticSign = createPart(fieldSigns, 'LunaticPracticeSign', Vector3.new(3, 7, 1), CFrame.new(644, 3.5, -50), Color3.fromRGB(255, 240, 240), Enum.Material.WoodPlanks)
    local willowSign = createPart(fieldSigns, 'WillowSign', Vector3.new(3, 7, 1), CFrame.new(692, 3.5, -50), Color3.fromRGB(153, 193, 134), Enum.Material.WoodPlanks)
    local rockerSign = createPart(fieldSigns, 'RockerSign', Vector3.new(3, 7, 1), CFrame.new(740, 3.5, -50), Color3.fromRGB(126, 226, 116), Enum.Material.WoodPlanks)
    local mayaSign = createPart(antHellSigns, 'MayaPurpleSign', Vector3.new(3, 7, 1), CFrame.new(12, 3.5, 308), Color3.fromRGB(162, 111, 255), Enum.Material.WoodPlanks)

    addBillboard(entrance, 'Dungeon Gate')
    addBillboard(fieldGate, 'South Field')
    addBillboard(blacksmith, 'Blacksmith')
    addBillboard(healer, 'Healer')
    addBillboard(warper, 'Warper')
    addBillboard(rebirth, 'Rebirth Master')
    addBillboard(jobChanger, 'Job Changer')
    addBillboard(shopkeeper, 'Baazar Merchant')
    addBillboard(monetization, 'Cash Shop')
    addBillboard(dummySign, 'Practice Yard')
    addBillboard(poringSign, 'Poring Meadow')
    addBillboard(lunaticSign, 'Lunatic Meadow')
    addBillboard(willowSign, 'Willow Grove')
    addBillboard(rockerSign, 'Rocker Ridge')
    addBillboard(mayaSign, 'Maya Purple')

    worldRefs.fieldGatePrompt = createPrompt(fieldGate, 'Travel', 'South Field', 'FieldGatePrompt')
    worldRefs.entrancePrompt = createPrompt(entrance, 'Enter', 'Dungeon Entrance', 'DungeonPrompt')
    worldRefs.blacksmithPrompt = createPrompt(blacksmith, 'Forge', 'Blacksmith', 'BlacksmithPrompt')
    worldRefs.healerPrompt = createPrompt(healer, 'Heal', 'Healer', 'HealerPrompt')
    worldRefs.warperPrompt = createPrompt(warper, 'Warp', 'Warper', 'WarperPrompt')
    worldRefs.rebirthPrompt = createPrompt(rebirth, 'Advance', 'Rebirth Master', 'RebirthPrompt')
    worldRefs.jobChangerPrompt = createPrompt(jobChanger, 'Change Job', 'Job Changer', 'JobChangePrompt')
    worldRefs.shopPrompt = createPrompt(shopkeeper, 'Trade', 'Baazar Merchant', 'ShopPrompt')
    worldRefs.storePrompt = createPrompt(monetization, 'Shop', 'Cash Shop', 'StorePrompt')
    worldRefs.fieldGateClickDetector = createClickDetector(fieldGate, 'FieldGateClickDetector')
    worldRefs.entranceClickDetector = createClickDetector(entrance, 'DungeonClickDetector')
    worldRefs.blacksmithClickDetector = createClickDetector(blacksmith, 'BlacksmithClickDetector')
    worldRefs.healerClickDetector = createClickDetector(healer, 'HealerClickDetector')
    worldRefs.warperClickDetector = createClickDetector(warper, 'WarperClickDetector')
    worldRefs.rebirthClickDetector = createClickDetector(rebirth, 'RebirthClickDetector')
    worldRefs.jobChangerClickDetector = createClickDetector(jobChanger, 'JobChangeClickDetector')
    worldRefs.shopClickDetector = createClickDetector(shopkeeper, 'ShopClickDetector')
    worldRefs.storeClickDetector = createClickDetector(monetization, 'StoreClickDetector')

    buildNiffheimFallback(maps, mainTownPlayerUse)

    EnemyService.spawnEnemyFamily('training_dummy', {
        Vector3.new(546, 4, -20),
        Vector3.new(560, 4, -20),
    })

    EnemyService.spawnEnemyFamily('poring', {
        Vector3.new(590, 3, -30),
        Vector3.new(602, 3, -12),
        Vector3.new(614, 3, -28),
        Vector3.new(598, 3, -22),
    })

    EnemyService.spawnEnemyFamily('lunatic', {
        Vector3.new(638, 3, -30),
        Vector3.new(652, 3, -12),
        Vector3.new(664, 3, -28),
    })

    EnemyService.spawnEnemyFamily('willow', {
        Vector3.new(686, 3, -30),
        Vector3.new(700, 3, -10),
        Vector3.new(714, 3, -32),
    })

    EnemyService.spawnEnemyFamily('rocker', {
        Vector3.new(734, 3, -26),
        Vector3.new(748, 3, -10),
        Vector3.new(762, 3, -28),
    })

    EnemyService.spawnEnemyFamily('crimson_arbiter', {
        Vector3.new(820, 5, 20),
    })

    EnemyService.spawnEnemyFamily('andre', {
        Vector3.new(-42, 3, 214),
        Vector3.new(-20, 3, 224),
        Vector3.new(-34, 3, 244),
    })

    EnemyService.spawnEnemyFamily('deniro', {
        Vector3.new(10, 3, 214),
        Vector3.new(22, 3, 232),
        Vector3.new(0, 3, 246),
    })

    EnemyService.spawnEnemyFamily('piere', {
        Vector3.new(40, 3, 252),
        Vector3.new(58, 3, 266),
        Vector3.new(24, 3, 280),
    })

    EnemyService.spawnEnemyFamily('vitata', {
        Vector3.new(70, 3, 286),
        Vector3.new(48, 3, 296),
    })

    EnemyService.spawnEnemyFamily('maya_purple_trial', {
        Vector3.new(16, 3, 274),
    })

    EnemyService.spawnEnemyFamily('lude', {
        Vector3.new(1506, 4, 1260),
        Vector3.new(1562, 4, 1248),
        Vector3.new(1594, 4, 1294),
        Vector3.new(1638, 4, 1266),
    })

    EnemyService.spawnEnemyFamily('quve', {
        Vector3.new(1622, 4, 1202),
        Vector3.new(1674, 4, 1196),
        Vector3.new(1708, 4, 1268),
        Vector3.new(1740, 4, 1328),
    })

    EnemyService.spawnEnemyFamily('hylozoist', {
        Vector3.new(1766, 4, 1226),
        Vector3.new(1816, 4, 1264),
        Vector3.new(1744, 4, 1368),
        Vector3.new(1662, 4, 1374),
    })

    EnemyService.spawnEnemyFamily('gibbet', {
        Vector3.new(1710, 7, 1118),
        Vector3.new(1764, 7, 1088),
        Vector3.new(1838, 7, 1152),
    })

    EnemyService.spawnEnemyFamily('dullahan', {
        Vector3.new(1874, 5, 1194),
        Vector3.new(1924, 5, 1298),
        Vector3.new(1966, 8, 1126),
    })

    EnemyService.spawnEnemyFamily('disguise', {
        Vector3.new(1606, 4, 1338),
        Vector3.new(1698, 4, 1384),
        Vector3.new(1814, 4, 1378),
    })

    EnemyService.spawnEnemyFamily('bloody_murderer', {
        Vector3.new(1908, 8, 1164),
        Vector3.new(1942, 8, 1084),
    })

    EnemyService.spawnEnemyFamily('loli_ruri', {
        Vector3.new(1852, 8, 1078),
        Vector3.new(1916, 8, 1038),
    })

    EnemyService.spawnEnemyFamily('lord_of_the_dead', {
        Vector3.new(1968, 9, 1122),
    })

    worldRefs.plaza = plaza
end

function WorldService.getTownSpawnCFrame(): CFrame
    return WorldService.getSpawnCFrameForZoneId('zoltraak')
end

function WorldService.getFieldSpawnCFrame(): CFrame
    return WorldService.getSpawnCFrameForZoneId('prontera_field')
end

function WorldService.getTowerOfAscensionSpawnCFrame(): CFrame
    local configuredDestination = WorldService.getWarpDestination('tower_of_ascension')
    if configuredDestination then
        return configuredDestination.cframe
    end

    local targetPosition = TOWER_OF_ASCENSION_FALLBACK_TARGET
    local rebirthFolder = Workspace:FindFirstChild('Rebirth')
    local towerWarpFloor = rebirthFolder and rebirthFolder:FindFirstChild('TowerOfAscensionWarpFloor')
    if not towerWarpFloor then
        towerWarpFloor = Instance.new('Part')
        towerWarpFloor.Name = 'TowerOfAscensionWarpFloor'
        towerWarpFloor.Anchored = true
        towerWarpFloor.CanCollide = true
        towerWarpFloor.CanTouch = false
        towerWarpFloor.CanQuery = false
        towerWarpFloor.Transparency = 1
        towerWarpFloor.Size = Vector3.new(18, 1, 18)
        towerWarpFloor.CFrame = CFrame.new(-172, 97, -96)
        towerWarpFloor.Parent = rebirthFolder or Workspace
    end

    local poringInTown = rebirthFolder and rebirthFolder:FindFirstChild('Poring_in_town')
    if poringInTown and poringInTown:IsA('Model') then
        local focusPart = poringInTown.PrimaryPart or poringInTown:FindFirstChild('HumanoidRootPart')
        if focusPart and focusPart:IsA('BasePart') then
            targetPosition = focusPart.Position
        end
    end

    local spawnPosition = TOWER_OF_ASCENSION_POSITION
    local horizontalTarget = Vector3.new(targetPosition.X, spawnPosition.Y, targetPosition.Z)
    return CFrame.lookAt(spawnPosition, horizontalTarget)
end

function WorldService.getWarpDestinations(): { WarpDestination }
    return buildWarpDestinations()
end

function WorldService.getWarpDestination(destination: string?): WarpDestination?
    local lookupKey = normalizeWarpKey(destination)
    local normalizedZoneId = normalizeZoneId(destination)

    for _, warpDestination in ipairs(buildWarpDestinations()) do
        if warpDestination.zoneId == normalizedZoneId then
            return warpDestination
        end

        for _, alias in ipairs(warpDestination.aliases) do
            if alias == lookupKey then
                return warpDestination
            end
        end
    end

    return nil
end

function WorldService.getZoneDisplayName(zoneId: string?): string
    local mapBoxZone = getMapBoxZoneById(zoneId)
    if mapBoxZone then
        return mapBoxZone.displayName
    end

    local destination = WorldService.getWarpDestination(zoneId)
    if destination then
        return destination.displayName
    end
    return tostring(zoneId or 'Unknown')
end

local function getFallbackSpawnCFrame(zoneId: string): CFrame
    if zoneId == 'zoltraak' then
        local townSpawn = worldRefs.townSpawn
        if townSpawn and townSpawn:IsA('SpawnLocation') then
            return townSpawn.CFrame + Vector3.new(0, 4, 0)
        end
        return CFrame.new(-304.0001220703125, 7.6500244140625, 246.93533325195312)
    elseif zoneId == 'prontera' then
        return getFallbackSpawnCFrame('zoltraak')
    elseif zoneId == 'prontera_field' then
        local fieldFloor = worldRefs.fieldFloor
        if fieldFloor and fieldFloor:IsA('BasePart') then
            return fieldFloor.CFrame + Vector3.new(-122, 4, 0)
        end
        return CFrame.new(538, 4, -20)
    elseif zoneId == 'ant_hell_floor_1' or zoneId == 'sewer_training_grounds' then
        local dungeonFloor = worldRefs.dungeonFloor
        if dungeonFloor and dungeonFloor:IsA('BasePart') then
            if zoneId == 'sewer_training_grounds' then
                return dungeonFloor.CFrame + Vector3.new(0, 4, 0)
            end
            return dungeonFloor.CFrame + Vector3.new(-56, 4, -42)
        end
        return CFrame.new(-56, 4, 196)
    elseif zoneId == 'tower_of_ascension' then
        local targetPosition = TOWER_OF_ASCENSION_FALLBACK_TARGET
        local spawnPosition = TOWER_OF_ASCENSION_POSITION
        local horizontalTarget = Vector3.new(targetPosition.X, spawnPosition.Y, targetPosition.Z)
        return CFrame.lookAt(spawnPosition, horizontalTarget)
    elseif zoneId == 'niffheim' then
        local maps = getMapsFolder()
        local niffheimMap = maps and maps:FindFirstChild('Niffheim')
        local spawnLanding = niffheimMap and niffheimMap:FindFirstChild('Map')
            and findNamedDescendant(niffheimMap.Map, 'SpawnLanding', 'Part')
        if spawnLanding and spawnLanding:IsA('BasePart') then
            local spawnPosition = spawnLanding.Position + Vector3.new(0, 6, 0)
            return CFrame.lookAt(spawnPosition, NIFFHEIM_CENTER + Vector3.new(-18, 4, 0))
        end
        local spawnPosition = NIFFHEIM_SPAWN_POSITION + Vector3.new(0, 6, 0)
        return CFrame.lookAt(spawnPosition, NIFFHEIM_CENTER + Vector3.new(-18, 4, 0))
    end

    return CFrame.new(0, 6, 0)
end

function WorldService.getSpawnCFrameForZoneId(zoneId: string?): CFrame
    local normalizedZoneId = normalizeZoneId(zoneId)
    local configuredDestination = WorldService.getWarpDestination(normalizedZoneId)
    if configuredDestination then
        return configuredDestination.cframe
    end
    return getFallbackSpawnCFrame(normalizedZoneId)
end

function WorldService.getDungeonSpawnCFrame(dungeonId: string): CFrame
    return WorldService.getSpawnCFrameForZoneId(dungeonId)
end

function WorldService.getNiffheimSpawnCFrame(): CFrame
    return WorldService.getSpawnCFrameForZoneId('niffheim')
end

local function getTeleportZoneConfig(zoneId: string)
    local mapBoxZone = getMapBoxZoneById(zoneId)
    if mapBoxZone then
        return {
            center = mapBoxZone.center,
            size = mapBoxZone.size,
            fallback = function()
                return getBasePartCFrame(mapBoxZone.part)
            end,
        }
    end

    local destination = WorldService.getWarpDestination(zoneId)
    if destination then
        return {
            center = destination.center,
            size = destination.size,
            fallback = function()
                return destination.cframe
            end,
        }
    end

    return nil
end

function WorldService.resolveZoneIdFromPosition(position: Vector3, fallbackZoneId: string?): string
    local mapBoxZone = resolveMapBoxZoneFromPosition(position)
    if mapBoxZone then
        return mapBoxZone.zoneId
    end

    return normalizeZoneId(fallbackZoneId)
end

function WorldService.getRandomTeleportCFrame(zoneId: string?, currentPosition: Vector3?, lookVector: Vector3?): CFrame
    local resolvedZoneId = normalizeZoneId(zoneId)
    local zoneConfig = getTeleportZoneConfig(resolvedZoneId)
    local fallbackCFrame = if zoneConfig and zoneConfig.fallback then zoneConfig.fallback() else WorldService.getFieldSpawnCFrame()

    if not zoneConfig then
        return fallbackCFrame
    end

    local filterInstances = {}
    for _, candidate in ipairs({
        Workspace:FindFirstChild('SpawnedDuringPlay') and Workspace.SpawnedDuringPlay:FindFirstChild('Enemies'),
        Workspace:FindFirstChild('SpawnedDuringPlay') and Workspace.SpawnedDuringPlay:FindFirstChild('Drops'),
        Workspace:FindFirstChild('PlayerUse'),
    }) do
        if candidate then
            table.insert(filterInstances, candidate)
        end
    end
    for _, mapFolder in ipairs(getMapFolders()) do
        local playerUse = getPlayerUseFolder(mapFolder)
        if playerUse then
            table.insert(filterInstances, playerUse)
        end
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = filterInstances
    raycastParams.IgnoreWater = true

    local fallbackPosition = fallbackCFrame.Position
    for _ = 1, 36 do
        local sampleX = zoneConfig.center.X + teleportRng:NextNumber(-zoneConfig.size.X * 0.5, zoneConfig.size.X * 0.5)
        local sampleZ = zoneConfig.center.Z + teleportRng:NextNumber(-zoneConfig.size.Y * 0.5, zoneConfig.size.Y * 0.5)
        local rayOrigin = Vector3.new(sampleX, math.max(fallbackPosition.Y + 220, 260), sampleZ)
        local rayResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -520, 0), raycastParams)
        if rayResult and rayResult.Instance and rayResult.Instance:IsA('BasePart') and rayResult.Normal.Y >= 0.55 then
            local destination = rayResult.Position + Vector3.new(0, 3.5, 0)
            if not currentPosition or (Vector3.new(destination.X, 0, destination.Z) - Vector3.new(currentPosition.X, 0, currentPosition.Z)).Magnitude >= 18 then
                local facing = lookVector and Vector3.new(lookVector.X, 0, lookVector.Z) or fallbackCFrame.LookVector
                if facing.Magnitude <= 0.05 then
                    facing = fallbackCFrame.LookVector
                else
                    facing = facing.Unit
                end
                return CFrame.lookAt(destination, destination + facing)
            end
        end
    end

    return fallbackCFrame
end

function WorldService.getWorldRefs()
    return worldRefs
end

return WorldService
