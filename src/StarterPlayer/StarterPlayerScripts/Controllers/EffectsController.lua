--!strict

local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local EffectsController = {
    Name = 'EffectsController',
}

local dependencies = nil
local DASH_TEXTURE = 'rbxassetid://7216979807'
local ATTACK_SOUND_ID = 'rbxassetid://134072730260352'
local MARKETPLACE_TEMPLATE_FOLDER = 'MarketplaceVfx7564537285'

local function getSkinBurstPalette(templateId: string?): (Color3, Color3)
    if templateId == 'DekuCharacterTemplate' then
        return Color3.fromRGB(78, 255, 176), Color3.fromRGB(211, 255, 243)
    end
    return Color3.fromRGB(180, 228, 255), Color3.fromRGB(244, 250, 255)
end

local function getDekuFxFolder(): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    local fxRoot = gameParts and gameParts:FindFirstChild('FX')
    local dekuFx = fxRoot and fxRoot:FindFirstChild('DekuSmash')
    if dekuFx and dekuFx:IsA('Folder') then
        return dekuFx
    end
    return nil
end

local function getMarketplaceVfxFolder(): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    local fxRoot = gameParts and gameParts:FindFirstChild('FX')
    local folder = fxRoot and fxRoot:FindFirstChild(MARKETPLACE_TEMPLATE_FOLDER)
    if folder and folder:IsA('Folder') then
        return folder
    end
    return nil
end

local function getFxParent(): Instance
    local spawnedRoot = Workspace:FindFirstChild('SpawnedDuringPlay')
    local fxFolder = spawnedRoot and spawnedRoot:FindFirstChild('FX')
    return fxFolder or Workspace
end

local function normalizeEffectClone(instance: Instance)
    if instance:IsA('BasePart') then
        instance.Anchored = true
        instance.CanCollide = false
        instance.CanTouch = false
        instance.CanQuery = false
    end

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('BasePart') then
            descendant.Anchored = true
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
        end
    end
end

local function setCloneColor(instance: Instance, color: Color3)
    if instance:IsA('BasePart') then
        instance.Color = color
        return
    end
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('BasePart') then
            descendant.Color = color
        end
    end
end

local function setCloneTransparency(instance: Instance, transparency: number)
    if instance:IsA('BasePart') then
        instance.Transparency = transparency
        return
    end
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('BasePart') then
            descendant.Transparency = transparency
        end
    end
end

local function placeClone(instance: Instance, cframe: CFrame)
    if instance:IsA('Model') then
        if not instance.PrimaryPart then
            local firstPart = instance:FindFirstChildWhichIsA('BasePart', true)
            if firstPart then
                instance.PrimaryPart = firstPart
            end
        end
        if instance.PrimaryPart then
            instance:PivotTo(cframe)
        end
        return
    end

    if instance:IsA('BasePart') then
        instance.CFrame = cframe
    end
end

local function cloneMarketplaceTemplate(templateName: string): Instance?
    local folder = getMarketplaceVfxFolder()
    local template = folder and folder:FindFirstChild(templateName)
    if not template then
        return nil
    end

    local clone = template:Clone()
    normalizeEffectClone(clone)
    clone.Parent = getFxParent()
    return clone
end

local function playWorldSound(soundId: string, position: Vector3, volume: number, playbackSpeed: number, lifetime: number)
    local anchor = Instance.new('Part')
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.5, 0.5, 0.5)
    anchor.CFrame = CFrame.new(position)
    anchor.Parent = getFxParent()

    local sound = Instance.new('Sound')
    sound.SoundId = soundId
    sound.Volume = volume
    sound.RollOffMaxDistance = 120
    sound.RollOffMinDistance = 12
    sound.PlaybackSpeed = playbackSpeed
    sound.Parent = anchor
    sound:Play()

    Debris:AddItem(anchor, lifetime)
end

