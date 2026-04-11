--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local SkillData = require(ReplicatedStorage.GameData.Skills.SkillData)

local SkillService = {
    Name = 'SkillService',
}

local dependencies = nil

function SkillService.init(deps)
    dependencies = deps
end

function SkillService.start()
    return nil
end

function SkillService.useSkill(player: Player, skillId: string)
    local profile = dependencies.PersistenceService.getProfile(player)
    if not profile then
        return false
    end

    local skillDef = SkillData[skillId]
    if not skillDef then
        return false
    end

    local unlocked = false
    for _, unlockedSkillId in ipairs(profile.unlockedSkills) do
        if unlockedSkillId == skillId then
            unlocked = true
            break
        end
    end

    -- Fallback for tool-driven skills: if the skill exists in the canonical SkillData table,
    -- allow cast even when legacy profile reconciliation drops it from unlockedSkills.
    if not unlocked and skillDef.toolKind == 'skill' then
        unlocked = true
    end

    if not unlocked then
        return false
    end

    local didCast = dependencies.CombatService.performSkill(player, skillId, skillDef)
    return didCast
end

return SkillService
