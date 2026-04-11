--!strict

local Players = game:GetService('Players')
local InsertService = game:GetService('InsertService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local ItemData = require(ReplicatedStorage.GameData.Items.ItemData)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local CharacterSkinService = {
    Name = 'CharacterSkinService',
}

local dependencies = nil
local dynamicTemplateAssetIds: { [string]: number } = {}
local templateItemIds: { [string]: string } = {}

local COSMETIC_CLASSES = {
    Accessory = true,
    Shirt = true,
    Pants = true,
    BodyColors = true,
    ShirtGraphic = true,
    CharacterMesh = true,
}

local FACE_COSMETIC_CLASSES = {
    Decal = true,
    Texture = true,
}

local EFFECT_NODE_CLASSES = {
    Attachment = true,
    ParticleEmitter = true,
    Trail = true,
    Beam = true,
    PointLight = true,
    SpotLight = true,
    SurfaceLight = true,
}

local CORE_CHARACTER_PART_NAMES = {
    Head = true,
    HumanoidRootPart = true,
    Torso = true,
    ['Left Arm'] = true,
    ['Right Arm'] = true,
    ['Left Leg'] = true,
    ['Right Leg'] = true,
    UpperTorso = true,
    LowerTorso = true,
    LeftUpperArm = true,
    LeftLowerArm = true,
    LeftHand = true,
    RightUpperArm = true,
    RightLowerArm = true,
    RightHand = true,
    LeftUpperLeg = true,
    LeftLowerLeg = true,
    LeftFoot = true,
    RightUpperLeg = true,
    RightLowerLeg = true,
    RightFoot = true,
}

local function shouldCopyInstance(instance: Instance): boolean
    return COSMETIC_CLASSES[instance.ClassName] == true
end

local function shouldCopyFaceInstance(instance: Instance): boolean
    return FACE_COSMETIC_CLASSES[instance.ClassName] == true
end

local function isEffectNodeClass(className: string): boolean
    return EFFECT_NODE_CLASSES[className] == true
end

local function isCoreCharacterPartName(name: string): boolean
    return CORE_CHARACTER_PART_NAMES[name] == true
end

local function markTreeAttribute(root: Instance, attrName: string)
    root:SetAttribute(attrName, true)
    for _, descendant in ipairs(root:GetDescendants()) do
        descendant:SetAttribute(attrName, true)
    end
end

local function getPlayerCharactersFolder(): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    if not gameParts then
        return nil
    end

    local playerCharacters = gameParts and gameParts:FindFirstChild('PlayerCharacters')
    if playerCharacters and playerCharacters:IsA('Folder') then
        return playerCharacters
    end
    return nil
end

local function ensurePlayerCharactersFolder(): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    if not gameParts then
        return nil
    end

    local playerCharacters = gameParts:FindFirstChild('PlayerCharacters')
    if playerCharacters and playerCharacters:IsA('Folder') then
        return playerCharacters
    end

    local created = Instance.new('Folder')
    created.Name = 'PlayerCharacters'
    created.Parent = gameParts
    return created
end

local function getImportedSkinCacheRoot(): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    if not gameParts then
        return nil
    end

    local importedAssets = gameParts:FindFirstChild('ImportedAssets')
    if not (importedAssets and importedAssets:IsA('Folder')) then
        importedAssets = Instance.new('Folder')
        importedAssets.Name = 'ImportedAssets'
        importedAssets.Parent = gameParts
    end

    local skinsFolder = importedAssets:FindFirstChild('Skins')
    if not (skinsFolder and skinsFolder:IsA('Folder')) then
        skinsFolder = Instance.new('Folder')
        skinsFolder.Name = 'Skins'
        skinsFolder.Parent = importedAssets
    end

    return skinsFolder :: Folder
end

local function sanitizeFolderName(rawName: string): string
    return string.gsub(rawName, '[^%w_%-]', '_')
end

local function scoreModelCosmetics(model: Model): number
    local score = 0
    if model:FindFirstChildOfClass('Humanoid') then
        score += 1000
    end
    for _, descendant in ipairs(model:GetDescendants()) do
        if shouldCopyInstance(descendant) then
            score += 1
        end
    end
    return score
end

local function resolveSkinModelFromAsset(assetContainer: Instance): Model?
    local bestModel: Model? = nil
    local bestScore = -1

    if assetContainer:IsA('Model') then
        local score = scoreModelCosmetics(assetContainer)
        if score > bestScore then
            bestModel = assetContainer
            bestScore = score
        end
    end

    for _, descendant in ipairs(assetContainer:GetDescendants()) do
        if descendant:IsA('Model') then
            local score = scoreModelCosmetics(descendant)
            if score > bestScore then
                bestModel = descendant
                bestScore = score
            end
        end
    end

    return bestModel
