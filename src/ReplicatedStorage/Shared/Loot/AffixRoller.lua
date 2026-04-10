--!strict

local LootConfig = require(script.Parent.Parent.Config.LootConfig)
local AffixDefs = require(script.Parent.Parent.DataDefs.Items.AffixDefs)
local WeightedRandom = require(script.Parent.WeightedRandom)

local AffixRoller = {}

local function getEntriesForFamily(family)
    local source = if family == 'prefix' then AffixDefs.prefixes else AffixDefs.suffixes
    local entries = {}

    for _, affix in pairs(source) do
        table.insert(entries, affix)
    end

    return entries
end

local function isAllowedForItem(affix, itemDef)
    for _, allowedType in ipairs(affix.allowedItemTypes) do
        if allowedType == itemDef.itemType then
            return true
        end
    end

    return false
end

function AffixRoller.getAffixRollChance(rarityId: string): number
    local chance = LootConfig.Affixes.BaseRollChance

    if rarityId == 'Rare' then
        chance += LootConfig.Affixes.RareRollBonus
    elseif rarityId == 'Epic' then
        chance += LootConfig.Affixes.EpicRollBonus
    elseif rarityId == 'Legendary' or rarityId == 'Mythic' then
        chance += LootConfig.Affixes.LegendaryRollBonus
    end

    return chance
end

function AffixRoller.rollForItem(itemDef, rarityId: string, rng)
    local maxAffixes = LootConfig.Affixes.MaxAffixesByRarity[rarityId] or 0
    if maxAffixes <= 0 or itemDef.itemType ~= 'Equipment' then
        return {}
    end

    local affixes = {}
    local families = { 'prefix', 'suffix' }

    for _, family in ipairs(families) do
        if #affixes >= maxAffixes then
            break
        end

        if rng:NextNumber() <= AffixRoller.getAffixRollChance(rarityId) then
            local candidates = {}
            for _, affix in ipairs(getEntriesForFamily(family)) do
                if isAllowedForItem(affix, itemDef) then
                    table.insert(candidates, affix)
                end
            end

            local picked = WeightedRandom.pick(candidates, rng)
            if picked then
                table.insert(affixes, picked.id)
            end
        end
    end

    return affixes
end

return AffixRoller
