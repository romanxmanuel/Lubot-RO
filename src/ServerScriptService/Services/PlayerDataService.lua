--!strict

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local DataStoreService = game:GetService('DataStoreService')
local RunService = game:GetService('RunService')

local DataSchema = require(script.Parent.Parent.Systems.Persistence.DataSchema)
local StatBalanceConfig = require(ReplicatedStorage.Shared.Config.StatBalanceConfig)
local ClassStageDefs = require(ReplicatedStorage.Shared.DataDefs.Progression.ClassStageDefs)
local ArchetypeDefs = require(ReplicatedStorage.Shared.DataDefs.Progression.ArchetypeDefs)
local EquipmentDefs = require(ReplicatedStorage.Shared.DataDefs.Items.EquipmentDefs)
local ItemDefs = require(ReplicatedStorage.Shared.DataDefs.Items.ItemDefs)
local SkillDefs = require(ReplicatedStorage.Shared.DataDefs.Skills.SkillDefs)
local SkillLoadout = require(ReplicatedStorage.Shared.Skills.SkillLoadout)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)
local AdminConfig = require(script.Parent.Parent.Config.AdminConfig)

local PlayerDataService = {}

local profileCache = {}
local HOTBAR_PRESET_VERSION = 5

local function shouldResetHotbarPreset(profile)
    local settings = profile.settings or {}
    return profile.archetypeId == 'knight_path' and (settings.hotbarPresetVersion or 0) < HOTBAR_PRESET_VERSION
end
local instanceCounter = 0
local profileStore = nil
local canUseDataStore = false
local MAX_BASE_LEVEL = 99
local MAX_JOB_LEVEL = 70

local function getRequiredBaseExperience(level: number): number
    return math.floor(50 * math.pow(math.max(level, 1), 2.2))
end

local function getRequiredJobExperience(jobLevel: number): number
    return math.floor(30 * math.pow(math.max(jobLevel, 1), 2.0))
end

local function getStatPointsGrantedForLevel(level: number): number
    return math.floor(math.max(level, 1) / 5) + 3
end

local function buildLevelUpSummary(baseLevelsGained: number, jobLevelsGained: number)
    return {
        baseLevelsGained = baseLevelsGained,
        jobLevelsGained = jobLevelsGained,
        didBaseLevelUp = baseLevelsGained > 0,
        didJobLevelUp = jobLevelsGained > 0,
        didAnyLevelUp = baseLevelsGained > 0 or jobLevelsGained > 0,
    }
end

local function getStatPointCost(currentValue: number): number
    return 2 + math.floor(math.max(currentValue, 1) / 10)
end

local function nextInstanceId(userId: number, itemId: string): string
    instanceCounter += 1
    return string.format('%d_%s_%d', userId, itemId, instanceCounter)
end

local function createItemInstance(player, entry)
    local itemId = entry.itemId
    local itemDef = ItemDefs[itemId]
    if not itemDef then
        return nil
    end

    local equipmentDef = EquipmentDefs[itemId]
    return {
        instanceId = nextInstanceId(player.UserId, itemId),
        itemId = itemId,
        itemType = itemDef.itemType,
        slot = itemDef.slot,
        enhancementTrack = equipmentDef and equipmentDef.enhancementTrack or nil,
        enhancementLevel = entry.enhancementLevel or 0,
        socketedCards = TableUtil.deepCopy(entry.socketedCards or {}),
        destroyed = false,
        obtainedAt = os.time(),
    }
end

local function ensureSettings(profile)
    profile.settings = profile.settings or {}
    profile.settings.hotbarSlots = profile.settings.hotbarSlots or {}
    profile.settings.itemHotbarSlots = profile.settings.itemHotbarSlots or {}
    profile.settings.customSkillHotkeys = profile.settings.customSkillHotkeys or {}
    profile.settings.equippedAmmoItemId = profile.settings.equippedAmmoItemId or ''
end

local function ensureArchetypeProgressionTables(profile)
    profile.archetypeProgression = profile.archetypeProgression or {}
    profile.starterPathClaims = profile.starterPathClaims or {}
