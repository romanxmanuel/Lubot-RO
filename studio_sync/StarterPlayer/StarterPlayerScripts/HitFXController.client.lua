local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Combat = ReplicatedStorage:WaitForChild("Combat")
local CameraShaker = require(Combat:WaitForChild("CameraShaker"))
local SlowMoService = require(Combat:WaitForChild("SlowMoService"))

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local impactRemote = remotes:WaitForChild("PlayImpactFX")
local presentationRemote = remotes:WaitForChild("PlayPresentationFX")

local shaker = CameraShaker.new(camera)
local slowMo = SlowMoService.new()

local defaultFOV = 70
local blur = Lighting:FindFirstChild("CombatBlur") or Instance.new("BlurEffect")
blur.Name = "CombatBlur"
blur.Size = 0
blur.Parent = Lighting

local function tween(obj, duration, props)
    local tw = TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

impactRemote.OnClientEvent:Connect(function(package)
    if type(package) ~= "table" then
        return
    end

    shaker:AddShake({
        Amplitude = package.ShakeCrackAmplitude,
        Rotation = package.ShakeCrackRotation,
        Frequency = package.ShakeCrackFrequency,
        Duration = package.ShakeCrackDuration,
    })

    shaker:AddShake({
        Amplitude = package.ShakeMassAmplitude,
        Rotation = package.ShakeMassRotation,
        Frequency = package.ShakeMassFrequency,
        Duration = package.ShakeMassDuration,
    })

    if package.FOVPunch and package.FOVPunch > 0 then
        camera.FieldOfView = defaultFOV + package.FOVPunch
        tween(camera, 0.14, { FieldOfView = defaultFOV })
    end

    if package.BlurPulse and package.BlurPulse > 0 then
        blur.Size = package.BlurPulse
        tween(blur, package.BlurDuration or 0.08, { Size = 0 })
    end

    if package.SlowMoScale and package.HitStop then
        slowMo:Apply(package.SlowMoScale, package.HitStop, {
            restoreDuration = package.SlowMoDuration or 0.1,
        })
    end
end)

presentationRemote.OnClientEvent:Connect(function(payload)
    if type(payload) ~= "table" then
        return
    end

    if payload.Kind == "CastFlash" then
        local flash = Instance.new("ColorCorrectionEffect")
        flash.Brightness = 0.12
        flash.Contrast = 0.08
        flash.Saturation = -0.05
        flash.Parent = Lighting
        task.delay(0.08, function()
            if flash and flash.Parent then
                flash:Destroy()
            end
        end)
    elseif payload.Kind == "CustomFOV" then
        camera.FieldOfView = defaultFOV + (payload.Amount or 2)
        tween(camera, 0.12, { FieldOfView = defaultFOV })
    end
end)