local Players = game:GetService("Players")

local TargetingService = {}

local VFX_NAME_BLOCKLIST = {
    ["Hakari Aura"] = true,
    ["Meteor"] = true,
    ["Portal"] = true,
}

local function isValidHostileTarget(model, selfCharacter)
    if not model or model == selfCharacter or not model:IsA("Model") then
        return false
    end

    if Players:GetPlayerFromCharacter(model) then
        return false
    end

    if VFX_NAME_BLOCKLIST[model.Name] then
        return false
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then
        return false
    end

    return true
end

function TargetingService.GetNearestTarget(character, maxRange)
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return nil
    end

    local nearest, bestDist = nil, maxRange or 90
    for _, model in ipairs(workspace:GetChildren()) do
        if isValidHostileTarget(model, character) then
            local hrp = model.HumanoidRootPart
            local dist = (hrp.Position - root.Position).Magnitude
            if dist < bestDist then
                bestDist = dist
                nearest = model
            end
        end
    end

    return nearest
end

return TargetingService