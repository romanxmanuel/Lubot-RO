--!strict

local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
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
local GLOBAL_IMPACT_SCALE = 1.35
local HIT_CAMERA_RADIUS = 36
local makeEffectPart: ((Color3, Vector3, CFrame, Enum.PartType?, number) -> Part)?
local tweenAndCleanup: ((Instance, TweenInfo, any) -> ())?
local makeDashEmitter: ((Instance, number, number, Vector2, number, number, number, NumberSequence, NumberSequence, number, ColorSequence, number) -> ParticleEmitter)?

local function getSkinBurstPalette(templateId: string?): (Color3, Color3)
    if templateId == 'DekuCharacterTemplate' then
        return Color3.fromRGB(78, 255, 176), Color3.fromRGB(211, 255, 243)
    end
    return Color3.fromRGB(180, 228, 255), Color3.fromRGB(244, 250, 255)
end

local SKILL_SOUND_PROFILE = {
    power_slash = {
        Slash1 = { id = 'http://www.roblox.com/asset/?id=12222216', volume = 0.75, speed = 1.02 },
        Recover = { id = 'http://www.roblox.com/asset/?id=12222225', volume = 0.28, speed = 1.1 },
    },
    arc_flare = {
        Slash1 = { id = 'http://www.roblox.com/asset/?id=12222095', volume = 0.62, speed = 1.08 },
        Slash2 = { id = 'http://www.roblox.com/asset/?id=12222208', volume = 0.67, speed = 1.18 },
    },
    nova_strike = {
        Dash = { id = 'http://www.roblox.com/asset/?id=12222095', volume = 0.55, speed = 1.32 },
        Slash1 = { id = 'rbxasset://sounds//paintball.wav', volume = 0.7, speed = 1.26 },
    },
    vortex_spin = {
        Slash1 = { id = 'http://www.roblox.com/asset/?id=12222095', volume = 0.6, speed = 0.95 },
        Slash2 = { id = 'rbxasset://sounds//Rubber band sling shot.wav', volume = 0.62, speed = 0.84 },
    },
    comet_drop = {
        Slash1 = { id = 'http://www.roblox.com/asset/?id=12222095', volume = 0.66, speed = 0.82 },
        Slash2 = { id = 'rbxasset://sounds/collide.wav', volume = 0.94, speed = 0.58 },
    },
    razor_orbit = {
        Slash1 = { id = 'http://www.roblox.com/asset/?id=12222225', volume = 0.54, speed = 1.16 },
        Slash2 = { id = 'http://www.roblox.com/asset/?id=12222216', volume = 0.7, speed = 1.2 },
    },
    gojo_blue_burst = {
        Windup = { id = 'http://www.roblox.com/asset/?id=12222216', volume = 0.45, speed = 0.9 },
        Slash1 = { id = 'rbxasset://sounds/electronicpingshort.wav', volume = 0.82, speed = 1.1 },
        Recover = { id = 'rbxasset://sounds/collide.wav', volume = 0.6, speed = 1.3 },
    },
    hollow_purple_burst = {
        Windup = { id = 'http://www.roblox.com/asset/?id=12222095', volume = 0.56, speed = 0.82 },
        Slash1 = { id = 'rbxasset://sounds/Rocket whoosh 01.wav', volume = 0.85, speed = 0.92 },
        Slash2 = { id = 'rbxasset://sounds/collide.wav', volume = 1, speed = 0.72 },
    },
}

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

local function forEachClonePart(instance: Instance, callback)
    if instance:IsA('BasePart') then
        callback(instance)
    end
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('BasePart') then
            callback(descendant)
        end
    end
end

local function scaleSequence(sequence: NumberSequence, factor: number): NumberSequence
    local keypoints = {}
    for _, keypoint in ipairs(sequence.Keypoints) do
        table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * factor, keypoint.Envelope))
    end
    return NumberSequence.new(keypoints)
end

