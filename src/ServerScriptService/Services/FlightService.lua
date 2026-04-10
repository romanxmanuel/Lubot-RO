--!strict
--[[
    FlightService — Server authority for Valkyrie flight system.
    Validates class, manages flight state, replicates effects.
]]

local FlightService = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

local FlightModule = require(ReplicatedStorage.Shared.FlightModule)
local ClassStageDefs = require(ReplicatedStorage.Shared.DataDefs.Progression.ClassStageDefs)

local PlayerDataService = nil -- lazy-loaded to avoid circular require

local VALKYRIE_ARCHETYPE = 'valkyrie_path'
local TOGGLE_COOLDOWN = 0.5
local lastToggleTime = {}

local function isValkyrieClass(classId: string): boolean
    local classDef = ClassStageDefs[classId]
    return classDef ~= nil and classDef.archetypeId == VALKYRIE_ARCHETYPE
end

function FlightService.init()
    -- Lazy-load PlayerDataService (it inits before us in ServerBootstrap)
    local Services = game:GetService('ServerScriptService').Services
    PlayerDataService = require(Services.PlayerDataService)
end

function FlightService.canFly(player: Player): boolean
    if not PlayerDataService then return false end
    local profile = PlayerDataService.getOrCreateProfile(player)
    if not profile then return false end
    return isValkyrieClass(profile.classId or '')
end

function FlightService.toggleFlight(player: Player): boolean
    if not FlightService.canFly(player) then return false end

    -- Rate-limit toggles
    local now = os.clock()
    if lastToggleTime[player] and (now - lastToggleTime[player]) < TOGGLE_COOLDOWN then
        return false
    end
    lastToggleTime[player] = now

    local chr = player.Character
    if not chr then return false end

    local isFlying = FlightModule.IsFlying(player)

    if isFlying then
        FlightModule.StopFlight(player)
    else
        FlightModule.StartFlight(player)
    end

    local newState = not isFlying

    -- Replicate state to all clients
    local remotes = ReplicatedStorage:FindFirstChild('Remotes')
    if remotes then
        local flightEvent = remotes:FindFirstChild('FlightStateChanged')
        if flightEvent then
            local profile = PlayerDataService.getOrCreateProfile(player)
            local classId = profile and profile.classId or 'valkyrie'
            flightEvent:FireAllClients(player, chr, newState, classId)
        end
    end

    return newState
end

function FlightService.handleEffectsReplicate(player: Player, effectType: string, extraParams: any)
    local chr = player.Character
    if not chr or not chr:IsDescendantOf(workspace) then return end
    if not FlightModule.IsFlying(player) then return end

    local remotes = ReplicatedStorage:FindFirstChild('Remotes')
    if not remotes then return end

    local effectsEvent = remotes:FindFirstChild('FlightEffectsReplicate')
    if not effectsEvent then return end

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            effectsEvent:FireClient(otherPlayer, effectType, chr, extraParams)
        end
    end
end

function FlightService.forceStopFlight(player: Player)
    if FlightModule.IsFlying(player) then
        FlightModule.StopFlight(player)

        local remotes = ReplicatedStorage:FindFirstChild('Remotes')
        if remotes then
            local flightEvent = remotes:FindFirstChild('FlightStateChanged')
            if flightEvent and player.Character then
                flightEvent:FireAllClients(player, player.Character, false, '')
            end
        end
    end
end

function FlightService.start()
    local remotes = ReplicatedStorage:WaitForChild('Remotes')

    local toggleRemote = remotes:WaitForChild('ToggleFlight')
    local velocityRemote = remotes:WaitForChild('FlightUpdateVelocity')

    toggleRemote.OnServerEvent:Connect(function(player)
        FlightService.toggleFlight(player)
    end)

    velocityRemote.OnServerEvent:Connect(function(player, velocity)
        if not FlightModule.IsFlying(player) then return end
        if typeof(velocity) ~= 'Vector3' then return end

        -- Clamp to max velocity to prevent speed hacks
        local maxVel = FlightModule.GetMaxVelocity()
        if velocity.Magnitude > maxVel * 1.05 then
            velocity = velocity.Unit * maxVel
        end

        local chr = player.Character
        if not chr then return end
        local humroot = chr:FindFirstChild('HumanoidRootPart')
        if not humroot then return end

        local force = humroot:FindFirstChild('FlyForce')
        if force then
            force.VectorVelocity = velocity
        end
    end)

    -- Force stop flight on death
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(chr)
            local hum = chr:WaitForChild('Humanoid')
            hum.Died:Connect(function()
                FlightService.forceStopFlight(p)
            end)
        end)
    end)

    -- Handle existing players
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local hum = p.Character:FindFirstChildOfClass('Humanoid')
            if hum then
                hum.Died:Connect(function()
                    FlightService.forceStopFlight(p)
                end)
            end
        end
    end
end

return FlightService