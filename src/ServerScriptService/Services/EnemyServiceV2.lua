--!strict

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local BossData = require(ReplicatedStorage.GameData.Bosses.BossData)
local EnemyData = require(ReplicatedStorage.GameData.Enemies.EnemyData)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local EnemyServiceV2 = {
    Name = 'EnemyService',
}

type SpawnPlan = {
    id: string,
    defId: string,
    isBoss: boolean,
    spawnPosition: Vector3,
    mapName: string?,
    mapFolder: Folder?,
    mapModel: Instance?,
    randomSpawnWithinMap: boolean?,
}

type AttackRuntime = {
    targetUserId: number,
    startedAt: number,
    phase: 'windup' | 'lunge' | 'recover',
    phaseStartedAt: number,
    origin: Vector3,
    strikePosition: Vector3,
    recoverPosition: Vector3,
    windupDuration: number,
    lungeDuration: number,
    recoverDuration: number,
    damageApplied: boolean,
}

type EnemyState = {
    runtimeId: string,
    plan: SpawnPlan,
    def: any,
    model: Model,
    root: BasePart,
    healthFill: Frame,
    healthLabel: TextLabel,
    maxHealth: number,
    currentHealth: number,
    homePosition: Vector3,
    nextAttackAt: number,
    nextSpecialAt: number,
    movementSeed: number,
    strafeSign: number,
    nextStrafeSwapAt: number,
    roamTarget: Vector3?,
    nextRoamDecisionAt: number,
    attackState: AttackRuntime?,
}

local dependencies = nil
local enemyFolder: Folder? = nil
local spawnPlans: { SpawnPlan } = {}
local enemyStates: { [string]: EnemyState } = {}
local running = false

local function getMovementProfile(def)
    local profile = def.movementProfile
    if type(profile) ~= 'table' then
        return {
            weaveAmplitude = 0.15,
            strafeWeight = 0.1,
            orbitWeight = 0.08,
            burstMultiplier = 1,
            roamRadius = 10,
        }
    end
    return {
        weaveAmplitude = type(profile.weaveAmplitude) == 'number' and profile.weaveAmplitude or 0.15,
        strafeWeight = type(profile.strafeWeight) == 'number' and profile.strafeWeight or 0.1,
        orbitWeight = type(profile.orbitWeight) == 'number' and profile.orbitWeight or 0.08,
        burstMultiplier = type(profile.burstMultiplier) == 'number' and profile.burstMultiplier or 1,
        roamRadius = type(profile.roamRadius) == 'number' and profile.roamRadius or 10,
    }
end

local function ensureEnemyFolder(): Folder
    local spawnedRoot = Workspace:FindFirstChild('SpawnedDuringPlay')
    if not spawnedRoot then
        spawnedRoot = Instance.new('Folder')
        spawnedRoot.Name = 'SpawnedDuringPlay'
        spawnedRoot.Parent = Workspace
    end

    local enemies = spawnedRoot:FindFirstChild('Enemies')
    if enemies and enemies:IsA('Folder') then
        return enemies
    end

    enemies = Instance.new('Folder')
    enemies.Name = 'Enemies'
    enemies.Parent = spawnedRoot
    return enemies
end

local function getDefinition(defId: string, isBoss: boolean)
    return isBoss and BossData[defId] or EnemyData[defId]
end

local function getRootHalfHeight(def): number
    return math.max(2, (def.size * 0.78) * 0.5)
end

