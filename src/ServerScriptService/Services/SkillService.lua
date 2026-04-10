--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local SkillData = require(ReplicatedStorage.GameData.Skills.SkillData)

local SkillService = {
    Name = 'SkillService',
}

local dependencies = nil
local cooldowns: { [Player]: { [string]: number } } = {}

local function getCooldownBucket(player: Player)
    local bucket = cooldowns[player]
    if bucket then
        return bucket
    end

    bucket = {}
    cooldowns[player] = bucket
    return bucket
end

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

    local unlocked = false
    for _, unlockedSkillId in ipairs(profile.unlockedSkills) do
        if unlockedSkillId == skillId then
            unlocked = true
            break
        end
    end
    if not unlocked then
        return false
    end

    local skillDef = SkillData[skillId]
    if not skillDef then
        return false
    end

    local bucket = getCooldownBucket(player)
    local now = os.clock()
    if (bucket[skillId] or 0) > now then
        return false
    end

    local didCast = dependencies.CombatService.performSkill(player, skillId, skillDef)
    if didCast then
        bucket[skillId] = now + skillDef.cooldown
    end
    return didCast
end

return SkillService
