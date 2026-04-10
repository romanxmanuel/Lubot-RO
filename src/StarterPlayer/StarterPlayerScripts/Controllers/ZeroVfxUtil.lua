--!strict

local ZeroVfxUtil = {}

local SPARK_TEXTURE = 'rbxasset://textures/particles/sparkles_main.dds'

local CAST_SOUNDS = {
    forward_slash = { soundId = 'rbxassetid://12222216', volume = 0.62, playbackSpeed = 1.28, maxDistance = 135 },
    circular_slash = { soundId = 'rbxassetid://12222124', volume = 0.7, playbackSpeed = 1.0, maxDistance = 145 },
    evasive_slash = { soundId = 'rbxassetid://12222124', volume = 0.62, playbackSpeed = 1.16, maxDistance = 140 },
    shadow_clone_slash = { soundId = 'rbxassetid://12222225', volume = 0.82, playbackSpeed = 1.05, maxDistance = 170 },
}

local IMPACT_SOUNDS = {
    forward_slash = { soundId = 'rbxassetid://12222225', volume = 0.34, playbackSpeed = 1.08, maxDistance = 105 },
    circular_slash = { soundId = 'rbxassetid://12222225', volume = 0.42, playbackSpeed = 0.9, maxDistance = 130 },
    evasive_slash = { soundId = 'rbxassetid://12222225', volume = 0.36, playbackSpeed = 1.15, maxDistance = 110 },
    shadow_clone_slash = { soundId = 'rbxassetid://12222225', volume = 0.5, playbackSpeed = 0.96, maxDistance = 150 },
    edge_tempo = { soundId = 'rbxassetid://12222124', volume = 0.28, playbackSpeed = 1.4, maxDistance = 96 },
}

local function createAnchor(workspaceRef: Workspace, position: Vector3)
    local part = Instance.new('Part')
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Size = Vector3.new(0.2, 0.2, 0.2)
    part.CFrame = CFrame.new(position)
    part.Parent = workspaceRef
    return part
end

local function fadeInstance(duration: number, stepSeconds: number, applyFn)
    task.spawn(function()
        local startedAt = os.clock()
        while true do
            local alpha = math.clamp((os.clock() - startedAt) / math.max(duration, 0.01), 0, 1)
            applyFn(alpha)
            if alpha >= 1 then
                break
            end
            task.wait(stepSeconds)
        end
    end)
end

local function createSound(workspaceRef: Workspace, debrisService, position: Vector3, config)
    if type(config) ~= 'table' or type(config.soundId) ~= 'string' or config.soundId == '' then
        return
    end

    local anchor = createAnchor(workspaceRef, position)
    local sound = Instance.new('Sound')
    sound.SoundId = config.soundId
    sound.Volume = config.volume or 0.6
    sound.PlaybackSpeed = config.playbackSpeed or 1
    sound.RollOffMode = Enum.RollOffMode.Linear
    sound.RollOffMaxDistance = config.maxDistance or 120
    sound.Parent = anchor
    sound:Play()
    debrisService:AddItem(anchor, 2.2)
end

local function createArcBeam(workspaceRef: Workspace, debrisService, fromPosition: Vector3, toPosition: Vector3, color: Color3, width0: number, width1: number, duration: number, curve0: number?, curve1: number?)
    local startAnchor = createAnchor(workspaceRef, fromPosition)
    local endAnchor = createAnchor(workspaceRef, toPosition)
    local startAttachment = Instance.new('Attachment')
    local endAttachment = Instance.new('Attachment')
    startAttachment.Parent = startAnchor
    endAttachment.Parent = endAnchor

    local beam = Instance.new('Beam')
    beam.Attachment0 = startAttachment
    beam.Attachment1 = endAttachment
    beam.FaceCamera = true
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Width0 = width0
    beam.Width1 = width1
    beam.CurveSize0 = curve0 or 0
    beam.CurveSize1 = curve1 or 0
    beam.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(255, 255, 255), 0.42), color)
    beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.04),
        NumberSequenceKeypoint.new(0.7, 0.18),
        NumberSequenceKeypoint.new(1, 1),
    })
    beam.Parent = startAnchor

    debrisService:AddItem(startAnchor, duration + 0.12)
    debrisService:AddItem(endAnchor, duration + 0.12)
    fadeInstance(duration, 0.03, function(alpha)
        if beam.Parent then
            local widthScale = 1 - alpha * 0.82
            beam.Width0 = math.max(width0 * widthScale, 0.03)
            beam.Width1 = math.max(width1 * widthScale, 0.03)
        end
    end)
end

