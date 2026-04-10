--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local CardDefs = require(ReplicatedStorage.Shared.DataDefs.Cards.CardDefs)
local EquipmentDefs = require(ReplicatedStorage.Shared.DataDefs.Items.EquipmentDefs)
local SkillInputConfig = require(ReplicatedStorage.Shared.Config.SkillInputConfig)
local ArchetypeDefs = require(ReplicatedStorage.Shared.DataDefs.Progression.ArchetypeDefs)
local SkillDefs = require(ReplicatedStorage.Shared.DataDefs.Skills.SkillDefs)
local SkillProgressionDefs = require(ReplicatedStorage.Shared.DataDefs.Progression.SkillProgressionDefs)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local SkillLoadout = {}

local DEFAULT_SLOT_COUNT = 18
local SHARED_UTILITY_SKILLS = {
    dash_step = true,
    teleport = true,
    blink_step = true,
}

local function addUniqueSkill(target, seen, skillDef)
    if skillDef and not seen[skillDef.id] then
        seen[skillDef.id] = true
        table.insert(target, skillDef)
    end
end

local function addGrantedSkillRank(target, skillId, rank)
    if type(skillId) ~= 'string' or skillId == '' then
        return
    end

    target[skillId] = math.max(target[skillId] or 0, math.max(math.floor(tonumber(rank) or 1), 1))
end

local function getEquippedGrantState(profile)
    local grantedSkills = {}
    local hotbarOverrides = {}
    local equipment = profile.equipment or {}
    local itemInstances = profile.itemInstances or {}

    for _, instanceId in pairs(equipment) do
        local itemInstance = itemInstances[instanceId]
        if itemInstance and not itemInstance.destroyed then
            local equipmentDef = EquipmentDefs[itemInstance.itemId]
            if equipmentDef then
                for skillId, rank in pairs(equipmentDef.grantedSkills or {}) do
                    addGrantedSkillRank(grantedSkills, skillId, rank)
                end

                for slotIndex, skillId in pairs(equipmentDef.hotbarOverrides or {}) do
                    local slotKey = tostring(slotIndex)
                    if type(skillId) == 'string' and skillId ~= '' and slotKey ~= '' then
                        hotbarOverrides[slotKey] = skillId
                    end
                end
            end

            for _, cardId in ipairs(itemInstance.socketedCards or {}) do
                local cardDef = CardDefs[cardId]
                local socketEffect = cardDef and cardDef.socketEffect or nil
                local grantedSkillId = socketEffect and socketEffect.grantedSkillId or nil
                if grantedSkillId then
                    addGrantedSkillRank(grantedSkills, grantedSkillId, socketEffect.grantedSkillRank)
                end
            end
        end
    end

    return grantedSkills, hotbarOverrides
end

local function getArchetypeSkills(profile)
    local progressionDef = SkillProgressionDefs[profile.archetypeId]
    if not progressionDef then
        return {}
    end

    local classOrderById = {}
    local currentClassOrder = 0
    local archetypeDef = ArchetypeDefs[profile.archetypeId]
    if archetypeDef then
        for index, classId in ipairs(archetypeDef.stageSequence) do
            classOrderById[classId] = index
            if classId == profile.classId then
                currentClassOrder = index
            end
        end
    end

    local unlocked = {}
    for _, milestone in ipairs(progressionDef.milestones) do
        local milestoneClassOrder = classOrderById[milestone.classId] or 0
        local unlockedByProgression = milestone.classId == profile.classId and (profile.level or 1) >= (milestone.unlockAtLevel or 1)
        local retainedFromEarlierClass = milestoneClassOrder > 0 and currentClassOrder > 0 and milestoneClassOrder < currentClassOrder

        if unlockedByProgression or retainedFromEarlierClass then
            local skillDef = SkillDefs[milestone.skillId]
            if skillDef then
                table.insert(unlocked, skillDef)
            end
        end
    end

    return unlocked
end

function SkillLoadout.getGrantedSkills(profile)
    local grantedSkills = {}
    if type(profile.grantedSkills) == 'table' then
        for skillId, rank in pairs(profile.grantedSkills) do
            addGrantedSkillRank(grantedSkills, skillId, rank)
        end
    end

    local equipmentGrantedSkills = getEquippedGrantState(profile)
    for skillId, rank in pairs(equipmentGrantedSkills) do
        addGrantedSkillRank(grantedSkills, skillId, rank)
    end

    return grantedSkills