local function getCharacterRootFromPayload(payload): BasePart?
    if type(payload) ~= 'table' then
        return nil
    end

    local userId = payload.userId
    if type(userId) ~= 'number' then
        return nil
    end

    local player = game:GetService('Players'):GetPlayerByUserId(userId)
    local character = player and player.Character
    local root = character and character:FindFirstChild('HumanoidRootPart')
    if root and root:IsA('BasePart') then
        return root
    end
    return nil
end

local function playAttackSound(payload)
    local root = getCharacterRootFromPayload(payload)
    if not root then
        return
    end

    local sound = Instance.new('Sound')
    sound.Name = 'AttackSwingOneShot'
    sound.SoundId = ATTACK_SOUND_ID
    sound.Volume = 0.72
    sound.RollOffMaxDistance = 110
    sound.RollOffMinDistance = 10
    sound.PlaybackSpeed = 1
    sound.Parent = root
    sound:Play()
    Debris:AddItem(sound, 4)
end

local function playSkinBurstEffect(payload)
    local root = getCharacterRootFromPayload(payload)
    if not root then
        return
    end

    local templateId = if type(payload) == 'table' and type(payload.templateId) == 'string' then payload.templateId else nil
    local primaryColor, secondaryColor = getSkinBurstPalette(templateId)
    local origin = root.Position

    local core = makeEffectPart(
        secondaryColor,
        Vector3.new(2.8, 2.8, 2.8),
        CFrame.new(origin + Vector3.new(0, 3.2, 0)),
        Enum.PartType.Ball,
        0.14
    )
    tweenAndCleanup(core, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(7.5, 7.5, 7.5),
        Transparency = 1,
    })

    local ring = makeEffectPart(
        primaryColor,
        Vector3.new(0.28, 8, 8),
        CFrame.new(origin + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.rad(90), 0, 0),
        Enum.PartType.Cylinder,
        0.1
    )
    tweenAndCleanup(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.28, 18, 18),
        Transparency = 1,
    })

    local column = makeEffectPart(
        primaryColor,
        Vector3.new(1.6, 6.2, 1.6),
        CFrame.new(origin + Vector3.new(0, 3.1, 0)),
        nil,
        0.3
    )
    tweenAndCleanup(column, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.4, 10.5, 0.4),
        Transparency = 1,
    })

    local burstAnchor = makeEffectPart(
        secondaryColor,
        Vector3.new(0.4, 0.4, 0.4),
        CFrame.new(origin + Vector3.new(0, 2.8, 0)),
        Enum.PartType.Ball,
        1
    )

    makeDashEmitter(
        burstAnchor,
        42,
        68,
        Vector2.new(30, 30),
        5,
        0.16,
        0.28,
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.7),
            NumberSequenceKeypoint.new(0.55, 0.36),
            NumberSequenceKeypoint.new(1, 0),
        }),
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.04),
            NumberSequenceKeypoint.new(0.75, 0.25),
            NumberSequenceKeypoint.new(1, 1),
        }),
        28,
        ColorSequence.new(primaryColor, secondaryColor),
        2.5
    )

    playWorldSound(ATTACK_SOUND_ID, origin, 0.45, 1.28, 1.2)
    Debris:AddItem(burstAnchor, 0.5)
end

local function tweenAndCleanup(instance: Instance, tweenInfo: TweenInfo, goal)
    local tween = TweenService:Create(instance, tweenInfo, goal)
    tween:Play()
    Debris:AddItem(instance, tweenInfo.Time + 0.1)
end

local function makeEffectPart(color: Color3, size: Vector3, cframe: CFrame, shape: Enum.PartType?, transparency: number)
    local part = Instance.new('Part')
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Size = size
    part.CFrame = cframe
    part.Transparency = transparency
    if shape then
        part.Shape = shape
    end
    part.Parent = getFxParent()
    return part
end

