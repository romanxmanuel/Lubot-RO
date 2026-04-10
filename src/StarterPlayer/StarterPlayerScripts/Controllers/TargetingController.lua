--!strict

local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')

local TargetingController = {
    Name = 'TargetingController',
}

local localPlayer = Players.LocalPlayer
local trackedBoss: Model? = nil
local trackedTarget: Model? = nil

local function getRoot()
    local character = localPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild('HumanoidRootPart') :: BasePart?
end

local function updateTargets()
    local root = getRoot()
    if not root then
        trackedBoss = nil
        trackedTarget = nil
        return
    end

    local enemyFolder = Workspace:FindFirstChild('SpawnedDuringPlay')
    enemyFolder = enemyFolder and enemyFolder:FindFirstChild('Enemies')
    if not enemyFolder then
        trackedBoss = nil
        trackedTarget = nil
        return
    end

    local nearestBoss = nil
    local nearestBossDistance = 120
    local nearestTarget = nil
    local nearestTargetDistance = 50

    for _, child in ipairs(enemyFolder:GetChildren()) do
        if child:IsA('Model') then
            local currentHp = child:GetAttribute('CurrentHP') or 0
            local maxHp = child:GetAttribute('MaxHP') or 0
            local rootPart = child.PrimaryPart or child:FindFirstChild('Root')
            if currentHp > 0 and maxHp > 0 and rootPart and rootPart:IsA('BasePart') then
                local distance = (rootPart.Position - root.Position).Magnitude
                if distance <= nearestTargetDistance then
                    nearestTarget = child
                    nearestTargetDistance = distance
                end

                if child:GetAttribute('IsBoss') and distance <= nearestBossDistance then
                    nearestBoss = child
                    nearestBossDistance = distance
                end
            end
        end
    end

    trackedBoss = nearestBoss
    trackedTarget = nearestTarget
end

function TargetingController.init()
    return nil
end

function TargetingController.start()
    task.spawn(function()
        while true do
            updateTargets()
            task.wait(0.15)
        end
    end)
end

function TargetingController.getTrackedBoss()
    return trackedBoss
end

function TargetingController.getTrackedTarget()
    return trackedTarget
end

return TargetingController
