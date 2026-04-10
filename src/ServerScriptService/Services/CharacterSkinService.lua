--!strict

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local CharacterSkinService = {
    Name = 'CharacterSkinService',
}

local dependencies = nil

local COSMETIC_CLASSES = {
    Accessory = true,
    Shirt = true,
    Pants = true,
    BodyColors = true,
    ShirtGraphic = true,
    CharacterMesh = true,
}

local function getSkinTemplate(templateId: string): Model?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    local playerCharacters = gameParts and gameParts:FindFirstChild('PlayerCharacters')
    local template = playerCharacters and playerCharacters:FindFirstChild(templateId)
    if template and template:IsA('Model') then
        return template
    end
    return nil
end

local function shouldCopyInstance(instance: Instance): boolean
    return COSMETIC_CLASSES[instance.ClassName] == true
end

local function clearSkinCosmetics(character: Model)
    for _, child in ipairs(character:GetChildren()) do
        if shouldCopyInstance(child) then
            child:Destroy()
        end
    end
end

local function applyTemplateToCharacter(character: Model, template: Model)
    clearSkinCosmetics(character)

    for _, child in ipairs(template:GetChildren()) do
        if shouldCopyInstance(child) then
            child:Clone().Parent = character
        end
    end
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
end

function CharacterSkinService.start()
    local function bindPlayer(player: Player)
        local function applyCurrent()
            local profile = dependencies.PersistenceService.waitForProfile(player, 10)
            if not profile then
                return
            end
            local templateId = profile.skinTemplateId or 'DekuCharacterTemplate'
            local template = getSkinTemplate(templateId)
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
                local template = getSkinTemplate(templateId)
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

function CharacterSkinService.applySkin(player: Player, templateId: string): boolean
    local template = getSkinTemplate(templateId)
    if not template then
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
