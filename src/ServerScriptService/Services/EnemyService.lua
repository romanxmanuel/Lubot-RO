--!strict

local CollectionService = game:GetService('CollectionService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Workspace = game:GetService('Workspace')

local CombatAudioConfig = require(ReplicatedStorage.Shared.Config.CombatAudioConfig)
local CombatFormula = require(ReplicatedStorage.Shared.Combat.CombatFormula)
local EnemyDefs = require(ReplicatedStorage.Shared.DataDefs.Enemies.EnemyDefs)
local GameplayNetDefs = require(ReplicatedStorage.Shared.Net.GameplayNetDefs)
local EnemyScaling = require(ReplicatedStorage.Shared.Combat.EnemyScaling)
local SkillRuntimeConfig = require(ReplicatedStorage.Shared.Skills.SkillRuntimeConfig)
local StatService = require(script.Parent.StatService)

local EnemyService = {}

local enemiesById = {}
local enemyCounter = 0
local movementConnection = nil

local PORING_WANDER_RADIUS = 18
local PORING_HOP_INTERVAL = 0.42
local PORING_HOP_DURATION = 0.34
local PORING_HOP_DISTANCE = 4.5
local PORING_HOP_HEIGHT = 1.8
local PORING_IDLE_DECISION_TIME = 1.3
local PORING_BOUNCE_SOUND_ID = CombatAudioConfig.skillSounds
    and CombatAudioConfig.skillSounds.dash_step
    and CombatAudioConfig.skillSounds.dash_step.soundId
    or 'rbxassetid://139994035606058'
local PORING_BOUNCE_BASE_SPEED = 1.12
local PORING_BOUNCE_ATTACK_SPEED = 1.28
local PORING_AGGRO_RADIUS = 28
local PORING_ATTACK_RANGE = 12
local PORING_ATTACK_HOP_DISTANCE = 7.5
local PORING_ATTACK_HOP_HEIGHT = 2.5
local PORING_ATTACK_COOLDOWN = 0.7
local ENEMY_BILLBOARD_REVEAL_DISTANCE = 24
local ENEMY_RESPAWN_DELAY_SECONDS = 4
local ENEMY_RESPAWN_RADIUS_MIN = 6
local ENEMY_RESPAWN_RADIUS_MAX = 13
local enemyRespawnRng = Random.new()
local enemyMoveRng = Random.new()
local GENERIC_WANDER_RADIUS = 16
local GENERIC_BOSS_WANDER_RADIUS = 20
local GENERIC_DECISION_DELAY_MIN = 0.35
local GENERIC_DECISION_DELAY_MAX = 1.15
local GENERIC_BOSS_DECISION_DELAY_MIN = 0.6
local GENERIC_BOSS_DECISION_DELAY_MAX = 1.45
local GENERIC_BOB_HEIGHT_MIN = 0.08
local GENERIC_BOB_HEIGHT_MAX = 0.48
local ENEMY_ATTACK_DAMAGE_MULTIPLIER = 0.5
local ENEMY_ATTACK_RANGE_PADDING = 2.15
local ENEMY_ATTACK_RANGE_MIN = 4.2
local ENEMY_ATTACK_RANGE_MAX = 8.5
local ENEMY_ATTACK_INTERVAL_MIN = 0.65
local ENEMY_ATTACK_INTERVAL_MAX = 1.6
local ENEMY_ATTACK_INTERVAL_BOSS_MIN = 0.55
local ENEMY_ATTACK_INTERVAL_BOSS_MAX = 1.25
local ENEMY_ATTACK_INTERVAL_SPEED_FACTOR = 0.055
local ENEMY_PASSIVE_ATTACK_RANGE = 5.5
local ENEMY_DETECTION_RANGE_MIN = 16
local ENEMY_DETECTION_RANGE_MAX = 34
local ENEMY_DETECTION_RANGE_PASSIVE_FLOOR = 18
local ENEMY_DETECTION_RANGE_BOSS_FLOOR = 28
local ENEMY_CHASE_STOP_DISTANCE = 2.25
local enemyAttackRng = Random.new()
local remotesFolder = nil
local playSkillEffectRemote = nil

local bossStaggerUntil = {}
-- bossStaggerUntil[runtimeId] = serverClockTime
local BOSS_STAGGER_SECONDS = 2.0

local enemyMasterModelNames = {
    poring = 'Poring_Master',
    lunatic = 'Lunatic_Master',
    willow = 'Willow_Master',
    rocker = 'Rocker_Master',
    andre = 'Andre_Master',
    deniro = 'Deniro_Master',
    piere = 'Piere_Master',
    vitata = 'Vitata_Master',
    maya_purple_trial = 'MayaPurple_Master',
    sewer_lord_murmur = 'SewerLordMurmur_Master',
    lude = 'Lude_Master',
    quve = 'Quve_Master',
    hylozoist = 'Hylozoist_Master',
    gibbet = 'Gibbet_Master',
    dullahan = 'Dullahan_Master',
    disguise = 'Disguise_Master',
    bloody_murderer = 'BloodyMurderer_Master',
    loli_ruri = 'LoliRuri_Master',
    lord_of_the_dead = 'LordOfTheDead_Master',
    crimson_arbiter = 'CrimsonArbiter_Master',
}

local preferredRootNames = {
    Body = true,
    Core = true,
    Trunk = true,
    Base = true,
    Root = true,
}

local function ensureRemotesFolder()
    if remotesFolder and remotesFolder.Parent == ReplicatedStorage then
        return remotesFolder
    end

    local existing = ReplicatedStorage:FindFirstChild('Remotes')
    if existing and existing:IsA('Folder') then
        remotesFolder = existing
        return remotesFolder
    end

    local folder = Instance.new('Folder')
    folder.Name = 'Remotes'
    folder.Parent = ReplicatedStorage
    remotesFolder = folder
    return folder
end

local function ensurePlaySkillEffectRemote()
    if playSkillEffectRemote and playSkillEffectRemote.Parent then
        return playSkillEffectRemote
    end

    local folder = ensureRemotesFolder()
    local remoteName = GameplayNetDefs.RemoteEvents.PlaySkillEffect
    local existing = folder:FindFirstChild(remoteName)
    if existing and existing:IsA('RemoteEvent') then
        playSkillEffectRemote = existing
        return existing
    end

    local remote = Instance.new('RemoteEvent')
    remote.Name = remoteName
    remote.Parent = folder
    playSkillEffectRemote = remote
    return remote
end

local function broadcastSkillEffect(effectPayload)
    if not effectPayload then
        return
    end

    local remote = ensurePlaySkillEffectRemote()
    for _, recipient in ipairs(Players:GetPlayers()) do
        remote:FireClient(recipient, effectPayload)
    end
end

local function weldToRoot(rootPart: BasePart, part: BasePart)
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = true
    part.Massless = true

    local weld = Instance.new('WeldConstraint')
    weld.Part0 = rootPart
    weld.Part1 = part
    weld.Parent = part
end

local function createAdornmentPart(parent: Instance, rootPart: BasePart, name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?)
    local part = Instance.new('Part')
    part.Name = name
    part.Size = size
    part.Shape = shape or Enum.PartType.Block
    part.Material = material or Enum.Material.SmoothPlastic
    part.Color = color
    part.CFrame = rootPart.CFrame * CFrame.new(offset)
    part.Parent = parent
    weldToRoot(rootPart, part)
    return part
end

local function applyPoringTravelLook(clone: Instance, rootPart: BasePart)
    for _, legacyName in ipairs({
        'TravelPack',
        'TravelPackFlap',
        'TravelPackPouch',
        'TravelStrapFront',
        'TravelStrapBack',
        'SmileLeft',
        'SmileRight',
    }) do
        local legacyPart = clone:FindFirstChild(legacyName, true)
        if legacyPart then
            legacyPart:Destroy()
        end
    end

    local bodyPart = clone:FindFirstChild('Body', true)
    if bodyPart and bodyPart:IsA('BasePart') then
        bodyPart.Color = Color3.fromRGB(255, 173, 208)
        bodyPart.Material = Enum.Material.SmoothPlastic
    end

    local crownTop = clone:FindFirstChild('CrownTop', true)
    if crownTop and crownTop:IsA('BasePart') then
        crownTop.Color = Color3.fromRGB(255, 182, 216)
        crownTop.Material = Enum.Material.SmoothPlastic
    end
end

local function ensurePoringBounceSound(rootPart: BasePart)
    local existing = rootPart:FindFirstChild('PoringBounceSound')
    if existing and existing:IsA('Sound') then
        return existing
    end

    local sound = Instance.new('Sound')
    sound.Name = 'PoringBounceSound'
    sound.SoundId = PORING_BOUNCE_SOUND_ID
    sound.Volume = 0.68
    sound.PlaybackSpeed = PORING_BOUNCE_BASE_SPEED
    sound.RollOffMaxDistance = 60
    sound.RollOffMinDistance = 8
    sound.Parent = rootPart
    return sound
end

local function getNearestPlayerRoot(position: Vector3, maxDistance: number)
    local nearestRoot = nil
    local nearestDistance = maxDistance

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        local rootPart = character and character:FindFirstChild('HumanoidRootPart')
        if humanoid and humanoid.Health > 0 and rootPart and rootPart:IsA('BasePart') then
            local distance = (rootPart.Position - position).Magnitude
            if distance <= nearestDistance then
                nearestDistance = distance
                nearestRoot = rootPart
            end
        end
    end

    return nearestRoot, nearestDistance
end

local function getNearestPlayerTarget(position: Vector3, maxDistance: number)
    local nearestPlayer = nil
    local nearestRoot = nil
    local nearestHumanoid = nil
    local nearestDistance = maxDistance

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        local rootPart = character and character:FindFirstChild('HumanoidRootPart')
        if humanoid and humanoid.Health > 0 and rootPart and rootPart:IsA('BasePart') then
            local distance = (rootPart.Position - position).Magnitude
            if distance <= nearestDistance then
                nearestDistance = distance
                nearestPlayer = player
                nearestRoot = rootPart
                nearestHumanoid = humanoid
            end
        end
    end

    return nearestPlayer, nearestRoot, nearestHumanoid, nearestDistance
end

local function getEnemyDetectionRange(enemyDef): number
    local baseAggroRange = enemyDef.aggroRange or 0
    local level = enemyDef.level or 1
    local levelBonus = math.clamp(level * 0.38, 0, 9)
    local behaviorFloor = if enemyDef.enemyType == 'Boss'
        then ENEMY_DETECTION_RANGE_BOSS_FLOOR
        elseif enemyDef.behavior == 'Aggressive'
        then 20
        else ENEMY_DETECTION_RANGE_PASSIVE_FLOOR

    return math.clamp(
        math.max(baseAggroRange + 10, behaviorFloor + levelBonus),
        ENEMY_DETECTION_RANGE_MIN,
        if enemyDef.enemyType == 'Boss' then ENEMY_DETECTION_RANGE_MAX + 6 else ENEMY_DETECTION_RANGE_MAX
    )
end

local function nextEnemyId(enemyTypeId: string): string
    enemyCounter += 1
    return string.format('%s_%d', enemyTypeId, enemyCounter)
end

local function getRuntimeEnemyFolder(): Folder
    local spawnedFolder = Workspace:FindFirstChild('SpawnedDuringPlay')
    if spawnedFolder and spawnedFolder:IsA('Folder') then
        local enemiesFolder = spawnedFolder:FindFirstChild('Enemies')
        if enemiesFolder and enemiesFolder:IsA('Folder') then
            return enemiesFolder
        end
    end

    local ensuredSpawnedFolder = spawnedFolder
    if not (ensuredSpawnedFolder and ensuredSpawnedFolder:IsA('Folder')) then
        ensuredSpawnedFolder = Instance.new('Folder')
        ensuredSpawnedFolder.Name = 'SpawnedDuringPlay'
        ensuredSpawnedFolder.Parent = Workspace
    end

    local enemiesFolder = Instance.new('Folder')
    enemiesFolder.Name = 'Enemies'
    enemiesFolder.Parent = ensuredSpawnedFolder
    return enemiesFolder
end

local function getMonsterMasterFolder(): Folder?
    local assetsFolder = ReplicatedStorage:FindFirstChild('Assets')
    if not assetsFolder or not assetsFolder:IsA('Folder') then
        return nil
    end

    local artSources = assetsFolder:FindFirstChild('ArtSources')
    if not artSources or not artSources:IsA('Folder') then
        return nil
    end

    local monsterMasters = artSources:FindFirstChild('MonsterMasters')
    if monsterMasters and monsterMasters:IsA('Folder') then
        return monsterMasters
    end

    return nil
end

local function getMasterModel(enemyTypeId: string): Model?
    local masterFolder = getMonsterMasterFolder()
    if not masterFolder then
        return nil
    end

    local modelName = enemyMasterModelNames[enemyTypeId]
    if not modelName then
        return nil
    end

    local masterModel = masterFolder:FindFirstChild(modelName)
    if masterModel and masterModel:IsA('Model') then
        return masterModel
    end

    return nil
end

local function findRootBasePart(instance: Instance?): BasePart?
    if not instance then
        return nil
    end

    if instance:IsA('BasePart') then
        return instance
    end

    local preferred = nil
    local fallback = nil
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('BasePart') then
            fallback = fallback or descendant
            if preferredRootNames[descendant.Name] then
                preferred = descendant
                break
            end
        end
    end

    return preferred or fallback
end

local function applyEnemyAttributes(instance: Instance, enemyId: string)
    instance:SetAttribute('EnemyRuntimeId', enemyId)
    if instance:IsA('BasePart') then
        CollectionService:AddTag(instance, 'Enemy')
    end

    for _, descendant in ipairs(instance:GetDescendants()) do
        descendant:SetAttribute('EnemyRuntimeId', enemyId)
        if descendant:IsA('BasePart') then
            CollectionService:AddTag(descendant, 'Enemy')
        end
    end
end

local function attachEnemyBillboard(hostPart: BasePart, enemyDef)
    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'EnemyBillboard'
    billboard.Size = UDim2.fromOffset(150, 68)
    billboard.StudsOffset = Vector3.new(0, hostPart.Size.Y * 0.75 + 1.8, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = ENEMY_BILLBOARD_REVEAL_DISTANCE
    billboard.Parent = hostPart

    local label = Instance.new('TextLabel')
    label.Name = 'NameLabel'
    label.Size = UDim2.new(1, 0, 0, 22)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.Text = enemyDef.name
    label.Parent = billboard

    local levelLabel = Instance.new('TextLabel')
    levelLabel.Name = 'LevelLabel'
    levelLabel.Size = UDim2.new(1, 0, 0, 14)
    levelLabel.Position = UDim2.fromOffset(0, 18)
    levelLabel.BackgroundTransparency = 1
    levelLabel.Font = Enum.Font.GothamSemibold
    levelLabel.TextSize = 10
    levelLabel.TextColor3 = Color3.fromRGB(235, 221, 162)
    levelLabel.TextStrokeTransparency = 0.2
    levelLabel.Text = string.format('Lv. %d', enemyDef.level or 1)
    levelLabel.Parent = billboard

    local healthBack = Instance.new('Frame')
    healthBack.Name = 'HealthBack'
    healthBack.Size = UDim2.new(1, -8, 0, 10)
    healthBack.Position = UDim2.fromOffset(4, 36)
    healthBack.BackgroundColor3 = Color3.fromRGB(50, 19, 22)
    healthBack.BorderSizePixel = 0
    healthBack.Parent = billboard

    local healthFill = Instance.new('Frame')
    healthFill.Name = 'HealthFill'
    healthFill.Size = UDim2.fromScale(1, 1)
    healthFill.BackgroundColor3 = Color3.fromRGB(255, 92, 111)
    healthFill.BorderSizePixel = 0
    healthFill.Parent = healthBack

    local hpText = Instance.new('TextLabel')
    hpText.Name = 'HealthText'
    hpText.Size = UDim2.new(1, 0, 0, 16)
    hpText.Position = UDim2.fromOffset(0, 48)
    hpText.BackgroundTransparency = 1
    hpText.Font = Enum.Font.GothamSemibold
    hpText.TextSize = 11
    hpText.TextColor3 = Color3.fromRGB(235, 239, 243)
    hpText.TextStrokeTransparency = 0.35
    hpText.Text = ''
    hpText.Parent = billboard
end

local function createClickHitbox(parent: Instance, enemyId: string, rootPart: BasePart, enemyDef)
    local hitbox = Instance.new('Part')
    hitbox.Name = 'ClickHitbox'
    hitbox.Anchored = true
    hitbox.CanCollide = false
    hitbox.CanTouch = false
    hitbox.CanQuery = true
    hitbox.Transparency = 1
    hitbox.Material = Enum.Material.ForceField
    hitbox.Color = Color3.fromRGB(255, 255, 255)

    local hitboxSize = Vector3.new(
        math.max(rootPart.Size.X + 0.8, rootPart.Size.X),
        math.max(rootPart.Size.Y + 0.8, rootPart.Size.Y),
        math.max(rootPart.Size.Z + 0.8, rootPart.Size.Z)
    )
    local hitboxCFrame = rootPart.CFrame

    if parent:IsA('Model') then
        local boundingCFrame, boundingSize = parent:GetBoundingBox()
        hitboxSize = Vector3.new(
            math.max(boundingSize.X + 0.6, boundingSize.X),
            math.max(boundingSize.Y + 0.6, boundingSize.Y),
            math.max(boundingSize.Z + 0.6, boundingSize.Z)
        )
        hitboxCFrame = boundingCFrame
    end

    hitbox.Size = hitboxSize
    hitbox.CFrame = hitboxCFrame
    hitbox.Parent = parent
    applyEnemyAttributes(hitbox, enemyId)

    if parent:IsA('Model') then
        hitbox.Anchored = false
        hitbox.Massless = true
        local weld = Instance.new('WeldConstraint')
        weld.Part0 = rootPart
        weld.Part1 = hitbox
        weld.Parent = hitbox
    end

    return hitbox
end

local function getNearbyRespawnPosition(origin: Vector3, fallbackY: number?): Vector3
    local angle = enemyRespawnRng:NextNumber(0, math.pi * 2)
    local radius = enemyRespawnRng:NextNumber(ENEMY_RESPAWN_RADIUS_MIN, ENEMY_RESPAWN_RADIUS_MAX)
    local y = fallbackY or origin.Y
    return Vector3.new(
        origin.X + math.cos(angle) * radius,
        y,
        origin.Z + math.sin(angle) * radius
    )
end

local function getEnemyMoveProfile(enemy)
    local enemyDef = enemy.enemyDef
    local moveSpeed = enemyDef.moveSpeed or 0
    local isBoss = enemyDef.enemyType == 'Boss'
    local isWillow = enemy.enemyTypeId == 'willow'
    local isAnt = enemy.enemyTypeId == 'andre'
        or enemy.enemyTypeId == 'deniro'
        or enemy.enemyTypeId == 'piere'
        or enemy.enemyTypeId == 'vitata'
        or enemy.enemyTypeId == 'maya_purple_trial'

    local stepDistance = math.clamp((moveSpeed * 0.48) + (isBoss and 1.6 or 0.9), if isBoss then 3.6 else 2.1, if isBoss then 8.5 else 6.6)
    local moveDuration = math.clamp(1.02 - moveSpeed * 0.045, if isBoss then 0.34 else 0.28, if isBoss then 0.82 else 0.7)
    local bobHeight = math.clamp((moveSpeed / 30), GENERIC_BOB_HEIGHT_MIN, GENERIC_BOB_HEIGHT_MAX)

    if isWillow then
        stepDistance *= 0.72
        moveDuration *= 1.18
        bobHeight = 0.12
    elseif isAnt then
        stepDistance *= 1.08
        moveDuration *= 0.94
        bobHeight = 0.1
    end

    return {
        wanderRadius = if isBoss then GENERIC_BOSS_WANDER_RADIUS else GENERIC_WANDER_RADIUS,
        decisionDelayMin = if isBoss then GENERIC_BOSS_DECISION_DELAY_MIN else GENERIC_DECISION_DELAY_MIN,
        decisionDelayMax = if isBoss then GENERIC_BOSS_DECISION_DELAY_MAX else GENERIC_DECISION_DELAY_MAX,
        stepDistance = stepDistance,
        moveDuration = moveDuration,
        bobHeight = bobHeight,
        chaseRange = getEnemyDetectionRange(enemyDef),
    }
end

local function chooseGenericMoveTarget(enemy, rootPart: BasePart, moveProfile, now: number)
    local movementState = enemy.movementState
    local targetPosition = nil

    local targetPlayerRoot, distanceToPlayer = getNearestPlayerRoot(rootPart.Position, moveProfile.chaseRange)
    if targetPlayerRoot and distanceToPlayer <= moveProfile.chaseRange then
        local chaseVector = Vector3.new(
            targetPlayerRoot.Position.X - rootPart.Position.X,
            0,
            targetPlayerRoot.Position.Z - rootPart.Position.Z
        )

        if chaseVector.Magnitude > 0.05 then
            local desiredStep = math.min(moveProfile.stepDistance, math.max(chaseVector.Magnitude - ENEMY_CHASE_STOP_DISTANCE, 0))
            if desiredStep > 0.2 then
                targetPosition = rootPart.Position + chaseVector.Unit * desiredStep
                movementState.nextDecisionAt = now + enemyMoveRng:NextNumber(0.08, 0.2)
            else
                movementState.nextDecisionAt = now + enemyMoveRng:NextNumber(0.12, 0.24)
                return Vector3.new(rootPart.Position.X, movementState.homeY, rootPart.Position.Z)
            end
        end
    end

    if not targetPosition then
        local angle = enemyMoveRng:NextNumber(0, math.pi * 2)
        local distance = enemyMoveRng:NextNumber(moveProfile.stepDistance * 0.45, moveProfile.stepDistance)
        targetPosition = rootPart.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
        movementState.nextDecisionAt = now + enemyMoveRng:NextNumber(moveProfile.decisionDelayMin, moveProfile.decisionDelayMax)
    end

    local flatOffsetFromSpawn = Vector3.new(
        targetPosition.X - enemy.spawnPosition.X,
        0,
        targetPosition.Z - enemy.spawnPosition.Z
    )

    if flatOffsetFromSpawn.Magnitude > moveProfile.wanderRadius then
        targetPosition = enemy.spawnPosition + (flatOffsetFromSpawn.Unit * moveProfile.wanderRadius)
    end

    return Vector3.new(targetPosition.X, movementState.homeY, targetPosition.Z)
end

local function getPoringAggroRange(enemy): number
    return math.max(PORING_AGGRO_RADIUS, getEnemyDetectionRange(enemy.enemyDef))
end

local function getPoringAttackTriggerRange(enemy): number
    return math.max(PORING_ATTACK_RANGE, math.min(getEnemyDetectionRange(enemy.enemyDef) - 6, PORING_AGGRO_RADIUS))
end

local function stepGenericEnemyMovement(enemy, rootPart: BasePart, now: number)
    enemy.movementState = enemy.movementState or {
        nextDecisionAt = now + enemyMoveRng:NextNumber(0.18, 0.42),
        moveStartAt = nil,
        moveFrom = nil,
        moveTo = nil,
        moveDuration = 0.5,
        homeY = enemy.spawnPosition.Y,
    }

    local movementState = enemy.movementState
    local moveProfile = getEnemyMoveProfile(enemy)

    if movementState.moveStartAt and movementState.moveFrom and movementState.moveTo then
        local elapsed = now - movementState.moveStartAt
        local alpha = math.clamp(elapsed / math.max(movementState.moveDuration, 0.01), 0, 1)
        local eased = if alpha < 0.5 then 2 * alpha * alpha else 1 - ((-2 * alpha + 2) ^ 2) / 2
        local horizontalPosition = movementState.moveFrom:Lerp(movementState.moveTo, eased)
        local bobOffset = math.sin(alpha * math.pi) * moveProfile.bobHeight
        local targetPosition = Vector3.new(horizontalPosition.X, movementState.homeY + bobOffset, horizontalPosition.Z)
        local facing = movementState.moveTo - movementState.moveFrom

        if facing.Magnitude > 0.05 then
            rootPart.CFrame = CFrame.lookAt(targetPosition, targetPosition + facing.Unit)
        else
            rootPart.CFrame = CFrame.new(targetPosition)
        end

        if alpha >= 1 then
            if facing.Magnitude > 0.05 then
                rootPart.CFrame = CFrame.lookAt(movementState.moveTo, movementState.moveTo + facing.Unit)
            else
                rootPart.CFrame = CFrame.new(movementState.moveTo)
            end
            movementState.moveStartAt = nil
            movementState.moveFrom = nil
            movementState.moveTo = nil
        end

        return
    end

    if now < (movementState.nextDecisionAt or 0) then
        return
    end

    movementState.moveDuration = moveProfile.moveDuration * enemyMoveRng:NextNumber(0.92, 1.08)
    movementState.moveStartAt = now
    movementState.moveFrom = Vector3.new(rootPart.Position.X, movementState.homeY, rootPart.Position.Z)
    movementState.moveTo = chooseGenericMoveTarget(enemy, rootPart, moveProfile, now)
end

local function getEnemyAttackInterval(enemy): number
    local enemyDef = enemy.enemyDef
    local moveSpeed = enemyDef.moveSpeed or 0
    local intervalBase = if enemyDef.enemyType == 'Boss'
        then math.clamp(1.15 - moveSpeed * ENEMY_ATTACK_INTERVAL_SPEED_FACTOR, ENEMY_ATTACK_INTERVAL_BOSS_MIN, ENEMY_ATTACK_INTERVAL_BOSS_MAX)
        else math.clamp(1.48 - moveSpeed * ENEMY_ATTACK_INTERVAL_SPEED_FACTOR, ENEMY_ATTACK_INTERVAL_MIN, ENEMY_ATTACK_INTERVAL_MAX)
    return intervalBase
end

local function getEnemyAttackRange(enemy): number
    local rootPart = enemy.instance
    local width = if rootPart then math.max(rootPart.Size.X, rootPart.Size.Z) else 2
    local baseRange = math.clamp(width + ENEMY_ATTACK_RANGE_PADDING, ENEMY_ATTACK_RANGE_MIN, ENEMY_ATTACK_RANGE_MAX)
    if enemy.enemyDef.enemyType == 'Boss' then
        return math.max(baseRange, 7)
    end
    if enemy.enemyDef.behavior ~= 'Aggressive' and (enemy.enemyDef.aggroRange or 0) <= 0 then
        return math.min(baseRange, ENEMY_PASSIVE_ATTACK_RANGE)
    end
    return baseRange
end

local function getEnemyScaledAttack(enemy): number
    local enemyDef = enemy.enemyDef
    return math.max(
        math.floor(EnemyScaling.getScaledAttack(enemyDef.baseAttack or 1, enemyDef.level or 1, enemyDef.scaling) * ENEMY_ATTACK_DAMAGE_MULTIPLIER),
        1
    )
end

local function getEnemySkillConfig(skillId: string)
    return SkillRuntimeConfig[skillId]
end

local function getEnemySkillCooldownState(enemy)
    enemy.skillCooldowns = enemy.skillCooldowns or {}
    return enemy.skillCooldowns
end

local function startEnemySkillCooldown(enemy, skillId: string, cooldownSeconds: number, now: number)
    getEnemySkillCooldownState(enemy)[skillId] = now + math.max(cooldownSeconds, 0.1)
end

local function applyEnemyDamageToPlayer(targetPlayer: Player, targetHumanoid, damage: number, effectPayload)
    local CombatService = require(script.Parent.CombatService)
    if CombatService.isEvading(targetPlayer) then
        if effectPayload then
            effectPayload.wasMiss = true
            effectPayload.damage = 0
            effectPayload.damagedUserId = targetPlayer.UserId
            broadcastSkillEffect(effectPayload)
        end
        return false
    end

    targetHumanoid:TakeDamage(damage)
    if effectPayload then
        broadcastSkillEffect(effectPayload)
    end
    return true
end

local function nudgePlayerAway(playerRoot: BasePart, sourcePosition: Vector3, distance: number)
    if distance <= 0 then
        return
    end

    local delta = playerRoot.Position - sourcePosition
    local planar = Vector3.new(delta.X, 0, delta.Z)
    if planar.Magnitude <= 0.05 then
        planar = Vector3.new(0, 0, -1)
    end

    playerRoot.CFrame += planar.Unit * distance
end

local function resolveGroundImpactPosition(origin: Vector3): Vector3
    local rayOrigin = origin + Vector3.new(0, 8, 0)
    local rayResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -24, 0))
    if rayResult then
        return rayResult.Position + Vector3.new(0, 0.2, 0)
    end

    return origin
