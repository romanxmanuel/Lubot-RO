--!strict

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local KeyframeSequenceProvider = game:GetService('KeyframeSequenceProvider')

local CharacterAnimationController = {
    Name = 'CharacterAnimationController',
}

local localPlayer = Players.LocalPlayer
local currentCharacter: Model? = nil
local currentHumanoid: Humanoid? = nil
local cachedTracks: { [string]: AnimationTrack } = {}
local comboIndex = 0
local comboResetAt = 0
local ensureTracks: (character: Model) -> ()

local animationSets = {
    Default = {
        folderPath = { 'PlayerCharacters', 'DekuAnimations' },
        jump = 'DetroitAnim',
        combo = { 'DetroitAnim', 'Manchester Smash', 'ST.LuisSmash', '100%DetroitSmash' },
        dash = {
            forward = 'Manchester Smash',
            back = 'Manchester Smash',
            left = 'Manchester Smash',
            right = 'Manchester Smash',
        },
    },
    HighQualityR6Combat = {
        folderPath = { 'AnimationSources', 'HighQualityR6CombatAnimations', 'AnimSaves' },
        jump = 'Landed',
        combo = { 'Combat1', 'Combat2', 'Combat3', 'Combat4', 'Combat5' },
        dash = {
            forward = 'Dash W',
            back = 'Dash S',
            left = 'Dash A',
            right = 'Dash D',
        },
        block = 'Block',
        parry = 'Parryed',
        blockbroken = 'Blockbroken',
        reactions = { 'HitReaction1', 'HitReaction2', 'HitReaction3', 'HitReaction4', 'HitReaction5' },
    },
}
local activeStyleName = 'Default'
local activeConfig = animationSets.Default

local function getAnimationFolderForStyle(styleName: string): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    if not gameParts then
        return nil
    end

    local config = animationSets[styleName]
    if not config then
        return nil
    end

    local current: Instance = gameParts
    for _, segment in ipairs(config.folderPath) do
        local nextNode = current:FindFirstChild(segment)
        if not nextNode or not nextNode:IsA('Folder') then
            return nil
        end
        current = nextNode
    end

    return current :: Folder
end

local function getSequence(sequenceName: string): KeyframeSequence?
    local folder = getAnimationFolderForStyle(activeStyleName)
    if not folder then
        return nil
    end

    local sequence = folder:FindFirstChild(sequenceName)
    if sequence and sequence:IsA('KeyframeSequence') then
        return sequence
    end

    return nil
end

local function getAnimator(humanoid: Humanoid): Animator
    local animator = humanoid:FindFirstChildOfClass('Animator')
    if not animator then
        animator = Instance.new('Animator')
        animator.Parent = humanoid
    end
    return animator
end

local function buildTrack(humanoid: Humanoid, sequenceName: string): AnimationTrack?
    local sequence = getSequence(sequenceName)
    if not sequence then
        return nil
    end

    local ok, contentId = pcall(function()
        return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
    end)
    if not ok or not contentId then
        return nil
    end

    local animation = Instance.new('Animation')
    animation.Name = sequenceName .. 'RuntimeAnimation'
    animation.AnimationId = tostring(contentId)

    local okTrack, track = pcall(function()
        return getAnimator(humanoid):LoadAnimation(animation)
    end)
    animation:Destroy()
    if not okTrack or not track then
        return nil
    end

    track.Priority = Enum.AnimationPriority.Action
    track.Looped = false
    return track
end

local function getCurrentStyleName(character: Model?): string
    if not character then
        return 'Default'
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA('Tool') then
            local override = child:GetAttribute('AnimationStyleOverride')
            if typeof(override) == 'string' and animationSets[override] then
                return override
            end
        end
    end

    return 'Default'
end