end

local function getWorkspaceAssetContainer(assetId: number): Instance?
    local wanted = tostring(assetId)

    for _, child in ipairs(workspace:GetChildren()) do
        if string.find(string.lower(child.Name), string.lower(wanted), 1, true) then
            return child
        end
    end

    return nil
end

local function buildSkinFolderName(templateId: string, itemId: string?, assetId: number): string
    if itemId and itemId ~= '' then
        return sanitizeFolderName(string.format('%s_%d', itemId, assetId))
    end
    return sanitizeFolderName(string.format('%s_%d', templateId, assetId))
end

local function cacheTemplateFromContainer(templateId: string, itemId: string?, assetId: number, sourceContainer: Instance): boolean
    local playerCharacters = ensurePlayerCharactersFolder()
    local skinCacheRoot = getImportedSkinCacheRoot()
    if not playerCharacters or not skinCacheRoot then
        return false
    end

    local folderName = buildSkinFolderName(templateId, itemId, assetId)
    local skinFolder = skinCacheRoot:FindFirstChild(folderName)
    if not (skinFolder and skinFolder:IsA('Folder')) then
        skinFolder = Instance.new('Folder')
        skinFolder.Name = folderName
        skinFolder.Parent = skinCacheRoot
    end

    local existingSource = skinFolder:FindFirstChild('SourcePackage')
    if existingSource then
        existingSource:Destroy()
    end

    local sourceClone = sourceContainer:Clone()
    sourceClone.Name = 'SourcePackage'
    sourceClone.Parent = skinFolder

    local modelTemplate = resolveSkinModelFromAsset(sourceClone)
    if not modelTemplate then
        return false
    end

    local existingTemplate = playerCharacters:FindFirstChild(templateId)
    if existingTemplate then
        existingTemplate:Destroy()
    end

    local clone = modelTemplate:Clone()
    clone.Name = templateId
    clone.Parent = playerCharacters
    return true
end

local function loadTemplateFromCachedSource(templateId: string, itemId: string?, assetId: number): boolean
    local skinCacheRoot = getImportedSkinCacheRoot()
    if not skinCacheRoot then
        return false
    end

    local folderName = buildSkinFolderName(templateId, itemId, assetId)
    local skinFolder = skinCacheRoot:FindFirstChild(folderName)
    if not (skinFolder and skinFolder:IsA('Folder')) then
        return false
    end

    local sourcePackage = skinFolder:FindFirstChild('SourcePackage')
    if not sourcePackage then
        return false
    end

    return cacheTemplateFromContainer(templateId, itemId, assetId, sourcePackage)
end

local function loadAssetContainer(assetId: number): Instance?
    local okInsert, loadedInsert = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    if okInsert and loadedInsert then
        return loadedInsert
    end

    local okObjects, loadedObjects = pcall(function()
        return game:GetObjects(string.format('rbxassetid://%d', assetId))
    end)
    if okObjects and type(loadedObjects) == 'table' and #loadedObjects > 0 then
        local firstInstance = loadedObjects[1]
        if typeof(firstInstance) == 'Instance' then
            return firstInstance
        end
    end

    warn(string.format('[CharacterSkinService] Failed to load skin asset %d via InsertService and game:GetObjects.', assetId))
    if not okInsert then
        warn(string.format('[CharacterSkinService] InsertService error for %d: %s', assetId, tostring(loadedInsert)))
    end
    if not okObjects then
        warn(string.format('[CharacterSkinService] game:GetObjects error for %d: %s', assetId, tostring(loadedObjects)))
    end
    return nil
end

local function ensureDynamicTemplateLoaded(templateId: string, explicitAssetId: number?)
    local playerCharacters = ensurePlayerCharactersFolder()
    if not playerCharacters then
        return
    end

    local existing = playerCharacters:FindFirstChild(templateId)
    if existing and existing:IsA('Model') then
        return
    end

    local assetId = explicitAssetId or dynamicTemplateAssetIds[templateId]
    if not assetId then
        return
    end

    local itemId = templateItemIds[templateId]
    if loadTemplateFromCachedSource(templateId, itemId, assetId) then
        return
    end

    local workspaceContainer = getWorkspaceAssetContainer(assetId)
    if workspaceContainer and cacheTemplateFromContainer(templateId, itemId, assetId, workspaceContainer) then
        return
    end

    local loaded = loadAssetContainer(assetId)
    if not loaded then
        return
    end

    if cacheTemplateFromContainer(templateId, itemId, assetId, loaded) then
        loaded:Destroy()
        return
    end

    local modelTemplate = resolveSkinModelFromAsset(loaded)
    if modelTemplate then
        local clone = modelTemplate:Clone()
        clone.Name = templateId
        clone.Parent = playerCharacters
    else
        warn(string.format('[CharacterSkinService] Skin asset %d did not contain a model with cosmetics for template %s.', assetId, templateId))
    end
    loaded:Destroy()
