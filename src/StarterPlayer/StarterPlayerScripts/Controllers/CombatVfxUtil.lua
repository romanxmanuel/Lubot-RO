--!strict

local CombatVfxUtil = {}

local function createTimedNeonPart(workspaceRef: Workspace, debrisService, cframe: CFrame, size: Vector3, color: Color3, shape: Enum.PartType?, lifetime: number?, transparency: number?)
    local part = Instance.new('Part')
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Size = size
    part.Shape = shape or Enum.PartType.Block
    part.Transparency = transparency or 0.14
    part.CFrame = cframe
    part.Parent = workspaceRef

    local totalLifetime = lifetime or 0.28
    debrisService:AddItem(part, totalLifetime + 0.05)
    task.spawn(function()
        local startedAt = os.clock()
        while part.Parent do
            local alpha = math.clamp((os.clock() - startedAt) / math.max(totalLifetime, 0.01), 0, 1)
            part.Transparency = (transparency or 0.14) + (alpha * 0.78)
            if alpha >= 1 then
                break
            end
            task.wait(0.03)
        end
        if part.Parent then
            part:Destroy()
        end
    end)

    return part
end

function CombatVfxUtil.createPersistentFireWallEffect(
    workspaceRef: Workspace,
    debrisService,
    runtimeConfig,
    combatRandom,
    targetPosition: Vector3,
    effectPayload,
    color: Color3
)
    local duration = effectPayload.duration or runtimeConfig.persistSeconds or 7
    local textureAssetId = runtimeConfig.textureAssetId or 'rbxassetid://10383034781'
    local columnOffsets = { -1.9, 0, 1.9 }

    local effectFolder = Instance.new('Folder')
    effectFolder.Name = 'FireWallEffect'
    effectFolder.Parent = workspaceRef

    local glowRing = Instance.new('Part')
    glowRing.Anchored = true
    glowRing.CanCollide = false
    glowRing.CanQuery = false
    glowRing.CanTouch = false
    glowRing.Material = Enum.Material.Neon
    glowRing.Color = color:Lerp(Color3.fromRGB(255, 220, 170), 0.24)
    glowRing.Shape = Enum.PartType.Cylinder
    glowRing.Size = Vector3.new(6.8, 0.18, 4.2)
    glowRing.Transparency = 0.22
    glowRing.CFrame = CFrame.new(targetPosition + Vector3.new(0, 0.14, 0)) * CFrame.Angles(math.rad(90), 0, 0)
    glowRing.Parent = effectFolder

    local columns = {}
    for _, offsetX in ipairs(columnOffsets) do
        local anchor = Instance.new('Part')
        anchor.Name = 'FireWallAnchor'
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(0.25, 5.2, 0.25)
        anchor.CFrame = CFrame.new(targetPosition + Vector3.new(offsetX, 2.15, combatRandom:NextNumber(-0.25, 0.25)))
        anchor.Parent = effectFolder

        local attachment = Instance.new('Attachment')
        attachment.Parent = anchor

        local emitter = Instance.new('ParticleEmitter')
        emitter.Name = 'FireWallEmitter'
        emitter.Texture = textureAssetId
        emitter.Color = ColorSequence.new(
            Color3.fromRGB(255, 242, 212),
            color:Lerp(Color3.fromRGB(255, 147, 96), 0.12),
            Color3.fromRGB(255, 92, 44)
        )
        emitter.LightEmission = 1
        emitter.LightInfluence = 0
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.08),
            NumberSequenceKeypoint.new(0.65, 0.18),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.7),
            NumberSequenceKeypoint.new(0.45, 2.7),
            NumberSequenceKeypoint.new(1, 3.4),
        })
        emitter.Lifetime = NumberRange.new(0.55, 0.9)
        emitter.Rate = 38
        emitter.Speed = NumberRange.new(2.6, 4.8)
        emitter.Rotation = NumberRange.new(-20, 20)
        emitter.RotSpeed = NumberRange.new(-28, 28)
        emitter.SpreadAngle = Vector2.new(14, 18)
        emitter.Acceleration = Vector3.new(0, 6, 0)
        emitter.Drag = 1.8
        emitter.Parent = attachment

        local light = Instance.new('PointLight')
        light.Color = color:Lerp(Color3.fromRGB(255, 226, 188), 0.25)
        light.Brightness = 1.95
        light.Range = 9.5
        light.Parent = anchor

        table.insert(columns, {
            anchor = anchor,
            emitter = emitter,
            light = light,
        })
    end

    debrisService:AddItem(effectFolder, duration + 0.75)
    task.spawn(function()
        local startedAt = os.clock()
        while effectFolder.Parent do
            local elapsed = os.clock() - startedAt
            local fadeAlpha = math.clamp((elapsed - math.max(duration - 1.15, 0)) / 1.15, 0, 1)
            glowRing.Transparency = 0.22 + (fadeAlpha * 0.68)
            for index, column in ipairs(columns) do
                if column.anchor.Parent then
                    column.anchor.CFrame = CFrame.new(
                        targetPosition + Vector3.new(columnOffsets[index], 2.15 + math.sin((elapsed * 5.2) + index) * 0.14, math.sin((elapsed * 3.4) + index) * 0.1)
                    )
                    column.light.Brightness = 1.95 * (1 - fadeAlpha)
                    column.light.Range = 9.5 - (fadeAlpha * 2.6)
                    column.emitter.Rate = math.max(math.floor(38 * (1 - fadeAlpha * 0.85)), 0)
                end
            end

            if elapsed >= duration then
                break
            end

            task.wait(0.08)
        end

        if effectFolder.Parent then
            effectFolder:Destroy()
        end
    end)
