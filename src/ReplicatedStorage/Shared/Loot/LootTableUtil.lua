--!strict

local LootTableUtil = {}

function LootTableUtil.flattenPools(dropTable)
    local entries = {}

    for _, pool in ipairs(dropTable.pools or {}) do
        for _, entry in ipairs(pool.entries or {}) do
            local decorated = table.clone(entry)
            decorated.poolId = pool.id
            decorated.poolCategory = pool.category
            decorated.poolRolls = pool.rolls or 1
            table.insert(entries, decorated)
        end
    end

    return entries
end

return LootTableUtil
