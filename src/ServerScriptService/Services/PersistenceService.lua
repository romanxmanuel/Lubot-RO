--!strict

local DataStoreService = game:GetService('DataStoreService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ClassData = require(ReplicatedStorage.GameData.Classes.KnightData)
local StatConfig = require(ReplicatedStorage.Shared.Config.StatConfig)
local SkillLoadout = require(ReplicatedStorage.Shared.Skills.SkillLoadout)

local PersistenceService = {
    Name = 'PersistenceService',
}

local dataStore = DataStoreService:GetDataStore(GameConfig.SaveStoreName)
local profileCache: { [Player]: any } = {}
local memoryFallback: { [number]: any } = {}

local function deepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = deepCopy(nested)
    end
    return copy
end

local function createDefaultProfile()
    local knight = ClassData.knight
    local inventory = {}
    for _, entry in ipairs(knight.starterItems) do
        table.insert(inventory, {
            itemId = entry.itemId,
            amount = entry.amount,
        })
    end

    return {
        version = GameConfig.Version,
        archetypeId = 'knight_path',
        classId = knight.id,
        level = 1,
        experience = 0,
        zeny = knight.starterZeny,
        equippedWeaponId = knight.starterWeaponId,
        inventory = inventory,
        unlockedSkills = deepCopy(knight.starterSkills),
        skillLoadout = deepCopy(knight.starterSkills),
        lastWarpId = GameConfig.StartingWarpId,
        statPoints = StatConfig.StartingStatPoints,
        stats = deepCopy(StatConfig.StartingStats),
        skinTemplateId = 'DekuCharacterTemplate',
    }
end

local function normalizeProfile(rawProfile)
    local profile = type(rawProfile) == 'table' and rawProfile or createDefaultProfile()
    local defaults = createDefaultProfile()

    for key, defaultValue in pairs(defaults) do
        if profile[key] == nil then
            profile[key] = deepCopy(defaultValue)
        end
    end

    profile.jobLevel = nil
    profile.jobExperience = nil

    return profile
end

local function getBaseExperienceRequirement(level: number): number
    return 100 + math.max(0, level - 1) * 45
end

local function reconcileProgression(profile)
    local unlockedById = {}
    local orderedUnlocked = {}

    for _, skillDef in ipairs(SkillLoadout.getUnlockedSkills(profile)) do
        if skillDef and skillDef.id and not unlockedById[skillDef.id] then
            unlockedById[skillDef.id] = true
            table.insert(orderedUnlocked, skillDef.id)
        end
    end

    profile.unlockedSkills = orderedUnlocked

    local nextLoadout = {}
    local seen = {}

    for _, skillId in ipairs(profile.skillLoadout or {}) do
        if type(skillId) == 'string' and not seen[skillId] and SkillLoadout.canEquipSkill(profile, skillId) then
            seen[skillId] = true
            table.insert(nextLoadout, skillId)
        end
    end

    for _, skillId in ipairs(orderedUnlocked) do
        if not seen[skillId] then
            seen[skillId] = true
            table.insert(nextLoadout, skillId)
        end
    end

    profile.skillLoadout = nextLoadout
end

local function syncPlayerSummaryAttributes(player: Player, profile)
    player:SetAttribute('ClassId', profile.classId)
    player:SetAttribute('Level', profile.level)
    player:SetAttribute('JobLevel', nil)
    player:SetAttribute('Zeny', profile.zeny)
    player:SetAttribute('Experience', profile.experience)
    player:SetAttribute('ExperienceMax', getBaseExperienceRequirement(profile.level))
    player:SetAttribute('JobExperience', nil)
    player:SetAttribute('JobExperienceMax', nil)
end

function PersistenceService.init()
    return nil
end

function PersistenceService.start()
    local function loadProfile(player: Player)
        local key = string.format('player_%d', player.UserId)
        local loadedProfile = nil

        local ok, result = pcall(function()
            return dataStore:GetAsync(key)
        end)

        if ok then
            loadedProfile = result
        else
            loadedProfile = memoryFallback[player.UserId]
        end

        local profile = normalizeProfile(loadedProfile)
        reconcileProgression(profile)
        profileCache[player] = profile
        memoryFallback[player.UserId] = deepCopy(profile)
        syncPlayerSummaryAttributes(player, profile)
    end

    local function saveProfile(player: Player)
        local profile = profileCache[player]
        if not profile then
            return
        end

        local key = string.format('player_%d', player.UserId)
        memoryFallback[player.UserId] = deepCopy(profile)

        pcall(function()
            dataStore:SetAsync(key, profile)
        end)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        loadProfile(player)
    end

    Players.PlayerAdded:Connect(loadProfile)
    Players.PlayerRemoving:Connect(function(player)
        saveProfile(player)
        profileCache[player] = nil
    end)

    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            saveProfile(player)
        end
    end)
end

function PersistenceService.waitForProfile(player: Player, timeoutSeconds: number?)
    local timeoutAt = os.clock() + (timeoutSeconds or 10)
    while os.clock() < timeoutAt do
        local profile = profileCache[player]
        if profile then
            return profile
        end
        task.wait(0.1)
    end
    return profileCache[player]
end

function PersistenceService.getProfile(player: Player)
    return profileCache[player]
end

function PersistenceService.updateProfile(player: Player, mutator)
    local profile = profileCache[player]
    if not profile then
        return
    end

    mutator(profile)
    reconcileProgression(profile)
    syncPlayerSummaryAttributes(player, profile)
    memoryFallback[player.UserId] = deepCopy(profile)
end

function PersistenceService.addZeny(player: Player, amount: number)
    PersistenceService.updateProfile(player, function(profile)
        profile.zeny += amount
    end)
end

function PersistenceService.setLastWarpId(player: Player, warpId: string)
    PersistenceService.updateProfile(player, function(profile)
        profile.lastWarpId = warpId
    end)
end

function PersistenceService.getBaseExperienceRequirement(level: number): number
    return getBaseExperienceRequirement(level)
end

function PersistenceService.grantExperience(player: Player, amount: number, jobAmount: number)
    local levelsGained = 0
    local leveledUp = false

    PersistenceService.updateProfile(player, function(profile)
        profile.experience += math.max(0, amount or 0) + math.max(0, jobAmount or 0)

        while profile.experience >= getBaseExperienceRequirement(profile.level) do
            profile.experience -= getBaseExperienceRequirement(profile.level)
            profile.level += 1
            levelsGained += 1
            leveledUp = true
        end

        if levelsGained > 0 then
            profile.statPoints += levelsGained * StatConfig.PointsPerLevel
        end
    end)

    return leveledUp, false
end

return PersistenceService