local function choosePaletteColor(palette, fallback: Color3): Color3
    if type(palette) == 'table' and #palette > 0 then
        local picked = palette[math.random(1, #palette)]
        if typeof(picked) == 'Color3' then
            return picked
        end
    end
    return fallback
end

local function getTemplateFolder(isBoss: boolean): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    if not gameParts then
        return nil
    end
    local folder = gameParts:FindFirstChild(isBoss and 'Bosses' or 'Monsters')
    if folder and folder:IsA('Folder') then
        return folder
    end
    return nil
end

local function getLivePlayers()
    local results = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        local root = character and character:FindFirstChild('HumanoidRootPart')
        if humanoid and root and humanoid.Health > 0 then
            table.insert(results, {
                player = player,
                root = root :: BasePart,
            })
        end
    end
    return results
end

local function buildHealthGui(root: BasePart, displayName: string, isBoss: boolean)
    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'EnemyBillboard'
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = isBoss and GameConfig.BossNameplateDistance or GameConfig.EnemyNameplateDistance
    billboard.Size = UDim2.fromOffset(isBoss and 200 or 146, isBoss and 48 or 40)
    billboard.StudsOffset = Vector3.new(0, isBoss and 8 or 5, 0)
    billboard.Parent = root

    local nameLabel = Instance.new('TextLabel')
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0, 18)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = isBoss and 16 or 13
    nameLabel.TextColor3 = Color3.fromRGB(255, 245, 236)
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Text = displayName
    nameLabel.Parent = billboard

    local barBack = Instance.new('Frame')
    barBack.BackgroundColor3 = Color3.fromRGB(28, 12, 18)
    barBack.BorderSizePixel = 0
    barBack.Position = UDim2.new(0, 0, 0, 22)
    barBack.Size = UDim2.new(1, 0, 0, 14)
    barBack.Parent = billboard

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = barBack

    local fill = Instance.new('Frame')
    fill.Name = 'HealthFill'
    fill.BackgroundColor3 = isBoss and Color3.fromRGB(255, 72, 112) or Color3.fromRGB(96, 228, 142)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.fromScale(1, 1)
    fill.Parent = barBack

    local fillCorner = Instance.new('UICorner')
    fillCorner.CornerRadius = UDim.new(0, 7)
    fillCorner.Parent = fill

    return fill, nameLabel
end

local function weldToRoot(root: BasePart, child: BasePart, offset: CFrame)
    child.CFrame = root.CFrame * offset
    child.Massless = true
    child.CanCollide = false
    child.Anchored = false

    local weld = Instance.new('WeldConstraint')
    weld.Part0 = root
    weld.Part1 = child
    weld.Parent = child
end

local function prepareTemplateModel(model: Model)
    local root = model.PrimaryPart or model:FindFirstChild('Root')
    if root and root:IsA('BasePart') then
        model.PrimaryPart = root
    end

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA('BasePart') then
            descendant.Anchored = true
            descendant.Massless = true
            if descendant.Name ~= 'Root' then
                descendant.CanCollide = false
            end
        end
    end
end

local function applySpawnVariation(model: Model, def)
    local scale = 1
    local scaleRange = def.scaleRange
    if type(scaleRange) == 'table' and type(scaleRange[1]) == 'number' and type(scaleRange[2]) == 'number' then
        scale = scaleRange[1] + (scaleRange[2] - scaleRange[1]) * math.random()
    end

    if math.abs(scale - 1) > 0.001 then
        pcall(function()
            model:ScaleTo(scale)
        end)
    end

    local bodyTint = choosePaletteColor(def.tintPalette, def.color)
    local eyeTint = choosePaletteColor(def.eyePalette, Color3.fromRGB(235, 245, 255))

    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA('BasePart') then
            local nameLower = string.lower(descendant.Name)
            if nameLower:find('eye') then
                descendant.Color = eyeTint
                if descendant.Material == Enum.Material.Neon then
                    local light = descendant:FindFirstChildWhichIsA('PointLight')
                    if light then
                        light.Color = eyeTint
                    end
                end
            elseif nameLower:find('crystal') or nameLower:find('halo') then
                descendant.Color = bodyTint:Lerp(Color3.new(1, 1, 1), 0.28)
            elseif descendant.Name ~= 'Root' then
                descendant.Color = bodyTint
            end
        end
    end

    model:SetAttribute('VariantScale', scale)
    model:SetAttribute('VariantTintR', bodyTint.R)
    model:SetAttribute('VariantTintG', bodyTint.G)
    model:SetAttribute('VariantTintB', bodyTint.B)
end

local function cloneTemplateModel(def, isBoss: boolean): (Model?, BasePart?)
    local templateName = def.templateName
    if type(templateName) ~= 'string' or templateName == '' then
        return nil, nil
    end

    local folder = getTemplateFolder(isBoss)
    local template = folder and folder:FindFirstChild(templateName)
    if not template or not template:IsA('Model') then
        return nil, nil
    end

    local model = template:Clone()
    model.Name = def.displayName:gsub('%s+', '')
    prepareTemplateModel(model)
    local root = model.PrimaryPart
    if root and root:IsA('BasePart') then
        return model, root
    end
    model:Destroy()
    return nil, nil
end

local function buildEnemyModel(def, isBoss: boolean)
    local templateModel, templateRoot = cloneTemplateModel(def, isBoss)
    if templateModel and templateRoot then
        applySpawnVariation(templateModel, def)
        local healthFill, healthLabel = buildHealthGui(templateRoot, def.displayName, isBoss)
        return templateModel, templateRoot, healthFill, healthLabel
    end

    local model = Instance.new('Model')
    model.Name = def.displayName:gsub('%s+', '')

    local root = Instance.new('Part')
    root.Name = 'Root'
    root.Shape = Enum.PartType.Ball
    root.Size = Vector3.new(def.size, def.size * 0.78, def.size)
    root.Color = def.color
    root.Material = def.material
    root.Anchored = true
    root.CanCollide = false
    root.Parent = model

    local eyeLeft = Instance.new('Part')
    eyeLeft.Name = 'EyeLeft'
    eyeLeft.Size = Vector3.new(def.size * 0.11, def.size * 0.11, def.size * 0.11)
    eyeLeft.Shape = Enum.PartType.Ball
    eyeLeft.Material = Enum.Material.Neon
    eyeLeft.Color = Color3.fromRGB(255, 245, 245)
    eyeLeft.Parent = model
    weldToRoot(root, eyeLeft, CFrame.new(-def.size * 0.16, def.size * 0.08, -def.size * 0.28))

    local eyeRight = eyeLeft:Clone()
    eyeRight.Name = 'EyeRight'
    eyeRight.Parent = model
    weldToRoot(root, eyeRight, CFrame.new(def.size * 0.16, def.size * 0.08, -def.size * 0.28))

    local mouth = Instance.new('Part')
    mouth.Name = 'Mouth'
    mouth.Size = Vector3.new(def.size * 0.32, def.size * 0.05, def.size * 0.08)
    mouth.Material = Enum.Material.Neon
    mouth.Color = Color3.fromRGB(38, 12, 18)
    mouth.Parent = model
    weldToRoot(root, mouth, CFrame.new(0, -def.size * 0.08, -def.size * 0.32))

    if isBoss then
        local crown = Instance.new('Part')
        crown.Name = 'Crown'
        crown.Size = Vector3.new(def.size * 0.9, def.size * 0.16, def.size * 0.9)
        crown.Shape = Enum.PartType.Cylinder
        crown.Material = Enum.Material.Neon
        crown.Color = Color3.fromRGB(255, 211, 92)
        crown.Parent = model
        weldToRoot(root, crown, CFrame.new(0, def.size * 0.45, 0) * CFrame.Angles(math.rad(90), 0, 0))

        local blade = Instance.new('Part')
        blade.Name = 'RoyalBlade'
        blade.Size = Vector3.new(def.size * 0.12, def.size * 1.5, def.size * 0.32)
        blade.Material = Enum.Material.Metal
        blade.Color = Color3.fromRGB(218, 232, 255)
        blade.Parent = model
        weldToRoot(root, blade, CFrame.new(def.size * 0.7, 0, 0))

        local aura = Instance.new('PointLight')
        aura.Range = 18
        aura.Brightness = 1.6
        aura.Color = def.color
        aura.Parent = root
    end

    local healthFill, healthLabel = buildHealthGui(root, def.displayName, isBoss)
    model.PrimaryPart = root
    return model, root, healthFill, healthLabel
end

local function updateHealthVisual(state: EnemyState)
    local ratio = math.clamp(state.currentHealth / state.maxHealth, 0, 1)
    state.healthFill.Size = UDim2.fromScale(ratio, 1)
    state.healthLabel.Text = string.format('%s  %d/%d', state.def.displayName, math.max(0, math.floor(state.currentHealth)), state.maxHealth)
    state.model:SetAttribute('CurrentHP', state.currentHealth)
    state.model:SetAttribute('MaxHP', state.maxHealth)
end

local function setEnemyPosition(state: EnemyState, position: Vector3, faceTarget: Vector3?)
    local lookAt = faceTarget or (position + Vector3.new(0, 0, -1))
    state.model:PivotTo(CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z)))
