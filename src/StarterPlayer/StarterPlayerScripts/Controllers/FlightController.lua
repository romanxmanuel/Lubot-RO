--!strict
--[[
    FlightController — Client-side flight input, VFX, and camera.
    Listens for ToggleFlight keybind, sends requests to server,
    handles local wing visuals and movement input while flying.
]]

local FlightController = {}

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')

local player = Players.LocalPlayer

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild('Remotes')
local ToggleFlightRemote = Remotes:WaitForChild('ToggleFlight')
local FlightStateChangedRemote = Remotes:WaitForChild('FlightStateChanged')
local FlightEffectsReplicateRemote = Remotes:WaitForChild('FlightEffectsReplicate')
local FlightUpdateVelocityRemote = Remotes:WaitForChild('FlightUpdateVelocity')

-- Config

local FLY_SPEED = 80
local FLY_SPEED_BOOST = 120
local ASCEND_KEY = Enum.KeyCode.Space
local DESCEND_KEY = Enum.KeyCode.LeftControl
local BOOST_KEY = Enum.KeyCode.LeftShift
local VERTICAL_SPEED = 50
local SEND_RATE = 0.05

-- Boost stamina
local BOOST_MAX = 100
local BOOST_DRAIN_RATE = 30
local BOOST_RECHARGE_RATE = 20
local BOOST_MIN_TO_START = 15
local boostStamina = BOOST_MAX

-- Flight HUD refs
local flightHudFrame = nil
local boostFillBar = nil
local currentClassId = 'valkyrie'

-- State
local isFlying = false
local isBoosting = false
local wingModel = nil
local trailEffect = nil
local heartbeatConn = nil
local lastVelocitySend = 0
local inputConn = nil
local endInputConn = nil
local stateConn = nil

local keysHeld = {
    W = false, A = false, S = false, D = false,
    Space = false, LeftControl = false, LeftShift = false,
}

local KEY_MAP = {
    [Enum.KeyCode.W] = 'W',
    [Enum.KeyCode.A] = 'A',
    [Enum.KeyCode.S] = 'S',
    [Enum.KeyCode.D] = 'D',
    [Enum.KeyCode.Space] = 'Space',
    [Enum.KeyCode.LeftControl] = 'LeftControl',
    [Enum.KeyCode.LeftShift] = 'LeftShift',
}

-------------------------------------------------
-- Wing VFX
-------------------------------------------------
local WING_STYLES = {
    valkyrie = {
        pairs = { { size = Vector3.new(0.2, 3, 2.5), offset = 1.8, yOff = 0.5, angle = 15 } },
        color = Color3.fromRGB(220, 230, 255),
        transparency = 0.3,
        material = Enum.Material.Neon,
    },
    high_valkyrie = {
        pairs = { { size = Vector3.new(0.25, 4, 3.2), offset = 2.0, yOff = 0.6, angle = 18 } },
        color = Color3.fromRGB(190, 215, 255),
        transparency = 0.15,
        material = Enum.Material.Neon,
        particles = true,
    },
    valkyrie_rebirthed = {
        pairs = {
            { size = Vector3.new(0.25, 4.5, 3.5), offset = 2.2, yOff = 0.6, angle = 20 },
            { size = Vector3.new(0.15, 2.5, 1.8), offset = 1.4, yOff = 1.2, angle = 30 },
        },
        color = Color3.fromRGB(255, 215, 100),
        transparency = 0.1,
        material = Enum.Material.Neon,
        particles = true,
        sparkle = true,
    },
    seraphim = {
        pairs = {
            { size = Vector3.new(0.3, 5, 4), offset = 2.4, yOff = 0.5, angle = 15 },
            { size = Vector3.new(0.25, 3.5, 2.8), offset = 1.8, yOff = 1.4, angle = 35 },
            { size = Vector3.new(0.2, 2.5, 2), offset = 1.2, yOff = -0.3, angle = -10 },
        },
        color = Color3.fromRGB(255, 245, 200),
        transparency = 0.05,
        material = Enum.Material.Neon,
        particles = true,
        sparkle = true,
        halo = true,
    },
}