end

local function buildRandomFireWallPosition(enemy, centerPosition: Vector3, radius: number): Vector3
    local rootPart = enemy.instance
    if not rootPart then
        return resolveGroundImpactPosition(centerPosition)
    end

    local angle = enemyMoveRng:NextNumber(0, math.pi * 2)
    local distance = enemyMoveRng:NextNumber(math.max(radius * 0.3, 2), math.max(radius, 3))
    local rawPosition = centerPosition + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
    return resolveGroundImpactPosition(rawPosition)
end

local function castFireWallAtPosition(enemy, impactPosition: Vector3, now: number, skillDirective, options)
    local skillId = 'fire_wall'
    local skillConfig = getEnemySkillConfig(skillId)
    if not skillConfig then
        return false
    end

    local rootPart = enemy.instance
    if not rootPart then
        return false
    end

    options = options or {}

    if not options.skipCooldownCheck then
        local cooldownState = getEnemySkillCooldownState(enemy)
        local readyAt = cooldownState[skillId] or 0
        if now < readyAt then
            return false
        end
    end

    local resolvedImpactPosition = resolveGroundImpactPosition(impactPosition)
    local range = skillDirective.range or skillConfig.range or 15
    local preferredMinDistance = skillDirective.preferredMinDistance or 0
    local distanceToTarget = (resolvedImpactPosition - rootPart.Position).Magnitude
    if distanceToTarget > range or distanceToTarget < preferredMinDistance then
        return false
    end

    local radius = skillConfig.radius or 6
    local hitCount = skillConfig.hitCountBase or 3
    local knockbackDistance = skillConfig.knockbackDistance or 0
    local scaledMagicAttack = math.max(math.floor(getEnemyScaledAttack(enemy) * 0.92), 1)

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local playerRoot = character and character:FindFirstChild('HumanoidRootPart')
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        if playerRoot and humanoid and humanoid.Health > 0 then
            local planarDistance = Vector3.new(
                playerRoot.Position.X - resolvedImpactPosition.X,
                0,
                playerRoot.Position.Z - resolvedImpactPosition.Z
            ).Magnitude
            if planarDistance <= radius then
                local defenderStats = StatService.getDerivedStats(player)
                local totalDamage = 0
                for _ = 1, hitCount do
                    totalDamage += CombatFormula.calculateMagicalDamage(
                        scaledMagicAttack,
                        defenderStats.magicDefense or 0,
                        skillConfig.damageMultiplierPerHit or 0.5
                    )
                end
                humanoid:TakeDamage(math.max(totalDamage, 1))
                nudgePlayerAway(playerRoot, resolvedImpactPosition, knockbackDistance)
            end
        end
    end

    broadcastSkillEffect({
        effectKey = skillId,
        sourcePosition = rootPart.Position,
        targetPosition = resolvedImpactPosition,
        radius = radius,
        duration = options.duration or skillDirective.persistSeconds or skillConfig.persistSeconds or 7,
        color = skillConfig.color,
        style = skillConfig.vfxStyle or 'fireWall',
        attackerUserId = 0,
        casterType = 'enemy',
        enemyRuntimeId = enemy.runtimeId,
        targetName = options.targetName,
    })

    if not options.skipStartCooldown then
        startEnemySkillCooldown(enemy, skillId, skillDirective.cooldownSeconds or skillConfig.cooldownSeconds or 2, now)
    end
    return true