local function makeDashEmitter(parent: Instance, speedMin: number, speedMax: number, spread: Vector2, drag: number, lifetimeMin: number, lifetimeMax: number, sizeSequence: NumberSequence, transparencySequence: NumberSequence, emission: number, color: ColorSequence, brightness: number)
    local emitter = Instance.new('ParticleEmitter')
    emitter.Texture = DASH_TEXTURE
    emitter.Color = color
    emitter.LightEmission = 1
    emitter.Brightness = brightness
    emitter.Lifetime = NumberRange.new(lifetimeMin, lifetimeMax)
    emitter.Speed = NumberRange.new(speedMin, speedMax)
    emitter.SpreadAngle = spread
    emitter.Drag = drag
    emitter.Rate = 0
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-220, 220)
    emitter.Size = sizeSequence
    emitter.Transparency = transparencySequence
    emitter.Parent = parent
    emitter:Emit(emission)
    Debris:AddItem(emitter, lifetimeMax + 0.2)
    return emitter
end

local function playDashEffect(payload)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    local distance = payload.distance or 16
    local lookDirection = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)
    local midPoint = origin + lookDirection * (distance * 0.35)

    local core = makeEffectPart(
        Color3.fromRGB(180, 245, 255),
        Vector3.new(1.3, 1.3, math.max(6, distance * 0.55)),
        CFrame.lookAt(midPoint, midPoint + lookDirection),
        nil,
        0.18
    )
    tweenAndCleanup(core, TweenInfo.new(0.16), {
        Size = Vector3.new(0.25, 0.25, math.max(10, distance * 1.1)),
        Transparency = 1,
    })

    local burstAnchor = makeEffectPart(
        Color3.fromRGB(255, 255, 255),
        Vector3.new(0.4, 0.4, 0.4),
        CFrame.lookAt(origin, origin + lookDirection),
        Enum.PartType.Ball,
        1
    )

    makeDashEmitter(
        burstAnchor,
        110,
        165,
        Vector2.new(16, 16),
        12,
        0.08,
        0.12,
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.9),
            NumberSequenceKeypoint.new(0.35, 0.55),
            NumberSequenceKeypoint.new(1, 0),
        }),
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.02),
            NumberSequenceKeypoint.new(0.7, 0.18),
            NumberSequenceKeypoint.new(1, 1),
        }),
        20,
        ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(134, 238, 255)),
        3
    )

    makeDashEmitter(
        burstAnchor,
        70,
        115,
        Vector2.new(36, 36),
        8,
        0.12,
        0.18,
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.2),
            NumberSequenceKeypoint.new(0.4, 0.7),
            NumberSequenceKeypoint.new(1, 0),
        }),
        NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 1),
        }),
        12,
        ColorSequence.new(Color3.fromRGB(124, 227, 255), Color3.fromRGB(255, 255, 255)),
        2
    )

    Debris:AddItem(burstAnchor, 0.35)
end

local function playSlashEffect(payload, color: Color3, width: number)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    local range = payload.range or 10
    local effect = makeEffectPart(
        color,
        Vector3.new(width, 0.6, range),
        CFrame.lookAt(origin + Vector3.new(0, 2, 0), origin + Vector3.new(direction.X, 2, direction.Z)) * CFrame.new(0, 0, -range * 0.5),
        nil,
        0.22
    )
    tweenAndCleanup(effect, TweenInfo.new(0.2), {
        Size = Vector3.new(width * 1.1, 0.2, range * 1.05),
        Transparency = 1,
    })
end

local function playArcFlareEffect(payload)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    local range = payload.range or 18
    local look = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)

    local clone = cloneMarketplaceTemplate('ArcFlare')
    if clone then
        setCloneColor(clone, Color3.fromRGB(119, 236, 255))
        setCloneTransparency(clone, 0.15)
        placeClone(clone, CFrame.lookAt(origin + Vector3.new(0, 2.6, 0), origin + Vector3.new(look.X, 2.6, look.Z)) * CFrame.new(0, 0, -range * 0.38))
        task.delay(0.18, function()
            if clone.Parent then
                setCloneTransparency(clone, 1)
                Debris:AddItem(clone, 0.06)
            end
        end)
    else
        playSlashEffect(payload, Color3.fromRGB(119, 236, 255), payload.width or 9)
    end