local function createTimedPart(workspaceRef: Workspace, debrisService, cframe: CFrame, size: Vector3, color: Color3, shape: Enum.PartType, duration: number, transparency: number?)
    local part = Instance.new('Part')
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Shape = shape
    part.Color = color
    part.Transparency = transparency or 0.12
    part.Size = size
    part.CFrame = cframe
    part.Parent = workspaceRef

    debrisService:AddItem(part, duration + 0.08)
    fadeInstance(duration, 0.03, function(alpha)
        if part.Parent then
            part.Transparency = math.clamp((transparency or 0.12) + alpha * 0.82, 0, 1)
        end
    end)

    return part
end

local function createRing(workspaceRef: Workspace, debrisService, position: Vector3, radius: number, color: Color3, duration: number, thickness: number?)
    local ring = createTimedPart(
        workspaceRef,
        debrisService,
        CFrame.new(position) * CFrame.Angles(math.rad(90), 0, 0),
        Vector3.new(radius, thickness or 0.18, radius),
        color,
        Enum.PartType.Cylinder,
        duration,
        0.22
    )
    fadeInstance(duration, 0.03, function(alpha)
        if ring.Parent then
            local grow = 1 + alpha * 0.35
            ring.Size = Vector3.new(radius * grow, ring.Size.Y, radius * grow)
        end
    end)
end

local function createGhostBody(workspaceRef: Workspace, debrisService, position: Vector3, color: Color3, duration: number, scale: number?)
    local sizeScale = scale or 1
    local torso = createTimedPart(
        workspaceRef,
        debrisService,
        CFrame.new(position + Vector3.new(0, 1.45 * sizeScale, 0)),
        Vector3.new(0.9 * sizeScale, 2.2 * sizeScale, 0.2 * sizeScale),
        color,
        Enum.PartType.Block,
        duration,
        0.48
    )
    local head = createTimedPart(
        workspaceRef,
        debrisService,
        CFrame.new(position + Vector3.new(0, 2.55 * sizeScale, 0)),
        Vector3.new(0.55 * sizeScale, 0.55 * sizeScale, 0.12 * sizeScale),
        color,
        Enum.PartType.Block,
        duration,
        0.52
    )
    fadeInstance(duration, 0.03, function()
        if torso.Parent then
            torso.Position += Vector3.new(0, 0.02, 0)
        end
        if head.Parent then
            head.Position += Vector3.new(0, 0.03, 0)
        end
    end)
end

local function emitBurst(workspaceRef: Workspace, debrisService, position: Vector3, color: Color3, duration: number, speedScale: number?)
    local anchor = createAnchor(workspaceRef, position)
    local attachment = Instance.new('Attachment')
    attachment.Parent = anchor

    local emitter = Instance.new('ParticleEmitter')
    emitter.Texture = SPARK_TEXTURE
    emitter.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(255, 255, 255), 0.32), color)
    emitter.LightEmission = 1
    emitter.LightInfluence = 0
    emitter.Lifetime = NumberRange.new(0.18, 0.32)
    emitter.Speed = NumberRange.new(3.2 * (speedScale or 1), 6.6 * (speedScale or 1))
    emitter.Rotation = NumberRange.new(-180, 180)
    emitter.RotSpeed = NumberRange.new(-90, 90)
    emitter.Acceleration = Vector3.new(0, 5.5, 0)
    emitter.SpreadAngle = Vector2.new(30, 30)
    emitter.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.28),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.06),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Rate = 0
    emitter.Parent = attachment
    emitter:Emit(10)

    debrisService:AddItem(anchor, duration + 0.4)
end

local function createRiftDriveCast(workspaceRef: Workspace, debrisService, sourcePosition: Vector3, targetPosition: Vector3, color: Color3)
    local ink = Color3.fromRGB(26, 30, 44)
    createArcBeam(workspaceRef, debrisService, sourcePosition + Vector3.new(0, 1.1, 0), targetPosition + Vector3.new(0, 1.0, 0), color, 1.25, 0.22, 0.22, 3.2, -3.2)
    createArcBeam(workspaceRef, debrisService, sourcePosition + Vector3.new(0, 0.85, 0), targetPosition + Vector3.new(0, 0.7, 0), ink, 0.46, 0.08, 0.16, 2.2, -2.2)
    createRing(workspaceRef, debrisService, sourcePosition + Vector3.new(0, 0.24, 0), 2.2, color, 0.2, 0.14)
    createRing(workspaceRef, debrisService, targetPosition + Vector3.new(0, 0.2, 0), 3.1, color, 0.22, 0.16)
    createGhostBody(workspaceRef, debrisService, sourcePosition, ink, 0.16, 0.94)
    emitBurst(workspaceRef, debrisService, targetPosition + Vector3.new(0, 1.1, 0), color, 0.3, 1.05)
end