end

local function castFireWallAtPlayer(enemy, targetPlayer, targetRoot: BasePart, now: number, skillDirective, options)
    return castFireWallAtPosition(enemy, targetRoot.Position, now, skillDirective, {
        skipCooldownCheck = options and options.skipCooldownCheck,
        skipStartCooldown = options and options.skipStartCooldown,
        targetName = targetPlayer and targetPlayer.Name or nil,
    })
end

local function buildFireWallClusterPositions(enemy, targetPlayer, targetRoot: BasePart, skillDirective)
    local positions = { resolveGroundImpactPosition(targetRoot.Position) }
    local clusterCount = math.max(math.floor(skillDirective.clusterCount or 1), 1)
    local randomClusterRadius = math.max(skillDirective.randomClusterRadius or 10, 3)
    local clusterCenter = enemy.instance and enemy.instance.Position or targetRoot.Position

    for _ = 2, clusterCount do
        table.insert(positions, buildRandomFireWallPosition(enemy, clusterCenter, randomClusterRadius))
    end

    return positions, targetPlayer and targetPlayer.UserId or 0
end

local function isBossStaggered(enemy): boolean
    local t = bossStaggerUntil[enemy.runtimeId]
    return t ~= nil and os.clock() < t
end

local function applyBossStagger(enemy)
    bossStaggerUntil[enemy.runtimeId] = os.clock() + BOSS_STAGGER_SECONDS