end

local function playNovaStrikeEffect(payload)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    local range = payload.range or 24
    local look = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)

    local clone = cloneMarketplaceTemplate('NovaStrike')
    if clone then
        setCloneColor(clone, Color3.fromRGB(166, 204, 255))
        setCloneTransparency(clone, 0.1)
        placeClone(clone, CFrame.lookAt(origin + Vector3.new(0, 2.2, 0), origin + Vector3.new(look.X, 2.2, look.Z)) * CFrame.new(0, 0, -range * 0.48))
        task.delay(0.2, function()
            if clone.Parent then
                setCloneTransparency(clone, 1)
                Debris:AddItem(clone, 0.06)
            end
        end)
    else
        playSlashEffect(payload, Color3.fromRGB(166, 204, 255), payload.width or 5)
    end
end

local function playVortexSpinEffect(payload)
    local origin = payload.origin or Vector3.zero
    local clone = cloneMarketplaceTemplate('VortexSpin')
    if clone then
        setCloneColor(clone, Color3.fromRGB(194, 132, 255))
        setCloneTransparency(clone, 0.22)
        placeClone(clone, CFrame.new(origin + Vector3.new(0, 2.2, 0)))
        task.delay(0.26, function()
            if clone.Parent then
                setCloneTransparency(clone, 1)
                Debris:AddItem(clone, 0.08)
            end
        end)
    else
        playSlashEffect(payload, Color3.fromRGB(194, 132, 255), payload.width or 12)
    end
end

local function playCometDropEffect(payload)
    local origin = payload.origin or Vector3.zero
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local look = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)

    local clone = cloneMarketplaceTemplate('CometDrop')
    if clone then
        setCloneColor(clone, Color3.fromRGB(255, 176, 118))
        setCloneTransparency(clone, 0.16)
        placeClone(clone, CFrame.lookAt(origin + Vector3.new(0, 18, 0), origin + Vector3.new(look.X, 18, look.Z)))
        task.delay(0.15, function()
            if clone.Parent then
                placeClone(clone, CFrame.lookAt(origin + Vector3.new(0, 2, 0), origin + Vector3.new(look.X, 2, look.Z)))
                setCloneTransparency(clone, 0.35)
            end
        end)
        task.delay(0.32, function()
            if clone.Parent then
                setCloneTransparency(clone, 1)
                Debris:AddItem(clone, 0.08)
            end
        end)
    else
        playSlashEffect(payload, Color3.fromRGB(255, 176, 118), payload.width or 14)
    end
end

local function playRazorOrbitEffect(payload)
    local origin = payload.origin or Vector3.zero
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local look = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)

    local clone = cloneMarketplaceTemplate('RazorOrbit')
    if clone then
        setCloneColor(clone, Color3.fromRGB(205, 246, 255))
        setCloneTransparency(clone, 0.2)
        placeClone(clone, CFrame.lookAt(origin + Vector3.new(0, 2.3, 0), origin + Vector3.new(look.X, 2.3, look.Z)))
        task.delay(0.22, function()
            if clone.Parent then
                setCloneTransparency(clone, 1)
                Debris:AddItem(clone, 0.08)
            end
        end)
    else
        playSlashEffect(payload, Color3.fromRGB(205, 246, 255), payload.width or 10)
    end
end

