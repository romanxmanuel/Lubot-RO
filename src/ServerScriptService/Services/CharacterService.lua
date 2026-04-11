--!strict

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ClassData = require(ReplicatedStorage.GameData.Classes.KnightData)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)
local StatConfig = require(ReplicatedStorage.Shared.Config.StatConfig)

local CharacterService = {
    Name = 'CharacterService',
}

local dependencies = nil
local runtimeStates: { [Player]: { lastDashAt: number, lastAttackAt: number } } = {}

local function deepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = deepCopy(nested)
    end
    return copy
end

local function normalizeStats(rawStats)
    local stats = deepCopy(StatConfig.StartingStats)
    if type(rawStats) == 'table' then
        for _, statName in ipairs(StatConfig.Order) do
            local value = rawStats[statName]
            if type(value) == 'number' then
                stats[statName] = math.max(1, math.floor(value))
            end
        end
    end
    return stats
end

local function getOrCreateRuntimeState(player: Player)
    local runtimeState = runtimeStates[player]
    if runtimeState then
        return runtimeState
    end

    runtimeState = {
        lastDashAt = 0,
        lastAttackAt = 0,
    }
    runtimeStates[player] = runtimeState
    return runtimeState
end

local function getHumanoid(player: Player): Humanoid?
    local character = player.Character
    if not character then
        return nil
    end
    return character:FindFirstChildOfClass('Humanoid')
end

local function syncAllocatedStats(player: Player, profile)
    local stats = normalizeStats(profile.stats)
    profile.stats = stats

    for _, statName in ipairs(StatConfig.Order) do
        player:SetAttribute(statName, stats[statName])
    end
    player:SetAttribute('StatPoints', math.max(0, math.floor(profile.statPoints or 0)))
end

local function getDerivedStats(classDef, profile)
    local level = profile.level or 1
    local stats = normalizeStats(profile.stats)
    profile.stats = stats
    local agiBonus = math.max(0, stats.AGI - 1) * StatConfig.WalkSpeedPerAgi

    return {
        maxHealth = classDef.maxHealth + math.max(0, level - 1) * 12 + math.max(0, stats.VIT - 1) * StatConfig.HealthPerVit,
        maxSp = classDef.maxSp + math.max(0, level - 1) * 3 + math.max(0, stats.INT - 1) * StatConfig.SpPerInt,
        walkSpeed = classDef.walkSpeed + agiBonus,
        attackPower = stats.STR * StatConfig.AttackPerStr,
        hitRating = stats.DEX * StatConfig.HitPerDex,
        critChance = stats.LUK * StatConfig.CritPerLuk,
        aspd = 100 + stats.AGI * StatConfig.AspdPerAgi,
    }
end

local function applyCharacterStats(player: Player, character: Model)
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    if not humanoid then
        return
    end

    local profile = dependencies.PersistenceService.waitForProfile(player, 10)
    if not profile then
        return
    end

    local classDef = ClassData[profile.classId] or ClassData.knight
    local derivedStats = getDerivedStats(classDef, profile)
    local previousHealthRatio = humanoid.MaxHealth > 0 and (humanoid.Health / humanoid.MaxHealth) or 1
    humanoid.MaxHealth = derivedStats.maxHealth
    humanoid.Health = math.clamp(derivedStats.maxHealth * previousHealthRatio, 1, derivedStats.maxHealth)
    humanoid.WalkSpeed = derivedStats.walkSpeed
    if type(GameConfig.BaseJumpPower) == 'number' and GameConfig.BaseJumpPower > 0 then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = GameConfig.BaseJumpPower
    end

    player:SetAttribute('HP', humanoid.Health)
    player:SetAttribute('MaxHP', humanoid.MaxHealth)
    player:SetAttribute('SP', derivedStats.maxSp)
    player:SetAttribute('MaxSP', derivedStats.maxSp)
    player:SetAttribute('ClassId', classDef.id)
    player:SetAttribute('Level', profile.level)
    player:SetAttribute('JobLevel', nil)
    player:SetAttribute('Zeny', profile.zeny)
    player:SetAttribute('Experience', profile.experience)
    player:SetAttribute('ExperienceMax', dependencies.PersistenceService.getBaseExperienceRequirement(profile.level))
    player:SetAttribute('JobExperience', nil)
    player:SetAttribute('JobExperienceMax', nil)
    player:SetAttribute('AttackPower', derivedStats.attackPower)
    player:SetAttribute('HitRating', derivedStats.hitRating)
    player:SetAttribute('CritChance', derivedStats.critChance)
    player:SetAttribute('AspdRating', derivedStats.aspd)
    syncAllocatedStats(player, profile)

    humanoid.HealthChanged:Connect(function(health)
        player:SetAttribute('HP', health)
        player:SetAttribute('MaxHP', humanoid.MaxHealth)
    end)