end

local function tryUseActiveSkills(enemy, now: number)
    if not enemy.alive or not enemy.instance or not enemy.instance.Parent then
        return
    end
    if isBossStaggered(enemy) then
        return false
    end

    local activeSkills = enemy.enemyDef.activeSkills
    if type(activeSkills) ~= 'table' or #activeSkills == 0 then
        return
    end

    for _, skillDirective in ipairs(activeSkills) do
        if skillDirective.skillId == 'fire_wall' then
            local range = skillDirective.range or (getEnemySkillConfig('fire_wall') and getEnemySkillConfig('fire_wall').range) or 15
            local targetPlayer, targetRoot = getNearestPlayerTarget(enemy.instance.Position, range)
            if targetPlayer and targetRoot then
                local clusterPositions = buildFireWallClusterPositions(enemy, targetPlayer, targetRoot, skillDirective)
                local didCast = false
                for _, clusterPosition in ipairs(clusterPositions) do
                    didCast = castFireWallAtPosition(enemy, clusterPosition, now, skillDirective, {
                        skipStartCooldown = true,
                        duration = skillDirective.persistSeconds,
                        targetName = targetPlayer.Name,
                    }) or didCast
                end
                if not didCast then
                    continue
                end

                startEnemySkillCooldown(
                    enemy,
                    skillDirective.skillId,
                    skillDirective.cooldownSeconds
                        or (getEnemySkillConfig(skillDirective.skillId) and getEnemySkillConfig(skillDirective.skillId).cooldownSeconds)
                        or 2,
                    now
                )
                return true
            end
        end
    end

    return false