end

function CombatVfxUtil.createZeroSkillAccent(
    workspaceRef: Workspace,
    debrisService,
    effectPayload,
    color: Color3
)
    if type(effectPayload) ~= 'table' then
        return
    end

    local effectKey = tostring(effectPayload.effectKey or '')
    local sourcePosition = effectPayload.sourcePosition or Vector3.zero
    local targetPosition = effectPayload.targetPosition or sourcePosition
    local midPoint = sourcePosition:Lerp(targetPosition, 0.5)
    local forward = targetPosition - sourcePosition
    if forward.Magnitude < 0.1 then
        forward = Vector3.new(0, 0, -1)
    else
        forward = forward.Unit
    end
    local right = forward:Cross(Vector3.yAxis)
    if right.Magnitude < 0.1 then
        right = Vector3.xAxis
    else
        right = right.Unit
    end
    local accentColor = color:Lerp(Color3.fromRGB(245, 248, 255), 0.4)

    if effectKey == 'forward_slash' then
        createTimedNeonPart(
            workspaceRef,
            debrisService,
            CFrame.lookAt(midPoint + Vector3.new(0, 1.4, 0), targetPosition + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(26)),
            Vector3.new(0.28, 3.1, math.max((targetPosition - sourcePosition).Magnitude * 0.9, 5)),
            accentColor,
            Enum.PartType.Block,
            0.22,
            0.08
        )
        createTimedNeonPart(
            workspaceRef,
            debrisService,
            CFrame.lookAt(midPoint + right * 0.4 + Vector3.new(0, 1.2, 0), targetPosition + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.rad(-24)),
            Vector3.new(0.22, 2.6, math.max((targetPosition - sourcePosition).Magnitude * 0.75, 4)),
            color,
            Enum.PartType.Block,
            0.18,
            0.12
        )
    elseif effectKey == 'circular_slash' then
        local radius = math.max(tonumber(effectPayload.radius) or 8, 6)
        createTimedNeonPart(
            workspaceRef,
            debrisService,
            CFrame.new(targetPosition + Vector3.new(0, 0.45, 0)) * CFrame.Angles(math.rad(90), 0, 0),
            Vector3.new(radius + 2.4, 0.22, radius + 2.4),
            accentColor,
            Enum.PartType.Cylinder,
            0.34,
            0.18
        )
        for index = 1, 6 do
            local angle = math.rad((index - 1) * 60)
            local radial = (Vector3.new(math.cos(angle), 0, math.sin(angle)) * (radius * 0.45))
            createTimedNeonPart(
                workspaceRef,
                debrisService,
                CFrame.lookAt(targetPosition + radial + Vector3.new(0, 1.15, 0), targetPosition + Vector3.new(0, 1.15, 0)),
                Vector3.new(0.2, 2.2, radius * 0.62),
                if index % 2 == 0 then accentColor else color,
                Enum.PartType.Block,
                0.26,
                0.14
            )
        end
    elseif effectKey == 'evasive_slash' then
        createTimedNeonPart(
            workspaceRef,
            debrisService,
            CFrame.lookAt(midPoint + Vector3.new(0, 1.4, 0), targetPosition + Vector3.new(0, 1.0, 0)),
            Vector3.new(0.32, 2.8, math.max((targetPosition - sourcePosition).Magnitude, 7)),
            accentColor,
            Enum.PartType.Block,
            0.26,
            0.06
        )
        for _, samplePosition in ipairs({
            sourcePosition,
            sourcePosition:Lerp(targetPosition, 0.35),
            sourcePosition:Lerp(targetPosition, 0.72),
        }) do
            createTimedNeonPart(
                workspaceRef,
                debrisService,
                CFrame.new(samplePosition + Vector3.new(0, 1.4, 0)),
                Vector3.new(1.25, 2.3, 0.3),
                color,
                Enum.PartType.Block,
                0.16,
                0.32
            )
        end
    elseif effectKey == 'shadow_clone_slash' then
        for index, side in ipairs({ -1, 1, 0 }) do
            local sideOffset = if side == 0 then Vector3.zero else right * (2.2 * side)
            createTimedNeonPart(
                workspaceRef,
                debrisService,
                CFrame.lookAt(targetPosition + sideOffset + Vector3.new(0, 1.5, 0), targetPosition + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(side == 0 and 0 or (20 * side))),
                Vector3.new(0.24, 3.4, 6.8),
                if index == 3 then accentColor else color,
                Enum.PartType.Block,
                0.28,
                0.08
            )
        end
        createTimedNeonPart(
            workspaceRef,
            debrisService,
            CFrame.new(targetPosition + Vector3.new(0, 2.2, 0)),
            Vector3.new(3.8, 3.8, 3.8),
            accentColor,
            Enum.PartType.Ball,
            0.24,
            0.14
        )
    end
end

return CombatVfxUtil
