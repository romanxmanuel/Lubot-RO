--!strict

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local CombatFormula = require(ReplicatedStorage.Shared.Combat.CombatFormula)
local SkillDefs = require(ReplicatedStorage.Shared.DataDefs.Skills.SkillDefs)
local SkillRuntimeConfig = require(ReplicatedStorage.Shared.Skills.SkillRuntimeConfig)
local DropResolver = require(script.Parent.Parent.Systems.Drops.DropResolver)
local EnemyService = require(script.Parent.EnemyService)
local InventoryService = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StatService = require(script.Parent.StatService)
local WorldService = require(script.Parent.WorldService)
local WorldDropService = require(script.Parent.WorldDropService)
local SkillLoadout = require(ReplicatedStorage.Shared.Skills.SkillLoadout)
local AdminConfig = require(script.Parent.Parent.Config.AdminConfig)
local FlightService = require(script.Parent.FlightService)
local FlightModule = require(ReplicatedStorage.Shared.FlightModule)

local CombatService = {}

local groundTargetedSkillIds = {
    arrow_shower = true,
    fire_wall = true,
}

local basicAttackCadenceByPlayer = {}
local combatRng = Random.new()

local parryState = {}
local edgeTempoState = {}

local PARRY_WINDOW_SECONDS = 0.5
local PARRY_COOLDOWN_SECONDS = 4.0
local PARRY_STUN_SECONDS = 0.5
local PARRY_BURST_SECONDS = 2.0
local PARRY_BURST_MULTIPLIER = 1.75
local PARRY_REFLECT_RATIO = 0.35
local EDGE_TEMPO_WINDOW_SECONDS = 0.9
local EDGE_TEMPO_RATIO = 0.35
local EDGE_TEMPO_BURST_RATIO = 0.60

local zeroSkillIds = {
    forward_slash = true,
    circular_slash = true,
    evasive_slash = true,
    shadow_clone_slash = true,
}
local BOSS_STAGGER_SECONDS   = 2.0

local function getCharacterRootPart(player)
    local character = player.Character
    local rootPart = character and character:FindFirstChild('HumanoidRootPart')
    if not rootPart then
        return nil
    end

    return rootPart
end

local function getProfile(player)
    return PlayerDataService.getOrCreateProfile(player)
end

local function isGroundTargetedSkill(skillId: string): boolean
    return groundTargetedSkillIds[skillId] == true
end

local function getPlanarDistance(left: Vector3, right: Vector3): number
    return Vector3.new(left.X - right.X, 0, left.Z - right.Z).Magnitude
end

local function hasAdminPowerMode(player): boolean
    return PlayerDataService.isAdminPowerEnabled(player)
end

local function getEffectiveSkillRange(player, skillConfig)
    if hasAdminPowerMode(player) and skillConfig then
        return 1000000
    end

    return (skillConfig and skillConfig.range) or 12
end

local function getEffectiveDashDistance(player, skillConfig)
    return (skillConfig and skillConfig.dashDistance) or 0
end

local function getBasicAttackConfig(player)
    local profile = getProfile(player)
    if profile.archetypeId == 'archer_path' then
        return SkillRuntimeConfig.archer_basic_attack
    end
    if profile.archetypeId == 'mage_path' then
        return SkillRuntimeConfig.ranged_basic_attack
    end

    return SkillRuntimeConfig.basic_attack
end

local function makeEffectPayload(effectKey, sourcePosition, targetPosition, radius, color, style)
    local payload = {
        effectKey = effectKey,
        sourcePosition = sourcePosition,
        targetPosition = targetPosition or sourcePosition,
        radius = radius,
        color = color,
        style = style or 'impact',
    }

    local skillConfig = if type(effectKey) == 'string' then SkillRuntimeConfig[effectKey] else nil
    if type(skillConfig) == 'table' then
        payload.effectProfile = skillConfig.effectProfile
        payload.phaseTimings = skillConfig.phaseTimings
        payload.movementProfile = skillConfig.movementProfile
        payload.hitboxProfile = skillConfig.hitboxProfile
        payload.autoAcquireNearest = skillConfig.autoAcquireNearest == true
        payload.comboWindowSeconds = skillConfig.comboWindowSeconds
    end

    return payload
end

local function enrichEffectPayload(effectPayload, enemy, damage, didCrit, wasMiss)
    local payload = effectPayload or makeEffectPayload('impact', enemy.instance.Position, enemy.instance.Position, nil, Color3.fromRGB(255, 235, 150), 'impact')
    payload.enemyRuntimeId = enemy.runtimeId
    payload.targetName = enemy.enemyDef.name
    payload.damage = damage
    payload.didCrit = didCrit
    payload.wasMiss = wasMiss
    payload.remainingHealth = enemy.currentHealth
    payload.maxHealth = enemy.maxHealth
    payload.attackerUserId = payload.attackerUserId or 0
    return payload
end

local function moveCharacterToward(rootPart, targetPosition, distance)
    local offset = targetPosition - rootPart.Position
    if offset.Magnitude <= 0.01 then
        return rootPart.Position
    end

    local clampedDistance = math.min(distance, math.max(offset.Magnitude - 3, 0))
    if clampedDistance <= 0 then
        return rootPart.Position
    end

    local destination = rootPart.Position + offset.Unit * clampedDistance
    rootPart.CFrame = CFrame.new(destination, destination + offset.Unit)
    return destination
end

local function dashCharacterForward(rootPart, distance)
    if distance <= 0 then
        return rootPart.Position
    end

    local lookVector = rootPart.CFrame.LookVector
    if lookVector.Magnitude <= 0.01 then
        return rootPart.Position
    end

    local destination = rootPart.Position + lookVector.Unit * distance
    rootPart.CFrame = CFrame.new(destination, destination + lookVector.Unit)
    return destination
end

local function dashCharacterBackward(rootPart, distance)
    if distance <= 0 then
        return rootPart.Position
    end

    local lookVector = rootPart.CFrame.LookVector
    if lookVector.Magnitude <= 0.01 then
        return rootPart.Position
    end

    local destination = rootPart.Position - lookVector.Unit * distance
    rootPart.CFrame = CFrame.new(destination, destination + lookVector.Unit)
    return destination
end

local function getNearestEnemyToPosition(position: Vector3, range: number)
    local nearestEnemy = nil
    local nearestDistance = range
    for _, enemy in ipairs(EnemyService.getAliveEnemies()) do
        if enemy.instance then
            local distance = (enemy.instance.Position - position).Magnitude
            if distance <= nearestDistance then
                nearestDistance = distance
                nearestEnemy = enemy
            end
        end
    end

    return nearestEnemy
end

local function isZeroSkill(skillId: string): boolean
    return zeroSkillIds[skillId] == true
end

local function getPlanarDirection(vector: Vector3): Vector3
    local planar = Vector3.new(vector.X, 0, vector.Z)
    if planar.Magnitude <= 0.01 then
        return Vector3.zero
    end

    return planar.Unit
end

