--!strict

local InsertService = game:GetService('InsertService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')

local ImportedAssetData = require(ReplicatedStorage.GameData.ImportedAssets.ImportedAssetData)
local ItemData = require(ReplicatedStorage.GameData.Items.ItemData)
local SkillData = require(ReplicatedStorage.GameData.Skills.SkillData)

local ImportedAssetService = {
    Name = 'ImportedAssetService',
}

local dependencies = nil
local assetDefsSorted = {}
local assetDefByItemId: { [string]: any } = {}
local dropWatcherConnection: RBXScriptConnection? = nil
local trackedToolConnections: { [Tool]: RBXScriptConnection } = {}

local SOURCE_PACKAGE_NAME = 'SourcePackage'
local TOOL_TEMPLATE_NAME = 'ToolTemplate'
local STATIC_PICKUP_FOLDER_NAME = 'ImportedAssetPickups'
local RUNTIME_DROP_FOLDER_NAME = 'DroppedInventoryPickups'
local DEFAULT_PICKUP_BASE_CFRAME = CFrame.new(-281.5, 6.35, 268.25)
local DEFAULT_PICKUP_COLUMNS = 5
local DEFAULT_PICKUP_SPACING_X = 6.2
local DEFAULT_PICKUP_SPACING_Z = 6.2
local DROP_PICKUP_LIFETIME = 120

local function ensureFolder(parent: Instance, name: string): Folder
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA('Folder') then
        return existing
    end

    if existing then
        existing:Destroy()
    end

    local created = Instance.new('Folder')
    created.Name = name
    created.Parent = parent
    return created
end

local function clearChildren(parent: Instance)
    for _, child in ipairs(parent:GetChildren()) do
        child:Destroy()
    end
end

local function getGameParts(): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    if gameParts and gameParts:IsA('Folder') then
        return gameParts
    end
    return nil
end

local function getImportedRoot(): Folder?
    local gameParts = getGameParts()
    if not gameParts then
        return nil
    end
    return ensureFolder(gameParts, 'ImportedAssets')
end

local function getAssetFolder(assetDef): Folder?
    local importedRoot = getImportedRoot()
    if not importedRoot then
        return nil
    end
    return ensureFolder(importedRoot, assetDef.folderName)
end

local function findWorkspaceAssetContainer(assetId: number): Instance?
    local direct = Workspace:FindFirstChild(tostring(assetId))
    if direct then
        return direct
    end

    for _, child in ipairs(Workspace:GetChildren()) do
        local taggedAssetId = tonumber(child:GetAttribute('ImportedAssetId'))
        if taggedAssetId and taggedAssetId == assetId then
            return child
        end
    end

    return nil
end

local function getStaticPickupFolder(): Folder?
    local maps = Workspace:FindFirstChild('Maps')
    local zoltraak = maps and maps:FindFirstChild('Zoltraak')
    local playerUse = zoltraak and zoltraak:FindFirstChild('PlayerUse')
    if not (playerUse and playerUse:IsA('Folder')) then
        return nil
    end
    return ensureFolder(playerUse, STATIC_PICKUP_FOLDER_NAME)
end

local function getRuntimeDropFolder(): Folder
    local spawnedDuringPlay = Workspace:FindFirstChild('SpawnedDuringPlay')
    if not (spawnedDuringPlay and spawnedDuringPlay:IsA('Folder')) then
        spawnedDuringPlay = Instance.new('Folder')
        spawnedDuringPlay.Name = 'SpawnedDuringPlay'
        spawnedDuringPlay.Parent = Workspace
    end
    return ensureFolder(spawnedDuringPlay, RUNTIME_DROP_FOLDER_NAME)
end

local function collectBaseParts(root: Instance): { BasePart }
    local parts = {}
    if root:IsA('BasePart') then
        table.insert(parts, root)
    end
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA('BasePart') then
            table.insert(parts, descendant)
        end
    end
    return parts
end

local function getFirstBasePart(root: Instance): BasePart?
    if root:IsA('BasePart') then
        return root
    end
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA('BasePart') then
            return descendant
        end
    end
    return nil
end

local function placeInstanceAtCFrame(root: Instance, targetCFrame: CFrame): boolean
    if root:IsA('Model') then
        root:PivotTo(targetCFrame)
        return true
    end

    if root:IsA('BasePart') then
        root.CFrame = targetCFrame
        return true
    end

    local anchorPart = getFirstBasePart(root)
    if not anchorPart then
        return false
    end

    local transform = targetCFrame * anchorPart.CFrame:Inverse()
    for _, part in ipairs(collectBaseParts(root)) do
        part.CFrame = transform * part.CFrame
    end
    return true
