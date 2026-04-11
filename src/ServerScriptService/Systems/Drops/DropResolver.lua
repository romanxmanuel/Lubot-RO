--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local AffixRoller = require(ReplicatedStorage.Shared.Loot.AffixRoller)
local DropTableDefs = require(ReplicatedStorage.Shared.DataDefs.Items.DropTableDefs)
local EnemyDefs = require(ReplicatedStorage.Shared.DataDefs.Enemies.EnemyDefs)
local ItemDefs = require(ReplicatedStorage.Shared.DataDefs.Items.ItemDefs)
local LootConfig = require(ReplicatedStorage.Shared.Config.LootConfig)
local WeightedRandom = require(ReplicatedStorage.Shared.Loot.WeightedRandom)

local DropResolver = {}
local RARITY_SCORE = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
}

local function rollQuantity(quantityDef, rng)
    if not quantityDef then
        return 1
    end

    return rng:NextInteger(quantityDef.min, quantityDef.max)
end

local function pityApplies(entry)
    if not entry.pityGroup then
        return false
    end

    if entry.kind == 'card' or entry.category == LootConfig.Categories.Power then
        return LootConfig.Pity.AllowPowerPity
    end

    return true
end

local function resolvePityThreshold(entry)
    if entry.pityGroup == 'boss_cosmetic' then
        return LootConfig.Pity.BossCosmeticPityThreshold
    end

    return LootConfig.Pity.CosmeticPityThreshold
end

local function passesChance(pool, rng)
    local chance = pool.chance or 1
    return rng:NextNumber() <= chance
end

local function getGuaranteedPityEntry(pool, pityState)
    for _, entry in ipairs(pool.entries) do
        if pityApplies(entry) and entry.pityGroup then
            local threshold = resolvePityThreshold(entry)
            local current = pityState[entry.pityGroup] or 0

            if current >= threshold then
                return entry
            end
        end
    end

    return nil
end

local function buildDrop(entry, poolCategory, rng)
    local itemDef = if entry.kind == 'item' then ItemDefs[entry.id] else nil
    local drop = {
        kind = entry.kind,
        id = entry.id,
        rarity = entry.rarity,
        category = entry.category or poolCategory,
        quantity = rollQuantity(entry.quantity, rng),
        affixes = {},
        chaseDrop = entry.chaseDrop == true,
        exclusive = entry.exclusive == true,
    }

    if itemDef and entry.affixEligible then
        drop.affixes = AffixRoller.rollForItem(itemDef, entry.rarity, rng)
    end

    return drop
end

local function buildMonsterBurstCandidates(dropTable)
    local candidates = {}
    for _, pool in ipairs(dropTable.pools or {}) do
        for _, entry in ipairs(pool.entries or {}) do
            if entry.kind == 'item'
                and entry.exclusive ~= true
                and entry.rarity ~= 'Rare'
                and entry.rarity ~= 'Epic'
                and entry.rarity ~= 'Legendary'
                and entry.rarity ~= 'Mythic'
            then
                table.insert(candidates, {
                    kind = entry.kind,
                    id = entry.id,
                    rarity = entry.rarity,
                    category = entry.category or pool.category,
                    quantity = entry.quantity,
                    weight = math.max(tonumber(entry.weight) or 1, 1),
                    chaseDrop = entry.chaseDrop == true,
                    exclusive = entry.exclusive == true,
                })
            end
        end
    end

    return candidates
end

local function getDropValueScore(drop)
    local rarityScore = RARITY_SCORE[tostring(drop.rarity or 'Common')] or 1
    local score = rarityScore * 10
    if drop.kind == 'card' then
        score += 120
    end
    if drop.chaseDrop == true then
        score += 90
    end
    if drop.exclusive == true then
        score += 80
    end
    return score
end

local function compactMonsterDrops(drops, rng)
    if #drops == 0 then
        return drops
    end

    table.sort(drops, function(a, b)
        return getDropValueScore(a) > getDropValueScore(b)
    end)

    local best = drops[1]
    if not best then
        return {}
    end

    local rarity = tostring(best.rarity or 'Common')
    local keepCommon = rarity ~= 'Common' or rng:NextNumber() <= 0.35
    if not keepCommon then
        return {}
    end

    return { best }
end

function DropResolver.roll(dropTableId: string, context)
    local dropTable = DropTableDefs[dropTableId]
    assert(dropTable, ('Unknown dropTableId: %s'):format(dropTableId))

    local rng = if context and context.rng then context.rng else Random.new()
    local pityState = if context and context.pityState then context.pityState else {}
    local drops = {}

    for _, pool in ipairs(dropTable.pools or {}) do
        local guaranteedEntry = getGuaranteedPityEntry(pool, pityState)
        local poolPassed = passesChance(pool, rng)

        if guaranteedEntry or poolPassed then
            for _ = 1, (pool.rolls or 1) do
                local picked = guaranteedEntry or WeightedRandom.pick(pool.entries, rng)
                if picked then
                    local resolvedDrop = buildDrop(picked, pool.category, rng)
                    table.insert(drops, resolvedDrop)

                    if picked.pityGroup and pityApplies(picked) then
                        pityState[picked.pityGroup] = 0
                    end
                end
            end
        else
            for _, entry in ipairs(pool.entries) do
                if entry.pityGroup and pityApplies(entry) then
                    pityState[entry.pityGroup] = (pityState[entry.pityGroup] or 0) + 1
                end
            end
        end
    end

    if dropTable.tableType == 'Monster' then
        drops = compactMonsterDrops(drops, rng)
    end

    return {
        drops = drops,
        pityState = pityState,
        sourceType = dropTable.tableType,
        sourceId = dropTable.sourceId,
    }
end

function DropResolver.rollForEnemy(enemyId: string, context)
    local enemyDef = EnemyDefs[enemyId]
    assert(enemyDef, ('Unknown enemyId: %s'):format(enemyId))

    return DropResolver.roll(enemyDef.dropTableId, context)
end

return DropResolver