local function createFallingHaloCast(workspaceRef: Workspace, debrisService, sourcePosition: Vector3, targetPosition: Vector3, color: Color3)
    local haloColor = color:Lerp(Color3.fromRGB(255, 255, 255), 0.28)
    createRing(workspaceRef, debrisService, targetPosition + Vector3.new(0, 0.12, 0), 5.4, haloColor, 0.28, 0.16)
    createArcBeam(workspaceRef, debrisService, sourcePosition, targetPosition + Vector3.new(0, 0.25, 0), haloColor, 0.9, 0.2, 0.28, 0, 0)
    createTimedPart(
        workspaceRef,
        debrisService,
        CFrame.new(targetPosition + Vector3.new(0, 0.18, 0)) * CFrame.Angles(math.rad(90), 0, 0),
        Vector3.new(7.8, 0.12, 7.8),
        color,
        Enum.PartType.Cylinder,
        0.3,
        0.28
    )
    emitBurst(workspaceRef, debrisService, targetPosition + Vector3.new(0, 0.8, 0), haloColor, 0.34, 1.15)
end

local function createBackstepRendCast(workspaceRef: Workspace, debrisService, sourcePosition: Vector3, targetPosition: Vector3, color: Color3)
    local ink = Color3.fromRGB(24, 28, 38)
    createArcBeam(workspaceRef, debrisService, sourcePosition + Vector3.new(0.8, 1.2, 0), sourcePosition + Vector3.new(-0.8, 1.9, 0), color, 0.8, 0.16, 0.18, 0.8, -0.8)
    createArcBeam(workspaceRef, debrisService, sourcePosition + Vector3.new(-0.8, 1.2, 0), sourcePosition + Vector3.new(0.8, 1.9, 0), ink, 0.58, 0.12, 0.18, -0.8, 0.8)
    createArcBeam(workspaceRef, debrisService, sourcePosition + Vector3.new(0, 1.0, 0), targetPosition + Vector3.new(0, 1.0, 0), color, 0.7, 0.12, 0.18, 1.2, -1.2)
    createGhostBody(workspaceRef, debrisService, sourcePosition, ink, 0.18, 0.86)
    emitBurst(workspaceRef, debrisService, sourcePosition + Vector3.new(0, 1.1, 0), color, 0.24, 0.92)
end

local function createTwinEclipseCast(workspaceRef: Workspace, debrisService, sourcePosition: Vector3, targetPosition: Vector3, color: Color3, fallback: boolean?)
    local ink = Color3.fromRGB(18, 20, 34)
    if fallback then
        createArcBeam(workspaceRef, debrisService, sourcePosition + Vector3.new(0, 1.1, 0), targetPosition + Vector3.new(0, 1.1, 0), color, 1.1, 0.16, 0.2, 1.8, -1.8)
        createGhostBody(workspaceRef, debrisService, sourcePosition, ink, 0.16, 0.82)
        emitBurst(workspaceRef, debrisService, targetPosition + Vector3.new(0, 1.0, 0), color, 0.26, 1.0)
        return
    end

    local offset = Vector3.new(2.1, 0, 0)
    createArcBeam(workspaceRef, debrisService, sourcePosition + offset + Vector3.new(0, 1.1, 0), targetPosition + Vector3.new(0, 1.15, 0), color, 0.82, 0.1, 0.22, 2.6, -2.2)
    createArcBeam(workspaceRef, debrisService, sourcePosition - offset + Vector3.new(0, 1.1, 0), targetPosition + Vector3.new(0, 1.15, 0), color, 0.82, 0.1, 0.22, -2.6, 2.2)
    createArcBeam(workspaceRef, debrisService, targetPosition + Vector3.new(1.6, 0.5, 0), targetPosition + Vector3.new(-1.6, 2.2, 0), ink, 0.62, 0.08, 0.18, 1.4, -1.4)
    createArcBeam(workspaceRef, debrisService, targetPosition + Vector3.new(-1.6, 0.5, 0), targetPosition + Vector3.new(1.6, 2.2, 0), color, 0.72, 0.1, 0.18, -1.4, 1.4)
    createGhostBody(workspaceRef, debrisService, sourcePosition + offset, ink, 0.18, 0.72)
    createGhostBody(workspaceRef, debrisService, sourcePosition - offset, ink, 0.18, 0.72)
    createRing(workspaceRef, debrisService, targetPosition + Vector3.new(0, 0.18, 0), 3.6, color, 0.2, 0.14)
    emitBurst(workspaceRef, debrisService, targetPosition + Vector3.new(0, 1.1, 0), color, 0.28, 1.2)
end