end

local function configureDisplayPhysics(displayRoot: Instance)
    for _, part in ipairs(collectBaseParts(displayRoot)) do
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.Massless = true
    end
end

local function disableDisplayScripts(displayRoot: Instance)
    if displayRoot:IsA('Script') or displayRoot:IsA('LocalScript') then
        displayRoot.Disabled = true
    end

    for _, descendant in ipairs(displayRoot:GetDescendants()) do
        if descendant:IsA('Script') or descendant:IsA('LocalScript') then
            descendant.Disabled = true
        end
    end
end

local function classifyAssetContainer(root: Instance): string
    local hasTool = root:IsA('Tool')
    local hasHumanoid = false
    local hasParticleOrBeam = false
    local hasAnimation = false
    local hasScript = root:IsA('Script') or root:IsA('LocalScript') or root:IsA('ModuleScript')

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA('Tool') then
            hasTool = true
        elseif descendant:IsA('Humanoid') then
            hasHumanoid = true
        elseif descendant:IsA('ParticleEmitter') or descendant:IsA('Beam') or descendant:IsA('Trail') then
            hasParticleOrBeam = true
        elseif descendant:IsA('Animation') then
            hasAnimation = true
        elseif descendant:IsA('Script') or descendant:IsA('LocalScript') or descendant:IsA('ModuleScript') then
            hasScript = true
        end
    end

    if hasTool then
        return 'tool'
    end
    if hasHumanoid then
        return 'character_model'
    end
    if hasParticleOrBeam or hasAnimation then
        return 'vfx_or_skill_pack'
    end
    if hasScript then
        return 'script'
    end
    return 'model_or_unknown'
end

local function findToolCandidate(root: Instance): Tool?
    if root:IsA('Tool') then
        return root
    end

    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA('Tool') then
            return descendant
        end
    end
    return nil
end

local function loadAssetContainer(assetId: number): Instance?
    local okInsert, loadedInsert = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    if okInsert and loadedInsert then
        return loadedInsert
    end
    warn(string.format('[ImportedAssetService] Failed to load asset %d with InsertService: %s', assetId, tostring(loadedInsert)))
    return nil
end

local function sourceHasContent(source: Instance?): boolean
    if not source then
        return false
    end

    if #source:GetChildren() > 0 then
        return true
    end

    return #source:GetDescendants() > 0
end

local function ensureToolTemplate(assetDef, assetFolder: Folder, source: Instance)
    local itemDef = assetDef.itemId and ItemData[assetDef.itemId]
    if not itemDef or itemDef.toolKind ~= 'imported_tool' then
        return
    end

    local existing = assetFolder:FindFirstChild(TOOL_TEMPLATE_NAME)
    if existing and existing:IsA('Tool') then
        existing:SetAttribute('ImportedAssetId', assetDef.assetId)
        existing:SetAttribute('ItemId', assetDef.itemId)
        return
    end
    if existing then
        existing:Destroy()
    end

    local template: Tool
    local toolCandidate = findToolCandidate(source)
    if toolCandidate then
        template = toolCandidate:Clone()
    else
        template = Instance.new('Tool')
        template.RequiresHandle = true
        template.ToolTip = itemDef.description or itemDef.displayName
        template.CanBeDropped = true
        template.Name = itemDef.displayName or assetDef.displayName

        local handleSource = getFirstBasePart(source)
        local handle = if handleSource then handleSource:Clone() else Instance.new('Part')
        handle.Name = 'Handle'
        handle.Size = if handle:IsA('BasePart') then handle.Size else Vector3.new(1, 1, 1)
        handle.Anchored = false
        handle.CanCollide = false
        handle.CanTouch = false
        handle.CanQuery = false
        handle.Massless = true
        handle.Parent = template

        local payload = source:Clone()
        payload.Name = 'SourcePayload'
        payload.Parent = template
    end

    template.Name = TOOL_TEMPLATE_NAME
    template:SetAttribute('ImportedAssetId', assetDef.assetId)
    template:SetAttribute('ItemId', assetDef.itemId)
    template.Parent = assetFolder
end