end

local function ensureInventoryOrdering(profile)
    profile.inventoryOrder = profile.inventoryOrder or {}
    profile.cardOrder = profile.cardOrder or {}
    profile.inventorySortCounter = math.max(math.floor(tonumber(profile.inventorySortCounter) or 0), 0)

    local function assignOrder(orderTable, key)
        if key == nil or key == '' or orderTable[key] ~= nil then
            return
        end
        profile.inventorySortCounter += 1
        orderTable[key] = profile.inventorySortCounter
    end

    for itemId, amount in pairs(profile.inventory or {}) do
        if (tonumber(amount) or 0) > 0 then
            assignOrder(profile.inventoryOrder, itemId)
        else
            profile.inventoryOrder[itemId] = nil
        end
    end

    for itemId in pairs(profile.inventoryOrder) do
        if (tonumber((profile.inventory or {})[itemId]) or 0) <= 0 then
            profile.inventoryOrder[itemId] = nil
        end
    end

    for cardId, amount in pairs(profile.cards or {}) do
        if (tonumber(amount) or 0) > 0 then
            assignOrder(profile.cardOrder, cardId)
        else
            profile.cardOrder[cardId] = nil
        end
    end

    for cardId in pairs(profile.cardOrder) do
        if (tonumber((profile.cards or {})[cardId]) or 0) <= 0 then
            profile.cardOrder[cardId] = nil
        end
    end

    for _, itemInstance in pairs(profile.itemInstances or {}) do
        if itemInstance and not itemInstance.destroyed and itemInstance.obtainedAt == nil then
            itemInstance.obtainedAt = os.time()
        end
    end
end

local function sanitizeEquipmentSnapshot(profile, equipment)
    local sanitized = {}
    for slotName, instanceId in pairs(equipment or {}) do
        local itemInstance = profile.itemInstances[instanceId]
        if itemInstance and not itemInstance.destroyed and itemInstance.slot == slotName then
            sanitized[slotName] = instanceId
        end
    end

    return sanitized
end

local function capturePathSpecificSettings(profile)
    ensureSettings(profile)

    return {
        hotbarSlots = TableUtil.deepCopy(profile.settings.hotbarSlots),
        customSkillHotkeys = TableUtil.deepCopy(profile.settings.customSkillHotkeys),
        hotbarPresetVersion = profile.settings.hotbarPresetVersion,
        equippedAmmoItemId = profile.settings.equippedAmmoItemId,
    }
end

local function buildArchetypeSnapshot(profile)
    return {
        archetypeId = profile.archetypeId,
        classId = profile.classId,
        classStage = profile.classStage,
        level = profile.level,
        experience = profile.experience,
        jobLevel = profile.jobLevel,
        jobExperience = profile.jobExperience,
        statPoints = profile.statPoints,
        skillPoints = profile.skillPoints,
        rebirthCount = profile.rebirthCount,
        baseStats = TableUtil.deepCopy(profile.baseStats),
        equipment = sanitizeEquipmentSnapshot(profile, profile.equipment),
        unlockedSkills = TableUtil.deepCopy(profile.unlockedSkills or {}),
        skillRanks = TableUtil.deepCopy(profile.skillRanks or {}),
        settings = capturePathSpecificSettings(profile),
    }
end

local function normalizeActiveArchetypeState(profile)
    ensureSettings(profile)
    profile.equipment = sanitizeEquipmentSnapshot(profile, profile.equipment)

    if profile.archetypeId == 'archer_path' then
        local equippedAmmoItemId = tostring(profile.settings.equippedAmmoItemId or '')
        if equippedAmmoItemId == '' and (tonumber((profile.inventory or {}).arrow_bundle_small) or 0) > 0 then
            profile.settings.equippedAmmoItemId = 'arrow_bundle_small'
        end
    end

    if shouldResetHotbarPreset(profile) or next(profile.settings.hotbarSlots) == nil then
        profile.settings.hotbarSlots = SkillLoadout.buildDefaultHotbar(profile)
    end
    profile.settings.hotbarPresetVersion = HOTBAR_PRESET_VERSION
