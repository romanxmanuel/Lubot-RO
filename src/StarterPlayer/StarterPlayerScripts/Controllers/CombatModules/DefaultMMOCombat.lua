--!strict

local Debris = game:GetService('Debris')

local DefaultMMOCombat = {}

local DASH_SOUND_ID = 'rbxassetid://114821792036929'
local DASH_SOUND_START_TIME = 0.5

local function playMovementSound(parent: Instance, soundId: string, volume: number, playbackSpeed: number, startTime: number?)
    local sound = Instance.new('Sound')
    sound.Name = 'MovementOneShot'
    sound.SoundId = soundId
    sound.Volume = volume
    sound.RollOffMaxDistance = 90
    sound.RollOffMinDistance = 8
    sound.PlaybackSpeed = playbackSpeed
    sound.Parent = parent

    local function playConfiguredSound()
        if startTime and startTime > 0 then
            sound.TimePosition = startTime
        end
        sound:Play()
    end

    if startTime and startTime > 0 and not sound.IsLoaded then
        local loadedConnection: RBXScriptConnection? = nil
        loadedConnection = sound.Loaded:Connect(function()
            if loadedConnection then
                loadedConnection:Disconnect()
            end
            playConfiguredSound()
        end)
        task.delay(1, function()
            if loadedConnection and loadedConnection.Connected then
                loadedConnection:Disconnect()
                playConfiguredSound()
            end
        end)
    else
        playConfiguredSound()
    end

    Debris:AddItem(sound, 2)
end

function DefaultMMOCombat:Attack(context)
    if context:hasUsableEquippedTool() then
        return false
    end

    local comboName = nil
    if context.dependencies.CharacterAnimationController then
        comboName = context.dependencies.CharacterAnimationController.playBasicAttack()
    end

    context.runtime.ActionRequest:FireServer({
        action = context.net.Actions.BasicAttack,
        comboName = comboName,
        styleName = context.dependencies.CharacterAnimationController and context.dependencies.CharacterAnimationController.getActiveStyleName() or 'Default',
    })

    return true
end

function DefaultMMOCombat:Block(_context)
    return false
end

function DefaultMMOCombat:Dash(context)
    if context:toolOwnsActionInput(Enum.KeyCode.Q) then
        return false
    end

    local character = context.localPlayer.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local root = character:FindFirstChild('HumanoidRootPart')
    if not humanoid or not root then
        return false
    end

    local direction = humanoid.MoveDirection
    if direction.Magnitude <= 0.1 then
        local lookVector = root.CFrame.LookVector
        direction = Vector3.new(lookVector.X, 0, lookVector.Z)
    end

    if direction.Magnitude <= 0.001 then
        return false
    end

    local dashVelocity = direction.Unit * (context.gameConfig.DashDistance / context.gameConfig.DashDuration)
    local verticalVelocity = math.max(root.AssemblyLinearVelocity.Y, context.gameConfig.DashLiftVelocity)
    root.AssemblyLinearVelocity = Vector3.new(dashVelocity.X, verticalVelocity, dashVelocity.Z)
    if context.dependencies.CharacterAnimationController then
        context.dependencies.CharacterAnimationController.playDash()
    end
    playMovementSound(root, DASH_SOUND_ID, 0.55, 1.03, DASH_SOUND_START_TIME)

    context.runtime.ActionRequest:FireServer({
        action = context.net.Actions.Dash,
    })

    return true
end

function DefaultMMOCombat:OnEquip(_context)
    return nil
end

function DefaultMMOCombat:OnUnequip(_context)
    return nil
end

return DefaultMMOCombat
