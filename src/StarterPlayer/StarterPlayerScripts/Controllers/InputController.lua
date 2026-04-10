--!strict

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Debris = game:GetService('Debris')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local InputController = {
    Name = 'InputController',
}

local localPlayer = Players.LocalPlayer
local dependencies = nil
local DASH_SOUND_ID = 'rbxassetid://114821792036929'
local JUMP_SOUND_ID = 'rbxassetid://87863790669536'
local DASH_SOUND_START_TIME = 0.5
local JUMP_SOUND_START_TIME = 0.5

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

local function shouldConfigureJumpSound(instance: Instance): boolean
    if not instance:IsA('Sound') then
        return false
    end

    local soundId = string.lower(instance.SoundId)
    local soundName = string.lower(instance.Name)

    return soundName == 'jumping'
        or string.find(soundId, 'action_jump', 1, true) ~= nil
        or string.find(soundId, '131227259390218', 1, true) ~= nil
        or string.find(soundId, '139725652240613', 1, true) ~= nil
        or string.find(soundId, '87863790669536', 1, true) ~= nil
end

local function configureJumpSound(instance: Instance)
    if not shouldConfigureJumpSound(instance) then
        return
    end

    local sound = instance :: Sound
    sound.Name = 'Jumping'
    sound.SoundId = JUMP_SOUND_ID
    sound.Volume = 0.65
    sound.RollOffMaxDistance = 90
    sound.RollOffMinDistance = 8
    sound.PlaybackSpeed = 1.06
    sound.TimePosition = JUMP_SOUND_START_TIME

    if not sound:GetAttribute('JumpStartOffsetHooked') then
        sound:SetAttribute('JumpStartOffsetHooked', true)
        sound.Played:Connect(function()
            sound.TimePosition = JUMP_SOUND_START_TIME
        end)
    end
end

local function refreshJumpSounds(character: Model)
    local jumpSounds = {}

    for _, descendant in ipairs(character:GetDescendants()) do
        if shouldConfigureJumpSound(descendant) then
            table.insert(jumpSounds, descendant :: Sound)
        end
    end

    if #jumpSounds == 0 then
        return
    end

    local primarySound = jumpSounds[1]
    local root = character:FindFirstChild('HumanoidRootPart')
    if root then
        for _, sound in ipairs(jumpSounds) do
            if sound.Parent == root then
                primarySound = sound
                break
            end
        end
    end

    configureJumpSound(primarySound)

    for _, sound in ipairs(jumpSounds) do
        if sound ~= primarySound then
            sound:Destroy()
        end
    end
end

local function bindJumpSoundSetup(character: Model)
    refreshJumpSounds(character)

    character.DescendantAdded:Connect(function()
        task.defer(function()
            refreshJumpSounds(character)
        end)
    end)
end

local function getEquippedTool(): Tool?
    local character = localPlayer.Character
    if not character then
        return nil
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA('Tool') then
            return child
        end
    end

    return nil
end

local function hasUsableEquippedTool(): boolean
    local equippedTool = getEquippedTool()
    if not equippedTool then
        return false
    end

    if equippedTool:GetAttribute('AllowsCombatStyleOnly') == true then
        return false
    end

    return true
end

local function toolOwnsActionInput(keyCode: Enum.KeyCode): boolean
    local equippedTool = getEquippedTool()
    if not equippedTool then
        return false
    end

    if equippedTool:GetAttribute('ImportedAssetId') == nil then
        return false
    end

    if keyCode == Enum.KeyCode.Q or keyCode == Enum.KeyCode.E then
        return true
    end

    return false
end

local function tryDash()
    local character = localPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local root = character:FindFirstChild('HumanoidRootPart')
    if not humanoid or not root then
        return
    end

    local direction = humanoid.MoveDirection
    if direction.Magnitude <= 0.1 then
        local lookVector = root.CFrame.LookVector
        direction = Vector3.new(lookVector.X, 0, lookVector.Z)
    end

    if direction.Magnitude <= 0.001 then
        return
    end

    local dashVelocity = direction.Unit * (GameConfig.DashDistance / GameConfig.DashDuration)
    local verticalVelocity = math.max(root.AssemblyLinearVelocity.Y, GameConfig.DashLiftVelocity)
    root.AssemblyLinearVelocity = Vector3.new(dashVelocity.X, verticalVelocity, dashVelocity.Z)
    if dependencies.CharacterAnimationController then
        dependencies.CharacterAnimationController.playDash()
    end
    playMovementSound(root, DASH_SOUND_ID, 0.55, 1.03, DASH_SOUND_START_TIME)
    dependencies.Runtime.ActionRequest:FireServer({
        action = MMONet.Actions.Dash,
    })
end

local function tryInfiniteJump()
    local character = localPlayer.Character
    if not character then
        return
    end

    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local root = character:FindFirstChild('HumanoidRootPart')
    if not humanoid or not root then
        return
    end

    local velocity = root.AssemblyLinearVelocity
    local upwardVelocity = math.max(velocity.Y, GameConfig.InfiniteJumpVelocity)
    root.AssemblyLinearVelocity = Vector3.new(velocity.X, upwardVelocity, velocity.Z)
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    if dependencies.CharacterAnimationController then
        dependencies.CharacterAnimationController.playJump()
    end
end

local function tryRandomTeleport()
    dependencies.Runtime.ActionRequest:FireServer({
        action = MMONet.Actions.RandomTeleport,
    })
end

local function tryBasicAttack()
    if hasUsableEquippedTool() then
        return
    end

    local comboName = nil
    if dependencies.CharacterAnimationController then
        comboName = dependencies.CharacterAnimationController.playBasicAttack()
    end

    dependencies.Runtime.ActionRequest:FireServer({
        action = MMONet.Actions.BasicAttack,
        comboName = comboName,
        styleName = dependencies.CharacterAnimationController and dependencies.CharacterAnimationController.getActiveStyleName() or 'Default',
    })
end

function InputController.init(deps)
    dependencies = deps
end

function InputController.start()
    if localPlayer.Character then
        task.defer(function()
            local character = localPlayer.Character :: Model
            bindJumpSoundSetup(character)
        end)
    end

    localPlayer.CharacterAdded:Connect(function(character)
        task.defer(function()
            bindJumpSoundSetup(character)
        end)
    end)

    UserInputService.JumpRequest:Connect(function()
        tryInfiniteJump()
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if UserInputService:GetFocusedTextBox() then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            tryBasicAttack()
            return
        end

        if toolOwnsActionInput(input.KeyCode) then
            return
        end

        if input.KeyCode == Enum.KeyCode.Q then
            tryDash()
        elseif input.KeyCode == Enum.KeyCode.R then
            tryRandomTeleport()
        end
    end)
end

return InputController