end

local function applyArchetypeSnapshot(profile, snapshot)
    ensureSettings(profile)

    profile.archetypeId = snapshot.archetypeId
    profile.classId = snapshot.classId
    profile.classStage = snapshot.classStage or 'Base'
    profile.level = snapshot.level or 1
    profile.experience = snapshot.experience or 0
    profile.jobLevel = snapshot.jobLevel or 1
    profile.jobExperience = snapshot.jobExperience or 0
    profile.statPoints = snapshot.statPoints or 0
    profile.skillPoints = snapshot.skillPoints or 1
    profile.rebirthCount = snapshot.rebirthCount or 0
    profile.baseStats = TableUtil.deepCopy(snapshot.baseStats or {})
    profile.equipment = sanitizeEquipmentSnapshot(profile, snapshot.equipment)
    profile.unlockedSkills = TableUtil.deepCopy(snapshot.unlockedSkills or {})
    profile.skillRanks = TableUtil.deepCopy(snapshot.skillRanks or {})
    profile.settings.hotbarSlots = TableUtil.deepCopy(snapshot.settings and snapshot.settings.hotbarSlots or {})
    profile.settings.customSkillHotkeys = TableUtil.deepCopy(snapshot.settings and snapshot.settings.customSkillHotkeys or {})
    profile.settings.hotbarPresetVersion = snapshot.settings and snapshot.settings.hotbarPresetVersion or 0
    profile.settings.equippedAmmoItemId = snapshot.settings and snapshot.settings.equippedAmmoItemId or ''

    profile.runtime.currentMana = nil
    profile.runtime.statusAilments = {}
    profile.runtime.activeBuffs = {}
    profile.runtime.skillCooldowns = {}

    normalizeActiveArchetypeState(profile)
end

local function grantTemplateConsumables(profile, template)
    for itemId, amount in pairs(template.inventory or {}) do
        profile.inventory[itemId] = (profile.inventory[itemId] or 0) + amount
    end
    ensureInventoryOrdering(profile)
end

local function buildFreshArchetypeSnapshot(player, profile, archetypeId: string)
    local template = DataSchema.getArchetypeTemplate(archetypeId)
    if not template then
        return nil
    end

    ensureArchetypeProgressionTables(profile)

    local snapshot = {
        archetypeId = template.archetypeId,
        classId = template.classId,
        classStage = 'Base',
        level = 1,
        experience = 0,
        jobLevel = 1,
        jobExperience = 0,
        statPoints = 0,
        skillPoints = 1,
        rebirthCount = 0,
        baseStats = TableUtil.deepCopy(template.baseStats),
        equipment = {},
        unlockedSkills = {},
        skillRanks = {},
        settings = {
            hotbarSlots = {},
            itemHotbarSlots = {},
            customSkillHotkeys = {},
            hotbarPresetVersion = HOTBAR_PRESET_VERSION,
        },
    }

    if not profile.starterPathClaims[archetypeId] then
        grantTemplateConsumables(profile, template)

        for _, entry in ipairs(template.starterEquipment or {}) do
            local itemInstance = createItemInstance(player, entry)
            if itemInstance then
                profile.itemInstances[itemInstance.instanceId] = itemInstance

                if entry.equipped and itemInstance.slot then
                    snapshot.equipment[itemInstance.slot] = itemInstance.instanceId
                end
            end
        end

        profile.starterPathClaims[archetypeId] = true
    end

    snapshot.settings.hotbarSlots = SkillLoadout.buildDefaultHotbar(snapshot)
    return snapshot
end

local function ensureArchetypeProgressionInitialized(profile)
    ensureArchetypeProgressionTables(profile)
    normalizeActiveArchetypeState(profile)
    profile.starterPathClaims[profile.archetypeId] = true
    profile.archetypeProgression[profile.archetypeId] = buildArchetypeSnapshot(profile)
end