end

local function resolveGroundedSpawnPosition(mapModel: Instance?, marker: BasePart, def): Vector3
    local fallback = marker.Position + Vector3.new(0, getRootHalfHeight(def) + 0.25, 0)
    if not mapModel then
        return fallback
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = { mapModel }

    local origin = marker.Position + Vector3.new(0, 36, 0)
    local result = Workspace:Raycast(origin, Vector3.new(0, -120, 0), raycastParams)
    if not result then
        return fallback
    end

    return Vector3.new(marker.Position.X, result.Position.Y + getRootHalfHeight(def) + 0.25, marker.Position.Z)
end

local function resolveGroundedPositionAt(mapModel: Instance?, probePosition: Vector3, def): Vector3
    local fallback = Vector3.new(probePosition.X, probePosition.Y, probePosition.Z)
    if not mapModel then
        return fallback
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = { mapModel }

    local origin = probePosition + Vector3.new(0, 24, 0)
    local result = Workspace:Raycast(origin, Vector3.new(0, -72, 0), raycastParams)
    if not result then
        return fallback
    end

    return Vector3.new(probePosition.X, result.Position.Y + getRootHalfHeight(def) + 0.25, probePosition.Z)
end

local function getMapBoxes(mapFolder: Folder?): { BasePart }
    local boxes = {}
    if not mapFolder then
        return boxes
    end

    for _, descendant in ipairs(mapFolder:GetDescendants()) do
        if descendant:IsA('BasePart') and descendant.Name == 'MapBox' then
            table.insert(boxes, descendant)
        end
    end

    return boxes