end

local function getSkinTemplate(templateId: string, explicitAssetId: number?): Model?
    ensureDynamicTemplateLoaded(templateId, explicitAssetId)
    local playerCharacters = getPlayerCharactersFolder()
    local template = playerCharacters and playerCharacters:FindFirstChild(templateId)
    if template and template:IsA('Model') then
        return template
    end
    return nil
end

local function clearSkinCosmetics(character: Model)
    for _, child in ipairs(character:GetChildren()) do
        if shouldCopyInstance(child) then
            child:Destroy()
        end
    end
end

local function clearFaceCosmetics(head: BasePart)
    for _, child in ipairs(head:GetChildren()) do
        if shouldCopyFaceInstance(child) then
            child:Destroy()
        end
    end
end

local function findTemplateHead(template: Model): BasePart?
    for _, descendant in ipairs(template:GetDescendants()) do
        if descendant:IsA('BasePart') and descendant.Name == 'Head' then
            return descendant
        end
    end
    return nil
end

local function clearSkinAddonParts(character: Model)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA('BasePart') and child:GetAttribute('SkinAddonPart') == true then
            child:Destroy()
        end
    end
end

local function clearSkinEffectNodes(character: Model)
    local toDestroy = {}
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:GetAttribute('SkinEffectNode') == true then
            table.insert(toDestroy, descendant)
        end
    end
    for _, instance in ipairs(toDestroy) do
        if instance.Parent then
            instance:Destroy()
        end
    end
end

local function templatePartWeldedToHead(templatePart: BasePart, templateHead: BasePart): boolean
    for _, child in ipairs(templatePart:GetChildren()) do
        if child:IsA('Weld') then
            if child.Part0 == templateHead or child.Part1 == templateHead then
                return true
            end
        elseif child:IsA('WeldConstraint') then
            if child.Part0 == templateHead or child.Part1 == templateHead then
                return true
            end
        end
    end
    return false
end

local function stripPartJoints(part: BasePart)
    for _, descendant in ipairs(part:GetDescendants()) do
        if descendant:IsA('Weld') or descendant:IsA('WeldConstraint') or descendant:IsA('Motor6D') then
            descendant:Destroy()
        end
    end
end

local function applyTemplateHeadAddons(character: Model, template: Model)
    clearSkinAddonParts(character)

    local characterHead = character:FindFirstChild('Head')
    local templateHead = findTemplateHead(template)
    if not (characterHead and characterHead:IsA('BasePart') and templateHead) then
        return
    end

    for _, descendant in ipairs(template:GetDescendants()) do
        if descendant:IsA('BasePart') and descendant ~= templateHead then
            if descendant:FindFirstAncestorOfClass('Accessory') then
                continue
            end
            if isCoreCharacterPartName(descendant.Name) then
                continue
            end
            if not templatePartWeldedToHead(descendant, templateHead) then
                continue
            end

            local clonePart = descendant:Clone()
            stripPartJoints(clonePart)
            clonePart.Name = descendant.Name
            local relative = templateHead.CFrame:ToObjectSpace(descendant.CFrame)
            clonePart.CFrame = characterHead.CFrame * relative
            clonePart.Anchored = false
            clonePart.CanCollide = false
            clonePart.Massless = true
            clonePart:SetAttribute('SkinAddonPart', true)
            clonePart.Parent = character

            local weldConstraint = Instance.new('WeldConstraint')
            weldConstraint.Part0 = clonePart
            weldConstraint.Part1 = characterHead
            weldConstraint.Parent = clonePart
        end
    end
end

local function attachmentContainsEffects(attachment: Attachment): boolean
    for _, descendant in ipairs(attachment:GetDescendants()) do
        if descendant ~= attachment and isEffectNodeClass(descendant.ClassName) and not descendant:IsA('Attachment') then
            return true
        end
    end
    return false
end

local function shouldCopyPartEffectNode(instance: Instance): boolean
    if instance:IsA('Attachment') then
        return attachmentContainsEffects(instance)
    end

    return isEffectNodeClass(instance.ClassName) and not instance:IsA('Attachment')
end