local function createWings(character, classId)
    if wingModel then
        wingModel:Destroy()
        wingModel = nil
    end

    local humroot = character:FindFirstChild('HumanoidRootPart')
    if not humroot then return end

    local style = WING_STYLES[classId or 'valkyrie'] or WING_STYLES.valkyrie
    local model = Instance.new('Model')
    model.Name = 'ValkyrieWings'

    for pairIdx, wingDef in ipairs(style.pairs) do
        for _, side in ipairs({1, -1}) do
            local part = Instance.new('Part')
            part.Name = if side > 0 then 'RightWing' .. pairIdx else 'LeftWing' .. pairIdx
            part.Size = wingDef.size
            part.Transparency = 1
            part.Color = style.color
            part.Material = style.material
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Massless = true
            part.Anchored = false
            part.Parent = model

            local weld = Instance.new('Weld')
            weld.Part0 = humroot
            weld.Part1 = part
            local xOff = wingDef.offset * side
            weld.C0 = CFrame.new(xOff, wingDef.yOff, 0.3) * CFrame.Angles(0, 0, math.rad(wingDef.angle * -side))
            weld.Parent = part

            -- Fade in
            TweenService:Create(part, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Transparency = style.transparency,
            }):Play()
        end
    end

    -- Particle emitter for higher tiers
    if style.particles then
        local emitter = Instance.new('ParticleEmitter')
        emitter.Name = 'WingGlow'
        emitter.Color = ColorSequence.new(style.color)
        emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
        emitter.Lifetime = NumberRange.new(0.3, 0.6)
        emitter.Rate = 20
        emitter.Speed = NumberRange.new(1, 3)
        emitter.SpreadAngle = Vector2.new(30, 30)
        emitter.LightEmission = 0.8
        emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
        emitter.Parent = model:FindFirstChildWhichIsA('BasePart')
    end

    -- Sparkle for rebirthed+
    if style.sparkle then
        for _, child in ipairs(model:GetChildren()) do
            if child:IsA('BasePart') and child.Name:find('Wing1') then
                local sparkle = Instance.new('Sparkles')
                sparkle.SparkleColor = style.color
                sparkle.Parent = child
            end
        end
    end

    -- Halo ring for seraphim
    if style.halo then
        local halo = Instance.new('Part')
        halo.Name = 'Halo'
        halo.Shape = Enum.PartType.Cylinder
        halo.Size = Vector3.new(0.15, 3, 3)
        halo.Color = Color3.fromRGB(255, 240, 180)
        halo.Material = Enum.Material.Neon
        halo.Transparency = 0.4
        halo.CanCollide = false
        halo.CanQuery = false
        halo.CanTouch = false
        halo.Massless = true
        halo.Anchored = false
        halo.Parent = model

        local haloWeld = Instance.new('Weld')
        haloWeld.Part0 = humroot
        haloWeld.Part1 = halo
        haloWeld.C0 = CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(90))
        haloWeld.Parent = halo
    end

    model.Parent = character
    wingModel = model
end

local function removeWings()
    if wingModel then
        for _, child in ipairs(wingModel:GetChildren()) do
            if child:IsA('BasePart') then
                TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Transparency = 1,
                }):Play()
            end
        end
        Debris:AddItem(wingModel, 0.4)
        wingModel = nil
    end
end

