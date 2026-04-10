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

local function shouldCopyInstance(instance: Instance): boolean
    return COSMETIC_CLASSES[instance.ClassName] == true
end

local function shouldCopyFaceInstance(instance: Instance): boolean
    return FACE_COSMETIC_CLASSES[instance.ClassName] == true
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

    local ok, loaded = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)
    if not ok or not loaded then
        warn(string.format('[CharacterSkinService] Failed to load skin asset %d for template %s: %s', assetId, templateId, tostring(loaded)))
        return
    end

    local modelTemplate = resolveSkinModelFromAsset(loaded)
    if not modelTemplate then
        warn(string.format('[CharacterSkinService] Skin asset %d did not contain a model with cosmetics for template %s.', assetId, templateId))
        loaded:Destroy()
        return
    end

    local clone = modelTemplate:Clone()
    clone.Name = templateId
    clone.Parent = playerCharacters
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

local function applyTemplateFace(character: Model, template: Model)
    local characterHead = character:FindFirstChild('Head')
    if not (characterHead and characterHead:IsA('BasePart')) then
        return
    end

    clearFaceCosmetics(characterHead)

    local templateHead = findTemplateHead(template)
    if not templateHead then
        return
    end

    for _, child in ipairs(templateHead:GetChildren()) do
        if shouldCopyFaceInstance(child) then
            child:Clone().Parent = characterHead
        end
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