local function ensureSourcePackage(assetDef): Instance?
    local assetFolder = getAssetFolder(assetDef)
    if not assetFolder then
        return nil
    end

    local source = assetFolder:FindFirstChild(SOURCE_PACKAGE_NAME)
    if sourceHasContent(source) then
        ensureToolTemplate(assetDef, assetFolder, source :: Instance)
        return source
    end
    if source then
        source:Destroy()
    end

    local workspaceSource = findWorkspaceAssetContainer(assetDef.assetId)
    local loaded = if workspaceSource then workspaceSource:Clone() else loadAssetContainer(assetDef.assetId)
    if not loaded then
        warn(string.format('[ImportedAssetService] Could not load asset %d (%s).', assetDef.assetId, tostring(assetDef.displayName)))
        return nil
    end

    loaded.Name = SOURCE_PACKAGE_NAME
    loaded:SetAttribute('ImportedAssetId', assetDef.assetId)
    loaded:SetAttribute('ExpectedType', assetDef.expectedType or '')
    local detectedType = classifyAssetContainer(loaded)
    loaded:SetAttribute('DetectedType', detectedType)
    loaded.Parent = assetFolder

    print(string.format(
        '[ImportedAssetService] Classified asset %d (%s) as %s (expected: %s).',
        assetDef.assetId,
        tostring(assetDef.displayName or assetDef.id),
        detectedType,
        tostring(assetDef.expectedType or 'n/a')
    ))

    ensureToolTemplate(assetDef, assetFolder, loaded)
    return loaded
end

local function getTemplateTool(assetDef): Tool?
    local assetFolder = getAssetFolder(assetDef)
    if not assetFolder then
        return nil
    end

    local template = assetFolder:FindFirstChild(TOOL_TEMPLATE_NAME)
    if template and template:IsA('Tool') then
        return template
    end
    return nil
end

local function disableImportedToolScripts(tool: Tool)
    for _, descendant in ipairs(tool:GetDescendants()) do
        if descendant:IsA('Script') or descendant:IsA('LocalScript') then
            descendant.Disabled = true
        end
    end
end

local function disableScriptsUnder(instance: Instance)
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('Script') or descendant:IsA('LocalScript') then
            descendant.Disabled = true
        end
    end
end

local function applyToolCompatibilityFixes(tool: Tool, assetDef)
    -- Shadow Crescendo package ships duplicated script trees in Handle + root.
    -- Keeping both active causes hard runtime errors and breaks backpack flow.
    if tonumber(assetDef.assetId) == 10288446354 then
        local handle = tool:FindFirstChild('Handle')
        if handle then
            disableScriptsUnder(handle)
        end
    end

    -- Azure package expects an embedded SoundBank child under CresHorror that is missing
    -- in this import variant, causing infinite-yield spam.
    if tonumber(assetDef.assetId) == 10288498712 then
        local cres = tool:FindFirstChild('CresHorror')
        if cres and cres:IsA('Script') and not cres:FindFirstChild('SoundBank') then
            cres.Disabled = true
        end
    end
end

local function getDisplayName(assetDef): string
    if assetDef.grantType == 'item' and assetDef.itemId then
        local itemDef = ItemData[assetDef.itemId]
        if itemDef and itemDef.displayName then
            return itemDef.displayName
        end
    elseif assetDef.grantType == 'skill' and assetDef.skillId then
        local skillDef = SkillData[assetDef.skillId]
        if skillDef and skillDef.displayName then
            return skillDef.displayName
        end
    end
    return assetDef.displayName or tostring(assetDef.id)
end

local function getPickupPrompt(assetDef): string
    if assetDef.pickupPrompt and assetDef.pickupPrompt ~= '' then
        return assetDef.pickupPrompt
    end

    if assetDef.grantType == 'skill' then
        return 'Learn ' .. getDisplayName(assetDef)
    end
    return 'Take ' .. getDisplayName(assetDef)
end

local function resolvePickupCFrame(assetDef, orderedIndex: number): CFrame
    if typeof(assetDef.pickupCFrame) == 'CFrame' then
        return assetDef.pickupCFrame
    end

    local index = math.max(1, tonumber(assetDef.spawnIndex) or orderedIndex)
    local offsetIndex = index - 1
    local row = math.floor(offsetIndex / DEFAULT_PICKUP_COLUMNS)
    local col = offsetIndex % DEFAULT_PICKUP_COLUMNS
    return DEFAULT_PICKUP_BASE_CFRAME * CFrame.new(col * DEFAULT_PICKUP_SPACING_X, 0, row * DEFAULT_PICKUP_SPACING_Z)
