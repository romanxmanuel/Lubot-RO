--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local CombatServiceV2 = {
    Name = 'CombatService',
}

local dependencies = nil
local HIGH_TARGET_CAP = 16

local SKILL_BEHAVIOR = {
    power_slash = {
        effect = MMONet.Effects.PowerSlash,
        shape = 'cone',
        dotThreshold = 0.2,
        maxTargets = 3,
    },
    arc_flare = {
        effect = MMONet.Effects.ArcFlare,
        shape = 'cone',
        dotThreshold = 0.35,
        maxTargets = 4,
    },
    nova_strike = {
        effect = MMONet.Effects.NovaStrike,
        shape = 'cone',
        dotThreshold = 0.75,
        maxTargets = 2,
    },
    vortex_spin = {
        effect = MMONet.Effects.VortexSpin,
        shape = 'radial',
        dotThreshold = -1,
        maxTargets = 8,
    },
    comet_drop = {
        effect = MMONet.Effects.CometDrop,
        shape = 'radial',
        dotThreshold = -1,
        maxTargets = 10,
    },
    razor_orbit = {
        effect = MMONet.Effects.RazorOrbit,
        shape = 'cone',
        dotThreshold = 0.05,
        maxTargets = 6,
    },
}

local function getForwardVector(player: Player)
    local root = dependencies.CharacterService.getHumanoidRootPart(player)
    if not root then
        return nil, nil
    end
    local lookVector = root.CFrame.LookVector
    local planar = Vector3.new(lookVector.X, 0, lookVector.Z)
    if planar.Magnitude <= 0.001 then
        planar = Vector3.new(0, 0, -1)
    end
    return root.Position, planar.Unit
end

local function rollBasicAttackDamage(player: Player)
    local baseDamage = math.random(GameConfig.BasicAttackDamageMin, GameConfig.BasicAttackDamageMax)
    local attackPower = math.max(0, math.floor(player:GetAttribute('AttackPower') or 0))
    return baseDamage + attackPower
end

function CombatServiceV2.init(deps)
    dependencies = deps
end

function CombatServiceV2.start()
    dependencies.Runtime.ActionRequest.OnServerEvent:Connect(function(player, payload)
        if type(payload) ~= 'table' or payload.action ~= MMONet.Actions.BasicAttack then
            return
        end

        CombatServiceV2.performBasicAttack(player, payload)
    end)
end

function CombatServiceV2.performBasicAttack(player: Player, payload)
    if not dependencies.CharacterService.canUseAttack(player, GameConfig.BasicAttackCooldown) then
        return false
    end

    local origin, lookVector = getForwardVector(player)
    if not origin or not lookVector then
        return false
    end

    dependencies.CharacterService.markAttackUsed(player)
    local styleName = type(payload) == 'table' and payload.styleName or 'Default'
    if styleName == 'DekuLegacy' then
        dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.DekuSmash, {
            userId = player.UserId,
            origin = origin,
            direction = lookVector,
            comboName = type(payload) == 'table' and payload.comboName or nil,
        })
    end
    dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.Slash, {
        userId = player.UserId,
        origin = origin,
        direction = lookVector,
        range = GameConfig.BasicAttackRange,
    })

    local enemies = dependencies.EnemyService.findEnemiesInCone(
        origin,
        lookVector,
        GameConfig.BasicAttackRange,
        GameConfig.BasicAttackConeDot,
        GameConfig.BasicAttackMaxTargets
    )
    for _, enemyId in ipairs(enemies) do
        dependencies.EnemyService.damageEnemy(enemyId, rollBasicAttackDamage(player), player)
    end

    return true
end

function CombatServiceV2.performSkill(player: Player, skillId: string, skillDef)
    local origin, lookVector = getForwardVector(player)
    if not origin or not lookVector then
        return false
    end

    local behavior = SKILL_BEHAVIOR[skillId]
    if not behavior then
        return false
    end

    dependencies.Runtime.EffectEvent:FireAllClients(behavior.effect, {
        userId = player.UserId,
        origin = origin,
        direction = lookVector,
        range = skillDef.range,
        width = skillDef.width,
    })

    local enemies = {}
    if behavior.shape == 'radial' then
        enemies = dependencies.EnemyService.findEnemiesInCone(
            origin,
            lookVector,
            skillDef.range,
            behavior.dotThreshold or -1,
            math.min(HIGH_TARGET_CAP, skillDef.maxTargets or behavior.maxTargets or HIGH_TARGET_CAP)
        )
    else
        enemies = dependencies.EnemyService.findEnemiesInCone(
            origin,
            lookVector,
            skillDef.range,
            behavior.dotThreshold or 0.2,
            skillDef.maxTargets or behavior.maxTargets or 3
        )
    end

    for _, enemyId in ipairs(enemies) do
        dependencies.EnemyService.damageEnemy(enemyId, skillDef.damage, player)
    end

    return true
end

return CombatServiceV2
