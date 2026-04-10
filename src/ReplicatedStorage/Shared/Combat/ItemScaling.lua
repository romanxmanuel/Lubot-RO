--!strict

local ItemScaling = {}

function ItemScaling.getScalingBonus(baseValue: number, totalStats, scalingProfile)
    if not scalingProfile then
        return 0
    end

    local totalScaling = 0

    totalScaling += totalStats.STR * (scalingProfile.strength or 0)
    totalScaling += totalStats.AGI * (scalingProfile.agility or 0)
    totalScaling += totalStats.VIT * (scalingProfile.vitality or 0)
    totalScaling += totalStats.INT * (scalingProfile.intelligence or 0)
    totalScaling += totalStats.DEX * (scalingProfile.dexterity or 0)
    totalScaling += totalStats.LUK * (scalingProfile.luck or 0)

    return math.floor(baseValue * totalScaling)
end

function ItemScaling.getScaledValue(baseValue: number, totalStats, scalingProfile)
    return baseValue + ItemScaling.getScalingBonus(baseValue, totalStats, scalingProfile)
end

return ItemScaling