local function isPositionInsideRectPath(position: Vector3, startPosition: Vector3, endPosition: Vector3, width: number): boolean
    local path = Vector3.new(endPosition.X - startPosition.X, 0, endPosition.Z - startPosition.Z)
    local length = path.Magnitude
    if length <= 0.05 then
        return false
    end

    local forward = path.Unit
    local right = Vector3.new(-forward.Z, 0, forward.X)
    local delta = Vector3.new(position.X - startPosition.X, 0, position.Z - startPosition.Z)
    local forwardDistance = delta:Dot(forward)
    local sideDistance = math.abs(delta:Dot(right))
    return forwardDistance >= 0 and forwardDistance <= length and sideDistance <= (width * 0.5)
end

local function isPositionInsideCone(position: Vector3, origin: Vector3, forwardVector: Vector3, length: number, halfAngle: number): boolean
    local delta = Vector3.new(position.X - origin.X, 0, position.Z - origin.Z)
    local planarForward = getPlanarDirection(forwardVector)
    if delta.Magnitude <= 0.05 or planarForward.Magnitude <= 0.05 then
        return false
    end

    if delta.Magnitude > length then
        return false
    end

    local dot = math.clamp(delta.Unit:Dot(planarForward), -1, 1)
    return dot >= math.cos(math.rad(halfAngle))
end

local function collectZeroSkillTargets(skillId: string, originPosition: Vector3, impactCenter: Vector3, forwardVector: Vector3)
    local skillConfig = SkillRuntimeConfig[skillId]
    local hitboxProfile = skillConfig and skillConfig.hitboxProfile or {}
    local targets = {}

    for _, enemy in ipairs(EnemyService.getAliveEnemies()) do
        if enemy.instance then
            local enemyPosition = enemy.instance.Position
            local shouldHit = false
            if hitboxProfile.mode == 'rect' then
                shouldHit = isPositionInsideRectPath(enemyPosition, originPosition, impactCenter, hitboxProfile.width or 8)
            elseif hitboxProfile.mode == 'cone' then
                shouldHit = isPositionInsideCone(enemyPosition, originPosition, forwardVector, hitboxProfile.length or 12, hitboxProfile.halfAngle or 50)
            else
                shouldHit = getPlanarDistance(enemyPosition, impactCenter) <= (hitboxProfile.radius or skillConfig.radius or 12)
            end

            if shouldHit then
                table.insert(targets, enemy)
            end
        end
    end

    return targets
end

local function getEdgeTempoTriggerState(player: Player, skillId: string, comboWindowSeconds: number?): boolean
    local state = edgeTempoState[player.UserId]
    local now = os.clock()
    if state and (state.expiresAt or 0) <= now then
        edgeTempoState[player.UserId] = nil
        state = nil
    end

    local triggered = state ~= nil and state.lastSkillId ~= skillId
    edgeTempoState[player.UserId] = {
        lastSkillId = skillId,
        expiresAt = now + math.max(comboWindowSeconds or EDGE_TEMPO_WINDOW_SECONDS, 0.1),
    }
    return triggered
end

local function getEdgeTempoDamageRatio(player: Player, enemyRuntimeId: string?): number
    local state = parryState[player.UserId]
    if state
        and enemyRuntimeId
        and os.clock() <= (state.burstWindowUntil or 0)
        and state.burstEnemyRuntimeId == enemyRuntimeId
    then
        return EDGE_TEMPO_BURST_RATIO
    end

    return EDGE_TEMPO_RATIO
end

local function appendEdgeTempoHit(results, player: Player, enemy, skillId: string, sourcePosition: Vector3, targetPosition: Vector3, damageType: string)
    local skillConfig = SkillRuntimeConfig[skillId]
    local effect = makeEffectPayload(skillId, sourcePosition, targetPosition, nil, skillConfig.color, skillConfig.vfxStyle)
    effect.attackerUserId = player.UserId
    effect.edgeTempo = true
    local hitResult = resolveSingleHit(
        player,
        enemy,
        effect,
        damageType,
        getEdgeTempoDamageRatio(player, enemy.runtimeId)
    )
    table.insert(results, hitResult)
end

local function pushEnemyAway(enemy, sourcePosition, distance)
    if not enemy.instance or distance <= 0 then
        return
    end

    local delta = enemy.instance.Position - sourcePosition
    if delta.Magnitude <= 0.05 then
        delta = Vector3.new(0, 0, -1)
    end

    enemy.instance.Position += delta.Unit * distance
end

local function getActiveEnemyModifiers(enemy)
    enemy.runtimeModifiers = enemy.runtimeModifiers or {}
    local now = os.clock()
    for modifierId, modifierState in pairs(enemy.runtimeModifiers) do
        if type(modifierState) ~= 'table' or (modifierState.expiresAt or 0) <= now then
            enemy.runtimeModifiers[modifierId] = nil
        end
    end

    return enemy.runtimeModifiers
end

local function getEffectiveEnemyDefense(enemy)
    local defense = enemy.enemyDef.baseDefense or 0
    local modifiers = getActiveEnemyModifiers(enemy)
    local provoke = modifiers.provoke
    if provoke then
        defense *= math.max(1 - (provoke.defenseReduction or 0), 0.1)
    end

    return defense
end

local function getEffectiveEnemyMagicDefense(enemy)
    return enemy.enemyDef.baseMagicDefense or 0
end

local function getEffectiveEnemyFlee(enemy)
    return enemy.enemyDef.baseFlee or 0
end

local function getCurrentMana(player, stats)
    local profile = getProfile(player)
    if hasAdminPowerMode(player) then
        profile.runtime.currentMana = stats.maxMana
        return stats.maxMana
    end

    if profile.runtime.currentMana == nil then
        profile.runtime.currentMana = stats.maxMana
    end

    return profile.runtime.currentMana
end

local function getCurrentWeightRatio(player, stats)
    return InventoryService.getCurrentWeight(player) / math.max(stats.carryWeight, 1)
end

local function canAttack(player, stats)
    if getCurrentWeightRatio(player, stats) >= 0.9 then
        return false, 'Overweight'
    end

    return true, nil
end

local function consumeBasicAttackWindow(player)
    local now = os.clock()
    local attackInterval = math.max(StatService.getDerivedStats(player).attackIntervalSeconds or 0.25, 1 / 7)
    local nextAllowedAt = basicAttackCadenceByPlayer[player] or 0
    if now + 0.01 < nextAllowedAt then
        return false, 'AttackOnCooldown'
    end

    basicAttackCadenceByPlayer[player] = now + attackInterval
    return true, attackInterval
end

local function resolveKillRewards(player, resolvedEnemy)
    local enemyDef = resolvedEnemy.enemyDef
    local baseExperience = enemyDef.baseExperience or math.max(enemyDef.level * 12, 1)
    local jobExperience = enemyDef.jobExperience or math.max(math.floor(baseExperience * 0.65), 1)
    local zeny = enemyDef.baseZeny or math.max(enemyDef.level * 4, 1)

    local levelUpSummary = PlayerDataService.addCombatRewards(player, baseExperience, jobExperience, zeny)
    local dropResult = DropResolver.rollForEnemy(resolvedEnemy.enemyTypeId, {})
    if #dropResult.drops > 0 then
        WorldDropService.spawnDrops(dropResult.drops, resolvedEnemy.deathPosition or resolvedEnemy.spawnPosition or resolvedEnemy.instance.Position, {
            sourceMonsterId = resolvedEnemy.enemyTypeId,
            sourceHint = enemyDef.name,
            defeatedByName = player.Name,
        })
    end

    return {
        zeny = zeny,
        experience = baseExperience,
        jobExperience = jobExperience,
        drops = dropResult.drops,
        levelUp = levelUpSummary,
    }
