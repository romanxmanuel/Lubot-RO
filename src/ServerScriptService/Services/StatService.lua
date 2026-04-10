--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local CardDefs = require(ReplicatedStorage.Shared.DataDefs.Cards.CardDefs)
local DerivedStats = require(ReplicatedStorage.Shared.Stats.DerivedStats)
local EquipmentDefs = require(ReplicatedStorage.Shared.DataDefs.Items.EquipmentDefs)
local ItemScaling = require(ReplicatedStorage.Shared.Combat.ItemScaling)
local BaseStats = require(ReplicatedStorage.Shared.Stats.BaseStats)
local SkillLoadout = require(ReplicatedStorage.Shared.Skills.SkillLoadout)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)

local StatService = {}

local function makeStatBonuses()
    return {
        STR = 0,
        AGI = 0,
        VIT = 0,
        INT = 0,
        DEX = 0,
        LUK = 0,
    }
end

local function makeSecondaryStats()
    return {
        aspd = 0,
        physicalAttack = 0,
        magicAttack = 0,
        physicalDefense = 0,
        magicalDefense = 0,
        hit = 0,
        flee = 0,
        critChance = 0,
        critDamageMultiplier = 0,
        perfectDodgeChance = 0,
        maxHealth = 0,
        maxMana = 0,
        hpRegenPerTick = 0,
        spRegenPerTick = 0,
        carryWeight = 0,
        cardFindBonus = 0,
        itemFindBonus = 0,
        upgradeLuckBonus = 0,
    }
end

local function applyPassiveSkillBonuses(profile, snapshot)
    local skillRanks = SkillLoadout.getResolvedSkillRanks(profile)

    local increaseHpRecoveryRank = skillRanks.increase_hp_recovery or 0
    if increaseHpRecoveryRank > 0 then
        snapshot.secondaryStats.hpRegenPerTick += 5 * increaseHpRecoveryRank
    end

    local owlsEyeRank = skillRanks.owls_eye or 0
    if owlsEyeRank > 0 then
        snapshot.statBonuses.DEX += owlsEyeRank
    end

    local katarMasteryRank = skillRanks.katar_mastery or 0
    if katarMasteryRank > 0 then
        snapshot.secondaryStats.physicalAttack += 4 * katarMasteryRank
        snapshot.secondaryStats.aspd += 0.08 * katarMasteryRank
        snapshot.secondaryStats.critChance += 0.006 * katarMasteryRank
    end

    local advancedKatarMasteryRank = skillRanks.advanced_katar_mastery or 0
    if advancedKatarMasteryRank > 0 then
        snapshot.statBonuses.AGI += advancedKatarMasteryRank
        snapshot.statBonuses.LUK += advancedKatarMasteryRank
        snapshot.secondaryStats.aspd += 0.15 * advancedKatarMasteryRank
        snapshot.secondaryStats.critChance += 0.01 * advancedKatarMasteryRank
        snapshot.secondaryStats.critDamageMultiplier += 0.03 * advancedKatarMasteryRank
    end
end

local function applyActiveBuffBonuses(profile, snapshot)
    local activeBuffs = profile.runtime and profile.runtime.activeBuffs
    if not activeBuffs then
        return
    end

    local now = os.clock()
    for buffId, buffState in pairs(activeBuffs) do
        if type(buffState) ~= 'table' or (buffState.expiresAt or 0) <= now then
            activeBuffs[buffId] = nil
        elseif buffId == 'improve_concentration' then
            local rank = buffState.rank or 1
            snapshot.statBonuses.DEX += 2 * rank
            snapshot.statBonuses.AGI += 2 * rank
        elseif buffId == 'cloaking' then
            local rank = buffState.rank or 1
            snapshot.statBonuses.AGI += rank
            snapshot.secondaryStats.flee += 6 * rank
            snapshot.secondaryStats.perfectDodgeChance += 0.004 * rank
            snapshot.secondaryStats.critChance += 0.004 * rank
            snapshot.secondaryStats.aspd += 0.04 * rank
        elseif buffId == 'enchant_deadly_poison' then
            local rank = buffState.rank or 1
            snapshot.secondaryStats.physicalAttack += 12 * rank
            snapshot.secondaryStats.aspd += 0.12 * rank
            snapshot.secondaryStats.critChance += 0.012 * rank
            snapshot.secondaryStats.critDamageMultiplier += 0.06 * rank
        end
    end