local function scaleCloneVisuals(instance: Instance, factor: number)
    if math.abs(factor - 1) <= 0.001 then
        return
    end

    forEachClonePart(instance, function(part: BasePart)
        part.Size = part.Size * factor
    end)

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('ParticleEmitter') then
            descendant.Size = scaleSequence(descendant.Size, factor)
            descendant.Speed = NumberRange.new(descendant.Speed.Min * 1.1, descendant.Speed.Max * 1.15)
            descendant.Brightness = descendant.Brightness + 1
        elseif descendant:IsA('Beam') then
            descendant.Width0 = descendant.Width0 * factor
            descendant.Width1 = descendant.Width1 * factor
            descendant.Brightness = descendant.Brightness + 1
        elseif descendant:IsA('Trail') then
            descendant.WidthScale = scaleSequence(descendant.WidthScale, factor)
            descendant.Lifetime = descendant.Lifetime * 1.1
        end
    end
end

local function playCameraPunch(position: Vector3, intensity: number, duration: number)
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    local cameraDistance = (camera.CFrame.Position - position).Magnitude
    if cameraDistance > HIT_CAMERA_RADIUS then
        return
    end

    local shakeScale = intensity * (1 - (cameraDistance / HIT_CAMERA_RADIUS))
    if shakeScale <= 0 then
        return
    end

    local startCFrame = camera.CFrame
    local startedAt = os.clock()
    local connection = nil
    connection = RunService.Heartbeat:Connect(function()
        if not camera.Parent then
            if connection then
                connection:Disconnect()
            end
            return
        end

        local alpha = math.clamp((os.clock() - startedAt) / math.max(duration, 0.01), 0, 1)
        local decay = 1 - alpha
        local noise = Vector3.new(
            (math.random() * 2 - 1) * 0.17 * shakeScale * decay,
            (math.random() * 2 - 1) * 0.14 * shakeScale * decay,
            (math.random() * 2 - 1) * 0.09 * shakeScale * decay
        )
        camera.CFrame = startCFrame * CFrame.new(noise)

        if alpha >= 1 then
            camera.CFrame = startCFrame
            if connection then
                connection:Disconnect()
            end
        end
    end)
end

local function spawnPowText(position: Vector3, color: Color3, text: string, scale: number)
    local anchor = Instance.new('Part')
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.CFrame = CFrame.new(position)
    anchor.Parent = getFxParent()

    local billboard = Instance.new('BillboardGui')
    billboard.Size = UDim2.fromOffset(math.floor(100 * scale), math.floor(54 * scale))
    billboard.StudsOffset = Vector3.new(0, 1.7 + (0.45 * scale), 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = anchor

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.Arcade
    label.TextScaled = true
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(18, 23, 33)
    label.Rotation = math.random(-14, 14)
    label.Parent = billboard

    local riseTween = TweenService:Create(billboard, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        StudsOffset = billboard.StudsOffset + Vector3.new(0, 1.7, 0),
    })
    local fadeTween = TweenService:Create(label, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.08), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })
    riseTween:Play()
    fadeTween:Play()
    Debris:AddItem(anchor, 0.35)
end

local function spawnDamageNumber(position: Vector3, amount: number, color: Color3, scale: number)
    local anchor = Instance.new('Part')
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    anchor.CFrame = CFrame.new(position)
    anchor.Parent = getFxParent()

    local billboard = Instance.new('BillboardGui')
    billboard.Size = UDim2.fromOffset(math.floor(112 * scale), math.floor(56 * scale))
    billboard.StudsOffset = Vector3.new(0, 1.4 + (0.52 * scale), 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = anchor

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    label.Text = string.format('-%d', math.max(1, math.floor(amount)))
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(10, 12, 20)
    label.Rotation = math.random(-9, 9)
    label.Parent = billboard

    local riseTween = TweenService:Create(billboard, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        StudsOffset = billboard.StudsOffset + Vector3.new(0, 2.1, 0),
    })
    local fadeTween = TweenService:Create(label, TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.1), {
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })
    riseTween:Play()
    fadeTween:Play()
    Debris:AddItem(anchor, 0.6)
end