end

function SkillLoadout.getEquipmentHotbarOverrides(profile)
    local _, hotbarOverrides = getEquippedGrantState(profile)
    return hotbarOverrides
end

function SkillLoadout.getSkillMilestone(profile, skillId)
    local progressionDef = SkillProgressionDefs[profile.archetypeId]
    if not progressionDef then
        return nil
    end

    for _, milestone in ipairs(progressionDef.milestones) do
        if milestone.skillId == skillId then
            return milestone
        end
    end

    return nil
end

function SkillLoadout.isSkillAvailableByProgression(profile, skillId)
    if SHARED_UTILITY_SKILLS[skillId] then
        return true
    end

    local milestone = SkillLoadout.getSkillMilestone(profile, skillId)
    if not milestone then
        return false
    end

    local classOrderById = {}
    local currentClassOrder = 0
    local archetypeDef = ArchetypeDefs[profile.archetypeId]
    if archetypeDef then
        for index, classId in ipairs(archetypeDef.stageSequence) do
            classOrderById[classId] = index
            if classId == profile.classId then
                currentClassOrder = index
            end
        end
    end

    local milestoneClassOrder = classOrderById[milestone.classId] or 0
    local unlockedByProgression = milestone.classId == profile.classId and (profile.level or 1) >= (milestone.unlockAtLevel or 1)
    local retainedFromEarlierClass = milestoneClassOrder > 0 and currentClassOrder > 0 and milestoneClassOrder < currentClassOrder

    return unlockedByProgression or retainedFromEarlierClass
end

function SkillLoadout.meetsPrerequisites(profile, skillId)
    local skillDef = SkillDefs[skillId]
    if not skillDef or not skillDef.prerequisites then
        return true, nil
    end

    for _, prerequisite in ipairs(skillDef.prerequisites) do
        local currentRank = SkillLoadout.getSkillRank(profile, prerequisite.skillId)
        if currentRank < prerequisite.rank then
            return false, prerequisite
        end
    end

    return true, nil
end

function SkillLoadout.canInvestSkill(profile, skillId)
    local skillDef = SkillDefs[skillId]
    if not skillDef then
        return false, 'UnknownSkill'
    end

    if SHARED_UTILITY_SKILLS[skillId] then
        return false, 'SharedUtility'
    end

    if profile.skillPoints <= 0 then
        return false, 'NoSkillPoints'
    end

    local currentRank = SkillLoadout.getSkillRank(profile, skillId)
    if currentRank >= (skillDef.maxLevel or 1) then
        return false, 'SkillAtMax'
    end

    if not SkillLoadout.isSkillAvailableByProgression(profile, skillId) then
        return false, 'LevelTooLow'
    end

    local meetsPrerequisites = SkillLoadout.meetsPrerequisites(profile, skillId)
    if not meetsPrerequisites then
        return false, 'MissingPrerequisites'
    end

    return true, nil
end

function SkillLoadout.getSkillUiState(profile)
    local uiState = {}
    for _, skillDef in ipairs(SkillLoadout.getArchetypeSkillCatalog(profile)) do
        local milestone = SkillLoadout.getSkillMilestone(profile, skillDef.id)
        local currentRank = SkillLoadout.getSkillRank(profile, skillDef.id)
        local canInvest, reason = SkillLoadout.canInvestSkill(profile, skillDef.id)
        local meetsPrerequisites, missingPrerequisite = SkillLoadout.meetsPrerequisites(profile, skillDef.id)

        uiState[skillDef.id] = {
            currentRank = currentRank,
            requiredLevel = milestone and milestone.unlockAtLevel or 1,
            availableByProgression = SkillLoadout.isSkillAvailableByProgression(profile, skillDef.id),
            canInvest = canInvest,
            investBlockReason = reason,
            meetsPrerequisites = meetsPrerequisites,
            missingPrerequisite = missingPrerequisite,
        }
    end

    return uiState
end