end

local function getSkillRank(player, skillId: string): number
    return SkillLoadout.getSkillRank(getProfile(player), skillId)
end

local function getSkillConfig(skillId: string)
    return SkillRuntimeConfig[skillId]
end

local function getSkillCooldownSeconds(skillId: string, skillRank: number): number
    local skillConfig = getSkillConfig(skillId)
    local skillDef = SkillDefs[skillId]
    local baseCooldown = if skillConfig and skillConfig.cooldownSeconds ~= nil
        then skillConfig.cooldownSeconds
        elseif skillDef and skillDef.cooldownSeconds ~= nil then skillDef.cooldownSeconds
        else 0

    return math.max(baseCooldown, 0)
end

local function getSkillManaCost(skillId: string, skillRank: number): number
    local skillConfig = getSkillConfig(skillId)
    local skillDef = SkillDefs[skillId]
    local baseCost = if skillConfig and skillConfig.manaCostBase ~= nil
        then skillConfig.manaCostBase
        elseif skillDef and skillDef.manaCost ~= nil then skillDef.manaCost
        else 0
    local perRank = if skillConfig and skillConfig.manaCostPerRank ~= nil then skillConfig.manaCostPerRank else 0

    if baseCost <= 0 then
        return 0
    end

    return math.max(math.floor(baseCost + perRank * skillRank), 0)
end

local function getSkillCastTime(player, skillId: string, stats, skillRank: number): number
    local skillConfig = getSkillConfig(skillId)
    local skillDef = SkillDefs[skillId]
    local baseCast = if skillConfig and skillConfig.castTimeBase ~= nil
        then skillConfig.castTimeBase + (skillConfig.castTimePerRank or 0) * skillRank
        elseif skillDef and skillDef.castSeconds ~= nil then skillDef.castSeconds
        else 0

    if baseCast <= 0 then
        return 0
    end

    return CombatFormula.getCastTime(baseCast, stats.castSpeedMultiplier or 1)
end

local function checkSkillCooldown(player, skillId: string): (boolean, string?)
    local profile = getProfile(player)
    if hasAdminPowerMode(player) or (AdminConfig.isPlayerAuthorized(player) and profile.settings.adminNoCooldowns == true) then
        return true, nil
    end
    profile.runtime.skillCooldowns = profile.runtime.skillCooldowns or {}
    local now = os.clock()
    local readyAt = profile.runtime.skillCooldowns[skillId] or 0
    if readyAt > now then
        return false, 'SkillOnCooldown'
    end
    return true, nil
end

local function startSkillCooldown(player, skillId: string, skillRank: number)
    local profile = getProfile(player)
    if hasAdminPowerMode(player) or (AdminConfig.isPlayerAuthorized(player) and profile.settings.adminNoCooldowns == true) then
        profile.runtime.skillCooldowns = {}
        return
    end
    profile.runtime.skillCooldowns = profile.runtime.skillCooldowns or {}
    profile.runtime.skillCooldowns[skillId] = os.clock() + getSkillCooldownSeconds(skillId, skillRank)
end

local function consumeSkillResources(player, skillId: string, stats, skillRank: number): (boolean, string?)
    if hasAdminPowerMode(player) then
        local profile = getProfile(player)
        profile.runtime.currentMana = stats.maxMana
        return true, nil
    end

    local manaCost = getSkillManaCost(skillId, skillRank)
    local profile = getProfile(player)
    local currentMana = getCurrentMana(player, stats)
    if currentMana < manaCost then
        return false, 'NotEnoughSP'
    end

    profile.runtime.currentMana = currentMana - manaCost
    return true, nil
end

local function resolveSingleHit(player, enemy, effectPayload, damageType: string, damageMultiplier: number)
    local stats = StatService.getDerivedStats(player)
    local perfectDodgeChance = 0
    local hitChance = CombatFormula.getHitChance(stats.hit, getEffectiveEnemyFlee(enemy))

    if combatRng:NextNumber() <= perfectDodgeChance or combatRng:NextNumber() > hitChance then
        local missEffect = enrichEffectPayload(effectPayload, enemy, 0, false, true)
        return {
            result = 'Miss',
            enemyId = enemy.runtimeId,
            effect = missEffect,
            damage = 0,
        }
    end

    local didCrit = false
    local damage = 1
    if damageType == 'Magic' then
        damage = CombatFormula.calculateMagicalDamage(
            stats.magicAttack,
            getEffectiveEnemyMagicDefense(enemy),
            damageMultiplier
        )
    else
        local critChance = CombatFormula.getCritChance(stats.critChance, enemy.enemyDef.baseCritResist)
        didCrit = combatRng:NextNumber() <= critChance
        if didCrit then
            local rawDamage = CombatFormula.calculatePhysicalRawDamage(stats.physicalAttack, damageMultiplier)
            damage = CombatFormula.applyCritical(rawDamage, true, stats.critDamageMultiplier)
        else
            damage = CombatFormula.calculatePhysicalDamage(
                stats.physicalAttack,
                getEffectiveEnemyDefense(enemy),
                damageMultiplier
            )
        end
    end

    damage = CombatService.applyBurstMultiplier(player, enemy.runtimeId, damage)
    local resolvedEnemy = EnemyService.damageEnemy(enemy.runtimeId, damage)
    local effect = enrichEffectPayload(effectPayload, resolvedEnemy or enemy, damage, didCrit, false)
    local result = {
        result = 'Hit',
        enemyId = enemy.runtimeId,
        damage = damage,
        didCrit = didCrit,
        enemyHealth = resolvedEnemy and resolvedEnemy.currentHealth or 0,
        effect = effect,
    }

    if resolvedEnemy and not resolvedEnemy.alive then
        result.killRewards = resolveKillRewards(player, resolvedEnemy)
    end

    return result
end

local function waitForCast(player, skillId: string, stats, skillRank: number): (boolean, string?)
    local castTime = getSkillCastTime(player, skillId, stats, skillRank)
    if castTime > 0 then
        task.wait(castTime)
    end

    return true, nil
end

local function applyActiveBuff(player, buffId: string, rank: number, durationSeconds: number)
    local profile = getProfile(player)
    profile.runtime.activeBuffs = profile.runtime.activeBuffs or {}
    local buffState = {
        rank = rank,
        expiresAt = os.clock() + durationSeconds,
    }
    profile.runtime.activeBuffs[buffId] = buffState
end

