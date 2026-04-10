--!strict

local EnhancementConfig = require(script.Parent.Parent.Config.EnhancementConfig)
local EnhancementTrackDefs = require(script.Parent.Parent.DataDefs.Progression.EnhancementTrackDefs)

local EnhancementFormula = {}

local function clamp(value: number, minimum: number, maximum: number): number
    return math.max(minimum, math.min(maximum, value))
end

function EnhancementFormula.getTrackLevelDef(trackId: string, targetLevel: number)
    local trackDef = EnhancementTrackDefs[trackId]
    assert(trackDef, ('Unknown enhancement track: %s'):format(trackId))

    local levelDef = trackDef.levels[targetLevel]
    assert(levelDef, ('Missing enhancement level %d for track %s'):format(targetLevel, trackId))

    return levelDef
end

function EnhancementFormula.getSuccessRate(trackId: string, targetLevel: number, luckBonus: number?): number
    local levelDef = EnhancementFormula.getTrackLevelDef(trackId, targetLevel)
    local bonus = clamp(luckBonus or 0, 0, EnhancementConfig.MaximumLuckBonus)
    return clamp(levelDef.successRate + bonus, 0.01, 1)
end

function EnhancementFormula.getFailureOutcome(trackId: string, targetLevel: number, protectionRules)
    local levelDef = EnhancementFormula.getTrackLevelDef(trackId, targetLevel)
    local outcome = levelDef.onFail

    if not protectionRules or outcome == 'None' or outcome == 'NoChange' then
        return outcome
    end

    for _, prevented in ipairs(protectionRules.prevents or {}) do
        if prevented == outcome then
            return 'NoChange'
        end
    end

    return outcome
end

function EnhancementFormula.getMaterialRequirements(trackId: string, targetLevel: number)
    local levelDef = EnhancementFormula.getTrackLevelDef(trackId, targetLevel)
    return levelDef.materials
end

function EnhancementFormula.getZenyCost(trackId: string, targetLevel: number): number
    local levelDef = EnhancementFormula.getTrackLevelDef(trackId, targetLevel)
    return levelDef.zenyCost
end

function EnhancementFormula.isSafeTier(targetLevel: number): boolean
    return targetLevel <= EnhancementConfig.SafeTierMax
end

function EnhancementFormula.isDestructiveTier(targetLevel: number): boolean
    return targetLevel >= EnhancementConfig.DestructiveTierStart
end

return EnhancementFormula
