--!strict

local StatBalanceConfig = require(script.Parent.Parent.Config.StatBalanceConfig)
local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local BaseStats = {}

function BaseStats.createStartingStats()
    return TableUtil.deepCopy(StatBalanceConfig.BaseStats.Starting)
end

function BaseStats.addBonuses(baseStats, bonuses)
    return {
        STR = baseStats.STR + (bonuses.STR or 0),
        AGI = baseStats.AGI + (bonuses.AGI or 0),
        VIT = baseStats.VIT + (bonuses.VIT or 0),
        INT = baseStats.INT + (bonuses.INT or 0),
        DEX = baseStats.DEX + (bonuses.DEX or 0),
        LUK = baseStats.LUK + (bonuses.LUK or 0),
    }
end

return BaseStats