end

local function chooseRandomSpawnPosition(plan: SpawnPlan, def): Vector3
    if plan.randomSpawnWithinMap ~= true then
        return plan.spawnPosition
    end

    local mapFolder = plan.mapFolder
    local mapModel = plan.mapModel
    if not mapFolder or not mapModel then
        return plan.spawnPosition
    end

    local boxes = getMapBoxes(mapFolder)
    if #boxes > 0 then
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Include
        raycastParams.FilterDescendantsInstances = { mapModel }

        for _ = 1, 16 do
            local box = boxes[math.random(1, #boxes)]
            local half = box.Size * 0.5
            local x = (math.random() * 2 - 1) * math.max(1, half.X - 8)
            local z = (math.random() * 2 - 1) * math.max(1, half.Z - 8)
            local origin = box.CFrame:PointToWorldSpace(Vector3.new(x, half.Y + 24, z))
            local result = Workspace:Raycast(origin, Vector3.new(0, -(box.Size.Y + 96), 0), raycastParams)
            if result and result.Normal.Y >= 0.45 then
                return Vector3.new(origin.X, result.Position.Y + getRootHalfHeight(def) + 0.25, origin.Z)
            end
        end
    end

    return plan.spawnPosition
end

local function chooseRoamTarget(state: EnemyState): Vector3
    local profile = getMovementProfile(state.def)
    local radius = profile.roamRadius
    local angle = math.random() * math.pi * 2
    local distance = math.random() * radius
    local probe = state.homePosition + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
    return resolveGroundedPositionAt(state.plan.mapModel, probe, state.def)
end

local function fireEnemyAttackEffect(state: EnemyState, effectKind: string, targetPosition: Vector3?, phase: string?)
    dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.EnemyAttack, {
        position = state.root.Position,
        targetPosition = targetPosition,
        isBoss = state.plan.isBoss,
        attackKind = effectKind,
        phase = phase,
        color = state.def.attackColor or state.def.color,
        soundId = state.def.attackSoundId,
        soundVolume = state.def.attackSoundVolume,
        soundSpeed = state.def.attackSoundSpeed,
    })
end

local function getLivePlayerByUserId(userId: number)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == userId then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass('Humanoid')
            local root = character and character:FindFirstChild('HumanoidRootPart')
            if humanoid and humanoid.Health > 0 and root and root:IsA('BasePart') then
                return {
                    player = player,
                    root = root :: BasePart,
                }
            end
            return nil
        end
    end
    return nil
end

local function startMeleeAttack(state: EnemyState, targetEntry, now: number)
    local offset = targetEntry.root.Position - state.root.Position
    local planar = Vector3.new(offset.X, 0, offset.Z)
    if planar.Magnitude <= 0.001 then
        return
    end

    local forward = planar.Unit
    local windupDuration = state.def.attackWindup or (state.plan.isBoss and 0.28 or 0.2)
    local lungeDuration = state.def.attackLungeDuration or (state.plan.isBoss and 0.24 or 0.18)
    local recoverDuration = state.def.attackRecoverDuration or (state.plan.isBoss and 0.32 or 0.24)
    local lungeDistance = math.max(2.6, math.min(planar.Magnitude + 1.2, state.def.attackRange + 3.6))

    local strikeProbe = state.root.Position + forward * lungeDistance
    local strikePosition = resolveGroundedPositionAt(state.plan.mapModel, strikeProbe, state.def)
    local recoverProbe = strikePosition - forward * math.max(1, state.def.attackRange * 0.2)
    local recoverPosition = resolveGroundedPositionAt(state.plan.mapModel, recoverProbe, state.def)

    state.attackState = {
        targetUserId = targetEntry.player.UserId,
        startedAt = now,
        phase = 'windup',
        phaseStartedAt = now,
        origin = state.root.Position,
        strikePosition = strikePosition,
        recoverPosition = recoverPosition,
        windupDuration = windupDuration,
        lungeDuration = lungeDuration,
        recoverDuration = recoverDuration,
        damageApplied = false,
    }

    fireEnemyAttackEffect(state, state.def.attackEffect or (state.plan.isBoss and 'BossBite' or 'EnemyBite'), targetEntry.root.Position, 'windup')
    state.nextAttackAt = now + windupDuration + lungeDuration + recoverDuration + (state.def.attackCooldown * 0.7)
end

local function stepActiveAttack(state: EnemyState, now: number): boolean
    local attackState = state.attackState
    if not attackState then
        return false
    end

    local target = getLivePlayerByUserId(attackState.targetUserId)
    local targetPosition = target and target.root.Position or attackState.strikePosition
    local offset = targetPosition - state.root.Position
    local planar = Vector3.new(offset.X, 0, offset.Z)
    local originToStrike = attackState.strikePosition - attackState.origin
    local originPlanar = Vector3.new(originToStrike.X, 0, originToStrike.Z)
    local forward = if planar.Magnitude > 0.001 then planar.Unit else if originPlanar.Magnitude > 0.001 then originPlanar.Unit else Vector3.new(0, 0, -1)
    if forward.Magnitude <= 0.001 then
        forward = Vector3.new(0, 0, -1)
    end

    if attackState.phase == 'windup' then
        local alpha = math.clamp((now - attackState.phaseStartedAt) / math.max(attackState.windupDuration, 0.01), 0, 1)
        local backstep = math.sin(alpha * math.pi * 0.5) * math.max(0.7, state.def.attackRange * 0.14)
        local rise = math.sin(alpha * math.pi) * (state.plan.isBoss and 1 or 0.6)
        local position = attackState.origin - forward * backstep + Vector3.new(0, rise, 0)
        setEnemyPosition(state, position, targetPosition)

        if alpha >= 1 then
            attackState.phase = 'lunge'
            attackState.phaseStartedAt = now
            fireEnemyAttackEffect(state, state.def.attackEffect or (state.plan.isBoss and 'BossBite' or 'EnemyBite'), targetPosition, 'strike')
        end
        return true
    end

    if attackState.phase == 'lunge' then
        local alpha = math.clamp((now - attackState.phaseStartedAt) / math.max(attackState.lungeDuration, 0.01), 0, 1)
        local launch = attackState.origin:Lerp(attackState.strikePosition, alpha)
        local arc = math.sin(alpha * math.pi) * (state.plan.isBoss and 1.3 or 0.8)
        local position = launch + Vector3.new(0, arc, 0)
        setEnemyPosition(state, position, targetPosition)

        local impactRange = state.def.attackRange + (state.plan.isBoss and 2.8 or 1.8)
        if not attackState.damageApplied and target and (target.root.Position - position).Magnitude <= impactRange then
            dependencies.CharacterService.damagePlayer(target.player, state.def.damage)
            attackState.damageApplied = true
        end

        if alpha >= 1 then
            attackState.phase = 'recover'
            attackState.phaseStartedAt = now
            if not attackState.damageApplied and target then
                dependencies.CharacterService.damagePlayer(target.player, state.def.damage)
                attackState.damageApplied = true
            end
        end
        return true
    end

    local recoverAlpha = math.clamp((now - attackState.phaseStartedAt) / math.max(attackState.recoverDuration, 0.01), 0, 1)
    local settle = attackState.strikePosition:Lerp(attackState.recoverPosition, recoverAlpha)
    setEnemyPosition(state, settle, targetPosition)
    if recoverAlpha >= 1 then
        state.attackState = nil
    end
    return true
end

local function damagePlayerIfClose(playerEntry, position: Vector3, radius: number, amount: number)
    if (playerEntry.root.Position - position).Magnitude <= radius then
        dependencies.CharacterService.damagePlayer(playerEntry.player, amount)
        return true
    end
    return false
end

local function performSpecialAttack(state: EnemyState, closest, distance: number): boolean
    local style = state.def.attackStyle
    if type(style) ~= 'string' or style == '' then
        return false
    end

    local specialRange = state.def.specialRange or state.def.attackRange
    if distance > specialRange then
        return false
    end

    local targetPosition = closest.root.Position
    local offset = targetPosition - state.root.Position
    local planar = Vector3.new(offset.X, 0, offset.Z)
    if planar.Magnitude <= 0.001 then
        return false
    end

    local specialDamage = state.def.specialDamage or state.def.damage
    local now = os.clock()

    if style == 'pounce' then
        local landing = targetPosition - planar.Unit * math.max(3.5, state.def.attackRange * 0.55)
        local finalPosition = resolveGroundedPositionAt(state.plan.mapModel, landing, state.def)
        setEnemyPosition(state, finalPosition, targetPosition)
        fireEnemyAttackEffect(state, state.def.attackEffect or 'FrostPounce', targetPosition)
        damagePlayerIfClose(closest, finalPosition, state.def.attackRange + 3, specialDamage)
    elseif style == 'bolt' then
        fireEnemyAttackEffect(state, state.def.attackEffect or 'PetalBolt', targetPosition)
        dependencies.CharacterService.damagePlayer(closest.player, specialDamage)
    elseif style == 'charge' then
        local travel = math.min(planar.Magnitude, math.max(10, state.def.specialRange * 0.75))
        local chargePosition = state.root.Position + planar.Unit * travel
        local finalPosition = resolveGroundedPositionAt(state.plan.mapModel, chargePosition, state.def)
        setEnemyPosition(state, finalPosition, targetPosition)
        fireEnemyAttackEffect(state, state.def.attackEffect or 'ShardCharge', targetPosition)
        damagePlayerIfClose(closest, finalPosition, state.def.attackRange + 4, specialDamage)
    else
        return false
    end

    state.nextSpecialAt = now + (state.def.specialCooldown or 4)
    state.nextAttackAt = now + math.max(0.55, state.def.attackCooldown * 0.75)
    return true
end

local function spawnFromPlan(plan: SpawnPlan)
    if not enemyFolder then
        enemyFolder = ensureEnemyFolder()
    end

    local def = getDefinition(plan.defId, plan.isBoss)
    if not def then
        return
    end

    local model, root, healthFill, healthLabel = buildEnemyModel(def, plan.isBoss)
    local runtimeId = plan.id
    model:SetAttribute('EnemyRuntimeId', runtimeId)
    model:SetAttribute('DisplayName', def.displayName)
    model:SetAttribute('IsBoss', plan.isBoss)
    model.Parent = enemyFolder

    local state: EnemyState = {
        runtimeId = runtimeId,
        plan = plan,
        def = def,
        model = model,
        root = root,
        healthFill = healthFill,
        healthLabel = healthLabel,
        maxHealth = def.maxHealth,
        currentHealth = def.maxHealth,
        homePosition = chooseRandomSpawnPosition(plan, def),
        nextAttackAt = 0,
        nextSpecialAt = os.clock() + (def.slamCooldown or def.specialCooldown or 99),
        movementSeed = math.random(),
        strafeSign = math.random(0, 1) == 0 and -1 or 1,
        nextStrafeSwapAt = os.clock() + 0.8 + math.random() * 1.2,
        roamTarget = nil,
        nextRoamDecisionAt = os.clock() + 0.8 + math.random() * 1.2,
        attackState = nil,
    }

    enemyStates[runtimeId] = state
    updateHealthVisual(state)
    setEnemyPosition(state, state.homePosition)
end

local function buildSpawnPlans()
    local plans = {}
    local mapsFolder = Workspace:FindFirstChild('Maps')
    if not mapsFolder then
        return plans
    end

    for _, mapFolder in ipairs(mapsFolder:GetChildren()) do
        if mapFolder:IsA('Folder') then
            local mapModel = mapFolder:FindFirstChild('Map')
            local monsterFolder = mapFolder:FindFirstChild('MonsterSpawnPoints')
            if monsterFolder then
                for _, child in ipairs(monsterFolder:GetChildren()) do
                    if child:IsA('BasePart') then
                        local enemyId = child:GetAttribute('EnemyId')
                        local def = type(enemyId) == 'string' and EnemyData[enemyId] or nil
                        if type(enemyId) == 'string' and enemyId ~= '' and def then
                            table.insert(plans, {
                                id = string.format('%s_%s', mapFolder.Name, child.Name),
                                defId = enemyId,
                                isBoss = false,
                                spawnPosition = resolveGroundedSpawnPosition(mapModel, child, def),
                                mapName = mapFolder.Name,
                                mapFolder = mapFolder,
                                mapModel = mapModel,
                                randomSpawnWithinMap = child:GetAttribute('RandomSpawnWithinMap') == true or def.randomSpawnWithinMap == true,
                            })
                        end
                    end
                end
            end

            local bossFolder = mapFolder:FindFirstChild('BossSpawnPoints')
            if bossFolder then
                for _, child in ipairs(bossFolder:GetChildren()) do
                    if child:IsA('BasePart') then
                        local bossId = child:GetAttribute('BossId')
                        local def = type(bossId) == 'string' and BossData[bossId] or nil
                        if type(bossId) == 'string' and bossId ~= '' and def then
                            table.insert(plans, {
                                id = string.format('%s_%s', mapFolder.Name, child.Name),
                                defId = bossId,
                                isBoss = true,
                                spawnPosition = resolveGroundedSpawnPosition(mapModel, child, def),
                                mapName = mapFolder.Name,
                                mapFolder = mapFolder,
                                mapModel = mapModel,
                                randomSpawnWithinMap = child:GetAttribute('RandomSpawnWithinMap') == true or def.randomSpawnWithinMap == true,
                            })
                        end
                    end
                end
            end
        end
    end

    return plans
end

local function getClosestPlayerTo(position: Vector3, range: number)
    local closest = nil
    local closestDistance = range

    for _, entry in ipairs(getLivePlayers()) do
        local distance = (entry.root.Position - position).Magnitude
        if distance <= closestDistance then
            closest = entry
            closestDistance = distance
        end
    end

    return closest, closestDistance
end

local function performBossSlam(state: EnemyState)
    fireEnemyAttackEffect(state, 'BossIceSlam')
    dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.BossSlam, {
        position = state.root.Position,
        radius = state.def.slamRadius,
        color = state.def.color,
    })

    for _, entry in ipairs(getLivePlayers()) do
        local distance = (entry.root.Position - state.root.Position).Magnitude
        if distance <= state.def.slamRadius then
            dependencies.CharacterService.damagePlayer(entry.player, state.def.slamDamage)
        end
    end

    state.nextSpecialAt = os.clock() + state.def.slamCooldown
