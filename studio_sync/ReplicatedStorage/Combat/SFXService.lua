local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local AssetRegistry = require(script.Parent.AssetRegistry)
local MasterConfig = require(ReplicatedStorage:WaitForChild("MasterConfig"))

local SFXService = {}

local function playOneShot(id, parent, volume)
    if not id or id == "" or id == "rbxassetid://0" then
        return nil
    end

    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Volume = volume or 1
    sound.Parent = parent or SoundService
    sound:Play()
    Debris:AddItem(sound, 3)
    return sound
end

function SFXService.PlayDash(parent)
    return playOneShot(MasterConfig.DashSoundId or AssetRegistry.SFX.Dash, parent, MasterConfig.DashSoundVolume or 0.95)
end

function SFXService.PlayHit(index, parent)
    local configId = (MasterConfig.PunchSounds and MasterConfig.PunchSounds[index]) or nil
    local soundId = configId or AssetRegistry.SFX["Hit" .. tostring(index)]
    local volume = (MasterConfig.PunchSoundVolumes and MasterConfig.PunchSoundVolumes[index]) or 1
    return playOneShot(soundId, parent, volume)
end

return SFXService