local function playImpactPunch(position: Vector3, color: Color3, intensity: number)
    local scale = GLOBAL_IMPACT_SCALE * intensity
    local createPart = makeEffectPart
    local tweenInstance = tweenAndCleanup
    if not createPart or not tweenInstance then
        return
    end

    local core = createPart(
        color:Lerp(Color3.new(1, 1, 1), 0.42),
        Vector3.new(2.2, 2.2, 2.2) * scale,
        CFrame.new(position + Vector3.new(0, 0.5, 0)),
        Enum.PartType.Ball,
        0.1
    )
    tweenInstance(core, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(6.8, 6.8, 6.8) * scale,
        Transparency = 1,
    })

    local ring = createPart(
        color,
        Vector3.new(0.28, 7.2, 7.2) * scale,
        CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(math.rad(90), 0, 0),
        Enum.PartType.Cylinder,
        0.08
    )
    tweenInstance(ring, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.28, 20, 20) * scale,
        Transparency = 1,
    })

    local powText = if math.random() < 0.52 then 'POW!' else 'HIT!'
    spawnPowText(position + Vector3.new(0, 1.2, 0), color, powText, 1 + (intensity * 0.2))
    playCameraPunch(position, 1.4 * intensity, 0.09)
end

local function emitCloneParticles(instance: Instance, burstCount: number?)
    local count = burstCount or 24
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('ParticleEmitter') then
            descendant.Enabled = true
            descendant:Emit(count)
        elseif descendant:IsA('Trail') then
            descendant.Enabled = true
        elseif descendant:IsA('Beam') then
            descendant.Enabled = true
        end
    end
end

local function fadeCloneVisuals(instance: Instance, fadeDuration: number)
    local duration = math.max(fadeDuration, 0.08)

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('ParticleEmitter') then
            descendant.Enabled = false
        elseif descendant:IsA('Trail') then
            descendant.Enabled = false
            descendant.Lifetime = descendant.Lifetime * 0.35
        elseif descendant:IsA('Beam') then
            descendant.Enabled = false
            descendant.Width0 = descendant.Width0 * 0.35
            descendant.Width1 = descendant.Width1 * 0.35
            descendant.Transparency = NumberSequence.new(1)
        end
    end

    forEachClonePart(instance, function(part: BasePart)
        local tween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 1,
        })
        tween:Play()
    end)
end

local function animateCloneMotion(clone: Instance, duration: number, updater)
    local safeDuration = math.max(duration, 0.05)
    local startedAt = os.clock()
    local connection = nil

    connection = RunService.Heartbeat:Connect(function()
        if not clone.Parent then
            if connection then
                connection:Disconnect()
            end
            return
        end

        local alpha = math.clamp((os.clock() - startedAt) / safeDuration, 0, 1)
        updater(alpha)
        if alpha >= 1 then
            if connection then
                connection:Disconnect()
            end
        end
    end)

    Debris:AddItem(clone, safeDuration + 0.45)
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

local function resolveSkillSound(payload)
    local skillId = if type(payload) == 'table' and type(payload.skillId) == 'string' then payload.skillId else nil
    if not skillId then
        return nil
    end

    local marker = if type(payload.marker) == 'string' then payload.marker else 'Slash1'
    local profile = SKILL_SOUND_PROFILE[skillId]
    if not profile then
        return nil
    end

    return profile[marker] or profile.Slash1
end

local function playSkillBite(payload, fallbackPosition: Vector3)
    local soundDef = resolveSkillSound(payload)
    if not soundDef then
        return
    end

    local position = if type(payload) == 'table' and typeof(payload.origin) == 'Vector3' then payload.origin else fallbackPosition
    playWorldSound(soundDef.id, position, soundDef.volume or 0.6, soundDef.speed or 1, 1.8)
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

function tweenAndCleanup(instance: Instance, tweenInfo: TweenInfo, goal)
    local tween = TweenService:Create(instance, tweenInfo, goal)
    tween:Play()
    Debris:AddItem(instance, tweenInfo.Time + 0.1)
end

function makeEffectPart(color: Color3, size: Vector3, cframe: CFrame, shape: Enum.PartType?, transparency: number)
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