end

local function stepEnemy(state: EnemyState, deltaTime: number)
    if state.currentHealth <= 0 or not state.model.Parent then
        return
    end

    local now = os.clock()
    if state.attackState and stepActiveAttack(state, now) then
        return
    end

    local closest, distance = getClosestPlayerTo(state.root.Position, state.def.aggroRange)
    local profile = getMovementProfile(state.def)

    if closest then
        local targetPosition = closest.root.Position
        if now >= state.nextStrafeSwapAt then
            state.strafeSign *= -1
            state.nextStrafeSwapAt = now + 0.7 + math.random() * 1.35
        end
        if state.plan.isBoss and now >= state.nextSpecialAt and distance <= state.def.slamRadius then
            performBossSlam(state)
        elseif now >= state.nextSpecialAt and performSpecialAttack(state, closest, distance) then
            return
        end

        if distance > state.def.attackRange then
            local offset = targetPosition - state.root.Position
            local planar = Vector3.new(offset.X, 0, offset.Z)
            if planar.Magnitude > 0.001 then
                local forward = planar.Unit
                local right = Vector3.new(-forward.Z, 0, forward.X)
                local weave = math.sin(now * 4 + state.movementSeed * math.pi * 2) * profile.weaveAmplitude
                local orbitFactor = distance <= math.max(state.def.attackRange * 2.2, 18) and profile.orbitWeight or 0
                local strafeOffset = (profile.strafeWeight + orbitFactor) * state.strafeSign + weave
                local desired = (forward + right * strafeOffset)
                if desired.Magnitude <= 0.001 then
                    desired = forward
                else
                    desired = desired.Unit
                end
                local burstMultiplier = profile.burstMultiplier
                if distance <= math.max(state.def.attackRange * 1.6, 12) then
                    burstMultiplier += 0.06
                end
                local stepDistance = math.min(planar.Magnitude, state.def.moveSpeed * burstMultiplier * deltaTime)
                local nextProbe = state.root.Position + desired * stepDistance
                local nextPosition = resolveGroundedPositionAt(state.plan.mapModel, nextProbe, state.def)
                setEnemyPosition(state, nextPosition, targetPosition)
            end
        elseif now >= state.nextAttackAt then
            startMeleeAttack(state, closest, now)
        end
        return
    end

    if now >= state.nextRoamDecisionAt then
        state.roamTarget = chooseRoamTarget(state)
        state.nextRoamDecisionAt = now + 1.6 + math.random() * 2.4
    end

    local passiveTarget = state.roamTarget or state.homePosition
    local returnOffset = passiveTarget - state.root.Position
    local planarReturn = Vector3.new(returnOffset.X, 0, returnOffset.Z)
    if planarReturn.Magnitude > 1.5 then
        local forward = planarReturn.Unit
        local right = Vector3.new(-forward.Z, 0, forward.X)
        local weave = math.sin(now * 2.4 + state.movementSeed * math.pi * 2) * (profile.weaveAmplitude * 0.45)
        local desired = (forward + right * weave)
        if desired.Magnitude <= 0.001 then
            desired = forward
        else
            desired = desired.Unit
        end
        local stepDistance = math.min(planarReturn.Magnitude, state.def.moveSpeed * deltaTime * 0.6)
        local nextProbe = state.root.Position + desired * stepDistance
        local nextPosition = resolveGroundedPositionAt(state.plan.mapModel, nextProbe, state.def)
        setEnemyPosition(state, nextPosition, passiveTarget)
    else
        state.roamTarget = nil
    end