local function playEnemyAttackEffect(payload)
    local position = payload.position or Vector3.zero
    local targetPosition = payload.targetPosition or position
    local color = payload.color or Color3.fromRGB(220, 245, 255)
    local attackKind = payload.attackKind or 'EnemyBite'
    local soundId = payload.soundId or ATTACK_SOUND_ID
    local soundVolume = payload.soundVolume or 0.5
    local soundSpeed = payload.soundSpeed or 1
    local direction = targetPosition - position
    local planar = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)
    local rootCFrame = CFrame.lookAt(position, position + planar)

    if attackKind == 'FrostPounce' then
        local streak = makeEffectPart(color, Vector3.new(2.4, 1.2, 12), rootCFrame * CFrame.new(0, 1.5, -6), nil, 0.25)
        tweenAndCleanup(streak, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.9, 0.35, 24), Transparency = 1 })
        playWorldSound(soundId, position, soundVolume, soundSpeed, 1.5)
    elseif attackKind == 'PetalBolt' then
        local orb = makeEffectPart(color, Vector3.new(2.4, 2.4, 2.4), CFrame.new(position + Vector3.new(0, 2.5, 0)), Enum.PartType.Ball, 0.12)
        tweenAndCleanup(orb, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
            CFrame = CFrame.new(targetPosition + Vector3.new(0, 2, 0)),
            Size = Vector3.new(0.65, 0.65, 0.65),
            Transparency = 1,
        })
        playWorldSound(soundId, position, soundVolume, soundSpeed, 1.5)
    elseif attackKind == 'ShardCharge' then
        local ring = makeEffectPart(color, Vector3.new(0.35, 5, 5), CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(math.rad(90), 0, 0), Enum.PartType.Cylinder, 0.18)
        tweenAndCleanup(ring, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.35, 16, 16), Transparency = 1 })
        local spear = makeEffectPart(color, Vector3.new(1.5, 1.5, 14), rootCFrame * CFrame.new(0, 1.8, -7), nil, 0.2)
        tweenAndCleanup(spear, TweenInfo.new(0.16, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { Size = Vector3.new(0.9, 0.9, 28), Transparency = 1 })
        playWorldSound(soundId, position, soundVolume, soundSpeed, 1.5)
    elseif attackKind == 'BossIceSlam' then
        local pulse = makeEffectPart(color, Vector3.new(0.4, 9, 9), CFrame.new(position + Vector3.new(0, 0.4, 0)) * CFrame.Angles(math.rad(90), 0, 0), Enum.PartType.Cylinder, 0.12)
        tweenAndCleanup(pulse, TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, 34, 34), Transparency = 1 })
        playWorldSound(soundId, position, soundVolume, soundSpeed, 2.2)
    else
        local burst = makeEffectPart(color, Vector3.new(2.2, 2.2, 2.2), CFrame.new(position + Vector3.new(0, 2, 0)), Enum.PartType.Ball, 0.18)
        tweenAndCleanup(burst, TweenInfo.new(0.16), { Size = Vector3.new(4, 4, 4), Transparency = 1 })
        playWorldSound(soundId, position, soundVolume, soundSpeed, 1.25)
    end
end

local function playEnemyHitEffect(payload)
    local part = makeEffectPart(
        payload.color or (payload.isBoss and Color3.fromRGB(255, 84, 120) or Color3.fromRGB(255, 255, 255)),
        Vector3.new(2.8, 2.8, 2.8),
        CFrame.new(payload.position or Vector3.zero),
        Enum.PartType.Ball,
        0.15
    )
    tweenAndCleanup(part, TweenInfo.new(0.16), {
        Size = Vector3.new(5.2, 5.2, 5.2),
        Transparency = 1,
    })
end

local function playEnemyDeathEffect(payload)
    local ring = makeEffectPart(
        payload.color or (payload.isBoss and Color3.fromRGB(255, 92, 128) or Color3.fromRGB(255, 208, 118)),
        Vector3.new(0.5, 4, 4),
        CFrame.new((payload.position or Vector3.zero) + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.rad(90), 0, 0),
        Enum.PartType.Cylinder,
        0.18
    )
    tweenAndCleanup(ring, TweenInfo.new(0.35), {
        Size = Vector3.new(0.5, 14, 14),
        Transparency = 1,
    })
    playWorldSound(ATTACK_SOUND_ID, payload.position or Vector3.zero, payload.isBoss and 0.75 or 0.42, payload.isBoss and 0.58 or 1.15, 1.8)
end

