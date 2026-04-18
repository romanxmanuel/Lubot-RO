local Debris = game:GetService("Debris")
local AssetRegistry = require(script.Parent.AssetRegistry)

local VFXService = {}

local function getVfxDropFolder()
    return workspace:FindFirstChild(AssetRegistry.VFX.VfxDropsFolder)
end

local function placeClone(clone, cframe)
    if not cframe then
        return
    end

    if clone:IsA("Model") then
        clone:PivotTo(cframe)
    elseif clone:IsA("BasePart") then
        clone.CFrame = cframe
    end
end

function VFXService.SpawnDrop(name, cframe, lifetime)
    local folder = getVfxDropFolder()
    if not folder then
        warn("[VFXService] Missing VFX folder:", AssetRegistry.VFX.VfxDropsFolder)
        return nil
    end

    local template = folder:FindFirstChild(name)
    if not template then
        warn("[VFXService] Missing VFX template:", name)
        return nil
    end

    local clone = template:Clone()

    -- Keep community VFX intact: do not rewrite particle rates, anchors, collisions, or scripts.
    placeClone(clone, cframe)
    clone.Parent = workspace

    if lifetime and lifetime > 0 then
        Debris:AddItem(clone, lifetime)
    end

    return clone
end

return VFXService