local function bindStyleWatcher(character: Model)
    character.ChildAdded:Connect(function(child)
        if child:IsA('Tool') and child:GetAttribute('AnimationStyleOverride') ~= nil then
            task.defer(function()
                ensureTracks(character)
            end)
        end
    end)

    character.ChildRemoved:Connect(function(child)
        if child:IsA('Tool') and child:GetAttribute('AnimationStyleOverride') ~= nil then
            task.defer(function()
                ensureTracks(character)
            end)
        end
    end)
end

ensureTracks = function(character: Model)
    currentCharacter = character
    currentHumanoid = character:FindFirstChildOfClass('Humanoid')
    table.clear(cachedTracks)
    comboIndex = 0
    comboResetAt = 0

    if not currentHumanoid then
        return
    end

    activeStyleName = getCurrentStyleName(character)
    activeConfig = animationSets[activeStyleName] or animationSets.Default

    cachedTracks.jump = buildTrack(currentHumanoid, activeConfig.jump) or nil
    cachedTracks['dash:forward'] = buildTrack(currentHumanoid, activeConfig.dash.forward) or nil
    cachedTracks['dash:back'] = buildTrack(currentHumanoid, activeConfig.dash.back) or nil
    cachedTracks['dash:left'] = buildTrack(currentHumanoid, activeConfig.dash.left) or nil
    cachedTracks['dash:right'] = buildTrack(currentHumanoid, activeConfig.dash.right) or nil

    for _, sequenceName in ipairs(activeConfig.combo) do
        local track = buildTrack(currentHumanoid, sequenceName)
        if track then
            cachedTracks['combo:' .. sequenceName] = track
        end
    end
end

local function playTrack(track: AnimationTrack?)
    if not track then
        return
    end

    if track.IsPlaying then
        track:Stop(0.03)
    end
    track:Play(0.04, 1, 1)
end

local function getNextComboTrack(): (AnimationTrack?, string?)
    local now = os.clock()
    if now > comboResetAt then
        comboIndex = 0
    end

    comboIndex = (comboIndex % #activeConfig.combo) + 1
    comboResetAt = now + 1.1

    local sequenceName = activeConfig.combo[comboIndex]
    return cachedTracks['combo:' .. sequenceName], sequenceName
end

function CharacterAnimationController.init()
    return nil
end

function CharacterAnimationController.start()
    if localPlayer.Character then
        task.defer(function()
            local character = localPlayer.Character :: Model
            ensureTracks(character)
            bindStyleWatcher(character)
        end)
    end

    localPlayer.CharacterAdded:Connect(function(character)
        task.defer(function()
            ensureTracks(character)
            bindStyleWatcher(character)
        end)
    end)
end

function CharacterAnimationController.playJump()
    playTrack(cachedTracks.jump)
end

function CharacterAnimationController.playDash()
    local character = currentCharacter
    local root = character and character:FindFirstChild('HumanoidRootPart')
    local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
    local move = currentHumanoid and currentHumanoid.MoveDirection or Vector3.zero
    local dashKey = 'dash:forward'
    if move.Magnitude > 0.05 then
        local unit = move.Unit
        local lookFlat = Vector3.new(look.X, 0, look.Z)
        if lookFlat.Magnitude <= 0.001 then
            lookFlat = Vector3.new(0, 0, -1)
        end
        local right = root and root.CFrame.RightVector or Vector3.new(1, 0, 0)
        local rightFlat = Vector3.new(right.X, 0, right.Z)
        if rightFlat.Magnitude <= 0.001 then
            rightFlat = Vector3.new(1, 0, 0)
        end
        local dot = unit:Dot(lookFlat.Unit)
        local sideDot = unit:Dot(rightFlat.Unit)
        if dot < -0.35 then
            dashKey = 'dash:back'
        elseif math.abs(sideDot) > 0.45 then
            dashKey = sideDot > 0 and 'dash:right' or 'dash:left'
        end
    end
    playTrack(cachedTracks[dashKey] or cachedTracks['dash:forward'])
end

function CharacterAnimationController.playBasicAttack(): string?
    local track, sequenceName = getNextComboTrack()
    playTrack(track)
    return sequenceName
end

return CharacterAnimationController