local function playBossSlamEffect(payload)
    local radius = payload.radius or 12
    local ring = makeEffectPart(
        payload.color or Color3.fromRGB(255, 74, 118),
        Vector3.new(0.4, radius, radius),
        CFrame.new((payload.position or Vector3.zero) + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.rad(90), 0, 0),
        Enum.PartType.Cylinder,
        0.12
    )
    tweenAndCleanup(ring, TweenInfo.new(0.4), {
        Size = Vector3.new(0.4, radius * 2.2, radius * 2.2),
        Transparency = 1,
    })
end

local function cloneFxTemplate(effectName: string): Folder?
    local dekuFx = getDekuFxFolder()
    local template = dekuFx and dekuFx:FindFirstChild(effectName)
    if template and template:IsA('Folder') then
        local clone = template:Clone()
        clone.Parent = getFxParent()
        return clone
    end
    return nil
end

local function orientClonePart(part: BasePart, rootCFrame: CFrame)
    part.Anchored = true
    part.CanCollide = false
    part.CFrame = rootCFrame * part.CFrame
end

local function playDekuSmashEffect(payload)
    local comboName = payload.comboName
    if type(comboName) ~= 'string' then
        return
    end

    playAttackSound(payload)

    local origin = payload.origin or Vector3.zero
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local planar = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)
    local rootCFrame = CFrame.lookAt(origin, origin + planar)

    if comboName == 'DetroitAnim' then
        local fx = cloneFxTemplate('DetroitSmash')
        if not fx then return end
        local mesh = fx:FindFirstChild('Mesh')
        local sueloMesh = fx:FindFirstChild('SueloMesh')
        local air = fx:FindFirstChild('Air')
        local wave = fx:FindFirstChild('Wave')
        if mesh and mesh:IsA('BasePart') then
            orientClonePart(mesh, rootCFrame * CFrame.new(0, 2, -12))
        end
        if sueloMesh and sueloMesh:IsA('BasePart') then
            orientClonePart(sueloMesh, rootCFrame * CFrame.new(0, -2, 0))
            tweenAndCleanup(sueloMesh, TweenInfo.new(1.2), { Orientation = sueloMesh.Orientation + Vector3.new(0, 3500, 0) })
        end
        if air and air:IsA('BasePart') then
            orientClonePart(air, rootCFrame * CFrame.new(0, 2, -7))
            tweenAndCleanup(air, TweenInfo.new(1.2), { Orientation = air.Orientation + Vector3.new(0, 0, 500) })
        end
        if wave and wave:IsA('BasePart') then
            orientClonePart(wave, rootCFrame * CFrame.new(0, 2, -5))
            tweenAndCleanup(wave, TweenInfo.new(0.75, Enum.EasingStyle.Linear), {
                CFrame = wave.CFrame * CFrame.new(0, 0, -75),
                Orientation = wave.Orientation + Vector3.new(0, 0, 500),
                Transparency = 1,
            })
        end
        Debris:AddItem(fx, 1.4)
    elseif comboName == 'Manchester Smash' then
        local fx = cloneFxTemplate('ManchesterSmash')
        if not fx then return end
        local tornado = fx:FindFirstChild('Tornado')
        if tornado and tornado:IsA('BasePart') then
            orientClonePart(tornado, rootCFrame * CFrame.new(0, 56, 0))
            tornado.Size = Vector3.new(179.08, 106.87, 179.489)
            tweenAndCleanup(tornado, TweenInfo.new(5, Enum.EasingStyle.Linear), {
                Orientation = tornado.Orientation + Vector3.new(0, 18200, 0),
                Transparency = 1,
            })
        end
        local hitbox = fx:FindFirstChild('Hitbox')
        if hitbox and hitbox:IsA('BasePart') then
            orientClonePart(hitbox, rootCFrame * CFrame.new(0, 2, 0))
            hitbox.Transparency = 1
            Debris:AddItem(hitbox, 0.6)
        end
        Debris:AddItem(fx, 5.2)
    elseif comboName == 'ST.LuisSmash' then
        local fx = cloneFxTemplate('StLuisSmash')
        if not fx then return end
        local newWave = fx:FindFirstChild('NewWave')
        local sueloMesh = fx:FindFirstChild('SueloMesh')
        if newWave and newWave:IsA('BasePart') then
            orientClonePart(newWave, rootCFrame * CFrame.new(0, 2, -5) * CFrame.Angles(0, math.rad(61), 0))
            tweenAndCleanup(newWave, TweenInfo.new(0.75, Enum.EasingStyle.Linear), {
                CFrame = newWave.CFrame * CFrame.new(0, 0, -25),
                Transparency = 1,
            })
        end
        if sueloMesh and sueloMesh:IsA('BasePart') then
            orientClonePart(sueloMesh, rootCFrame * CFrame.new(0, -2, 0))
            tweenAndCleanup(sueloMesh, TweenInfo.new(1.2), { Orientation = sueloMesh.Orientation + Vector3.new(0, 3500, 0) })
        end
        Debris:AddItem(fx, 1.4)
    elseif comboName == '100%DetroitSmash' then
        local fx = cloneFxTemplate('DelawereDetroitSmash')
        if not fx then return end
        local efecto = fx:FindFirstChild('Efecto')
        local aros = fx:FindFirstChild('Aros')
        local wave = fx:FindFirstChild('Wave')
        if efecto and efecto:IsA('BasePart') then
            orientClonePart(efecto, rootCFrame * CFrame.new(0, 10, -25))
        end
        if aros and aros:IsA('BasePart') then
            orientClonePart(aros, rootCFrame * CFrame.new(0, 10, -38))
            tweenAndCleanup(aros, TweenInfo.new(1.2), { Orientation = aros.Orientation + Vector3.new(0, 0, 500) })
        end
        if wave and wave:IsA('BasePart') then
            orientClonePart(wave, rootCFrame * CFrame.new(0, 10, -45))
            tweenAndCleanup(wave, TweenInfo.new(0.75, Enum.EasingStyle.Linear), {
                CFrame = wave.CFrame * CFrame.new(0, 0, -75),
                Orientation = wave.Orientation + Vector3.new(0, 0, 500),
                Transparency = 1,
            })
        end
        Debris:AddItem(fx, 1.4)
    end
