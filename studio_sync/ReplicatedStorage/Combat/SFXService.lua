local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local AssetRegistry = require(script.Parent.AssetRegistry)

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
    return playOneShot(AssetRegistry.SFX.Dash, parent, 0.95)
end

function SFXService.PlayHit(index, parent)
    return playOneShot(AssetRegistry.SFX["Hit" .. tostring(index)], parent, 1)
end

return SFXService
