--!strict
--[[
    FlightModule — Server-authoritative flight physics
    Ported from acquired $500K flight system.
    Uses LinearVelocity for smooth 60fps flight.
]]

local FlightModule = {}

local MAX_FLY_FORCE = 20000
local NETWORK_OWNERSHIP_CHECK_INTERVAL = 1
local PHYSICS_UPDATE_RATE = 0.016
local VELOCITY_DAMPING = 0.85
local MAX_VELOCITY = 120

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Debris = game:GetService('Debris')

local physicsConnections = {}
local networkChecks = {}
local lastPhysicsUpdate = {}
local velocityCache = {}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function assignNetworkOwnership(part, throttle)
    local now = os.clock()
    if velocityCache[part] and (now - (velocityCache[part].lastOwnershipCheck or 0)) < throttle then
        return
    end

    local closestPlayer = nil
    local closestDistance = math.huge
    local partPosition = part.Position

    for _, player in pairs(Players:GetPlayers()) do
        local character = player.Character
        local primaryPart = character and character.PrimaryPart
        if primaryPart then
            local distance = (primaryPart.Position - partPosition).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestPlayer = player
            end
        end
    end

    if not part:IsDescendantOf(workspace) then return end
    pcall(function()
        part:SetNetworkOwner(closestPlayer)
    end)

    if not velocityCache[part] then
        velocityCache[part] = {}
    end
    velocityCache[part].lastOwnershipCheck = now
end

local function setupNetworkOwnershipCheck(character)
    if networkChecks[character] then return end

    local humroot = character:FindFirstChild('HumanoidRootPart')
    if not humroot then return end

    networkChecks[character] = RunService.Heartbeat:Connect(function()
        if character:GetAttribute('IsFlying') then
            assignNetworkOwnership(humroot, NETWORK_OWNERSHIP_CHECK_INTERVAL)
        else
            if networkChecks[character] then
                networkChecks[character]:Disconnect()
                networkChecks[character] = nil
            end
        end
    end)
end

local function createFlyForce(chr)
    local humroot = chr:FindFirstChild('HumanoidRootPart')
    if not humroot then return nil end

    local oldForce = humroot:FindFirstChild('FlyForce')
    if oldForce then
        oldForce.Enabled = false
        Debris:AddItem(oldForce, 0.1)
    end

    local oldAtt = humroot:FindFirstChild('FlyAttachment')
    if oldAtt then
        Debris:AddItem(oldAtt, 0.1)
    end

    local att = Instance.new('Attachment')
    att.Name = 'FlyAttachment'
    att.Parent = humroot

    local linear = Instance.new('LinearVelocity')
    linear.Name = 'FlyForce'
    linear.Attachment0 = att
    linear.MaxForce = MAX_FLY_FORCE
    linear.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    linear.RelativeTo = Enum.ActuatorRelativeTo.World
    linear.Parent = humroot

    velocityCache[humroot] = {
        currentVelocity = Vector3.new(),
        targetVelocity = Vector3.new(),
        lastUpdate = os.clock(),
    }

    assignNetworkOwnership(humroot, 0)
    setupNetworkOwnershipCheck(chr)

    return linear
end

local function cleanUpPhysics(character)
    if physicsConnections[character] then
        physicsConnections[character]:Disconnect()
        physicsConnections[character] = nil
    end

    if networkChecks[character] then
        networkChecks[character]:Disconnect()
        networkChecks[character] = nil
    end

    local humroot = character:FindFirstChild('HumanoidRootPart')
    if humroot then
        velocityCache[humroot] = nil

        local force = humroot:FindFirstChild('FlyForce')
        if force then
            force.Enabled = false
            Debris:AddItem(force, 0.1)
        end

        local att = humroot:FindFirstChild('FlyAttachment')
        if att then
            Debris:AddItem(att, 0.1)
        end
    end
end

local function setHumanoidFlightStates(hum, enable)
    local statesToToggle = {
        Enum.HumanoidStateType.Physics,
        Enum.HumanoidStateType.PlatformStanding,
        Enum.HumanoidStateType.Flying,
    }

    local statesToDisable = {
        Enum.HumanoidStateType.FallingDown,
        Enum.HumanoidStateType.Running,
        Enum.HumanoidStateType.Jumping,
        Enum.HumanoidStateType.Seated,
        Enum.HumanoidStateType.Freefall,
        Enum.HumanoidStateType.GettingUp,
        Enum.HumanoidStateType.Climbing,
        Enum.HumanoidStateType.Swimming,
        Enum.HumanoidStateType.Landed,
    }

    for _, state in ipairs(statesToToggle) do
        hum:SetStateEnabled(state, enable)
    end

    if enable then
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        hum.PlatformStand = false
    else
        for _, state in ipairs(statesToDisable) do
            hum:SetStateEnabled(state, true)
        end
    end
end

function FlightModule.StartFlight(player)
    local chr = player.Character
    if not chr then return end

    local hum = chr:FindFirstChildOfClass('Humanoid')
    if not hum then return end

    cleanUpPhysics(chr)
    setHumanoidFlightStates(hum, true)

    local force = createFlyForce(chr)
    chr:SetAttribute('IsFlying', true)

    lastPhysicsUpdate[chr] = os.clock()

    local function clampVector3(vec, min, max)
        return Vector3.new(
            math.clamp(vec.X, min.X, max.X),
            math.clamp(vec.Y, min.Y, max.Y),
            math.clamp(vec.Z, min.Z, max.Z)
        )
    end

    physicsConnections[chr] = RunService.Stepped:Connect(function(_, deltaTime)
        if not (chr:GetAttribute('IsFlying') and force) then return end

        local now = os.clock()
        local humroot = chr:FindFirstChild('HumanoidRootPart')
        if not humroot or not velocityCache[humroot] then return end

        if now - lastPhysicsUpdate[chr] < PHYSICS_UPDATE_RATE then return end
        lastPhysicsUpdate[chr] = now

        local cache = velocityCache[humroot]
        cache.currentVelocity = lerp(
            cache.currentVelocity,
            Vector3.new(),
            VELOCITY_DAMPING * deltaTime * 60
        )

        cache.currentVelocity = clampVector3(
            cache.currentVelocity,
            Vector3.new(-MAX_VELOCITY, -MAX_VELOCITY, -MAX_VELOCITY),
            Vector3.new(MAX_VELOCITY, MAX_VELOCITY, MAX_VELOCITY)
        )

        force.VectorVelocity = cache.currentVelocity
        humroot.AssemblyLinearVelocity = cache.currentVelocity
        humroot.AssemblyAngularVelocity = Vector3.new()
    end)
end

function FlightModule.StopFlight(player)
    local chr = player.Character
    if not chr then return end

    local hum = chr:FindFirstChildOfClass('Humanoid')
    if not hum then return end

    chr:SetAttribute('IsFlying', false)
    setHumanoidFlightStates(hum, false)

    task.delay(0.2, function()
        cleanUpPhysics(chr)
    end)
end

function FlightModule.IsFlying(player)
    local chr = player.Character
    return chr and chr:GetAttribute('IsFlying') == true
end

function FlightModule.GetMaxVelocity()
    return MAX_VELOCITY
end

Players.PlayerRemoving:Connect(function(player)
    local chr = player.Character
    if chr then
        cleanUpPhysics(chr)
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        cleanUpPhysics(character)
    end)
end)

return FlightModule