local function setCharacterCloakingVisual(player, enabled: boolean)
    local character = player.Character
    if not character then
        return
    end

    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA('BasePart') then
            if enabled then
                if descendant:GetAttribute('CloakBaseTransparency') == nil then
                    descendant:SetAttribute('CloakBaseTransparency', descendant.Transparency)
                end
                descendant.Transparency = if descendant.Name == 'HumanoidRootPart' then 1 else math.max(descendant.Transparency, 0.72)
            else
                local baseTransparency = descendant:GetAttribute('CloakBaseTransparency')
                if type(baseTransparency) == 'number' then
                    descendant.Transparency = baseTransparency
                    descendant:SetAttribute('CloakBaseTransparency', nil)
                end
            end
        elseif descendant:IsA('Decal') then
            if enabled then
                if descendant:GetAttribute('CloakBaseTransparency') == nil then
                    descendant:SetAttribute('CloakBaseTransparency', descendant.Transparency)
                end
                descendant.Transparency = math.max(descendant.Transparency, 0.82)
            else
                local baseTransparency = descendant:GetAttribute('CloakBaseTransparency')
                if type(baseTransparency) == 'number' then
                    descendant.Transparency = baseTransparency
                    descendant:SetAttribute('CloakBaseTransparency', nil)
                end
            end
        end
    end
end

local function clearActiveBuff(player, buffId: string)
    local profile = getProfile(player)
    local activeBuffs = profile.runtime.activeBuffs or {}
    if not activeBuffs[buffId] then
        return
    end

    activeBuffs[buffId] = nil
    if buffId == 'cloaking' then
        setCharacterCloakingVisual(player, false)
    end
end

local function breakCloaking(player)
    clearActiveBuff(player, 'cloaking')
end

local function applyTimedBuff(player, buffId: string, rank: number, durationSeconds: number)
    applyActiveBuff(player, buffId, rank, durationSeconds)
    if buffId == 'cloaking' then
        setCharacterCloakingVisual(player, true)
    end

    local profile = getProfile(player)
    local activeBuffs = profile.runtime.activeBuffs or {}
    local activeState = activeBuffs[buffId]
    if not activeState then
        return
    end

    task.delay(durationSeconds, function()
        local refreshedProfile = getProfile(player)
        local refreshedBuffs = refreshedProfile.runtime.activeBuffs or {}
        if refreshedBuffs[buffId] == activeState and (activeState.expiresAt or 0) <= os.clock() then
            clearActiveBuff(player, buffId)
        end
    end)
end