local function createImpactAccent(workspaceRef: Workspace, debrisService, effectPayload, color: Color3)
    local targetPosition = effectPayload.targetPosition or effectPayload.sourcePosition or Vector3.zero
    local skillId = tostring(effectPayload.effectKey or '')
    local flashColor = if effectPayload.edgeTempo
        then color:Lerp(Color3.fromRGB(255, 255, 255), 0.46)
        else color:Lerp(Color3.fromRGB(255, 255, 255), 0.22)

    createRing(workspaceRef, debrisService, targetPosition + Vector3.new(0, 0.18, 0), if effectPayload.edgeTempo then 2.6 else 2.1, flashColor, 0.16, 0.12)
    emitBurst(workspaceRef, debrisService, targetPosition + Vector3.new(0, 1.0, 0), flashColor, 0.24, if effectPayload.edgeTempo then 1.2 else 0.9)

    if skillId == 'forward_slash' then
        createArcBeam(workspaceRef, debrisService, targetPosition + Vector3.new(1.4, 0.7, 0), targetPosition + Vector3.new(-1.2, 1.8, 0), flashColor, 0.42, 0.08, 0.14, 1.1, -1.1)
    elseif skillId == 'circular_slash' then
        createRing(workspaceRef, debrisService, targetPosition + Vector3.new(0, 0.12, 0), 4.6, flashColor, 0.18, 0.12)
    elseif skillId == 'evasive_slash' then
        createArcBeam(workspaceRef, debrisService, targetPosition + Vector3.new(1.1, 0.8, 0), targetPosition + Vector3.new(-1.1, 1.9, 0), flashColor, 0.34, 0.08, 0.14, 0.8, -0.8)
    elseif skillId == 'shadow_clone_slash' then
        createArcBeam(workspaceRef, debrisService, targetPosition + Vector3.new(1.5, 0.5, 0), targetPosition + Vector3.new(-1.5, 2.0, 0), flashColor, 0.58, 0.08, 0.16, 1.1, -1.1)
        createArcBeam(workspaceRef, debrisService, targetPosition + Vector3.new(-1.5, 0.5, 0), targetPosition + Vector3.new(1.5, 2.0, 0), flashColor, 0.58, 0.08, 0.16, -1.1, 1.1)
    end
end

function ZeroVfxUtil.playSkillEffect(workspaceRef: Workspace, debrisService, effectPayload, color: Color3, isLocalAttacker: boolean)
    if type(effectPayload) ~= 'table' then
        return nil
    end

    local effectKey = tostring(effectPayload.effectKey or '')
    local sourcePosition = effectPayload.sourcePosition or Vector3.zero
    local targetPosition = effectPayload.targetPosition or sourcePosition

    if effectPayload.damage or effectPayload.wasMiss or effectPayload.edgeTempo then
        createImpactAccent(workspaceRef, debrisService, effectPayload, color)
        createSound(
            workspaceRef,
            debrisService,
            targetPosition + Vector3.new(0, 0.8, 0),
            if effectPayload.edgeTempo then IMPACT_SOUNDS.edge_tempo else IMPACT_SOUNDS[effectKey]
        )
        if isLocalAttacker then
            return {
                flashStrength = if effectPayload.edgeTempo then 0.26 else 0.16,
                cameraPitch = 0.02,
                cameraRoll = if effectPayload.edgeTempo then 0.018 else 0.01,
            }
        end
        return nil
    end

    if effectKey == 'forward_slash' then
        createRiftDriveCast(workspaceRef, debrisService, sourcePosition, targetPosition, color)
    elseif effectKey == 'circular_slash' then
        createFallingHaloCast(workspaceRef, debrisService, sourcePosition, targetPosition, color)
    elseif effectKey == 'evasive_slash' then
        createBackstepRendCast(workspaceRef, debrisService, sourcePosition, targetPosition, color)
    elseif effectKey == 'shadow_clone_slash' then
        createTwinEclipseCast(workspaceRef, debrisService, sourcePosition, targetPosition, color, effectPayload.fallback == true)
    else
        return nil
    end

    createSound(workspaceRef, debrisService, targetPosition, CAST_SOUNDS[effectKey])

    if not isLocalAttacker then
        return nil
    end

    if effectKey == 'forward_slash' then
        return { flashStrength = 0.14, cameraPitch = 0.03, cameraRoll = 0.015 }
    elseif effectKey == 'circular_slash' then
        return { flashStrength = 0.16, cameraPitch = 0.04, cameraRoll = 0.01 }
    elseif effectKey == 'evasive_slash' then
        return { flashStrength = 0.1, cameraPitch = 0.02, cameraRoll = -0.014 }
    elseif effectKey == 'shadow_clone_slash' then
        return { flashStrength = 0.22, cameraPitch = 0.05, cameraRoll = 0.02 }
    end

    return nil
end

return ZeroVfxUtil