local function createTrail(character)
    if trailEffect then
        trailEffect:Destroy()
        trailEffect = nil
    end

    local humroot = character:FindFirstChild('HumanoidRootPart')
    if not humroot then return end

    local att0 = Instance.new('Attachment')
    att0.Name = 'FlightTrailAtt0'
    att0.Position = Vector3.new(0, 0, 1)
    att0.Parent = humroot

    local att1 = Instance.new('Attachment')
    att1.Name = 'FlightTrailAtt1'
    att1.Position = Vector3.new(0, 0, -1)
    att1.Parent = humroot

    local trail = Instance.new('Trail')
    trail.Name = 'FlightTrail'
    trail.Attachment0 = att0
    trail.Attachment1 = att1
    trail.Lifetime = 0.4
    trail.MinLength = 0.1
    trail.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255), Color3.fromRGB(100, 150, 255))
    trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)})
    trail.LightEmission = 0.6
    trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3)})
    trail.Parent = humroot

    -- Store refs for cleanup
    trailEffect = Instance.new('Folder')
    trailEffect.Name = '_FlightTrailRefs'
    att0.Parent = humroot
    att1.Parent = humroot
    trail.Parent = humroot
    trailEffect.Parent = character

    -- Tag children for cleanup
    local tag0 = Instance.new('ObjectValue')
    tag0.Name = 'Att0'
    tag0.Value = att0
    tag0.Parent = trailEffect

    local tag1 = Instance.new('ObjectValue')
    tag1.Name = 'Att1'
    tag1.Value = att1
    tag1.Parent = trailEffect

    local tagTrail = Instance.new('ObjectValue')
    tagTrail.Name = 'Trail'
    tagTrail.Value = trail
    tagTrail.Parent = trailEffect
end

local function removeTrail()
    if trailEffect and trailEffect.Parent then
        for _, ref in ipairs(trailEffect:GetChildren()) do
            if ref:IsA('ObjectValue') and ref.Value then
                ref.Value:Destroy()
            end
        end
        trailEffect:Destroy()
        trailEffect = nil
    end
end

-------------------------------------------------
-- Movement computation
-------------------------------------------------
local function getDesiredVelocity(): Vector3
    local camera = workspace.CurrentCamera
    if not camera then return Vector3.zero end

    local camCF = camera.CFrame
    local forward = camCF.LookVector
    local right = camCF.RightVector

    -- Flatten for horizontal movement
    local rawForward = Vector3.new(forward.X, 0, forward.Z)
    local flatForward = if rawForward.Magnitude > 0.001 then rawForward.Unit else Vector3.new(0, 0, -1)
    local rawRight = Vector3.new(right.X, 0, right.Z)
    local flatRight = if rawRight.Magnitude > 0.001 then rawRight.Unit else Vector3.new(1, 0, 0)

    local dir = Vector3.zero

    if keysHeld.W then dir = dir + flatForward end
    if keysHeld.S then dir = dir - flatForward end
    if keysHeld.D then dir = dir + flatRight end
    if keysHeld.A then dir = dir - flatRight end

    -- Vertical
    if keysHeld.Space then dir = dir + Vector3.new(0, 1, 0) end
    if keysHeld.LeftControl then dir = dir - Vector3.new(0, 1, 0) end

    if dir.Magnitude < 0.01 then
        return Vector3.zero
    end

    dir = dir.Unit

    local wantBoost = keysHeld.LeftShift and boostStamina >= (if isBoosting then 0.1 else BOOST_MIN_TO_START)
    isBoosting = wantBoost
    local speed = if wantBoost then FLY_SPEED_BOOST else FLY_SPEED

    -- Scale vertical component separately
    local horizontal = Vector3.new(dir.X, 0, dir.Z)
    local vertical = Vector3.new(0, dir.Y, 0)

    return horizontal * speed + vertical * VERTICAL_SPEED
end

