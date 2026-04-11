--!strict

local HitboxService = {}

function HitboxService.acquireTargets(enemyService, origin: Vector3, direction: Vector3, hitboxDef, hitRegistry: { [string]: boolean })
    local shape = hitboxDef.shape or 'cone'
    local range = hitboxDef.range or 12
    local maxTargets = hitboxDef.maxTargets or 3
    local dotThreshold = if shape == 'radial' then -1 else (hitboxDef.dotThreshold or 0.2)
    local allowRepeat = hitboxDef.allowRepeat == true

    local ids = enemyService.findEnemiesInCone(origin, direction, range, dotThreshold, maxTargets)
    if allowRepeat then
        return ids
    end

    local filtered = {}
    for _, enemyId in ipairs(ids) do
        if not hitRegistry[enemyId] then
            hitRegistry[enemyId] = true
            table.insert(filtered, enemyId)
        end
    end
    return filtered
end

return HitboxService