end

local function refreshCharacterFromProfile(player: Player)
    local character = player.Character
    if not character then
        return
    end
    applyCharacterStats(player, character)
end

function CharacterService.init(deps)
    dependencies = deps
end

function CharacterService.start()
    local function bindPlayer(player: Player)
        getOrCreateRuntimeState(player)
        player.CharacterAdded:Connect(function(character)
            task.defer(function()
                applyCharacterStats(player, character)
            end)
        end)

        if player.Character then
            task.defer(function()
                applyCharacterStats(player, player.Character :: Model)
            end)
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        bindPlayer(player)
    end
    Players.PlayerAdded:Connect(bindPlayer)

    dependencies.Runtime.ActionRequest.OnServerEvent:Connect(function(player, payload)
        if type(payload) ~= 'table' or payload.action ~= MMONet.Actions.Dash then
            return
        end
        CharacterService.tryUseDash(player)
    end)

    dependencies.Runtime.StatRequest.OnServerEvent:Connect(function(player, payload)
        if type(payload) ~= 'table' then
            return
        end

        if payload.kind == 'allocate' then
            CharacterService.allocateStat(player, tostring(payload.stat or ''))
        elseif payload.kind == 'reset' then
            CharacterService.resetStats(player)
        end
    end)
end

function CharacterService.getHumanoidRootPart(player: Player)
    local character = player.Character
    if not character then
        return nil
    end
    return character:FindFirstChild('HumanoidRootPart')
end

function CharacterService.tryUseDash(player: Player): boolean
    local runtimeState = getOrCreateRuntimeState(player)
    runtimeState.lastDashAt = os.clock()
    local root = CharacterService.getHumanoidRootPart(player)
    if root then
        local lookVector = root.CFrame.LookVector
        local planar = Vector3.new(lookVector.X, 0, lookVector.Z)
        if planar.Magnitude <= 0.001 then
            planar = Vector3.new(0, 0, -1)
        end

        dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.Dash, {
            userId = player.UserId,
            origin = root.Position,
            direction = planar.Unit,
            distance = GameConfig.DashDistance,
        })
    end
    return true
end

function CharacterService.allocateStat(player: Player, statName: string): boolean
    local normalizedStat = string.upper(statName)
    local isAllowed = false
    for _, allowed in ipairs(StatConfig.Order) do
        if allowed == normalizedStat then
            isAllowed = true
            break
        end
    end
    if not isAllowed then
        dependencies.Runtime.SystemMessage:FireClient(player, 'Unknown stat.')
        return false
    end

    local changed = false
    dependencies.PersistenceService.updateProfile(player, function(profile)
        profile.stats = normalizeStats(profile.stats)
        profile.statPoints = math.max(0, math.floor(profile.statPoints or 0))
        if profile.statPoints <= 0 then
            return
        end
        profile.statPoints -= 1
        profile.stats[normalizedStat] += 1
        changed = true
    end)

    if changed then
        refreshCharacterFromProfile(player)
    end
    return changed
end

function CharacterService.resetStats(player: Player): boolean
    local changed = false
    dependencies.PersistenceService.updateProfile(player, function(profile)
        local currentStats = normalizeStats(profile.stats)
        local refunded = 0
        for _, statName in ipairs(StatConfig.Order) do
            refunded += math.max(0, currentStats[statName] - StatConfig.StartingStats[statName])
        end
        profile.stats = deepCopy(StatConfig.StartingStats)
        profile.statPoints = math.max(0, math.floor(profile.statPoints or 0)) + refunded
        changed = refunded > 0
    end)

    if changed then
        refreshCharacterFromProfile(player)
    end
    return changed
end

function CharacterService.canUseAttack(player: Player, cooldown: number): boolean
    local runtimeState = getOrCreateRuntimeState(player)
    return os.clock() - runtimeState.lastAttackAt >= cooldown
end

function CharacterService.markAttackUsed(player: Player)
    getOrCreateRuntimeState(player).lastAttackAt = os.clock()
end

function CharacterService.damagePlayer(player: Player, amount: number)
    local humanoid = getHumanoid(player)
    if humanoid and humanoid.Health > 0 then
        local root = CharacterService.getHumanoidRootPart(player)
        humanoid:TakeDamage(amount)
        player:SetAttribute('HP', humanoid.Health)
        if root then
            dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.PlayerHit, {
                userId = player.UserId,
                position = root.Position + Vector3.new(0, 2, 0),
                damage = amount,
            })
        end
    end
end

function CharacterService.healPlayer(player: Player, amount: number)
    local humanoid = getHumanoid(player)
    if not humanoid then
        return
    end

    humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
    player:SetAttribute('HP', humanoid.Health)
end

return CharacterService
