--!strict

local WeightedRandom = {}

function WeightedRandom.pick(entries, rng)
    local totalWeight = 0

    for _, entry in ipairs(entries) do
        totalWeight += entry.weight
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = rng:NextNumber(0, totalWeight)
    local running = 0

    for _, entry in ipairs(entries) do
        running += entry.weight
        if roll <= running then
            return entry
        end
    end

    return entries[#entries]
end

return WeightedRandom
