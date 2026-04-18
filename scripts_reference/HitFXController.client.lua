-- HitFXController.client.lua
-- Path: StarterPlayerScripts/HitFXController
-- SOURCE: Copied from ChatGPT design session https://chatgpt.com/c/69e31ae1-fbc8-83ea-be7f-0989d3156054

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraShaker = require(ReplicatedStorage.Combat.CameraShaker)
local shaker = CameraShaker.new(camera)

local remote = ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("PlayImpactFX")
local defaultFOV = 70

local blur = Lighting:FindFirstChild("CombatBlur") or Instance.new("BlurEffect")
blur.Name = "CombatBlur"
blur.Size = 0
blur.Parent = Lighting

local function tween(obj, duration, props)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tw = TweenService:Create(obj, info, props)
	tw:Play()
	return tw
end

local function playImpact(package)
	-- Crack layer: high frequency, short — sells violent collision
	shaker:AddShake({
		Amplitude = package.ShakeCrackAmplitude,
		Rotation = package.ShakeCrackRotation,
		Frequency = package.ShakeCrackFrequency,
		Duration = package.ShakeCrackDuration,
	})
	-- Mass layer: low frequency, long — sells weapon weight
	shaker:AddShake({
		Amplitude = package.ShakeMassAmplitude,
		Rotation = package.ShakeMassRotation,
		Frequency = package.ShakeMassFrequency,
		Duration = package.ShakeMassDuration,
	})
	-- FOV punch
	camera.FieldOfView = defaultFOV + package.FOVPunch
	tween(camera, 0.14, {FieldOfView = defaultFOV})
	-- Blur pulse
	if package.BlurPulse and package.BlurPulse > 0 then
		blur.Size = package.BlurPulse
		tween(blur, package.BlurDuration or 0.08, {Size = 0})
	end
end

remote.OnClientEvent:Connect(playImpact)