end

local function respawnPlanLater(plan: SpawnPlan)
    task.delay(plan.isBoss and 25 or 9, function()
        if running then
            spawnFromPlan(plan)
        end
    end)
end

function EnemyServiceV2.init(deps)
    dependencies = deps
end

function EnemyServiceV2.start()
    enemyFolder = ensureEnemyFolder()
    for _, child in ipairs(enemyFolder:GetChildren()) do
        child:Destroy()
    end

    spawnPlans = buildSpawnPlans()
    for _, plan in ipairs(spawnPlans) do
        spawnFromPlan(plan)
    end

    running = true
    task.spawn(function()
        while running do
            for _, state in pairs(enemyStates) do
                stepEnemy(state, GameConfig.EnemyTickRate)
            end
            task.wait(GameConfig.EnemyTickRate)
        end
    end)
end

function EnemyServiceV2.findEnemiesInCone(origin: Vector3, direction: Vector3, range: number, dotThreshold: number, maxTargets: number)
    local hits = {}
    for runtimeId, state in pairs(enemyStates) do
        if state.currentHealth > 0 and state.model.Parent then
            local offset = state.root.Position - origin
            local distance = offset.Magnitude
            if distance <= range and distance > 0.001 then
                local unit = offset.Unit
                if direction:Dot(unit) >= dotThreshold then
                    table.insert(hits, {
                        runtimeId = runtimeId,
                        distance = distance,
                    })
                end
            end
        end
    end

    table.sort(hits, function(a, b)
        return a.distance < b.distance
    end)

    local enemyIds = {}
    for index, hit in ipairs(hits) do
        if index > maxTargets then
            break
        end
        table.insert(enemyIds, hit.runtimeId)
    end
    return enemyIds