local function applyTemplatePartEffects(character: Model, template: Model)
    clearSkinEffectNodes(character)

    for _, templatePart in ipairs(template:GetDescendants()) do
        if not templatePart:IsA('BasePart') then
            continue
        end

        local targetPart = character:FindFirstChild(templatePart.Name)
        if not (targetPart and targetPart:IsA('BasePart')) then
            continue
        end

        for _, child in ipairs(templatePart:GetChildren()) do
            if shouldCopyPartEffectNode(child) then
                local clone = child:Clone()
                markTreeAttribute(clone, 'SkinEffectNode')
                clone.Parent = targetPart
            end
        end
    end
end

local function applyTemplateFace(character: Model, template: Model)
    local characterHead = character:FindFirstChild('Head')
    if not (characterHead and characterHead:IsA('BasePart')) then
        return
    end

    local templateHead = findTemplateHead(template)
    if not templateHead then
        return
    end

    local templateFaceNodes = {}
    for _, child in ipairs(templateHead:GetChildren()) do
        if shouldCopyFaceInstance(child) then
            table.insert(templateFaceNodes, child)
        end
    end

    -- Keep existing face if the template does not include one.
    if #templateFaceNodes == 0 then
        return
    end

    clearFaceCosmetics(characterHead)
    for _, faceNode in ipairs(templateFaceNodes) do
        faceNode:Clone().Parent = characterHead
    end
end

local function extractHumanoidDescription(template: Model): HumanoidDescription?
    for _, descendant in ipairs(template:GetDescendants()) do
        if descendant:IsA('Humanoid') then
            local ok, description = pcall(function()
                return descendant:GetAppliedDescription()
            end)
            if ok and description and description:IsA('HumanoidDescription') then
                return description
            end
        end
    end
    return nil
end

local function applyTemplateToCharacter(character: Model, template: Model)
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local description = extractHumanoidDescription(template)
    if humanoid and description then
        pcall(function()
            humanoid:ApplyDescription(description)
        end)
    end

    clearSkinCosmetics(character)

    for _, descendant in ipairs(template:GetDescendants()) do
        if shouldCopyInstance(descendant) then
            descendant:Clone().Parent = character
        end
    end

    applyTemplateFace(character, template)
    applyTemplateHeadAddons(character, template)
    applyTemplatePartEffects(character, template)
end

local function applySkinToCharacter(player: Player, templateId: string)
    local character = player.Character
    if not character then
        return false
    end

    local template = getSkinTemplate(templateId)
    if not template then
        return false
    end

    applyTemplateToCharacter(character, template)
    return true
end

function CharacterSkinService.init(deps)
    dependencies = deps

    for _, itemDef in pairs(ItemData) do
        if itemDef.toolKind == 'skin'
            and type(itemDef.skinTemplateId) == 'string'
            and type(itemDef.skinAssetId) == 'number'
        then
            dynamicTemplateAssetIds[itemDef.skinTemplateId] = itemDef.skinAssetId
            templateItemIds[itemDef.skinTemplateId] = itemDef.id
        end
    end
end

function CharacterSkinService.start()
    local function bindPlayer(player: Player)
        local function applyCurrent()
            local profile = dependencies.PersistenceService.waitForProfile(player, 10)
            if not profile then
                return
            end
            local templateId = profile.skinTemplateId or 'DekuCharacterTemplate'
            local template = getSkinTemplate(templateId, nil)
            if template and player.Character then
                applyTemplateToCharacter(player.Character, template)
            end
        end

        player.CharacterAdded:Connect(function(character)
            task.defer(function()
                local profile = dependencies.PersistenceService.waitForProfile(player, 10)
                if not profile then
                    return
                end
                local templateId = profile.skinTemplateId or 'DekuCharacterTemplate'
                local template = getSkinTemplate(templateId, nil)
                if template then
                    applyTemplateToCharacter(character, template)
                end
            end)
        end)

        if player.Character then
            task.defer(applyCurrent)
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        bindPlayer(player)
    end

    Players.PlayerAdded:Connect(bindPlayer)
end

function CharacterSkinService.applySkin(player: Player, templateId: string, skinAssetId: number?): boolean
    local template = getSkinTemplate(templateId, skinAssetId)
    if not template then
        dependencies.Runtime.SystemMessage:FireClient(
            player,
            string.format('Could not apply skin: template %s failed to load.', templateId)
        )
        return false
    end

    dependencies.PersistenceService.updateProfile(player, function(profile)
        profile.skinTemplateId = templateId
    end)

    local success = applySkinToCharacter(player, templateId)
    if success then
        local root = player.Character and player.Character:FindFirstChild('HumanoidRootPart')
        if root and root:IsA('BasePart') then
            dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.SkinBurst, {
                userId = player.UserId,
                position = root.Position,
                templateId = templateId,
            })
        end
        dependencies.Runtime.SystemMessage:FireClient(player, string.format('Skin applied: %s', template.Name))
    end
    return success
end

return CharacterSkinService