function makeDashEmitter(parent: Instance, speedMin: number, speedMax: number, spread: Vector2, drag: number, lifetimeMin: number, lifetimeMax: number, sizeSequence: NumberSequence, transparencySequence: NumberSequence, emission: number, color: ColorSequence, brightness: number)
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
    playSkillBite(payload, origin)
    local look = Vector3.new(direction.X, 0, direction.Z)
    if look.Magnitude <= 0.001 then
        look = Vector3.new(0, 0, -1)
    else
        look = look.Unit
    end
    local effect = makeEffectPart(
        color,
        Vector3.new(width * GLOBAL_IMPACT_SCALE, 0.7, range * 1.08),
        CFrame.lookAt(origin + Vector3.new(0, 2, 0), origin + Vector3.new(direction.X, 2, direction.Z)) * CFrame.new(0, 0, -range * 0.5),
        nil,
        0.15
    )
    tweenAndCleanup(effect, TweenInfo.new(0.2), {
        Size = Vector3.new(width * 1.85, 0.2, range * 1.25),
        Transparency = 1,
    })

    task.delay(0.06, function()
        playImpactPunch(origin + look * (range * 0.72), color, 0.8)
    end)
end

local function getPlanarLookAndRight(direction: Vector3): (Vector3, Vector3)
    local planar = Vector3.new(direction.X, 0, direction.Z)
    local look = if planar.Magnitude > 0.001 then planar.Unit else Vector3.new(0, 0, -1)
    local right = look:Cross(Vector3.yAxis)
    if right.Magnitude <= 0.001 then
        right = Vector3.new(1, 0, 0)
    else
        right = right.Unit
    end
    return look, right
end

local function playPowerSlashEffect(payload)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    playSkillBite(payload, origin)
    local vfx = payload.vfx or {}
    local duration = tonumber(vfx.duration) or 0.26
    local range = tonumber(vfx.range) or payload.range or 18
    local side = tonumber(vfx.side) or 1
    local arc = tonumber(vfx.arc) or 3.6
    local spin = tonumber(vfx.spin) or 1.1
    local look, right = getPlanarLookAndRight(direction)

    local clone = cloneMarketplaceTemplate('PowerSlash')
    if not clone then
        playSlashEffect(payload, Color3.fromRGB(106, 228, 255), payload.width or 8)
        return
    end

    setCloneTransparency(clone, 0.08)
    scaleCloneVisuals(clone, 1.35)
    emitCloneParticles(clone, 44)

    local baseHeight = 2.3
    animateCloneMotion(clone, duration, function(alpha)
        local wave = math.sin(alpha * math.pi)
        local forward = look * (range * alpha)
        local lateral = right * (wave * arc * side)
        local vertical = Vector3.new(0, wave * 0.45, 0)
        local position = origin + Vector3.new(0, baseHeight, 0) + forward + lateral + vertical
        local rotation = CFrame.Angles(0, math.rad(540 * alpha * spin), math.rad((1 - alpha) * 18 * side))
        placeClone(clone, CFrame.lookAt(position, position + look) * rotation)
        setCloneTransparency(clone, 0.06 + alpha * 0.9)
    end)

    task.delay(duration * 0.82, function()
        playImpactPunch(origin + look * (range * 0.82), Color3.fromRGB(106, 228, 255), 1.2)
    end)
end

local function playArcFlareEffect(payload)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    playSkillBite(payload, origin)
    local vfx = payload.vfx or {}
    local duration = tonumber(vfx.duration) or 0.28
    local range = tonumber(vfx.range) or payload.range or 18
    local side = tonumber(vfx.side) or 1
    local arc = tonumber(vfx.arc) or 4.2
    local spin = tonumber(vfx.spin) or 1.2
    local look, right = getPlanarLookAndRight(direction)

    local clone = cloneMarketplaceTemplate('ArcFlare')
    if not clone then
        playSlashEffect(payload, Color3.fromRGB(119, 236, 255), payload.width or 9)
        return
    end

    setCloneColor(clone, Color3.fromRGB(119, 236, 255))
    setCloneTransparency(clone, 0.1)
    scaleCloneVisuals(clone, 1.28)
    emitCloneParticles(clone, 32)

    local baseHeight = 2.4
    animateCloneMotion(clone, duration, function(alpha)
        local wave = math.sin(alpha * math.pi)
        local forward = look * (range * alpha)
        local lateral = right * (wave * arc * side)
        local vertical = Vector3.new(0, wave * 0.55, 0)
        local position = origin + Vector3.new(0, baseHeight, 0) + forward + lateral + vertical
        local rotation = CFrame.Angles(0, math.rad(180 * alpha * spin), math.rad((1 - alpha) * 20 * side))
        placeClone(clone, CFrame.lookAt(position, position + look) * rotation)
        setCloneTransparency(clone, 0.08 + alpha * 0.92)
    end)

    task.delay(duration * 0.85, function()
        playImpactPunch(origin + look * (range * 0.85), Color3.fromRGB(119, 236, 255), 1.05)
    end)
