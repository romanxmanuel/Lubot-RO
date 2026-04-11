--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)
local SkillTimelineData = require(ReplicatedStorage.GameData.Skills.SkillTimelineData)
local HitboxService = require(script.Parent.Modules.HitboxService)
local DamageService = require(script.Parent.Modules.DamageService)
local VFXService = require(script.Parent.Modules.VFXService)

local CombatServiceV2 = {
    Name = 'CombatService',
}

local dependencies = nil
local HIGH_TARGET_CAP = 16
local IMPACT_RANGE_SCALE = 1.12
local IMPACT_WIDTH_SCALE = 1.25

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
    gojo_blue_burst = {
        effect = MMONet.Effects.GojoBlueBurst,
        shape = 'cone',
        dotThreshold = 0.72,
        maxTargets = 3,
    },
    hollow_purple_burst = {
        effect = MMONet.Effects.HollowPurpleBurst,
        shape = 'cone',
        dotThreshold = 0.56,
        maxTargets = 6,
    },
}

local function getForwardVector(player: Player)
    local root = dependencies.CharacterService.getHumanoidRootPart(player)
    if not root then
        return nil, nil, nil
    end
    local lookVector = root.CFrame.LookVector
    local planar = Vector3.new(lookVector.X, 0, lookVector.Z)
    if planar.Magnitude <= 0.001 then
        planar = Vector3.new(0, 0, -1)
    end
    return root.Position, planar.Unit, root
end

local function rollBasicAttackDamage(player: Player)
    local baseDamage = math.random(GameConfig.BasicAttackDamageMin, GameConfig.BasicAttackDamageMax)
    local attackPower = math.max(0, math.floor(player:GetAttribute('AttackPower') or 0))
    return baseDamage + attackPower
end

local function resolveEffectName(effectName: string?): string
    if type(effectName) ~= 'string' or effectName == '' then
        return MMONet.Effects.Slash
    end
    return (MMONet.Effects :: any)[effectName] or effectName
end

local function dashRoot(root: BasePart, direction: Vector3, distance: number): Vector3
    if distance <= 0 then
        return root.Position
    end

    local destination = root.Position + direction * distance
    root.CFrame = CFrame.new(destination, destination + direction)
    return destination
end

local function runSkillTimeline(player: Player, root: BasePart, initialLook: Vector3, skillId: string, skillDef, timelineDef)
    local startedAt = os.clock()
    local hitRegistry: { [string]: boolean } = {}

    for _, phase in ipairs(timelineDef.phases or {}) do
        local scheduleAt = tonumber(phase.t) or 0
        local waitSeconds = scheduleAt - (os.clock() - startedAt)
        if waitSeconds > 0 then
            task.wait(waitSeconds)
        end

        if not root.Parent then
            break
        end

        local currentLook = initialLook
        local rootLook = root.CFrame.LookVector
        local planarLook = Vector3.new(rootLook.X, 0, rootLook.Z)
        if planarLook.Magnitude > 0.001 then
            currentLook = planarLook.Unit
        end

        local currentOrigin = root.Position
        if type(phase.move) == 'table' and phase.move.type == 'dash' then
            currentOrigin = dashRoot(root, currentLook, tonumber(phase.move.distance) or 0)
        end

        local effectName = resolveEffectName(phase.effect or (SKILL_BEHAVIOR[skillId] and SKILL_BEHAVIOR[skillId].effect))
        local phaseRange = ((phase.vfx and phase.vfx.range) or skillDef.range) * IMPACT_RANGE_SCALE
        local phaseWidth = ((phase.vfx and phase.vfx.width) or skillDef.width) * IMPACT_WIDTH_SCALE

        VFXService.emit(dependencies.Runtime.EffectEvent, effectName, {
            userId = player.UserId,
            skillId = skillId,
            marker = phase.marker or 'Phase',
            origin = currentOrigin,
            direction = currentLook,
            range = phaseRange,
            width = phaseWidth,
            timeline = true,
            vfx = phase.vfx,
        })

        if type(phase.hitbox) == 'table' then
            local targets = HitboxService.acquireTargets(
                dependencies.EnemyService,
                currentOrigin,
                currentLook,
                phase.hitbox,
                hitRegistry
            )
            if #targets > 0 then
                DamageService.applyHits(
                    dependencies.EnemyService,
                    player,
                    targets,
                    skillDef.damage,
                    tonumber(phase.hitbox.damageScale) or 1
                )
            end
        end
    end
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
    local origin, lookVector, root = getForwardVector(player)
    if not origin or not lookVector or not root then
        return false
    end

    local timelineDef = SkillTimelineData[skillId]
    if timelineDef and type(timelineDef) == 'table' then
        task.spawn(function()
            local ok, err = pcall(function()
                runSkillTimeline(player, root, lookVector, skillId, skillDef, timelineDef)
            end)
            if not ok then
                warn(string.format('[CombatServiceV2] skill timeline failed (%s): %s', skillId, tostring(err)))
            end
        end)
        return true
    end

    local behavior = SKILL_BEHAVIOR[skillId]
    if not behavior then
        return false
    end

    VFXService.emit(dependencies.Runtime.EffectEvent, behavior.effect, {
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