local function buildHitSeries(player, enemy, skillId: string, hitCount: number, damageType: string, damageMultiplier: number, sourcePosition, targetPosition, styleOverride)
    local hits = {}
    local totalDamage = 0

    for hitIndex = 1, hitCount do
        if not enemy.alive then
            break
        end

        local effect = makeEffectPayload(
            skillId,
            sourcePosition,
            targetPosition,
            nil,
            getSkillConfig(skillId).color,
            styleOverride or getSkillConfig(skillId).vfxStyle
        )
        effect.sequenceIndex = hitIndex
        local hitResult = resolveSingleHit(player, enemy, effect, damageType, damageMultiplier)
        totalDamage += hitResult.damage or 0
        table.insert(hits, hitResult)
        if hitResult.killRewards then
            break
        end
    end

    return {
        result = 'MultiHit',
        skillId = skillId,
        hits = hits,
        totalDamage = totalDamage,
        damage = totalDamage,
        effect = makeEffectPayload(skillId, sourcePosition, targetPosition, nil, getSkillConfig(skillId).color, getSkillConfig(skillId).vfxStyle),
        killRewards = hits[#hits] and hits[#hits].killRewards or nil,
    }
end

local function useZeroSplashSkill(player: Player, skillId: string, rootPart, skillConfig, skillRank: number)
    local originPosition = rootPart.Position
    local lookVector = rootPart.CFrame.LookVector
    local movementProfile = skillConfig.movementProfile or {}
    local sourcePosition = originPosition + Vector3.new(0, 1.05, 0)
    local visualTargetPosition = originPosition
    local impactCenter = originPosition
    local damageType = skillConfig.damageType or 'Physical'
    local baseMultiplier = (skillConfig.damageMultiplierBase or 1) + (skillConfig.damageMultiplierPerRank or 0) * skillRank

    if skillId == 'forward_slash' then
        visualTargetPosition = dashCharacterForward(rootPart, movementProfile.distance or getEffectiveDashDistance(player, skillConfig))
        impactCenter = visualTargetPosition
    elseif skillId == 'circular_slash' then
        local planarLook = getPlanarDirection(lookVector)
        if planarLook.Magnitude <= 0.05 then
            planarLook = Vector3.new(0, 0, -1)
        end
        visualTargetPosition = originPosition + planarLook * (movementProfile.projectedDistance or getEffectiveDashDistance(player, skillConfig))
        impactCenter = visualTargetPosition
        sourcePosition = visualTargetPosition + Vector3.new(0, movementProfile.launchHeight or skillConfig.launchHeight or 18, 0)
    elseif skillId == 'evasive_slash' then
        visualTargetPosition = dashCharacterBackward(rootPart, movementProfile.distance or getEffectiveDashDistance(player, skillConfig))
        impactCenter = originPosition + getPlanarDirection(lookVector) * (((skillConfig.hitboxProfile and skillConfig.hitboxProfile.length) or 12) * 0.65)
        CombatService.startEvasionWindow(player, movementProfile.evadeSeconds or 0.12)
    end

    local triggeredTempo = getEdgeTempoTriggerState(player, skillId, skillConfig.comboWindowSeconds)
    local targets = collectZeroSkillTargets(skillId, originPosition, impactCenter, lookVector)
    local results = {}

    for _, enemy in ipairs(targets) do
        local hitEffect = makeEffectPayload(skillId, sourcePosition, enemy.instance.Position, nil, skillConfig.color, skillConfig.vfxStyle)
        hitEffect.attackerUserId = player.UserId
        local hitResult = resolveSingleHit(player, enemy, hitEffect, damageType, baseMultiplier)
        table.insert(results, hitResult)
        if triggeredTempo and (hitResult.damage or 0) > 0 and not hitResult.killRewards and enemy.alive then
            appendEdgeTempoHit(results, player, enemy, skillId, sourcePosition, enemy.instance.Position, damageType)
        end
    end

    local effect = makeEffectPayload(
        skillId,
        sourcePosition,
        if skillId == 'evasive_slash' then visualTargetPosition else impactCenter,
        skillId == 'circular_slash' and (skillConfig.hitboxProfile and skillConfig.hitboxProfile.radius) or nil,
        skillConfig.color,
        skillConfig.vfxStyle
    )
    effect.attackerUserId = player.UserId
    effect.edgeTempo = triggeredTempo

    return {
        result = 'Splash',
        skillId = skillId,
        hits = results,
        effect = effect,
    }
end

local function useZeroTwinEclipse(player: Player, skillId: string, rootPart, skillConfig, skillRank: number)
    local originPosition = rootPart.Position
    local acquireRange = skillConfig.range or getEffectiveSkillRange(player, skillConfig)
    local targetEnemy = getNearestEnemyToPosition(originPosition, acquireRange)
    local triggeredTempo = getEdgeTempoTriggerState(player, skillId, skillConfig.comboWindowSeconds)

    if not targetEnemy then
        local fallbackDistance = (skillConfig.movementProfile and skillConfig.movementProfile.fallbackDistance) or 14
        local destination = dashCharacterForward(rootPart, fallbackDistance)
        local fallbackEffect = makeEffectPayload(skillId, originPosition, destination, nil, skillConfig.color, skillConfig.vfxStyle)
        fallbackEffect.attackerUserId = player.UserId
        fallbackEffect.fallback = true
        fallbackEffect.edgeTempo = triggeredTempo
        return {
            result = 'Instant',
            skillId = skillId,
            message = 'Twin Eclipse cut through empty space.',
            effect = fallbackEffect,
        }
    end

    local enemyPosition = targetEnemy.instance.Position
    local blinkVector = enemyPosition - originPosition
    if blinkVector.Magnitude <= 0.05 then
        blinkVector = rootPart.CFrame.LookVector
    end
    local planarBlink = getPlanarDirection(blinkVector)
    if planarBlink.Magnitude <= 0.05 then
        planarBlink = Vector3.new(0, 0, -1)
    end
    local right = Vector3.new(-planarBlink.Z, 0, planarBlink.X)
    local destination = enemyPosition - planarBlink * 2.6 + right * 1.25
    rootPart.CFrame = CFrame.lookAt(destination, enemyPosition)

    local cloneMultiplier = (skillConfig.damageMultiplierPerHitBase or 0.48) + (skillConfig.damageMultiplierPerHitPerRank or 0) * skillRank
    local finisherMultiplier = (skillConfig.finisherDamageMultiplierBase or 1.1) + (skillConfig.finisherDamageMultiplierPerRank or 0) * skillRank
    local hits = {}

    for hitIndex = 1, 2 do
        if not targetEnemy.alive then
            break
        end
        local effect = makeEffectPayload(skillId, originPosition, enemyPosition, nil, skillConfig.color, skillConfig.vfxStyle)
        effect.attackerUserId = player.UserId
        effect.sequenceIndex = hitIndex
        effect.cloneSide = if hitIndex == 1 then -1 else 1
        local hitResult = resolveSingleHit(player, targetEnemy, effect, skillConfig.damageType or 'Physical', cloneMultiplier)
        table.insert(hits, hitResult)
        if hitResult.killRewards then
            break
        end
    end

    if targetEnemy.alive then
        local finisherEffect = makeEffectPayload(skillId, originPosition, enemyPosition, nil, skillConfig.color, skillConfig.vfxStyle)
        finisherEffect.attackerUserId = player.UserId
        finisherEffect.sequenceIndex = 3
        finisherEffect.finisher = true
        local finisherResult = resolveSingleHit(player, targetEnemy, finisherEffect, skillConfig.damageType or 'Physical', finisherMultiplier)
        table.insert(hits, finisherResult)
        if triggeredTempo and (finisherResult.damage or 0) > 0 and not finisherResult.killRewards and targetEnemy.alive then
            appendEdgeTempoHit(hits, player, targetEnemy, skillId, originPosition, enemyPosition, skillConfig.damageType or 'Physical')
        end
    end

    local totalDamage = 0
    for _, hit in ipairs(hits) do
        totalDamage += hit.damage or hit.totalDamage or 0
    end

    local effect = makeEffectPayload(skillId, originPosition, enemyPosition, nil, skillConfig.color, skillConfig.vfxStyle)
    effect.attackerUserId = player.UserId
    effect.edgeTempo = triggeredTempo

    return {
        result = 'MultiHit',
        skillId = skillId,
        hits = hits,
        totalDamage = totalDamage,
        damage = totalDamage,
        effect = effect,
        message = 'Twin Eclipse landed.',
        killRewards = hits[#hits] and hits[#hits].killRewards or nil,
    }
end

function CombatService.init() end

function CombatService.start()
    Players.PlayerRemoving:Connect(function(player)
        basicAttackCadenceByPlayer[player] = nil
        parryState[player.UserId] = nil
        edgeTempoState[player.UserId] = nil
    end)
end

function CombatService.basicAttackNearest(player)
    local rootPart = getCharacterRootPart(player)
    if not rootPart then
        return false, 'NoCharacter'
    end

    local config = getBasicAttackConfig(player)
    local enemy = EnemyService.getNearestEnemy(rootPart.Position, config.range)
    if not enemy then
        return false, 'NoEnemy'
    end

    return CombatService.basicAttackTarget(player, enemy.runtimeId)
end

function CombatService.basicAttackTarget(player, enemyRuntimeId: string)
    local rootPart = getCharacterRootPart(player)
    if not rootPart then
        return false, 'NoCharacter'
    end

    local enemy = EnemyService.getEnemy(enemyRuntimeId)
    if not enemy or not enemy.alive or not enemy.instance then
        return false, 'InvalidTarget'
    end

    local config = getBasicAttackConfig(player)
    if (enemy.instance.Position - rootPart.Position).Magnitude > config.range then
        return false, 'TargetTooFar'
    end

    local stats = StatService.getDerivedStats(player)
    local canBasicAttack, weightReason = canAttack(player, stats)
    if not canBasicAttack then
        return false, weightReason
    end

    local cadenceOk, cadenceReason = consumeBasicAttackWindow(player)
    if not cadenceOk then
        return false, cadenceReason
    end

    local profile = getProfile(player)
    if profile.archetypeId == 'archer_path' then
        local ammoOk, ammoReason = InventoryService.consumeEquippedAmmo(player, 1)
        if not ammoOk then
            return false, ammoReason
        end
    end

    breakCloaking(player)

    return true, resolveSingleHit(
        player,
        enemy,
        (function()
            local payload = makeEffectPayload('basic_attack', rootPart.Position, enemy.instance.Position, nil, config.color, config.vfxStyle)
            payload.attackerUserId = player.UserId
            if profile.archetypeId == 'archer_path' then
                payload.projectileVariant = 'arrow'
            end
            return payload
        end)(),
        config.damageType or 'Physical',
        config.damageMultiplier or 1
    )
end

function CombatService.useTargetedSkill(player, skillId: string, enemyRuntimeId: string?, targetPosition: Vector3?)
    local rootPart = getCharacterRootPart(player)
    if not rootPart then
        return false, 'NoCharacter'
    end

    local profile = getProfile(player)
    local skillConfig = getSkillConfig(skillId)
    if not skillConfig then
        return false, 'UnknownSkill'
    end
    if not SkillLoadout.canEquipSkill(profile, skillId) then
        return false, 'SkillLocked'
    end

    local usesGroundTarget = isGroundTargetedSkill(skillId)
    local enemy = nil
    local impactPosition = nil

    if usesGroundTarget then
        if typeof(targetPosition) == 'Vector3' then
            impactPosition = targetPosition
        elseif enemyRuntimeId then
            enemy = EnemyService.getEnemy(enemyRuntimeId)
            if enemy and enemy.alive and enemy.instance then
                impactPosition = enemy.instance.Position
            end
        end

        if not impactPosition then
            return false, 'InvalidGroundTarget'
        end
    else
        if not enemyRuntimeId then
            return false, 'InvalidTarget'
        end

        enemy = EnemyService.getEnemy(enemyRuntimeId)
        if not enemy or not enemy.alive or not enemy.instance then
            return false, 'InvalidTarget'
        end

        impactPosition = enemy.instance.Position
    end

    local stats = StatService.getDerivedStats(player)
    local canUse, reason = canAttack(player, stats)
    if not canUse then
        return false, reason
    end

    local effectiveRange = getEffectiveSkillRange(player, skillConfig)
    if not impactPosition then
        return false, 'InvalidTarget'
    end

    if usesGroundTarget then
        if getPlanarDistance(impactPosition, rootPart.Position) > effectiveRange then
            return false, 'TargetTooFar'
        end
    elseif (impactPosition - rootPart.Position).Magnitude > effectiveRange then
        return false, 'TargetTooFar'
    end

    local skillRank = math.max(getSkillRank(player, skillId), 1)
    local cooldownOk, cooldownReason = checkSkillCooldown(player, skillId)
    if not cooldownOk then
        return false, cooldownReason
    end

    local manaOk, manaReason = consumeSkillResources(player, skillId, stats, skillRank)
    if not manaOk then
        return false, manaReason
    end
    startSkillCooldown(player, skillId, skillRank)
    breakCloaking(player)

    waitForCast(player, skillId, stats, skillRank)

    local sourcePosition = rootPart.Position
    local effectiveDashDistance = getEffectiveDashDistance(player, skillConfig)
    if effectiveDashDistance > 0 then
        sourcePosition = moveCharacterToward(rootPart, impactPosition, effectiveDashDistance)
    end

    if skillId == 'bash' or skillId == 'charge_break' then
        local multiplier = skillConfig.damageMultiplierBase + skillConfig.damageMultiplierPerRank * skillRank
        return true, resolveSingleHit(
            player,
            enemy,
            makeEffectPayload(skillId, sourcePosition, enemy.instance.Position, nil, skillConfig.color, skillConfig.vfxStyle),
            'Physical',
            multiplier
        )
    elseif skillId == 'unwing_flyers' then
        local multiplier = (skillConfig.damageMultiplierBase or 1) + (skillConfig.damageMultiplierPerRank or 0) * skillRank
        local result = resolveSingleHit(
            player,
            enemy,
            makeEffectPayload(skillId, sourcePosition, enemy.instance.Position, nil, skillConfig.color, skillConfig.vfxStyle),
            skillConfig.damageType or 'Physical',
            multiplier
        )
        if enemy.instance then
            local launchDirection = getPlanarDirection(enemy.instance.Position - sourcePosition)
            enemy.instance.AssemblyLinearVelocity =
                (if launchDirection.Magnitude > 0.01 then launchDirection * 42 else Vector3.zero)
                + Vector3.new(0, 34, 0)
        end
        result.message = string.format('%s had its wings cut.', enemy.enemyDef.name)
        return true, result
    elseif skillId == 'blink_step' then
        local enemyPosition = enemy.instance.Position
        local blinkVector = enemyPosition - rootPart.Position
        if blinkVector.Magnitude <= 0.05 then
            blinkVector = rootPart.CFrame.LookVector
        end

        local destination = enemyPosition - blinkVector.Unit * 4
        rootPart.CFrame = CFrame.new(destination, enemyPosition)
        return true, resolveSingleHit(
            player,
            enemy,
            makeEffectPayload(skillId, sourcePosition, enemy.instance.Position, 8, skillConfig.color, skillConfig.vfxStyle),
            skillConfig.damageType or 'Physical',
            skillConfig.damageMultiplier or 1
        )
    elseif skillId == 'provoke' then
        enemy.runtimeModifiers = enemy.runtimeModifiers or {}
        enemy.runtimeModifiers.provoke = {
            defenseReduction = skillConfig.defenseReductionPerRank * skillRank,
            expiresAt = os.clock() + skillConfig.durationBase + skillConfig.durationPerRank * skillRank,
        }
        return true, {
            result = 'Debuff',
            skillId = skillId,
            message = string.format('%s provoked.', enemy.enemyDef.name),
            effect = makeEffectPayload(skillId, sourcePosition, enemy.instance.Position, nil, skillConfig.color, skillConfig.vfxStyle),
        }
    elseif skillId == 'fire_bolt' or skillId == 'cold_bolt' then
        return true, buildHitSeries(
            player,
            enemy,
            skillId,
            skillRank,
            'Magic',
            skillConfig.damageMultiplierPerHit,
            sourcePosition,
            enemy.instance.Position,
            'projectile'
        )
    elseif skillId == 'ice_shard' then
        local hitCount = (skillConfig.hitCountBase or 5) + math.floor(skillRank / 2) * (skillConfig.hitCountPerTwoRanks or 1)
        local perHitMultiplier = (skillConfig.damageMultiplierPerHitBase or 0.42) + (skillConfig.damageMultiplierPerHitPerRank or 0) * skillRank
        local hits = {}
        local totalDamage = 0

        for hitIndex = 1, hitCount do
            if not enemy.alive then
                break
            end

            local hitEffect = makeEffectPayload(skillId, sourcePosition, enemy.instance.Position, skillConfig.explosionRadius, skillConfig.color, skillConfig.vfxStyle)
            hitEffect.attackerUserId = player.UserId
            hitEffect.sequenceIndex = hitIndex
            hitEffect.projectileVariant = 'ice_shard'
            hitEffect.impactVariant = 'ice_cube'
            hitEffect.meshAssetId = skillConfig.projectileMeshAssetId
            hitEffect.hitSoundId = skillConfig.hitSoundId
            hitEffect.explosionRadius = skillConfig.explosionRadius
            hitEffect.shardSpread = skillConfig.shardSpread

            local hitResult = resolveSingleHit(player, enemy, hitEffect, 'Magic', perHitMultiplier)
            totalDamage += hitResult.damage or 0
            table.insert(hits, hitResult)
            if hitResult.killRewards then
                break
            end
        end

        local effect = makeEffectPayload(skillId, sourcePosition, enemy.instance.Position, skillConfig.explosionRadius, skillConfig.color, skillConfig.vfxStyle)
        effect.attackerUserId = player.UserId
        effect.projectileVariant = 'ice_shard'
        effect.impactVariant = 'ice_cube'
        effect.meshAssetId = skillConfig.projectileMeshAssetId
        effect.hitSoundId = skillConfig.hitSoundId
        effect.explosionRadius = skillConfig.explosionRadius
        effect.shardSpread = skillConfig.shardSpread
        effect.hitCount = hitCount

        return true, {
            result = 'MultiHit',
            skillId = skillId,
            hits = hits,
            totalDamage = totalDamage,
            damage = totalDamage,
            effect = effect,
            killRewards = hits[#hits] and hits[#hits].killRewards or nil,
        }
    elseif skillId == 'soul_strike' then
        local hitCount = math.max(math.ceil(skillRank / 2), 1)
        return true, buildHitSeries(
            player,
            enemy,
            skillId,
            hitCount,
            'Magic',
            skillConfig.damageMultiplierPerHit,
            sourcePosition,
            enemy.instance.Position,
            'projectileBurst'
        )
    elseif skillId == 'double_strafe' then
        local perHitMultiplier = skillConfig.damageMultiplierPerHitBase + skillConfig.damageMultiplierPerHitPerRank * skillRank
        return true, buildHitSeries(
            player,
            enemy,
            skillId,
            skillConfig.hitCountBase,
            'Physical',
            perHitMultiplier,
            sourcePosition,
            enemy.instance.Position,
            'projectileBurst'
        )
    elseif skillId == 'sonic_blow' then
        local perHitMultiplier = skillConfig.damageMultiplierPerHitBase + skillConfig.damageMultiplierPerHitPerRank * skillRank
        return true, buildHitSeries(
            player,
            enemy,
            skillId,
            skillConfig.hitCountBase,
            'Physical',
            perHitMultiplier,
            sourcePosition,
            enemy.instance.Position,
            'dashImpact'
        )
    elseif skillId == 'grimtooth' then
        local radius = skillConfig.radius or 7
        local hits = {}
        local totalDamage = 0
        local multiplier = (skillConfig.damageMultiplierBase or 1) + (skillConfig.damageMultiplierPerRank or 0) * skillRank
        for _, targetEnemy in ipairs(EnemyService.getAliveEnemies()) do
            if targetEnemy.instance and (targetEnemy.instance.Position - impactPosition).Magnitude <= radius then
                local result = buildHitSeries(
                    player,
                    targetEnemy,
                    skillId,
                    1,
                    'Physical',
                    multiplier,
                    sourcePosition,
                    targetEnemy.instance.Position,
                    'nova'
                )
                totalDamage += result.totalDamage or result.damage or 0
                table.insert(hits, result)
            end
        end

        local effect = makeEffectPayload(skillId, sourcePosition, impactPosition, radius, skillConfig.color, skillConfig.vfxStyle)
        if skillId == 'fire_wall' then
            effect.duration = skillConfig.persistSeconds or 7
        end

        return true, {
            result = 'TargetArea',
            skillId = skillId,
            hits = hits,
            totalDamage = totalDamage,
            damage = totalDamage,
            effect = effect,
        }
    elseif skillId == 'arrow_shower' or skillId == 'fire_wall' then
        local radius = skillConfig.radius or 6
        local hits = {}
        local totalDamage = 0
        for _, targetEnemy in ipairs(EnemyService.getAliveEnemies()) do
            if targetEnemy.instance and (targetEnemy.instance.Position - impactPosition).Magnitude <= radius then
                local hitCount = if skillId == 'fire_wall' then skillConfig.hitCountBase or 3 else 1
                local perHitMultiplier = if skillId == 'fire_wall'
                    then skillConfig.damageMultiplierPerHit
                    else skillConfig.damageMultiplierBase + skillConfig.damageMultiplierPerRank * skillRank
                local result = buildHitSeries(
                    player,
                    targetEnemy,
                    skillId,
                    hitCount,
                    if skillId == 'fire_wall' then 'Magic' else 'Physical',
                    perHitMultiplier,
                    sourcePosition,
                    impactPosition,
                    skillId == 'fire_wall' and 'nova' or 'rain'
                )
                totalDamage += result.totalDamage or result.damage or 0
                table.insert(hits, result)

                if skillId == 'fire_wall' then
                    pushEnemyAway(targetEnemy, impactPosition, skillConfig.knockbackDistance or 0)
                end
            end
        end

        return true, {
            result = 'TargetArea',
            skillId = skillId,
            hits = hits,
            totalDamage = totalDamage,
            damage = totalDamage,
            effect = makeEffectPayload(skillId, sourcePosition, impactPosition, radius, skillConfig.color, skillConfig.vfxStyle),
        }
    end

    return false, 'UnsupportedTargetedSkill'
end

function CombatService.useSplashSkill(player, skillId: string)
    local rootPart = getCharacterRootPart(player)
    if not rootPart then
        return false, 'NoCharacter'
    end

    local profile = getProfile(player)
    local skillConfig = getSkillConfig(skillId)
    if not skillConfig then
        return false, 'UnknownSkill'
    end
    if not SkillLoadout.canEquipSkill(profile, skillId) then
        return false, 'SkillLocked'
    end

    local stats = StatService.getDerivedStats(player)
    local canUse, reason = canAttack(player, stats)
    if not canUse then
        return false, reason
    end

    local skillRank = math.max(getSkillRank(player, skillId), 1)
    local cooldownOk, cooldownReason = checkSkillCooldown(player, skillId)
    if not cooldownOk then
        return false, cooldownReason
    end

    local manaOk, manaReason = consumeSkillResources(player, skillId, stats, skillRank)
    if not manaOk then
        return false, manaReason
    end
    startSkillCooldown(player, skillId, skillRank)
    breakCloaking(player)

    if isZeroSkill(skillId) then
        return true, useZeroSplashSkill(player, skillId, rootPart, skillConfig, skillRank)
    end

    local originPosition = rootPart.Position
    local sourcePosition = originPosition
    local impactCenter = originPosition
    local effectiveDashDistance = getEffectiveDashDistance(player, skillConfig)
    local radius = skillConfig.radius or 12
    local multiplier = (skillConfig.damageMultiplierBase or 1) + (skillConfig.damageMultiplierPerRank or 0) * skillRank

    if skillId == 'forward_slash' then
        sourcePosition = originPosition
        impactCenter = dashCharacterForward(rootPart, effectiveDashDistance)
    elseif skillId == 'circular_slash' then
        local lookVector = rootPart.CFrame.LookVector
        local launchHeight = skillConfig.launchHeight or 16
        local landingOffset = lookVector.Unit * effectiveDashDistance
        sourcePosition = originPosition + Vector3.new(0, launchHeight, 0)
        impactCenter = originPosition + landingOffset
    elseif skillId == 'evasive_slash' then
        sourcePosition = originPosition
        impactCenter = originPosition
        dashCharacterBackward(rootPart, effectiveDashDistance)
    else
        if effectiveDashDistance > 0 then
            sourcePosition = dashCharacterForward(rootPart, effectiveDashDistance)
        end
        impactCenter = rootPart.Position
    end

    local results = {}
    for _, enemy in ipairs(EnemyService.getAliveEnemies()) do
        if enemy.instance and (enemy.instance.Position - impactCenter).Magnitude <= radius then
            table.insert(results, resolveSingleHit(
                player,
                enemy,
                makeEffectPayload(skillId, sourcePosition, enemy.instance.Position, nil, skillConfig.color, skillConfig.vfxStyle or 'impact'),
                skillConfig.damageType or 'Physical',
                multiplier
            ))
        end
    end

    return true, {
        result = 'Splash',
        skillId = skillId,
        hits = results,
        effect = makeEffectPayload(skillId, sourcePosition, impactCenter, radius, skillConfig.color, skillConfig.vfxStyle),
    }
end

function CombatService.useInstantSkill(player, skillId: string)
    local rootPart = getCharacterRootPart(player)
    if not rootPart then
        return false, 'NoCharacter'
    end

    local profile = getProfile(player)
    local skillConfig = getSkillConfig(skillId)
    if not skillConfig then
        return false, 'UnknownSkill'
    end
    if not SkillLoadout.canEquipSkill(profile, skillId) then
        return false, 'SkillLocked'
    end

    local stats = StatService.getDerivedStats(player)
    local skillRank = math.max(getSkillRank(player, skillId), 1)
    local cooldownOk, cooldownReason = checkSkillCooldown(player, skillId)
    if not cooldownOk then
        return false, cooldownReason
    end

    -- Valkyrie flight toggle (Divine Ascent)
    if skillId == 'divine_ascent' then
        if not FlightService.canFly(player) then
            return false, 'CannotFly'
        end
        local mOk, mReason = consumeSkillResources(player, skillId, stats, skillRank)
        if not mOk then
            return false, mReason
        end
        startSkillCooldown(player, skillId, skillRank)
        local newState = FlightService.toggleFlight(player)
        return true, {
            result = 'Instant',
            skillId = skillId,
            message = if newState then 'Wings spread — taking flight!' else 'Landed safely.',
            effect = { skillId = skillId, flightState = newState },
        }
    end

    -- Block skills that require flight if player is not flying
    local runtimeCfg = SkillRuntimeConfig[skillId]
    if runtimeCfg and runtimeCfg.requiresFlight then
        if not FlightModule.IsFlying(player) then
            return false, 'MustBeFlying'
        end
    end
    local manaOk, manaReason = consumeSkillResources(player, skillId, stats, skillRank)
    if not manaOk then
        return false, manaReason
    end
    startSkillCooldown(player, skillId, skillRank)


    if skillId == 'shadow_clone_slash' then
        return true, useZeroTwinEclipse(player, skillId, rootPart, skillConfig, skillRank)
    end

    if skillId == 'dash_step' then
        local origin = rootPart.Position
        local lookVector = rootPart.CFrame.LookVector
        local dashDistance = getEffectiveDashDistance(player, skillConfig)
        if dashDistance <= 0 then
            dashDistance = 16
        end
        local destination = origin + lookVector * dashDistance
        rootPart.CFrame = CFrame.new(destination, destination + lookVector)
        return true, {
            result = 'Instant',
            skillId = skillId,
            message = 'Dashed forward.',
            effect = makeEffectPayload(skillId, origin, destination, dashDistance, skillConfig.color, skillConfig.vfxStyle),
        }
    elseif skillId == 'teleport' then
        local origin = rootPart.Position
        local profile = getProfile(player)
        local zoneId = WorldService.resolveZoneIdFromPosition(origin, profile.runtime.lastZoneId)
        local destinationCFrame = WorldService.getRandomTeleportCFrame(zoneId, origin, rootPart.CFrame.LookVector)
        rootPart.CFrame = destinationCFrame
        profile.runtime.lastZoneId = zoneId
        return true, {
            result = 'Instant',
            skillId = skillId,
            message = 'Teleported to another point on the current map.',
            effect = makeEffectPayload(skillId, origin, destinationCFrame.Position, nil, skillConfig.color, skillConfig.vfxStyle),
        }
    elseif skillId == 'improve_concentration' then
        local duration = (skillConfig.durationBase or 30) + (skillConfig.durationPerRank or 0) * skillRank
        applyTimedBuff(player, skillId, skillRank, duration)
        return true, {
            result = 'Buff',
            skillId = skillId,
            message = string.format('Improve Concentration active for %ds.', math.floor(duration)),
            effect = makeEffectPayload(skillId, rootPart.Position, rootPart.Position, nil, skillConfig.color, skillConfig.vfxStyle),
        }
    elseif skillId == 'cloaking' or skillId == 'enchant_deadly_poison' then
        local duration = (skillConfig.durationBase or 10) + (skillConfig.durationPerRank or 0) * skillRank
        applyTimedBuff(player, skillId, skillRank, duration)
        return true, {
            result = 'Buff',
            skillId = skillId,
            message = string.format('%s active for %ds.', SkillDefs[skillId].name, math.floor(duration)),
            effect = makeEffectPayload(skillId, rootPart.Position, rootPart.Position, nil, skillConfig.color, skillConfig.vfxStyle),
        }
    end

    return false, 'UnsupportedInstantSkill'
end

function CombatService.requestSkillUse(player, payload)
    if payload and payload.action == 'BasicAttackNearest' then
        return CombatService.basicAttackNearest(player)
    end

    return false, 'UnsupportedAction'
end

function CombatService.breakCloaking(player)
    breakCloaking(player)
end

function CombatService.startParryWindow(player: Player): (boolean, string?)
    local userId = player.UserId
    local now = os.clock()
    local state = parryState[userId] or {}

    if (state.cooldownUntil or 0) > now then
        return false, 'ParryOnCooldown'
    end

    if (state.stunUntil or 0) > now then
        return false, 'ParryStunned'
    end

    parryState[userId] = {
        activeUntil = now + PARRY_WINDOW_SECONDS,
        cooldownUntil = now + PARRY_COOLDOWN_SECONDS,
        stunUntil = state.stunUntil or 0,
        burstWindowUntil = state.burstWindowUntil or 0,
        burstEnemyRuntimeId = state.burstEnemyRuntimeId,
    }

    return true, nil
end

function CombatService.checkAndConsumeParry(player: Player, enemyRuntimeId: string?): boolean
    local state = parryState[player.UserId]
    if not state then
        return false
    end

    local now = os.clock()
    if now <= (state.activeUntil or 0) then
        state.activeUntil = 0
        state.burstWindowUntil = now + PARRY_BURST_SECONDS
        state.burstEnemyRuntimeId = enemyRuntimeId
        return true
    end

    return false
end

function CombatService.applyParryPunish(player: Player): boolean
    local state = parryState[player.UserId]
    if not state then
        return false
    end

    local now = os.clock()
    if (state.cooldownUntil or 0) <= now then
        return false
    end

    state.stunUntil = now + PARRY_STUN_SECONDS
    state.activeUntil = 0
    return true
end

function CombatService.startEvasionWindow(player: Player, durationSeconds: number)
    local state = parryState[player.UserId] or {}
    state.evadeUntil = math.max(state.evadeUntil or 0, os.clock() + math.max(durationSeconds, 0))
    parryState[player.UserId] = state
end

function CombatService.isEvading(player: Player): boolean
    local state = parryState[player.UserId]
    if not state then
        return false
    end

    return os.clock() < (state.evadeUntil or 0)
end

function CombatService.isParryStunned(player: Player): boolean
    local state = parryState[player.UserId]
    if not state then
        return false
    end

    return os.clock() < (state.stunUntil or 0)
end

function CombatService.applyBurstMultiplier(player: Player, enemyRuntimeId: string?, damage: number): number
    local state = parryState[player.UserId]
    if not state then
        return damage
    end

    if os.clock() <= (state.burstWindowUntil or 0)
        and enemyRuntimeId
        and state.burstEnemyRuntimeId == enemyRuntimeId
    then
        return math.max(math.floor(damage * PARRY_BURST_MULTIPLIER), damage)
    end

    return damage
end

function CombatService.getParryReflectDamage(bossBaseAttack: number): number
    return math.max(math.floor(math.max(bossBaseAttack, 1) * PARRY_REFLECT_RATIO), 1)
end

return CombatService