end

local function playNovaStrikeEffect(payload)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    playSkillBite(payload, origin)
    local vfx = payload.vfx or {}
    local range = tonumber(vfx.range) or payload.range or 24
    local duration = tonumber(vfx.duration) or 0.24
    local spin = tonumber(vfx.spin) or 2
    local look = getPlanarLookAndRight(direction)
    local startOffset = 2.8
    local travelDistance = range * 0.74

    local clone = cloneMarketplaceTemplate('NovaStrike')
    if not clone then
        playSlashEffect(payload, Color3.fromRGB(166, 204, 255), payload.width or 5)
        return
    end

    setCloneTransparency(clone, 0.05)
    scaleCloneVisuals(clone, 0.62)
    emitCloneParticles(clone, 28)

    animateCloneMotion(clone, duration, function(alpha)
        local eased = alpha * alpha * (3 - 2 * alpha)
        local position = origin + Vector3.new(0, 1.95, 0) + look * (startOffset + (travelDistance * eased))
        placeClone(clone, CFrame.lookAt(position, position + look) * CFrame.Angles(0, math.rad(560 * alpha * spin), 0))
        setCloneTransparency(clone, 0.08 + math.max(alpha - 0.62, 0) * 1.65)
    end)

    task.delay(duration * 0.86, function()
        if clone.Parent then
            fadeCloneVisuals(clone, 0.16)
        end
    end)

    task.delay(duration * 0.9, function()
        local hitPosition = origin + Vector3.new(0, 1.95, 0) + look * (startOffset + travelDistance)
        local burst = makeEffectPart(
            Color3.fromRGB(190, 222, 255),
            Vector3.new(2.2, 2.2, 2.2),
            CFrame.new(hitPosition),
            Enum.PartType.Ball,
            0.12
        )
        tweenAndCleanup(burst, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(6.4, 6.4, 6.4),
            Transparency = 1,
        })
        playImpactPunch(hitPosition, Color3.fromRGB(166, 204, 255), 1.15)
    end)
end

local function playGojoBlueBurstEffect(payload)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    playSkillBite(payload, origin)
    local vfx = payload.vfx or {}
    local range = tonumber(vfx.range) or payload.range or 30
    local duration = tonumber(vfx.duration) or 0.28
    local spin = tonumber(vfx.spin) or 1.7
    local look = getPlanarLookAndRight(direction)
    local startOffset = 2.2
    local travelDistance = range * 0.78

    local clone = cloneMarketplaceTemplate('GojoBlueBurst')
    if not clone then
        playSlashEffect(payload, Color3.fromRGB(112, 198, 255), payload.width or 6)
        return
    end

    setCloneColor(clone, Color3.fromRGB(112, 198, 255))
    setCloneTransparency(clone, 0.06)
    scaleCloneVisuals(clone, 0.82)
    emitCloneParticles(clone, 38)

    animateCloneMotion(clone, duration, function(alpha)
        local eased = alpha * alpha * (3 - 2 * alpha)
        local position = origin + Vector3.new(0, 2.1, 0) + look * (startOffset + (travelDistance * eased))
        placeClone(clone, CFrame.lookAt(position, position + look) * CFrame.Angles(0, math.rad(520 * alpha * spin), 0))
        setCloneTransparency(clone, 0.08 + math.max(alpha - 0.62, 0) * 1.7)
    end)

    task.delay(duration * 0.88, function()
        local hitPosition = origin + Vector3.new(0, 2.1, 0) + look * (startOffset + travelDistance)
        local burst = makeEffectPart(
            Color3.fromRGB(140, 215, 255),
            Vector3.new(2.6, 2.6, 2.6),
            CFrame.new(hitPosition),
            Enum.PartType.Ball,
            0.1
        )
        tweenAndCleanup(burst, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(7.5, 7.5, 7.5),
            Transparency = 1,
        })
        playImpactPunch(hitPosition, Color3.fromRGB(112, 198, 255), 1.25)
    end)