end

local function tryBossAttackSet(enemy, now: number)
    if not enemy.alive or not enemy.instance or not enemy.instance.Parent then
        return
    end
    if isBossStaggered(enemy) then
        return
    end
    if (enemy.nextAttackAt or 0) > now then
        return
    end

    local attackSet = enemy.enemyDef.attackSet
    if type(attackSet) ~= 'table' or #attackSet == 0 then
        return
    end

    -- Cycle through attacks in order
    enemy._attackSetIndex = ((enemy._attackSetIndex or 0) % #attackSet) + 1
    local attack = attackSet[enemy._attackSetIndex]

    local targetPlayer, targetRoot, targetHumanoid, distanceToPlayer =
        getNearestPlayerTarget(enemy.instance.Position, attack.rangeStuds or 20)
    if not targetPlayer or not targetRoot or not targetHumanoid then
        return
    end
    if distanceToPlayer > (attack.rangeStuds or 20) then
        return
    end

    -- Set next attack time BEFORE async wind-up to prevent re-triggering
    enemy.nextAttackAt = now + getEnemyAttackInterval(enemy) + (attack.windUpDuration or 0.7)

    -- Broadcast wind-up to all clients
    local SliceRuntimeService = require(script.Parent.SliceRuntimeService)
    SliceRuntimeService.broadcastBossWindUp({
        enemyRuntimeId = enemy.runtimeId,
        attackId = attack.id,
        windUpDuration = attack.windUpDuration or 0.7,
        isParryable = attack.isParryable,
        sourcePosition = enemy.instance.Position,
        targetUserId = targetPlayer.UserId,
    })

    -- Guard against double-resolve if multiple coroutines somehow fire for same strike
    local parryHandled = false

    -- Spawn the delayed strike (does not block the game loop)
    task.spawn(function()
        task.wait(attack.windUpDuration or 0.7)

        -- Re-validate: enemy still alive and not staggered
        if not enemy.alive or not enemy.instance or not enemy.instance.Parent then
            return
        end
        if isBossStaggered(enemy) then
            return
        end

        -- Re-validate: target still alive
        local character = targetPlayer.Character
        local currentHumanoid = character and character:FindFirstChildOfClass('Humanoid')
        if not currentHumanoid or currentHumanoid.Health <= 0 then
            return
        end

        local currentRoot = character and character:FindFirstChild('HumanoidRootPart')
        local attackRange = (attack.rangeStuds or 20) + 4  -- slight leniency for moving targets
        local currentDist = currentRoot and (currentRoot.Position - enemy.instance.Position).Magnitude or 999
        if currentDist > attackRange then
            return  -- target moved out of range during wind-up
        end

        -- Check parry — guard ensures reflect damage fires at most once per strike
        local CombatService = require(script.Parent.CombatService)
        if attack.isParryable and not parryHandled and CombatService.checkAndConsumeParry(targetPlayer, enemy.runtimeId) then
            parryHandled = true
            applyBossStagger(enemy)
            local reflectDamage = CombatService.getParryReflectDamage(enemy.enemyDef.baseAttack or 1)
            enemy.currentHealth = math.max(enemy.currentHealth - reflectDamage, 0)
            updateEnemyBillboard(enemy)

            SliceRuntimeService.broadcastParryResult(targetPlayer, {
                result = 'success',
                enemyRuntimeId = enemy.runtimeId,
                reflectDamage = reflectDamage,
                burstWindowSeconds = 2,
                sourcePosition = enemy.instance.Position,
            })
            -- Broadcast stagger visually to all players
            SliceRuntimeService.broadcastBossWindUp({
                enemyRuntimeId = enemy.runtimeId,
                attackId = 'stagger',
                windUpDuration = 0,
                isParryable = false,
                sourcePosition = enemy.instance.Position,
                targetUserId = 0,
            })
            return
        end

        -- Check if player was in parry stance but missed (hard punish)
        if attack.isParryable then
            local wasStunned = CombatService.applyParryPunish(targetPlayer)
            if wasStunned then
                SliceRuntimeService.broadcastParryResult(targetPlayer, {
                    result = 'punished',
                    stunSeconds = 0.5,
                })
            end
        end

        -- Deal full damage
        local defenderStats = StatService.getDerivedStats(targetPlayer)
        local scaledAttack = getEnemyScaledAttack(enemy)
        local damage = CombatFormula.calculatePhysicalDamage(
            scaledAttack,
            defenderStats.physicalDefense or 0,
            1
        )
        local levelFloor = math.max(math.floor((enemy.enemyDef.level or 1) * 0.75), 1)
        damage = math.max(damage, levelFloor)
        applyEnemyDamageToPlayer(targetPlayer, currentHumanoid, damage, {
            effectKey = 'enemy_basic_attack',
            style = 'slash',
            sourcePosition = enemy.instance.Position,
            targetPosition = (currentRoot and currentRoot.Position or enemy.instance.Position) + Vector3.new(0, 1.8, 0),
            attackerUserId = 0,
            damagedUserId = targetPlayer.UserId,
            enemyRuntimeId = enemy.runtimeId,
            damage = damage,
            didCrit = false,
        })
    end)
end

local function tryAttackNearbyPlayer(enemy, now: number)
    if not enemy.alive or not enemy.instance or not enemy.instance.Parent then
        return
    end
    if isBossStaggered(enemy) then
        return
    end

    if enemy.enemyDef.enemyType == 'Practice' or (enemy.enemyDef.baseAttack or 0) <= 0 then
        return
    end

    local attackRange = getEnemyAttackRange(enemy)
    local targetPlayer, targetRoot, targetHumanoid, distanceToPlayer = getNearestPlayerTarget(enemy.instance.Position, attackRange)
    if not targetPlayer or not targetRoot or not targetHumanoid or distanceToPlayer > attackRange then
        return
    end

    local nextAttackAt = enemy.nextAttackAt or 0
    if now < nextAttackAt then
        return
    end

    local defenderStats = StatService.getDerivedStats(targetPlayer)
    local perfectDodgeChance = (defenderStats.perfectDodgeChance or 0) * 0.5
    local attackerHit = math.max((enemy.enemyDef.baseHit or 0) + (enemy.enemyDef.level or 1) * 8, 1)
    local hitChance = math.max(
        CombatFormula.getHitChance(attackerHit, defenderStats.flee or 0),
        math.clamp(0.2 + (enemy.enemyDef.level or 1) * 0.01, 0.2, 0.55)
    )
    if enemyAttackRng:NextNumber() <= perfectDodgeChance or enemyAttackRng:NextNumber() > hitChance then
        broadcastSkillEffect({
            effectKey = 'enemy_basic_attack',
            style = 'slash',
            sourcePosition = enemy.instance.Position,
            targetPosition = targetRoot.Position + Vector3.new(0, 1.8, 0),
            attackerUserId = 0,
            damagedUserId = targetPlayer.UserId,
            enemyRuntimeId = enemy.runtimeId,
            wasMiss = true,
        })
        enemy.nextAttackAt = now + getEnemyAttackInterval(enemy)
        return
    end

    local scaledAttack = getEnemyScaledAttack(enemy)
    local damage = CombatFormula.calculatePhysicalDamage(
        scaledAttack,
        defenderStats.physicalDefense or 0,
        1
    )
    local levelFloor = math.max(math.floor((enemy.enemyDef.level or 1) * 0.75), 1)
    local pressureFloor = math.max(math.floor(scaledAttack * 0.45), 1)
    damage = math.max(damage, levelFloor, pressureFloor)
    applyEnemyDamageToPlayer(targetPlayer, targetHumanoid, damage, {
        effectKey = 'enemy_basic_attack',
        style = 'slash',
        sourcePosition = enemy.instance.Position,
        targetPosition = targetRoot.Position + Vector3.new(0, 1.8, 0),
        attackerUserId = 0,
        damagedUserId = targetPlayer.UserId,
        enemyRuntimeId = enemy.runtimeId,
        damage = damage,
        didCrit = false,
    })
    enemy.nextAttackAt = now + getEnemyAttackInterval(enemy)
end

local function createFallbackEnemyPart(enemyId: string, enemyDef, position: Vector3)
    local folder = getRuntimeEnemyFolder()

    local part = Instance.new('Part')
    part.Name = enemyDef.name
    part.Size = enemyDef.visual and enemyDef.visual.size or if enemyDef.enemyType == 'Boss' then Vector3.new(7, 7, 7) elseif enemyDef.level >= 8 then Vector3.new(5.5, 5.5, 5.5) else Vector3.new(4, 4, 4)
    part.Shape = enemyDef.visual and enemyDef.visual.shape or Enum.PartType.Ball
    part.Color = enemyDef.visual and enemyDef.visual.color or if enemyDef.enemyType == 'Boss' then Color3.fromRGB(255, 166, 92) elseif enemyDef.level >= 8 then Color3.fromRGB(110, 255, 135) else Color3.fromRGB(120, 255, 140)
    part.Material = enemyDef.visual and enemyDef.visual.material or Enum.Material.Neon
    part.Position = position
    part.Anchored = true
    part.CanCollide = true
    part.Parent = folder
    applyEnemyAttributes(part, enemyId)
    attachEnemyBillboard(part, enemyDef)

    return part, part
end

local function createEnemyFromMaster(enemyId: string, enemyDef, position: Vector3)
    local masterModel = getMasterModel(enemyDef.id)
    if not masterModel then
        return createFallbackEnemyPart(enemyId, enemyDef, position)
    end

    local runtimeFolder = getRuntimeEnemyFolder()
    local clone = masterModel:Clone()
    clone.Name = enemyDef.name
    clone.Parent = runtimeFolder

    local rootPart = findRootBasePart(clone)
    if not rootPart then
        clone:Destroy()
        return createFallbackEnemyPart(enemyId, enemyDef, position)
    end

    clone.PrimaryPart = rootPart
    clone:PivotTo(CFrame.new(position))

    for _, descendant in ipairs(clone:GetDescendants()) do
        if descendant:IsA('BasePart') then
            if descendant == rootPart then
                descendant.Anchored = true
                descendant.CanCollide = true
                descendant.CanQuery = true
            else
                descendant.Anchored = false
                descendant.CanCollide = false
                descendant.CanQuery = true
                descendant.Massless = true

                local weld = Instance.new('WeldConstraint')
                weld.Part0 = rootPart
                weld.Part1 = descendant
                weld.Parent = descendant
            end
        end
    end

    if enemyDef.id == 'poring' then
        applyPoringTravelLook(clone, rootPart)
        applyEnemyAttributes(clone, enemyId)
        
        -- Rename Part to Mouth
        local part = clone:FindFirstChild('Part')
        if part then
            part.Name = 'Mouth'
        end
        
        -- Fix face orientation for porings - eyes and mouth should face the player
        local eye1 = clone:FindFirstChild('Eye1')
        local eye2 = clone:FindFirstChild('Eye2')
        local mouth = clone:FindFirstChild('Mouth')
        
        if eye1 then
            eye1.CFrame = eye1.CFrame * CFrame.Angles(0, math.rad(180), 0)
        end
        if eye2 then
            eye2.CFrame = eye2.CFrame * CFrame.Angles(0, math.rad(180), 0)
        end
        if mouth then
            local currentPos = mouth.Position
            mouth.CFrame = CFrame.new(currentPos.X, 1.2, currentPos.Z) * CFrame.Angles(0, math.rad(180), 0)
        end
    end

    applyEnemyAttributes(clone, enemyId)
    createClickHitbox(clone, enemyId, rootPart, enemyDef)
    attachEnemyBillboard(rootPart, enemyDef)

    return rootPart, clone
end

local function updateEnemyBillboard(enemy)
    local part = enemy.instance
    if not part then
        return
    end

    local billboard = part:FindFirstChild('EnemyBillboard')
    if not billboard or not billboard:IsA('BillboardGui') then
        return
    end

    local fill = billboard:FindFirstChild('HealthBack') and billboard.HealthBack:FindFirstChild('HealthFill')
    local hpText = billboard:FindFirstChild('HealthText')
    local ratio = if enemy.maxHealth > 0 then enemy.currentHealth / enemy.maxHealth else 0

    if fill and fill:IsA('Frame') then
        fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
        fill.BackgroundColor3 = if ratio <= 0.2 then Color3.fromRGB(255, 105, 105) elseif ratio <= 0.5 then Color3.fromRGB(255, 186, 87) else Color3.fromRGB(115, 240, 132)
    end

    if hpText and hpText:IsA('TextLabel') then
        if enemy.enemyDef.infiniteHealth then
            hpText.Text = string.format('%d / INF HP', math.floor(enemy.currentHealth))
        else
            hpText.Text = string.format('%d / %d HP', math.floor(enemy.currentHealth), math.floor(enemy.maxHealth))
        end
    end
end

function EnemyService.init()
    table.clear(enemiesById)
    if movementConnection then
        movementConnection:Disconnect()
        movementConnection = nil
    end
end

function EnemyService.start()
    if movementConnection then
        return
    end

    movementConnection = RunService.Heartbeat:Connect(function()
        local now = os.clock()

        for _, enemy in pairs(enemiesById) do
            if not enemy.alive or not enemy.instance or not enemy.instance.Parent then
                continue
            end

            if enemy.enemyDef.enemyType == 'Practice' or (enemy.enemyDef.moveSpeed or 0) <= 0 then
                continue
            end

            if enemy.enemyTypeId ~= 'poring' then
                stepGenericEnemyMovement(enemy, enemy.instance, now)
                if tryUseActiveSkills(enemy, now) then
                    continue
                end
                if enemy.enemyDef.enemyType == 'Boss' and type(enemy.enemyDef.attackSet) == 'table' then
                    tryBossAttackSet(enemy, now)
                else
                    tryAttackNearbyPlayer(enemy, now)
                end
                continue
            end

            enemy.movementState = enemy.movementState or {
                nextDecisionAt = now + PORING_IDLE_DECISION_TIME,
                hopStartAt = nil,
                hopFrom = nil,
                hopTo = nil,
                lastLandingAt = 0,
                homeY = enemy.spawnPosition.Y,
                isAttackHop = false,
            }

            local movementState = enemy.movementState
            local rootPart = enemy.instance

            if movementState.hopStartAt and movementState.hopFrom and movementState.hopTo then
                local elapsed = now - movementState.hopStartAt
                local alpha = math.clamp(elapsed / PORING_HOP_DURATION, 0, 1)
                local horizontalPosition = movementState.hopFrom:Lerp(movementState.hopTo, alpha)
                local hopHeight = movementState.isAttackHop and PORING_ATTACK_HOP_HEIGHT or PORING_HOP_HEIGHT
                local hopOffset = math.sin(alpha * math.pi) * hopHeight
                local targetPosition = Vector3.new(horizontalPosition.X, movementState.homeY + hopOffset, horizontalPosition.Z)

                local facing = movementState.hopTo - movementState.hopFrom
                if facing.Magnitude > 0.05 then
                    -- Make poring face the nearest player instead of just the hop direction
                    local nearestPlayerRoot = getNearestPlayerRoot(rootPart.Position, PORING_AGGRO_RADIUS)
                    if nearestPlayerRoot then
                        local playerDirection = nearestPlayerRoot.Position - rootPart.Position
                        if playerDirection.Magnitude > 0.05 then
                            rootPart.CFrame = CFrame.lookAt(targetPosition, Vector3.new(targetPosition.X, targetPosition.Y, targetPosition.Z) + playerDirection.Unit)
                        else
                            rootPart.CFrame = CFrame.lookAt(targetPosition, Vector3.new(targetPosition.X, targetPosition.Y, targetPosition.Z) + facing.Unit)
                        end
                    else
                        rootPart.CFrame = CFrame.lookAt(targetPosition, Vector3.new(targetPosition.X, targetPosition.Y, targetPosition.Z) + facing.Unit)
                    end
                else
                    -- Even when not hopping, face the nearest player
                    local nearestPlayerRoot = getNearestPlayerRoot(rootPart.Position, PORING_AGGRO_RADIUS)
                    if nearestPlayerRoot then
                        local playerDirection = nearestPlayerRoot.Position - rootPart.Position
                        if playerDirection.Magnitude > 0.05 then
                            rootPart.CFrame = CFrame.lookAt(targetPosition, Vector3.new(targetPosition.X, targetPosition.Y, targetPosition.Z) + playerDirection.Unit)
                        else
                            rootPart.CFrame = CFrame.new(targetPosition)
                        end
                    else
                        rootPart.CFrame = CFrame.new(targetPosition)
                    end
                end

                if alpha >= 1 then
                    rootPart.CFrame = CFrame.new(movementState.hopTo)
                    local landedFromAttackHop = movementState.isAttackHop
                    movementState.hopStartAt = nil
                    movementState.hopFrom = nil
                    movementState.hopTo = nil
                    movementState.nextDecisionAt = now + PORING_HOP_INTERVAL
                    movementState.lastLandingAt = now

                    local bounceSound = ensurePoringBounceSound(rootPart)
                    bounceSound.TimePosition = 0
                    local randomPitch = math.random(-8, 8) / 100
                    bounceSound.PlaybackSpeed = (if landedFromAttackHop then PORING_BOUNCE_ATTACK_SPEED else PORING_BOUNCE_BASE_SPEED) + randomPitch
                    bounceSound:Play()
                    movementState.isAttackHop = false
                end
            elseif now >= (movementState.nextDecisionAt or 0) then
                local aggroRange = getPoringAggroRange(enemy)
                local attackTriggerRange = getPoringAttackTriggerRange(enemy)
                local targetPlayerRoot, distanceToPlayer = getNearestPlayerRoot(rootPart.Position, aggroRange)
                local targetPosition = nil
                local hopDistance = PORING_HOP_DISTANCE

                if targetPlayerRoot and distanceToPlayer <= attackTriggerRange and now - (movementState.lastLandingAt or 0) >= PORING_ATTACK_COOLDOWN then
                    local chaseVector = Vector3.new(
                        targetPlayerRoot.Position.X - rootPart.Position.X,
                        0,
                        targetPlayerRoot.Position.Z - rootPart.Position.Z
                    )

                    if chaseVector.Magnitude > 0.05 then
                        hopDistance = math.min(PORING_ATTACK_HOP_DISTANCE, math.max(chaseVector.Magnitude - 2.5, 0))
                        if hopDistance > 0.2 then
                            targetPosition = rootPart.Position + chaseVector.Unit * hopDistance
                            movementState.isAttackHop = true
                        end
                    end
                elseif targetPlayerRoot and distanceToPlayer <= aggroRange then
                    local chaseVector = Vector3.new(
                        targetPlayerRoot.Position.X - rootPart.Position.X,
                        0,
                        targetPlayerRoot.Position.Z - rootPart.Position.Z
                    )

                    if chaseVector.Magnitude > 0.05 then
                        hopDistance = math.min(PORING_HOP_DISTANCE, math.max(chaseVector.Magnitude - ENEMY_CHASE_STOP_DISTANCE, 0))
                        if hopDistance > 0.2 then
                            targetPosition = rootPart.Position + chaseVector.Unit * hopDistance
                            movementState.isAttackHop = false
                            movementState.nextDecisionAt = now + enemyMoveRng:NextNumber(0.16, 0.3)
                        end
                    end
                end

                if not targetPosition then
                    local offset = Vector3.new(
                        math.random(-100, 100) / 100,
                        0,
                        math.random(-100, 100) / 100
                    )

                    if offset.Magnitude < 0.1 then
                        movementState.nextDecisionAt = now + PORING_IDLE_DECISION_TIME
                        continue
                    end

                    targetPosition = rootPart.Position + (offset.Unit * PORING_HOP_DISTANCE)
                    movementState.isAttackHop = false
                end

                local flatOffsetFromSpawn = Vector3.new(
                    targetPosition.X - enemy.spawnPosition.X,
                    0,
                    targetPosition.Z - enemy.spawnPosition.Z
                )

                if flatOffsetFromSpawn.Magnitude > PORING_WANDER_RADIUS then
                    targetPosition = enemy.spawnPosition + (flatOffsetFromSpawn.Unit * PORING_WANDER_RADIUS)
                end

                targetPosition = Vector3.new(targetPosition.X, movementState.homeY, targetPosition.Z)

                movementState.hopStartAt = now
                movementState.hopFrom = Vector3.new(rootPart.Position.X, movementState.homeY, rootPart.Position.Z)
                movementState.hopTo = targetPosition
            end

            tryAttackNearbyPlayer(enemy, now)
            tryUseActiveSkills(enemy, now)
        end
    end)
end

function EnemyService.spawnEnemy(enemyTypeId: string, position: Vector3)
    local enemyDef = EnemyDefs[enemyTypeId]
    assert(enemyDef, ('Unknown enemyTypeId: %s'):format(enemyTypeId))

    local runtimeId = nextEnemyId(enemyTypeId)
    local part, visualModel = createEnemyFromMaster(runtimeId, enemyDef, position)
    local maxHealth = EnemyScaling.getScaledHealth(enemyDef.baseHealth, enemyDef.level, enemyDef.scaling)

    enemiesById[runtimeId] = {
        runtimeId = runtimeId,
        enemyTypeId = enemyTypeId,
        enemyDef = enemyDef,
        instance = part,
        visualModel = visualModel,
        spawnPosition = position,
        currentHealth = maxHealth,
        maxHealth = maxHealth,
        alive = true,
        movementState = nil,
        nextAttackAt = 0,
        fireWallChain = nil,
        skillCooldowns = {},
    }

    updateEnemyBillboard(enemiesById[runtimeId])

    return enemiesById[runtimeId]
end

function EnemyService.spawnEnemyFamily(enemyTypeId: string, positions)
    local spawned = {}
    for _, position in ipairs(positions) do
        table.insert(spawned, EnemyService.spawnEnemy(enemyTypeId, position))
    end
    return spawned
end

function EnemyService.getEnemy(runtimeId: string)
    return enemiesById[runtimeId]
end

function EnemyService.getAliveEnemies()
    local results = {}
    for _, enemy in pairs(enemiesById) do
        if enemy.alive and enemy.instance and enemy.instance.Parent then
            table.insert(results, enemy)
        end
    end
    return results
end

function EnemyService.getNearestEnemy(position: Vector3, maxDistance: number?)
    local nearest = nil
    local bestDistance = maxDistance or math.huge

    for _, enemy in ipairs(EnemyService.getAliveEnemies()) do
        local distance = (enemy.instance.Position - position).Magnitude
        if distance <= bestDistance then
            bestDistance = distance
            nearest = enemy
        end
    end

    return nearest
end

function EnemyService.damageEnemy(runtimeId: string, amount: number)
    local enemy = enemiesById[runtimeId]
    if not enemy or not enemy.alive then
        return nil
    end

    enemy.currentHealth = math.max(enemy.currentHealth - amount, 0)
    updateEnemyBillboard(enemy)
    if enemy.enemyDef.infiniteHealth then
        if enemy.currentHealth <= 0 and enemy.enemyDef.autoRefillHealth then
            task.delay(0.18, function()
                local liveEnemy = enemiesById[runtimeId]
                if liveEnemy and liveEnemy.alive then
                    liveEnemy.currentHealth = liveEnemy.maxHealth
                    updateEnemyBillboard(liveEnemy)
                end
            end)
        end
        return enemy
    end

    if enemy.currentHealth <= 0 then
        enemy.alive = false
        enemy.deathPosition = if enemy.instance then enemy.instance.Position else enemy.spawnPosition
        enemy.respawnPosition = getNearbyRespawnPosition(enemy.deathPosition, enemy.spawnPosition.Y)

        local deadVisual = enemy.visualModel or enemy.instance
        task.defer(function()
            if deadVisual and deadVisual.Parent then
                deadVisual:Destroy()
            end
            bossStaggerUntil[runtimeId] = nil
            enemiesById[runtimeId] = nil
        end)

        task.delay(ENEMY_RESPAWN_DELAY_SECONDS, function()
            EnemyService.spawnEnemy(enemy.enemyTypeId, enemy.respawnPosition or enemy.spawnPosition)
        end)
    end

    return enemy
end

function EnemyService.getState()
    local list = {}
    for _, enemy in ipairs(EnemyService.getAliveEnemies()) do
        table.insert(list, {
            runtimeId = enemy.runtimeId,
            enemyTypeId = enemy.enemyTypeId,
            name = enemy.enemyDef.name,
            currentHealth = enemy.currentHealth,
            maxHealth = enemy.maxHealth,
            position = enemy.instance.Position,
        })
    end
    return list
end

return EnemyService
