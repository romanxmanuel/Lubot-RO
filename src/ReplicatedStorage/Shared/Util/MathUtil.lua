--!strict

local MathUtil = {}

function MathUtil.clampMin(value: number, minimum: number): number
    if value < minimum then
        return minimum
    end

    return value
end

function MathUtil.percent(value: number, denominator: number): number
    if denominator == 0 then
        return 0
    end

    return value / denominator
end

return MathUtil