end

local function createFallbackVisual(parent: Instance, color: Color3)
    local orb = Instance.new('Part')
    orb.Name = 'FallbackVisual'
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(1.9, 1.9, 1.9)
    orb.Material = Enum.Material.Neon
    orb.Color = color
    orb.Anchored = true
    orb.CanCollide = false
    orb.CanTouch = false
    orb.CanQuery = false
    orb.Parent = parent
    return orb
end

local function spawnPickupModel(displaySource: Instance?, assetDef, grantPayload, targetCFrame: CFrame, parent: Instance, respawnOnPickup: boolean)
    local pickupModel = Instance.new('Model')
    pickupModel.Name = assetDef.pickupName or string.format('ImportedPickup_%s', tostring(assetDef.id))
    pickupModel:SetAttribute('ImportedPickup', true)
    pickupModel:SetAttribute('ImportedAssetId', assetDef.assetId)
    pickupModel:SetAttribute('GrantType', grantPayload.grantType)
    if grantPayload.itemId then
        pickupModel:SetAttribute('GrantItemId', grantPayload.itemId)
    end
    if grantPayload.skillId then
        pickupModel:SetAttribute('GrantSkillId', grantPayload.skillId)
    end
    if grantPayload.amount then
        pickupModel:SetAttribute('GrantAmount', tonumber(grantPayload.amount) or 1)
    end

    local root = Instance.new('Part')
    root.Name = 'PickupRoot'
    root.Size = Vector3.new(3, 3.8, 3)
    root.Transparency = 1
    root.Anchored = true
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.CFrame = targetCFrame
    root.Parent = pickupModel
    pickupModel.PrimaryPart = root

    local displayPlaced = false
    if displaySource then
        local displayClone = displaySource:Clone()
        displayClone.Name = 'Display'
        displayClone.Parent = pickupModel
        disableDisplayScripts(displayClone)
        configureDisplayPhysics(displayClone)
        displayPlaced = placeInstanceAtCFrame(displayClone, targetCFrame * CFrame.new(0, 1.1, 0))
    end

    if not displayPlaced then
        local fallback = createFallbackVisual(pickupModel, Color3.fromRGB(162, 206, 255))
        fallback.CFrame = targetCFrame * CFrame.new(0, 1.1, 0)
    end

    local prompt = Instance.new('ProximityPrompt')
    prompt.Name = 'PickupPrompt'
    prompt.ActionText = 'Pick Up'
    prompt.ObjectText = getPickupPrompt(assetDef)
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 14
    prompt.Parent = root

    local label = Instance.new('BillboardGui')
    label.Name = 'PickupLabel'
    label.Size = UDim2.fromOffset(230, 54)
    label.StudsOffset = Vector3.new(0, 4.8, 0)
    label.AlwaysOnTop = true
    label.MaxDistance = 48
    label.Parent = root

    local frame = Instance.new('Frame')
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = label

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 9)
    corner.Parent = frame

    local stroke = Instance.new('UIStroke')
    stroke.Thickness = 1.2
    stroke.Transparency = 0.14
    stroke.Color = Color3.fromRGB(176, 214, 255)
    stroke.Parent = frame

    local text = Instance.new('TextLabel')
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamBold
    text.TextSize = 14
    text.TextColor3 = Color3.fromRGB(248, 252, 255)
    text.Text = getDisplayName(assetDef)
    text.Parent = frame

    local claimed = false
    prompt.Triggered:Connect(function(player)
        if claimed then
            return
        end
        claimed = true

        local success, message = ImportedAssetService.grantAsset(player, grantPayload)
        if not success then
            claimed = false
            if message and message ~= '' then
                dependencies.Runtime.SystemMessage:FireClient(player, message)
            end
            return
        end

        pickupModel:Destroy()
        if respawnOnPickup then
            task.delay(1.8, function()
                if parent.Parent == nil then
                    return
                end
                spawnPickupModel(displaySource, assetDef, grantPayload, targetCFrame, parent, true)
            end)
        end
    end)

    pickupModel.Parent = parent
    if not respawnOnPickup then
        task.delay(DROP_PICKUP_LIFETIME, function()
            if pickupModel.Parent then
                pickupModel:Destroy()
            end
        end)
    end
    return pickupModel
end

local function getPickupDisplaySource(assetDef): Instance?
    local source = ensureSourcePackage(assetDef)
    if source then
        return source
    end
    return nil
end