local function applyAdminDefaults(player, profile)
    if not AdminConfig.isPlayerAuthorized(player) then
        return
    end

    profile.runtime = profile.runtime or {}
    profile.skillRanks = profile.skillRanks or {}
    profile.settings = profile.settings or {}

    for statName in pairs(profile.baseStats or {}) do
        profile.baseStats[statName] = StatBalanceConfig.BaseStats.MaxBaseStat
    end

    for _, skillDef in ipairs(SkillLoadout.getArchetypeSkillCatalog(profile)) do
        profile.skillRanks[skillDef.id] = skillDef.maxLevel or 1
    end

    profile.settings.adminNoCooldowns = false
    profile.runtime.skillCooldowns = {}
end

local function grantStarterLoadout(player, profile)
    if next(profile.itemInstances) ~= nil then
        return
    end

    local template = DataSchema.getArchetypeTemplate(profile.archetypeId) or DataSchema.getArchetypeTemplate('knight_path')
    if not template then
        return
    end

    for _, entry in ipairs(template.starterEquipment or {}) do
        local itemInstance = createItemInstance(player, entry)
        if itemInstance then
            profile.itemInstances[itemInstance.instanceId] = itemInstance

            if entry.equipped and itemInstance.slot then
                profile.equipment[itemInstance.slot] = itemInstance.instanceId
            end
        end
    end

    if profile.archetypeId == 'archer_path' and (tonumber((profile.inventory or {}).arrow_bundle_small) or 0) > 0 then
        profile.settings.equippedAmmoItemId = 'arrow_bundle_small'
    end
end

local function applySchema(profile)
    local merged = DataSchema.createDefaultProfile(profile.archetypeId)

    for key, value in pairs(profile) do
        if type(value) == 'table' and type((merged :: any)[key]) == 'table' then
            for nestedKey, nestedValue in pairs(value) do
                ((merged :: any)[key] :: any)[nestedKey] = nestedValue
            end
        else
            (merged :: any)[key] = value
        end
    end

    merged.version = DataSchema.Version
    return merged
end

function PlayerDataService.init()
    table.clear(profileCache)

    local ok, store = pcall(function()
        return DataStoreService:GetDataStore('RagnarokOnline_PlayerProfiles_v1')
    end)

    canUseDataStore = ok and store ~= nil
    profileStore = if canUseDataStore then store else nil

    if not canUseDataStore then
        warn(string.format('PlayerDataService: profile store unavailable%s.', if RunService:IsStudio() then ' in Studio. Enable Studio access to API services for persistence' else ''))
    end
end

