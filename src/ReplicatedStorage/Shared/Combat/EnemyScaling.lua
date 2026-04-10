--!strict

local StatBalanceConfig = require(script.Parent.Parent.Config.StatBalanceConfig)

local EnemyScaling = {}

local function getLevelFactor(level: number): number
    if level <= 1 then
        return 1
    end

    return 1 + (level - 1)
end

local function getScaleValue(defaultValue: number, overrideValue: number?): number
    if overrideValue ~= nil then
        return overrideValue
    end

    return defaultValue
end

function EnemyScaling.getScaledHealth(baseHealth: number, level: number, scalingProfile): number
    local perLevel = getScaleValue(StatBalanceConfig.EnemyScaling.HealthPerLevel, scalingProfile and scalingProfile.healthPerLevel)
    local factor = 1 + (getLevelFactor(level) - 1) * perLevel
    return math.floor(baseHealth * factor)
end

function EnemyScaling.getScaledAttack(baseAttack: number, level: number, scalingProfile): number
    local perLevel = getScaleValue(StatBalanceConfig.EnemyScaling.AttackPerLevel, scalingProfile and scalingProfile.attackPerLevel)
    local factor = 1 + (getLevelFactor(level) - 1) * perLevel
    return math.floor(baseAttack * factor)
end

function EnemyScaling.getScaledDefense(baseDefense: number, level: number, scalingProfile): number
    local perLevel = getScaleValue(StatBalanceConfig.EnemyScaling.DefensePerLevel, scalingProfile and scalingProfile.defensePerLevel)
    local factor = 1 + (getLevelFactor(level) - 1) * perLevel
    return math.floor(baseDefense * factor)
end

function EnemyScaling.getRewardMultiplier(level: number, scalingProfile): number
    local perLevel = getScaleValue(StatBalanceConfig.EnemyScaling.RewardPerLevel, scalingProfile and scalingProfile.rewardPerLevel)
    return 1 + (getLevelFactor(level) - 1) * perLevel
end

return EnemyScaling