end

local function playHollowPurpleBurstEffect(payload)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local origin = payload.origin or Vector3.zero
    playSkillBite(payload, origin)
    local vfx = payload.vfx or {}
    local range = tonumber(vfx.range) or payload.range or 34
    local duration = tonumber(vfx.duration) or 0.34
    local spin = tonumber(vfx.spin) or 1.45
    local look = getPlanarLookAndRight(direction)
    local startOffset = 2.4
    local travelDistance = range * 0.76

    local clone = cloneMarketplaceTemplate('HollowPurpleBurst')
    if not clone then
        playSlashEffect(payload, Color3.fromRGB(198, 132, 255), payload.width or 10)
        return
    end

    setCloneColor(clone, Color3.fromRGB(198, 132, 255))
    setCloneTransparency(clone, 0.08)
    scaleCloneVisuals(clone, 1.1)
    emitCloneParticles(clone, 52)

    animateCloneMotion(clone, duration, function(alpha)
        local eased = alpha * alpha * (3 - 2 * alpha)
        local position = origin + Vector3.new(0, 2.3, 0) + look * (startOffset + (travelDistance * eased))
        placeClone(clone, CFrame.lookAt(position, position + look) * CFrame.Angles(0, math.rad(420 * alpha * spin), 0))
        setCloneTransparency(clone, 0.08 + math.max(alpha - 0.52, 0) * 1.5)
    end)

    task.delay(duration * 0.9, function()
        local hitPosition = origin + Vector3.new(0, 2.1, 0) + look * (startOffset + travelDistance)
        local ring = makeEffectPart(
            Color3.fromRGB(215, 166, 255),
            Vector3.new(0.35, 10.5, 10.5),
            CFrame.new(hitPosition + Vector3.new(0, 0.25, 0)) * CFrame.Angles(math.rad(90), 0, 0),
            Enum.PartType.Cylinder,
            0.1
        )
        tweenAndCleanup(ring, TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.35, 28, 28),
            Transparency = 1,
        })
        local burst = makeEffectPart(
            Color3.fromRGB(202, 139, 255),
            Vector3.new(3.2, 3.2, 3.2),
            CFrame.new(hitPosition),
            Enum.PartType.Ball,
            0.16
        )
        tweenAndCleanup(burst, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(9.6, 9.6, 9.6),
            Transparency = 1,
        })
        playImpactPunch(hitPosition, Color3.fromRGB(198, 132, 255), 1.45)
    end)
end

local function playVortexSpinEffect(payload)
    local origin = payload.origin or Vector3.zero
    playSkillBite(payload, origin)
    local vfx = payload.vfx or {}
    local duration = tonumber(vfx.duration) or 0.3
    local radius = tonumber(vfx.radius) or 5
    local turns = tonumber(vfx.turns) or 1.6
    local clone = cloneMarketplaceTemplate('VortexSpin')
    if not clone then
        playSlashEffect(payload, Color3.fromRGB(194, 132, 255), payload.width or 12)
        return
    end

    setCloneColor(clone, Color3.fromRGB(194, 132, 255))
    setCloneTransparency(clone, 0.15)
    scaleCloneVisuals(clone, 1.24)
    emitCloneParticles(clone, 42)

    animateCloneMotion(clone, duration, function(alpha)
        local theta = alpha * turns * math.pi * 2
        local orbitRadius = radius * (0.6 + alpha * 0.5)
        local position = origin + Vector3.new(math.cos(theta) * orbitRadius, 2 + math.sin(theta * 1.4) * 0.4, math.sin(theta) * orbitRadius)
        placeClone(clone, CFrame.lookAt(position, origin + Vector3.new(0, 2, 0)) * CFrame.Angles(0, theta * 2.1, 0))
        setCloneTransparency(clone, 0.12 + alpha * 0.86)
    end)

    task.delay(duration * 0.9, function()
        playImpactPunch(origin + Vector3.new(0, 1.6, 0), Color3.fromRGB(194, 132, 255), 1.2)
    end)