-------------------------------------------------
-- Flight HUD
-------------------------------------------------
local function createFlightHud()
    if flightHudFrame then return end

    local pg = player:FindFirstChildOfClass('PlayerGui')
    if not pg then return end

    local gui = pg:FindFirstChild('VerticalSliceUI')
    if not gui then
        gui = Instance.new('ScreenGui')
        gui.Name = 'FlightHUD'
        gui.ResetOnSpawn = false
        gui.Parent = pg
    end

    -- Container frame — top-center of screen
    local frame = Instance.new('Frame')
    frame.Name = 'FlightStatus'
    frame.Size = UDim2.fromOffset(160, 42)
    frame.Position = UDim2.new(0.5, -80, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0
    frame.ZIndex = 30
    frame.Parent = gui

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new('UIStroke')
    stroke.Color = Color3.fromRGB(140, 180, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = frame

    -- FLYING label
    local label = Instance.new('TextLabel')
    label.Name = 'FlyingLabel'
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Position = UDim2.fromOffset(0, 2)
    label.BackgroundTransparency = 1
    label.Text = '✦ FLYING'
    label.TextColor3 = Color3.fromRGB(180, 210, 255)
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.ZIndex = 31
    label.Parent = frame

    -- Boost bar background
    local barBg = Instance.new('Frame')
    barBg.Name = 'BoostBarBg'
    barBg.Size = UDim2.new(0.85, 0, 0, 8)
    barBg.Position = UDim2.new(0.075, 0, 0, 24)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 31
    barBg.Parent = frame

    local barCorner = Instance.new('UICorner')
    barCorner.CornerRadius = UDim.new(0, 3)
    barCorner.Parent = barBg

    -- Boost bar fill
    local fill = Instance.new('Frame')
    fill.Name = 'BoostFill'
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 170, 255)
    fill.BorderSizePixel = 0
    fill.ZIndex = 32
    fill.Parent = barBg

    local fillCorner = Instance.new('UICorner')
    fillCorner.CornerRadius = UDim.new(0, 3)
    fillCorner.Parent = fill

    flightHudFrame = frame
    boostFillBar = fill

    -- Fade in
    frame.BackgroundTransparency = 1
    label.TextTransparency = 1
    barBg.BackgroundTransparency = 1
    fill.BackgroundTransparency = 1
    stroke.Transparency = 1

    TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 0.25 }):Play()
    TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
    TweenService:Create(barBg, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(fill, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 0.4 }):Play()
end

local function destroyFlightHud()
    if flightHudFrame then
        local frame = flightHudFrame
        flightHudFrame = nil
        boostFillBar = nil

        -- Fade out then destroy
        for _, child in ipairs(frame:GetDescendants()) do
            if child:IsA('TextLabel') then
                TweenService:Create(child, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
            elseif child:IsA('Frame') then
                TweenService:Create(child, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            elseif child:IsA('UIStroke') then
                TweenService:Create(child, TweenInfo.new(0.2), { Transparency = 1 }):Play()
            end
        end
        TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        Debris:AddItem(frame, 0.3)
    end
end

function FlightController._updateHud()
    if not boostFillBar then return end
    local ratio = boostStamina / BOOST_MAX
    boostFillBar.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)

    -- Color shift: blue when full, orange when low
    if ratio > 0.4 then
        boostFillBar.BackgroundColor3 = Color3.fromRGB(100, 170, 255)
    elseif ratio > 0.15 then
        boostFillBar.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
    else
        boostFillBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    end
end

-------------------------------------------------
-- Flight start/stop
-------------------------------------------------
local function startLocalFlight()
    local character = player.Character
    if not character then return end

    isFlying = true

    createWings(character, currentClassId)
    createTrail(character)
    createFlightHud()

    -- Disable default jump so Space = ascend
    local hum = character:FindFirstChildOfClass('Humanoid')
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    end

    heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        if not isFlying then return end
        local chr = player.Character
        if not chr then return end

        local humroot = chr:FindFirstChild('HumanoidRootPart')
        if not humroot then return end

        local velocity = getDesiredVelocity()

        -- Apply locally for responsiveness
        local force = humroot:FindFirstChild('FlyForce')
        if force then
            force.VectorVelocity = velocity
        end

        -- Tilt character into movement direction
        if velocity.Magnitude > 1 then
            local flatVel = Vector3.new(velocity.X, 0, velocity.Z)
            if flatVel.Magnitude > 0.5 then
                humroot.CFrame = CFrame.lookAt(humroot.Position, humroot.Position + flatVel)
            end
        end

        -- Boost stamina tick
        if isBoosting then
            boostStamina = math.max(0, boostStamina - BOOST_DRAIN_RATE * dt)
            if boostStamina <= 0 then isBoosting = false end
        else
            boostStamina = math.min(BOOST_MAX, boostStamina + BOOST_RECHARGE_RATE * dt)
        end
        FlightController._updateHud()

        -- Throttled server sync
        local now = os.clock()
        if now - lastVelocitySend >= SEND_RATE then
            lastVelocitySend = now
            FlightUpdateVelocityRemote:FireServer(velocity)
        end
    end)