local function resolveItemDropAmount(tool: Tool): number
    local amountAttr = tonumber(tool:GetAttribute('Amount'))
    if amountAttr and amountAttr >= 1 then
        return math.floor(amountAttr)
    end
    return 1
end

local function getToolWorldCFrame(tool: Tool): CFrame?
    local handle = tool:FindFirstChild('Handle')
    if handle and handle:IsA('BasePart') then
        return handle.CFrame
    end

    local firstPart = getFirstBasePart(tool)
    if firstPart then
        return firstPart.CFrame
    end
    return nil
end

local function findAssetDefByItemId(itemId: string?)
    if not itemId then
        return nil
    end
    return assetDefByItemId[itemId]
end

local function findAssetDefBySkillId(skillId: string?)
    for _, assetDef in ipairs(assetDefsSorted) do
        if assetDef.grantType == 'skill' and assetDef.skillId == skillId then
            return assetDef
        end
    end
    return nil
end

local function spawnDroppedToolPickup(tool: Tool, itemId: string?, skillId: string?)
    local dropFolder = getRuntimeDropFolder()
    local toolCFrame = getToolWorldCFrame(tool)
    if not toolCFrame then
        return
    end

    local fallbackDef = {
        id = string.format('runtime_drop_%d', math.floor(os.clock() * 1000)),
        assetId = tonumber(tool:GetAttribute('ImportedAssetId')) or 0,
        displayName = tool.Name,
        pickupName = string.format('Dropped_%s', tool.Name),
        pickupPrompt = string.format('Take %s', tool.Name),
    }

    local grantPayload = {
        grantType = if skillId and skillId ~= '' then 'skill' else 'item',
        itemId = itemId,
        skillId = skillId,
        amount = resolveItemDropAmount(tool),
    }

    local assetDef = if grantPayload.grantType == 'item'
        then findAssetDefByItemId(itemId)
        else findAssetDefBySkillId(skillId)

    local displaySource: Instance = tool
    local pickupDef = assetDef or fallbackDef

    spawnPickupModel(
        displaySource,
        pickupDef,
        grantPayload,
        CFrame.new(toolCFrame.Position),
        dropFolder,
        false
    )
end

local function processDroppedTool(tool: Tool)
    if tool.Parent ~= Workspace then
        return
    end

    if tool:GetAttribute('DropProcessed') == true then
        return
    end

    if tool:GetAttribute('ImportedPickupDisplay') == true then
        return
    end

    local ownerUserId = tonumber(tool:GetAttribute('InventoryOwnerUserId'))
    if not ownerUserId then
        return
    end

    local owner = Players:GetPlayerByUserId(ownerUserId)
    if not owner then
        return
    end

    local itemId = tool:GetAttribute('ItemId')
    local skillId = tool:GetAttribute('SkillId')
    if itemId ~= nil then
        itemId = tostring(itemId)
    end
    if skillId ~= nil then
        skillId = tostring(skillId)
    end
    if (not itemId or itemId == '') and (not skillId or skillId == '') then
        return
    end

    local removed = false
    if skillId and skillId ~= '' then
        removed = dependencies.InventoryService.removeSkill(owner, skillId)
    elseif itemId and itemId ~= '' then
        removed = dependencies.InventoryService.removeItem(owner, itemId, resolveItemDropAmount(tool))
    end

    if not removed then
        return
    end

    tool:SetAttribute('DropProcessed', true)
    spawnDroppedToolPickup(tool, itemId, skillId)
    tool:Destroy()
end

local function disconnectTrackedTool(tool: Tool)
    local existing = trackedToolConnections[tool]
    if existing then
        existing:Disconnect()
        trackedToolConnections[tool] = nil
    end
end

local function bindToolDropWatcher()
    if dropWatcherConnection then
        dropWatcherConnection:Disconnect()
        dropWatcherConnection = nil
    end

    dropWatcherConnection = Workspace.ChildAdded:Connect(function(child)
        if not child:IsA('Tool') then
            return
        end
        task.defer(function()
            processDroppedTool(child)
        end)
    end)
end

function ImportedAssetService.init(deps)
    dependencies = deps
    table.clear(assetDefsSorted)
    table.clear(assetDefByItemId)

    for _, assetDef in pairs(ImportedAssetData) do
        if type(assetDef) == 'table' and tonumber(assetDef.assetId) then
            table.insert(assetDefsSorted, assetDef)
            if assetDef.itemId then
                assetDefByItemId[tostring(assetDef.itemId)] = assetDef
            end
        end
    end

    table.sort(assetDefsSorted, function(a, b)
        local aIndex = tonumber(a.spawnIndex) or 99999
        local bIndex = tonumber(b.spawnIndex) or 99999
        if aIndex == bIndex then
            return tostring(a.id) < tostring(b.id)
        end
        return aIndex < bIndex
    end)