function SkillLoadout.getArchetypeSkillCatalog(profile)
    local catalog = {}
    local seen = {}
    addUniqueSkill(catalog, seen, SkillDefs.dash_step)
    addUniqueSkill(catalog, seen, SkillDefs.teleport)
    addUniqueSkill(catalog, seen, SkillDefs.blink_step)

    local progressionDef = SkillProgressionDefs[profile.archetypeId]
    if progressionDef then
        for _, milestone in ipairs(progressionDef.milestones) do
            addUniqueSkill(catalog, seen, SkillDefs[milestone.skillId])
        end
    end

    for skillId, rank in pairs(profile.skillRanks or {}) do
        if rank ~= nil then
            addUniqueSkill(catalog, seen, SkillDefs[skillId])
        end
    end

    for grantedSkillId in pairs(SkillLoadout.getGrantedSkills(profile)) do
        addUniqueSkill(catalog, seen, SkillDefs[grantedSkillId])
    end

    return catalog
end

function SkillLoadout.getSkillRank(profile, skillId)
    if SHARED_UTILITY_SKILLS[skillId] then
        return profile.skillRanks and profile.skillRanks[skillId] ~= nil and profile.skillRanks[skillId] or 1
    end

    if profile.skillRanks and profile.skillRanks[skillId] ~= nil then
        return profile.skillRanks[skillId]
    end

    local grantedSkillRank = SkillLoadout.getGrantedSkills(profile)[skillId]
    if grantedSkillRank and grantedSkillRank > 0 then
        return grantedSkillRank
    end

    for _, skillDef in ipairs(getArchetypeSkills(profile)) do
        if skillDef.id == skillId then
            return 1
        end
    end

    return 0
end

function SkillLoadout.getResolvedSkillRanks(profile)
    local resolved = {}
    for _, skillDef in ipairs(SkillLoadout.getArchetypeSkillCatalog(profile)) do
        resolved[skillDef.id] = SkillLoadout.getSkillRank(profile, skillDef.id)
    end

    return resolved
end

function SkillLoadout.getUnlockedSkills(profile)
    local unlocked = {}

    for _, skillDef in ipairs(SkillLoadout.getArchetypeSkillCatalog(profile)) do
        if SkillLoadout.getSkillRank(profile, skillDef.id) > 0 then
            table.insert(unlocked, skillDef)
        end
    end

    return unlocked
end

function SkillLoadout.buildDefaultHotbar(profile)
    local binding = SkillInputConfig.classBindings[profile.classId] or SkillInputConfig.classBindings.knight
    local resolved = {}

    for slotIndex = 1, DEFAULT_SLOT_COUNT do
        resolved[tostring(slotIndex)] = nil
    end

    resolved['1'] = binding.targetedSkillId
    resolved['2'] = binding.splashSkillId
    resolved['3'] = 'dash_step'

    if binding.hotbarSlots then
        for slotIndex, slotDef in pairs(binding.hotbarSlots) do
            resolved[tostring(slotIndex)] = slotDef.skillId
        end
    end

    return resolved
end

function SkillLoadout.getResolvedHotbar(profile)
    local stored = TableUtil.deepCopy(profile.settings.hotbarSlots or {})
    local defaults = SkillLoadout.buildDefaultHotbar(profile)
    local equipmentOverrides = SkillLoadout.getEquipmentHotbarOverrides(profile)
    local resolved = {}

    for slotIndex = 1, DEFAULT_SLOT_COUNT do
        local slotKey = tostring(slotIndex)
        local equipmentSkillId = equipmentOverrides[slotKey]
        local preferredSkillId = stored[slotKey]
        if equipmentSkillId and SkillLoadout.canEquipSkill(profile, equipmentSkillId) then
            resolved[slotKey] = equipmentSkillId
        elseif preferredSkillId and SkillLoadout.canEquipSkill(profile, preferredSkillId) then
            resolved[slotKey] = preferredSkillId
        else
            local defaultSkillId = defaults[slotKey]
            resolved[slotKey] = if defaultSkillId and SkillLoadout.canEquipSkill(profile, defaultSkillId) then defaultSkillId else nil
        end
    end

    return resolved
end

function SkillLoadout.canEquipSkill(profile, skillId)
    return SkillLoadout.getSkillRank(profile, skillId) > 0
end

return SkillLoadout