end

local function stopLocalFlight()
    isFlying = false
    isBoosting = false
    boostStamina = BOOST_MAX

    removeWings()
    removeTrail()
    destroyFlightHud()

    if heartbeatConn then
        heartbeatConn:Disconnect()
        heartbeatConn = nil
    end

    -- Re-enable jumping
    local character = player.Character
    if character then
        local hum = character:FindFirstChildOfClass('Humanoid')
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        end
    end

    -- Reset key state
    for key, _ in pairs(keysHeld) do
        keysHeld[key] = false
    end
end

-------------------------------------------------
-- Input handling
-------------------------------------------------
local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end







    -- Movement keys while flying
    if isFlying then
        local mapped = KEY_MAP[input.KeyCode]
        if mapped then
            keysHeld[mapped] = true
        end
    end
end

local function onInputEnded(input, _gameProcessed)
    if isFlying then
        local mapped = KEY_MAP[input.KeyCode]
        if mapped then
            keysHeld[mapped] = false
        end
    end
end

-------------------------------------------------
-- Remote listeners (other players' effects)
-------------------------------------------------
local function onFlightStateChanged(flightPlayer, character, newState, classId)
    if flightPlayer == player then
        -- Our own state change
        if newState then
            currentClassId = classId or 'valkyrie'
            startLocalFlight()
        else
            stopLocalFlight()
        end
    else
        -- Another player toggled flight — show/hide their wings
        if newState then
            createWingsForOther(character, classId)
        else
            removeWingsForOther(character)
        end
    end
end

local createWingsForOther
local removeWingsForOther

-- Simple wing display for other players
local otherWings = {}

createWingsForOther = function(character, classId)
    if not character then return end
    if otherWings[character] then return end

    local humroot = character:FindFirstChild('HumanoidRootPart')
    if not humroot then return end

    local style = WING_STYLES[classId or 'valkyrie'] or WING_STYLES.valkyrie
    local model = Instance.new('Model')
    model.Name = 'ValkyrieWings'

    for pairIdx, wingDef in ipairs(style.pairs) do
        for _, side in ipairs({1, -1}) do
            local part = Instance.new('Part')
            part.Name = if side > 0 then 'RightWing' .. pairIdx else 'LeftWing' .. pairIdx
            part.Size = wingDef.size
            part.Transparency = style.transparency
            part.Color = style.color
            part.Material = style.material
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Massless = true
            part.Anchored = false
            part.Parent = model

            local weld = Instance.new('Weld')
            weld.Part0 = humroot
            weld.Part1 = part
            local xOff = wingDef.offset * side
            weld.C0 = CFrame.new(xOff, wingDef.yOff, 0.3) * CFrame.Angles(0, 0, math.rad(wingDef.angle * -side))
            weld.Parent = part
        end
    end

    model.Parent = character
    otherWings[character] = model
end

removeWingsForOther = function(character)
    if otherWings[character] then
        otherWings[character]:Destroy()
        otherWings[character] = nil
    end
end


-------------------------------------------------
-- Public API
-------------------------------------------------
function FlightController.isFlying(): boolean
    return isFlying
end

function FlightController.start()
    inputConn = UserInputService.InputBegan:Connect(onInputBegan)
    endInputConn = UserInputService.InputEnded:Connect(onInputEnded)
    stateConn = FlightStateChangedRemote.OnClientEvent:Connect(onFlightStateChanged)

    -- Clean up other player wings on character removal
    Players.PlayerRemoving:Connect(function(leavingPlayer)
        local chr = leavingPlayer.Character
        if chr then
            removeWingsForOther(chr)
        end
    end)

    -- If we rejoin / respawn, stop flight
    player.CharacterAdded:Connect(function()
        if isFlying then
            stopLocalFlight()
        end
    end)
end

function FlightController.stop()
    if inputConn then inputConn:Disconnect(); inputConn = nil end
    if endInputConn then endInputConn:Disconnect(); endInputConn = nil end
    if stateConn then stateConn:Disconnect(); stateConn = nil end
    stopLocalFlight()
end

return FlightController