end

function ImportedAssetService.start()
    local staticPickupFolder = getStaticPickupFolder()
    if not staticPickupFolder then
        warn('[ImportedAssetService] Static pickup folder is missing (Workspace.Maps.Zoltraak.PlayerUse).')
    else
        clearChildren(staticPickupFolder)
        for index, assetDef in ipairs(assetDefsSorted) do
            local source = getPickupDisplaySource(assetDef)
            local spawnCFrame = resolvePickupCFrame(assetDef, index)
            local grantPayload = {
                grantType = assetDef.grantType,
                itemId = assetDef.itemId,
                skillId = assetDef.skillId,
                amount = 1,
            }
            spawnPickupModel(source, assetDef, grantPayload, spawnCFrame, staticPickupFolder, true)
        end
    end

    bindToolDropWatcher()
end

function ImportedAssetService.trackInventoryTool(tool: Tool, ownerUserId: number)
    if not tool or not tool:IsA('Tool') then
        return
    end

    tool:SetAttribute('InventoryOwnerUserId', ownerUserId)

    if trackedToolConnections[tool] then
        return
    end

    trackedToolConnections[tool] = tool.AncestryChanged:Connect(function(_, parent)
        if parent == Workspace then
            processDroppedTool(tool)
            return
        end

        if parent == nil then
            disconnectTrackedTool(tool)
        end
    end)
end

function ImportedAssetService.createToolClone(itemId: string): Tool?
    local assetDef = assetDefByItemId[itemId]
    if not assetDef then
        return nil
    end

    local source = ensureSourcePackage(assetDef)
    if not source then
        return nil
    end

    local assetFolder = getAssetFolder(assetDef)
    if not assetFolder then
        return nil
    end

    ensureToolTemplate(assetDef, assetFolder, source)
    local template = getTemplateTool(assetDef)
    if not template then
        return nil
    end

    local clone = template:Clone()
    local itemDef = ItemData[itemId]
    if itemDef and itemDef.displayName then
        clone.Name = itemDef.displayName
    end

    clone:SetAttribute('ImportedAssetId', assetDef.assetId)
    clone:SetAttribute('ImportedInputPriority', true)
    clone:SetAttribute('ItemId', itemId)
    clone:SetAttribute('InventoryItemId', itemId)
    clone.CanBeDropped = true

    -- Preserve community tool behavior for actual tool assets.
    -- Script or unknown packs are kept as collectible tools but sandboxed to avoid runtime breakage.
    local expectedType = tostring(assetDef.expectedType or '')
    if expectedType ~= 'tool' then
        disableImportedToolScripts(clone)
    else
        applyToolCompatibilityFixes(clone, assetDef)
    end

    return clone
end

function ImportedAssetService.grantAsset(player: Player, grantPayload)
    local grantType = tostring(grantPayload.grantType or '')
    if grantType == 'skill' then
        local skillId = tostring(grantPayload.skillId or '')
        if skillId == '' then
            return false, 'This skill pickup is misconfigured.'
        end
        if not SkillData[skillId] then
            return false, string.format('Unknown skill: %s', skillId)
        end
        local granted = dependencies.InventoryService.grantSkill(player, skillId)
        if granted then
            dependencies.Runtime.SystemMessage:FireClient(player, string.format('Learned skill: %s', SkillData[skillId].displayName or skillId))
        else
            dependencies.Runtime.SystemMessage:FireClient(player, string.format('You already know: %s', SkillData[skillId].displayName or skillId))
        end
        return true, nil
    end

    local itemId = tostring(grantPayload.itemId or '')
    if itemId == '' then
        return false, 'This pickup has no item mapping.'
    end
    if not ItemData[itemId] then
        return false, string.format('Unknown item: %s', itemId)
    end

    local amount = math.max(1, math.floor(tonumber(grantPayload.amount) or 1))
    dependencies.InventoryService.addItem(player, itemId, amount)
    dependencies.Runtime.SystemMessage:FireClient(player, string.format('Picked up: %s x%d', ItemData[itemId].displayName or itemId, amount))
    return true, nil
end

return ImportedAssetService