end

local function playCometDropEffect(payload)
    local origin = payload.origin or Vector3.zero
    playSkillBite(payload, origin)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local vfx = payload.vfx or {}
    local look = getPlanarLookAndRight(direction)
    local duration = tonumber(vfx.duration) or 0.24
    local dropHeight = tonumber(vfx.height) or 22
    local range = tonumber(vfx.range) or payload.range or 12

    local clone = cloneMarketplaceTemplate('CometDrop')
    if not clone then
        playSlashEffect(payload, Color3.fromRGB(255, 176, 118), payload.width or 14)
        return
    end

    setCloneColor(clone, Color3.fromRGB(255, 176, 118))
    setCloneTransparency(clone, 0.1)
    scaleCloneVisuals(clone, 1.33)
    emitCloneParticles(clone, 50)

    local impactPoint = origin + look * math.max(range * 0.2, 0)
    animateCloneMotion(clone, duration, function(alpha)
        local eased = 1 - ((1 - alpha) * (1 - alpha))
        local position = impactPoint + Vector3.new(0, dropHeight * (1 - eased) + 2.4, 0)
        placeClone(clone, CFrame.lookAt(position, impactPoint + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, math.rad(alpha * 340), 0))
        setCloneTransparency(clone, 0.08 + math.max(alpha - 0.55, 0) * 2.1)
    end)

    task.delay(duration * 0.92, function()
        local ring = makeEffectPart(
            Color3.fromRGB(255, 198, 148),
            Vector3.new(0.35, 9, 9),
            CFrame.new(impactPoint + Vector3.new(0, 0.3, 0)) * CFrame.Angles(math.rad(90), 0, 0),
            Enum.PartType.Cylinder,
            0.12
        )
        tweenAndCleanup(ring, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.35, 24, 24),
            Transparency = 1,
        })
        playImpactPunch(impactPoint, Color3.fromRGB(255, 176, 118), 1.4)
    end)
end

local function playRazorOrbitEffect(payload)
    local origin = payload.origin or Vector3.zero
    playSkillBite(payload, origin)
    local direction = payload.direction or Vector3.new(0, 0, -1)
    local vfx = payload.vfx or {}
    local duration = tonumber(vfx.duration) or 0.24
    local range = tonumber(vfx.range) or payload.range or 18
    local radius = tonumber(vfx.radius) or 4.5
    local turns = tonumber(vfx.turns) or 1.6
    local look, right = getPlanarLookAndRight(direction)

    local clone = cloneMarketplaceTemplate('RazorOrbit')
    if not clone then
        playSlashEffect(payload, Color3.fromRGB(205, 246, 255), payload.width or 10)
        return
    end

    setCloneColor(clone, Color3.fromRGB(205, 246, 255))
    setCloneTransparency(clone, 0.12)
    scaleCloneVisuals(clone, 1.25)
    emitCloneParticles(clone, 34)

    animateCloneMotion(clone, duration, function(alpha)
        local theta = alpha * turns * math.pi * 2
        local orbitScale = 1 - math.max(alpha - 0.55, 0)
        local orbitPosition = origin
            + look * (range * alpha * 0.85)
            + right * math.cos(theta) * radius * orbitScale
            + Vector3.new(0, 2.25 + math.sin(theta * 1.4) * 0.25, 0)

        placeClone(clone, CFrame.lookAt(orbitPosition, orbitPosition + look) * CFrame.Angles(0, theta * 2, math.rad(math.sin(theta) * 24)))
        setCloneTransparency(clone, 0.08 + alpha * 0.9)
    end)

    task.delay(duration * 0.9, function()
        playImpactPunch(origin + look * (range * 0.82), Color3.fromRGB(205, 246, 255), 1.08)
    end)
end

