--!strict

local DropResolver = require(script.Parent.DropResolver)

local LootSimulation = {}

local function increment(map, key, amount)
    map[key] = (map[key] or 0) + amount
end

local function normalizeDropKey(drop)
    return ('%s:%s'):format(drop.kind, drop.id)
end

function LootSimulation.runEnemyKills(enemyId: string, killCount: number, seed: number?)
    local rng = Random.new(seed or 12345)
    local pityState = {}
    local summary = {
        enemyId = enemyId,
        killCount = killCount,
        totalDrops = 0,
        byDrop = {},
        byRarity = {},
        byCategory = {},
        affixHits = 0,
        chaseHits = 0,
        exclusiveHits = 0,
    }

    for _ = 1, killCount do
        local result = DropResolver.rollForEnemy(enemyId, {
            rng = rng,
            pityState = pityState,
        })
        pityState = result.pityState

        for _, drop in ipairs(result.drops) do
            local key = normalizeDropKey(drop)
            summary.totalDrops += drop.quantity
            increment(summary.byDrop, key, drop.quantity)
            increment(summary.byRarity, drop.rarity or 'Unknown', drop.quantity)
            increment(summary.byCategory, drop.category or 'Unknown', drop.quantity)

            if drop.affixes and #drop.affixes > 0 then
                summary.affixHits += 1
            end
            if drop.chaseDrop then
                summary.chaseHits += 1
            end
            if drop.exclusive then
                summary.exclusiveHits += 1
            end
        end
    end

    return summary
end

function LootSimulation.formatSummary(summary)
    local lines = {}

    table.insert(lines, ('Loot Simulation for %s (%d kills)'):format(summary.enemyId, summary.killCount))
    table.insert(lines, ('Total drop quantity: %d'):format(summary.totalDrops))
    table.insert(lines, ('Affix hits: %d | Chase hits: %d | Exclusive hits: %d'):format(summary.affixHits, summary.chaseHits, summary.exclusiveHits))
    table.insert(lines, 'Drops by rarity:')

    for rarity, amount in pairs(summary.byRarity) do
        table.insert(lines, ('- %s: %d'):format(rarity, amount))
    end

    table.insert(lines, 'Top drops:')
    local sortable = {}
    for key, amount in pairs(summary.byDrop) do
        table.insert(sortable, { key = key, amount = amount })
    end
    table.sort(sortable, function(a, b)
        return a.amount > b.amount
    end)

    for index = 1, math.min(10, #sortable) do
        local row = sortable[index]
        table.insert(lines, ('- %s: %d'):format(row.key, row.amount))
    end

    return table.concat(lines, '\n')
end

return LootSimulation