function PlayerDataService.start()
    Players.PlayerAdded:Connect(function(player)
        PlayerDataService.loadProfile(player)
        player.CharacterAdded:Connect(function() end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        PlayerDataService.saveProfile(player)
        PlayerDataService.removeProfile(player)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        PlayerDataService.loadProfile(player)
    end

    task.spawn(function()
        while true do
            task.wait(60)
            for player in pairs(profileCache) do
                if player.Parent == Players then
                    PlayerDataService.saveProfile(player)
                end
            end
        end
    end)
end

function PlayerDataService.loadProfile(player)
    local existing = profileCache[player]
    if existing then
        return existing
    end

    local profile = nil
    local success, storedProfile = false, nil

    if canUseDataStore and profileStore then
        success, storedProfile = pcall(function()
            return profileStore:GetAsync(tostring(player.UserId))
        end)
        if not success then
            warn(string.format('PlayerDataService.loadProfile failed for %s: %s', player.Name, tostring(storedProfile)))
        end
    end

    if success and storedProfile then
        profile = applySchema(storedProfile)
    else
        profile = DataSchema.createDefaultProfile()
    end

    grantStarterLoadout(player, profile)
    applyAdminDefaults(player, profile)
    ensureInventoryOrdering(profile)
    ensureArchetypeProgressionInitialized(profile)
    profileCache[player] = profile

    return profile
end

function PlayerDataService.isAdminPowerEnabled(player): boolean
    return AdminConfig.isPlayerAuthorized(player)
end

function PlayerDataService.saveProfile(player)
    local profile = profileCache[player]
    if not profile then
        return nil
    end

    ensureArchetypeProgressionTables(profile)
    ensureInventoryOrdering(profile)
    profile.archetypeProgression[profile.archetypeId] = buildArchetypeSnapshot(profile)

    local payload = TableUtil.deepCopy(profile)
    if payload.runtime then
        payload.runtime = {
            lastZoneId = payload.runtime.lastZoneId,
        }
    end

    if canUseDataStore and profileStore then
        local success, err = pcall(function()
            profileStore:SetAsync(tostring(player.UserId), payload)
        end)
        if not success then
            warn(string.format('PlayerDataService.saveProfile failed for %s: %s', player.Name, tostring(err)))
        end
    end

    return profile
end

function PlayerDataService.getProfile(player)
    return profileCache[player]
end

function PlayerDataService.getOrCreateProfile(player)
    return profileCache[player] or PlayerDataService.loadProfile(player)
end

function PlayerDataService.removeProfile(player)
    profileCache[player] = nil
end

function PlayerDataService.allocateStat(player, statName: string): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local current = profile.baseStats[statName]
    if current == nil then
        return false, 'UnknownStat'
    end
    if current >= StatBalanceConfig.BaseStats.MaxBaseStat then
        return false, 'StatAtCap'
    end
    local cost = getStatPointCost(current)
    if profile.statPoints < cost then
        return false, 'NoStatPoints'
    end

    profile.baseStats[statName] += 1
    profile.statPoints -= cost
    return true, nil
end

function PlayerDataService.commitStatDraft(player, draft): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    if type(draft) ~= 'table' then
        return false, 'InvalidDraft'
    end

    local totalCost = 0
    for statName, deltaValue in pairs(draft) do
        local current = profile.baseStats[statName]
        if current == nil then
            return false, 'UnknownStat'
        end

        local delta = math.max(math.floor(tonumber(deltaValue) or 0), 0)
        local previewValue = current
        for _ = 1, delta do
            if previewValue >= StatBalanceConfig.BaseStats.MaxBaseStat then
                return false, 'StatAtCap'
            end
            totalCost += getStatPointCost(previewValue)
            previewValue += 1
        end
    end

    if totalCost <= 0 then
        return false, 'NoChanges'
    end

    if profile.statPoints < totalCost then
        return false, 'NoStatPoints'
    end

    for statName, deltaValue in pairs(draft) do
        local delta = math.max(math.floor(tonumber(deltaValue) or 0), 0)
        profile.baseStats[statName] += delta
    end

    profile.statPoints -= totalCost
    return true, nil
end

function PlayerDataService.setBaseStatValue(player, statName: string, targetValue: number): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    if profile.baseStats[statName] == nil then
        return false, 'UnknownStat'
    end

    local clampedValue = math.clamp(math.floor(targetValue), 1, StatBalanceConfig.BaseStats.MaxBaseStat)
    profile.baseStats[statName] = clampedValue
    return true, nil
end

function PlayerDataService.maxAllBaseStats(player): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    for statName in pairs(profile.baseStats) do
        profile.baseStats[statName] = StatBalanceConfig.BaseStats.MaxBaseStat
    end

    return true, nil
end

function PlayerDataService.resetBaseStats(player): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local template = DataSchema.getArchetypeTemplate(profile.archetypeId) or DataSchema.getArchetypeTemplate('knight_path')
    if template then
        profile.baseStats = TableUtil.deepCopy(template.baseStats)
    end
    return true, nil
end

function PlayerDataService.grantBaseLevels(player, amount: number): (boolean, string?, any?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local delta = math.max(math.floor(amount), 0)
    if delta <= 0 then
        return false, 'InvalidLevelAmount', nil
    end

    local baseLevelsGained = 0
    for _ = 1, delta do
        if profile.level >= MAX_BASE_LEVEL then
            break
        end

        profile.level += 1
        profile.statPoints += getStatPointsGrantedForLevel(profile.level)
        baseLevelsGained += 1
    end

    profile.experience = 0
    return true, nil, buildLevelUpSummary(baseLevelsGained, 0)
end

function PlayerDataService.grantJobLevels(player, amount: number): (boolean, string?, any?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local delta = math.max(math.floor(amount), 0)
    if delta <= 0 then
        return false, 'InvalidJobLevelAmount', nil
    end

    local jobLevelsGained = 0
    for _ = 1, delta do
        if profile.jobLevel >= MAX_JOB_LEVEL then
            break
        end

        profile.jobLevel += 1
        profile.skillPoints += 1
        jobLevelsGained += 1
    end

    profile.jobExperience = 0
    return true, nil, buildLevelUpSummary(0, jobLevelsGained)
end

function PlayerDataService.setSkillRank(player, skillId: string, rank: number): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local skillDef = SkillDefs[skillId]
    if not skillDef then
        return false, 'UnknownSkill'
    end

    profile.skillRanks = profile.skillRanks or {}
    local clampedRank = math.clamp(math.floor(rank), 0, skillDef.maxLevel or 1)
    profile.skillRanks[skillId] = clampedRank
    return true, nil
end

function PlayerDataService.investSkillPoint(player, skillId: string): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local canInvest, reason = SkillLoadout.canInvestSkill(profile, skillId)
    if not canInvest then
        return false, reason
    end

    profile.skillRanks = profile.skillRanks or {}
    profile.skillRanks[skillId] = SkillLoadout.getSkillRank(profile, skillId) + 1
    profile.skillPoints -= 1
    return true, nil
end

function PlayerDataService.maxAllAvailableSkills(player): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    profile.skillRanks = profile.skillRanks or {}

    for _, skillDef in ipairs(SkillLoadout.getArchetypeSkillCatalog(profile)) do
        profile.skillRanks[skillDef.id] = skillDef.maxLevel or 1
    end

    return true, nil
end

function PlayerDataService.resetSkillOverrides(player): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    profile.skillRanks = {}
    return true, nil
end

function PlayerDataService.setAdminNoCooldowns(player, enabled: boolean): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    profile.settings.adminNoCooldowns = enabled == true
    if not profile.settings.adminNoCooldowns then
        profile.runtime.skillCooldowns = {}
    end
    return true, nil
end

function PlayerDataService.getClassSequence(profile)
    local archetype = ArchetypeDefs[profile.archetypeId]
    return archetype and archetype.stageSequence or nil
end

function PlayerDataService.getNextClassId(profile)
    local sequence = PlayerDataService.getClassSequence(profile)
    if not sequence then
        return nil
    end

    for index, classId in ipairs(sequence) do
        if classId == profile.classId then
            return sequence[index + 1]
        end
    end

    return nil
end

function PlayerDataService.canAdvanceClass(player): (boolean, string?, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local nextClassId = PlayerDataService.getNextClassId(profile)
    if not nextClassId then
        return false, 'NoFurtherAdvancement', nil
    end

    local currentClassDef = ClassStageDefs[profile.classId]
    if not currentClassDef then
        return false, 'MissingClassDef', nil
    end

    if profile.jobLevel < currentClassDef.promotionLevel then
        return false, 'JobLevelTooLow', nextClassId
    end

    return true, nil, nextClassId
end

function PlayerDataService.advanceClass(player): (boolean, string?, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local ok, reason, nextClassId = PlayerDataService.canAdvanceClass(player)
    if not ok or not nextClassId then
        return false, reason, nil
    end

    local nextDef = ClassStageDefs[nextClassId]
    profile.classId = nextClassId
    profile.classStage = nextDef.stage
    profile.jobLevel = 1
    profile.jobExperience = 0
    profile.skillPoints += 3
    profile.settings.hotbarSlots = SkillLoadout.buildDefaultHotbar(profile)
    applyAdminDefaults(player, profile)

    return true, nil, nextClassId
end

function PlayerDataService.canRebirth(player): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    if profile.classStage ~= 'High' then
        return false, 'OnlyHighClassCanRebirth'
    end

    local classDef = ClassStageDefs[profile.classId]
    if not classDef or profile.jobLevel < classDef.promotionLevel then
        return false, 'JobLevelTooLowForRebirth'
    end

    return true, nil
end

function PlayerDataService.rebirth(player): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local ok, reason = PlayerDataService.canRebirth(player)
    if not ok then
        return false, reason
    end

    local sequence = PlayerDataService.getClassSequence(profile)
    if not sequence or not sequence[3] then
        return false, 'MissingRebirthClass'
    end

    profile.classId = sequence[3]
    profile.classStage = 'Rebirth'
    profile.level = 1
    profile.experience = 0
    profile.jobLevel = 1
    profile.jobExperience = 0
    profile.statPoints += 10
    profile.skillPoints += 5
    profile.rebirthCount += 1
    profile.settings.hotbarSlots = SkillLoadout.buildDefaultHotbar(profile)
    applyAdminDefaults(player, profile)

    return true, nil
end

function PlayerDataService.getArchetypeProgressionSummary(player)
    local profile = PlayerDataService.getOrCreateProfile(player)
    ensureArchetypeProgressionTables(profile)

    local summary = {}
    for archetypeId, archetypeDef in pairs(ArchetypeDefs) do
        local template = DataSchema.getArchetypeTemplate(archetypeId)
        local snapshot = if profile.archetypeId == archetypeId then buildArchetypeSnapshot(profile) else profile.archetypeProgression[archetypeId]

        summary[archetypeId] = {
            archetypeId = archetypeId,
            displayName = archetypeDef.displayName,
            family = archetypeDef.family,
            classId = if snapshot then snapshot.classId else (template and template.classId or archetypeId),
            classStage = if snapshot then snapshot.classStage else 'Base',
            level = if snapshot then snapshot.level else 1,
            jobLevel = if snapshot then snapshot.jobLevel else 1,
            rebirthCount = if snapshot then snapshot.rebirthCount else 0,
            hasProgress = snapshot ~= nil,
            isCurrent = profile.archetypeId == archetypeId,
        }
    end

    return summary
end

function PlayerDataService.changeArchetype(player, archetypeId: string): (boolean, string?)
    local archetypeDef = ArchetypeDefs[archetypeId]
    if not archetypeDef then
        return false, 'UnknownArchetype'
    end

    local profile = PlayerDataService.getOrCreateProfile(player)
    if profile.archetypeId == archetypeId then
        return false, 'AlreadyOnArchetype'
    end

    ensureArchetypeProgressionTables(profile)
    profile.archetypeProgression[profile.archetypeId] = buildArchetypeSnapshot(profile)

    local targetSnapshot = profile.archetypeProgression[archetypeId]
    if not targetSnapshot then
        targetSnapshot = buildFreshArchetypeSnapshot(player, profile, archetypeId)
        if not targetSnapshot then
            return false, 'MissingArchetypeTemplate'
        end
        profile.archetypeProgression[archetypeId] = targetSnapshot
    end

    applyArchetypeSnapshot(profile, targetSnapshot)
    applyAdminDefaults(player, profile)
    profile.archetypeProgression[archetypeId] = buildArchetypeSnapshot(profile)
    PlayerDataService.saveProfile(player)

    return true, nil
end

function PlayerDataService.setHotbarSkill(player, slotIndex: number, skillId: string?): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    if slotIndex < 1 or slotIndex > 18 then
        return false, 'InvalidSlot'
    end

    if skillId and skillId ~= '' and not SkillLoadout.canEquipSkill(profile, skillId) then
        return false, 'SkillNotUnlocked'
    end

    profile.settings.hotbarSlots = profile.settings.hotbarSlots or {}
    profile.settings.itemHotbarSlots = profile.settings.itemHotbarSlots or {}
    profile.settings.hotbarSlots[tostring(slotIndex)] = if skillId and skillId ~= '' then skillId else nil
    if skillId and skillId ~= '' then
        profile.settings.itemHotbarSlots[tostring(slotIndex)] = nil
    end

    return true, nil
end

function PlayerDataService.setHotbarItem(player, slotIndex: number, itemId: string?): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    if slotIndex < 1 or slotIndex > 18 then
        return false, 'InvalidSlot'
    end

    if itemId and itemId ~= '' then
        local itemDef = ItemDefs[itemId]
        if not itemDef then
            return false, 'UnknownItem'
        end
        if itemDef.itemType ~= 'Consumable' then
            return false, 'NotConsumable'
        end
    end

    profile.settings.itemHotbarSlots = profile.settings.itemHotbarSlots or {}
    profile.settings.hotbarSlots = profile.settings.hotbarSlots or {}
    profile.settings.itemHotbarSlots[tostring(slotIndex)] = if itemId and itemId ~= '' then itemId else nil
    if itemId and itemId ~= '' then
        profile.settings.hotbarSlots[tostring(slotIndex)] = nil
    end

    return true, nil
end

function PlayerDataService.setCustomSkillHotkey(player, keyCodeName: string, skillId: string?): (boolean, string?)
    local profile = PlayerDataService.getOrCreateProfile(player)
    profile.settings.customSkillHotkeys = profile.settings.customSkillHotkeys or {}

    if not keyCodeName or keyCodeName == '' then
        return false, 'InvalidKey'
    end

    if skillId and skillId ~= '' and not SkillLoadout.canEquipSkill(profile, skillId) then
        return false, 'SkillNotUnlocked'
    end

    for existingKey, existingSkillId in pairs(profile.settings.customSkillHotkeys) do
        if existingKey == keyCodeName or existingSkillId == skillId then
            profile.settings.customSkillHotkeys[existingKey] = nil
        end
    end

    if skillId and skillId ~= '' then
        profile.settings.customSkillHotkeys[keyCodeName] = skillId
    end

    return true, nil
end

function PlayerDataService.fullHeal(player)
    local profile = PlayerDataService.getOrCreateProfile(player)
    profile.runtime.statusAilments = {}
end

function PlayerDataService.addCombatRewards(player, experience: number, jobExperience: number, zeny: number)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local baseLevelsGained = 0
    local jobLevelsGained = 0

    profile.experience += experience
    profile.jobExperience += jobExperience
    profile.zeny += zeny

    while profile.level < MAX_BASE_LEVEL and profile.experience >= getRequiredBaseExperience(profile.level) do
        profile.experience -= getRequiredBaseExperience(profile.level)
        profile.level += 1
        profile.statPoints += getStatPointsGrantedForLevel(profile.level)
        baseLevelsGained += 1
    end

    while profile.jobLevel < MAX_JOB_LEVEL and profile.jobExperience >= getRequiredJobExperience(profile.jobLevel) do
        profile.jobExperience -= getRequiredJobExperience(profile.jobLevel)
        profile.jobLevel += 1
        profile.skillPoints += 1
        jobLevelsGained += 1
    end

    return buildLevelUpSummary(baseLevelsGained, jobLevelsGained)
end

function PlayerDataService.applyDeathPenalty(player): number
    local profile = PlayerDataService.getOrCreateProfile(player)
    local penalty = math.floor(getRequiredBaseExperience(profile.level) * 0.05)
    if penalty <= 0 then
        return 0
    end

    local previousExperience = profile.experience
    profile.experience = math.max(profile.experience - penalty, 0)
    return previousExperience - profile.experience
end

function PlayerDataService.getRequiredBaseExperience(level: number): number
    return getRequiredBaseExperience(level)
end

function PlayerDataService.getRequiredJobExperience(jobLevel: number): number
    return getRequiredJobExperience(jobLevel)
end

function PlayerDataService.getStatPointCost(currentValue: number): number
    return getStatPointCost(currentValue)
end

function PlayerDataService.getStatPointsGrantedForLevel(level: number): number
    return getStatPointsGrantedForLevel(level)
end

return PlayerDataService