end

function EffectsController.init(deps)
    dependencies = deps
end

function EffectsController.start()
    dependencies.Runtime.EffectEvent.OnClientEvent:Connect(function(effectName, payload)
        if effectName == MMONet.Effects.Dash then
            playDashEffect(payload)
        elseif effectName == MMONet.Effects.SkinBurst then
            playSkinBurstEffect(payload)
        elseif effectName == MMONet.Effects.DekuSmash then
            playDekuSmashEffect(payload)
        elseif effectName == MMONet.Effects.Slash then
            playSlashEffect(payload, Color3.fromRGB(210, 240, 255), 4)
        elseif effectName == MMONet.Effects.PowerSlash then
            playSlashEffect(payload, Color3.fromRGB(106, 228, 255), payload.width or 8)
        elseif effectName == MMONet.Effects.ArcFlare then
            playArcFlareEffect(payload)
        elseif effectName == MMONet.Effects.NovaStrike then
            playNovaStrikeEffect(payload)
        elseif effectName == MMONet.Effects.VortexSpin then
            playVortexSpinEffect(payload)
        elseif effectName == MMONet.Effects.CometDrop then
            playCometDropEffect(payload)
        elseif effectName == MMONet.Effects.RazorOrbit then
            playRazorOrbitEffect(payload)
        elseif effectName == MMONet.Effects.EnemyAttack then
            playEnemyAttackEffect(payload)
        elseif effectName == MMONet.Effects.EnemyHit then
            playEnemyHitEffect(payload)
        elseif effectName == MMONet.Effects.EnemyDeath then
            playEnemyDeathEffect(payload)
        elseif effectName == MMONet.Effects.BossSlam then
            playBossSlamEffect(payload)
        end
    end)
end

return EffectsController
