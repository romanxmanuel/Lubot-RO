--!strict

local DamageService = {}

function DamageService.applyHits(enemyService, attacker: Player, enemyIds: { string }, baseDamage: number, damageScale: number?)
    local scale = damageScale or 1
    local resolvedDamage = math.max(1, math.floor(baseDamage * scale))
    local applied = 0

    for _, enemyId in ipairs(enemyIds) do
        if enemyService.damageEnemy(enemyId, resolvedDamage, attacker) then
            applied += 1
        end
    end

    return applied, resolvedDamage
end

return DamageService