end

function EnemyServiceV2.damageEnemy(runtimeId: string, amount: number, attacker: Player?)
    local state = enemyStates[runtimeId]
    if not state or state.currentHealth <= 0 then
        return false
    end

    state.currentHealth = math.max(0, state.currentHealth - amount)
    updateHealthVisual(state)

    dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.EnemyHit, {
        position = state.root.Position,
        isBoss = state.plan.isBoss,
        color = state.def.attackColor or state.def.color,
        damage = amount,
    })

    if state.currentHealth > 0 then
        return true
    end

    dependencies.Runtime.EffectEvent:FireAllClients(MMONet.Effects.EnemyDeath, {
        position = state.root.Position,
        isBoss = state.plan.isBoss,
        color = state.def.deathColor or state.def.color,
    })

    if attacker then
        dependencies.PersistenceService.grantExperience(attacker, (state.def.experience or 0) + (state.def.bonusExperience or 0), 0)
    end

    dependencies.LootService.spawnDropBundle(state.root.Position, state.def.dropTableId, attacker, state.def.displayName)

    if state.plan.isBoss then
        dependencies.Runtime.SystemMessage:FireAllClients(string.format('%s was defeated.', state.def.displayName))
    end

    local plan = state.plan
    enemyStates[runtimeId] = nil
    state.model:Destroy()
    respawnPlanLater(plan)
    return true
end

return EnemyServiceV2