local function playEnemyAttackEffect(payload)
    local position = payload.position or Vector3.zero
    local targetPosition = payload.targetPosition or position
    local color = payload.color or Color3.fromRGB(220, 245, 255)
    local attackKind = payload.attackKind or 'EnemyBite'
    local soundId = payload.soundId or ATTACK_SOUND_ID
    local soundVolume = payload.soundVolume or 0.5
    local soundSpeed = payload.soundSpeed or 1
    local phase = tostring(payload.phase or '')
    local direction = targetPosition - position
    local planar = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)
    local rootCFrame = CFrame.lookAt(position, position + planar)

    if phase == 'windup' then
        local telegraph = makeEffectPart(
            color:Lerp(Color3.new(1, 1, 1), 0.2),
            Vector3.new(0.25, 4.4, 4.4),
            CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.rad(90), 0, 0),
            Enum.PartType.Cylinder,
            0.24
        )
        tweenAndCleanup(telegraph, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.25, 8.5, 8.5),
            Transparency = 1,
        })
        return
    end

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
        local strike = makeEffectPart(color, Vector3.new(1.6, 1.2, 8), rootCFrame * CFrame.new(0, 1.8, -4), nil, 0.14)
        tweenAndCleanup(strike, TweenInfo.new(0.14, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
            Size = Vector3.new(0.8, 0.8, 16),
            Transparency = 1,
        })
        local burst = makeEffectPart(color, Vector3.new(2.2, 2.2, 2.2), CFrame.new(targetPosition + Vector3.new(0, 2, 0)), Enum.PartType.Ball, 0.12)
        tweenAndCleanup(burst, TweenInfo.new(0.16), { Size = Vector3.new(4, 4, 4), Transparency = 1 })
        playWorldSound(soundId, position, soundVolume, soundSpeed, 1.25)
    end
end

local function playEnemyHitEffect(payload)
    local color = payload.color or (payload.isBoss and Color3.fromRGB(255, 84, 120) or Color3.fromRGB(255, 255, 255))
    local intensity = if payload.isBoss then 1.25 else 1
    local impactPosition = payload.position or Vector3.zero
    playImpactPunch(impactPosition, color, intensity)

    local damage = tonumber(payload.damage)
    if damage and damage > 0 then
        spawnDamageNumber(
            impactPosition + Vector3.new(math.random(-2, 2) * 0.15, 1.5, math.random(-2, 2) * 0.15),
            damage,
            payload.isBoss and Color3.fromRGB(255, 168, 180) or Color3.fromRGB(255, 246, 198),
            payload.isBoss and 1.12 or 1
        )
    end
end

local function playPlayerHitEffect(payload)
    local position = payload.position or Vector3.zero
    local damage = tonumber(payload.damage) or 1
    local color = Color3.fromRGB(255, 96, 122)
    playImpactPunch(position, color, 0.9)
    spawnDamageNumber(position + Vector3.new(0, 0.5, 0), damage, Color3.fromRGB(255, 132, 148), 1.05)
end

local function playEnemyDeathEffect(payload)
    local deathColor = payload.color or (payload.isBoss and Color3.fromRGB(255, 92, 128) or Color3.fromRGB(255, 208, 118))
    local ring = makeEffectPart(
        deathColor,
        Vector3.new(0.5, 4, 4),
        CFrame.new((payload.position or Vector3.zero) + Vector3.new(0, 0.2, 0)) * CFrame.Angles(math.rad(90), 0, 0),
        Enum.PartType.Cylinder,
        0.18
    )
    tweenAndCleanup(ring, TweenInfo.new(0.35), {
        Size = Vector3.new(0.5, 14, 14),
        Transparency = 1,
    })
    playImpactPunch(payload.position or Vector3.zero, deathColor, payload.isBoss and 1.75 or 1.25)
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
            playPowerSlashEffect(payload)
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
        elseif effectName == MMONet.Effects.GojoBlueBurst then
            playGojoBlueBurstEffect(payload)
        elseif effectName == MMONet.Effects.HollowPurpleBurst then
            playHollowPurpleBurstEffect(payload)
        elseif effectName == MMONet.Effects.EnemyAttack then
            playEnemyAttackEffect(payload)
        elseif effectName == MMONet.Effects.EnemyHit then
            playEnemyHitEffect(payload)
        elseif effectName == MMONet.Effects.EnemyDeath then
            playEnemyDeathEffect(payload)
        elseif effectName == MMONet.Effects.PlayerHit then
            playPlayerHitEffect(payload)
        elseif effectName == MMONet.Effects.BossSlam then
            playBossSlamEffect(payload)
        end
    end)
end

return EffectsController