end

local function collectEquipmentSnapshot(player)
    local statBonuses = makeStatBonuses()
    local secondaryStats = makeSecondaryStats()
    local equippedEntries = {}

    for _, instanceId in pairs(PlayerDataService.getOrCreateProfile(player).equipment) do
        if instanceId then
            local itemInstance = InventoryService.getEnhanceableItem(player, instanceId)
            if itemInstance and not itemInstance.destroyed then
                local equipmentDef = EquipmentDefs[itemInstance.itemId]
                if equipmentDef then
                    if equipmentDef.statBonuses then
                        for statName, amount in pairs(equipmentDef.statBonuses) do
                            statBonuses[statName] += amount
                        end
                    end

                    if equipmentDef.secondaryStats then
                        for statName, amount in pairs(equipmentDef.secondaryStats) do
                            if secondaryStats[statName] ~= nil then
                                secondaryStats[statName] += amount
                            end
                        end
                    end

                    for _, cardId in ipairs(itemInstance.socketedCards or {}) do
                        local cardDef = CardDefs[cardId]
                        local socketEffect = cardDef and cardDef.socketEffect or nil
                        if socketEffect and socketEffect.statBonuses then
                            for statName, amount in pairs(socketEffect.statBonuses) do
                                if statBonuses[statName] ~= nil then
                                    statBonuses[statName] += amount
                                end
                            end
                        end
                        if socketEffect and socketEffect.secondaryStats then
                            for statName, amount in pairs(socketEffect.secondaryStats) do
                                if secondaryStats[statName] ~= nil then
                                    secondaryStats[statName] += amount
                                end
                            end
                        end
                    end

                    table.insert(equippedEntries, {
                        equipmentDef = equipmentDef,
                        enhancementLevel = itemInstance.enhancementLevel or 0,
                    })
                end
            end
        end
    end

    return {
        statBonuses = statBonuses,
        secondaryStats = secondaryStats,
        equippedEntries = equippedEntries,
    }
end

local function resolveWeaponAttack(totalStats, snapshot)
    local weaponAttack = 0

    for _, entry in ipairs(snapshot.equippedEntries) do
        local equipmentDef = entry.equipmentDef
        if equipmentDef.attack then
            weaponAttack += ItemScaling.getScaledValue(equipmentDef.attack, totalStats, equipmentDef.scaling)
            weaponAttack += entry.enhancementLevel * 2
        end
    end

    return weaponAttack
end

function StatService.init() end
function StatService.start() end

function StatService.getDerivedStats(player)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local snapshot = collectEquipmentSnapshot(player)
    applyPassiveSkillBonuses(profile, snapshot)
    applyActiveBuffBonuses(profile, snapshot)
    local totalStats = BaseStats.addBonuses(profile.baseStats, snapshot.statBonuses)
    snapshot.weaponAttack = resolveWeaponAttack(totalStats, snapshot)
    return DerivedStats.fromProfile(profile, snapshot)
end

function StatService.getPreviewContext(player)
    local profile = PlayerDataService.getOrCreateProfile(player)
    local snapshot = collectEquipmentSnapshot(player)
    applyPassiveSkillBonuses(profile, snapshot)
    applyActiveBuffBonuses(profile, snapshot)
    local totalStats = BaseStats.addBonuses(profile.baseStats, snapshot.statBonuses)
    snapshot.weaponAttack = resolveWeaponAttack(totalStats, snapshot)
    snapshot.equippedEntries = nil
    return snapshot
end

function StatService.getUpgradeLuckBonus(player): number
    return StatService.getDerivedStats(player).upgradeLuckBonus
end

return StatService
