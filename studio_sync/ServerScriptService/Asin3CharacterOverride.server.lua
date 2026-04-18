local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local TEMPLATE_NAME = "asin3"
local VISUAL_NAME = "Asin3Visual"
local ANCHOR_NAME = "Asin3Anchor"
local TARGET_HEIGHT = 6.5

local function firstBasePart(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            return d
        end
    end
    return nil
end

local function getTemplateModel()
    local stored = ServerStorage:FindFirstChild(TEMPLATE_NAME)
    if stored and stored:IsA("Model") then
        return stored
    end

    local workspaceTemplate = Workspace:FindFirstChild(TEMPLATE_NAME)
    if workspaceTemplate and workspaceTemplate:IsA("Model") then
        workspaceTemplate.Parent = ServerStorage
        return workspaceTemplate
    end

    return nil
end

local function scaleModelToTargetHeight(model, targetHeight)
    if not model:IsA("Model") then
        return
    end

    local size = model:GetExtentsSize()
    if size.Y <= 0 then
        return
    end

    local ratio = targetHeight / size.Y
    if math.abs(ratio - 1) > 0.01 then
        local currentScale = model:GetScale()
        model:ScaleTo(currentScale * ratio)
    end
end

local function clearLegacyAppearance(character)
    local oldVisual = character:FindFirstChild(VISUAL_NAME)
    if oldVisual then
        oldVisual:Destroy()
    end

    local oldAnchor = character:FindFirstChild(ANCHOR_NAME)
    if oldAnchor then
        oldAnchor:Destroy()
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
            child:Destroy()
        end
    end

    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
            d:Destroy()
        end
    end
end

local function hideDefaultCharacterVisuals(character, visualModel)
    for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") and not d:IsDescendantOf(visualModel) then
            if d.Name ~= "HumanoidRootPart" then
                d.Transparency = 1
            end
            d.CanCollide = false
        elseif d:IsA("Decal") and not d:IsDescendantOf(visualModel) then
            d.Transparency = 1
        end
    end
end

local function collectBodyParts(character)
    local function gather(names)
        local parts = {}
        for _, name in ipairs(names) do
            local p = character:FindFirstChild(name)
            if p and p:IsA("BasePart") then
                table.insert(parts, p)
            end
        end
        return parts
    end

    local groups = {
        head = gather({ "Head" }),
        torso = gather({ "UpperTorso", "LowerTorso", "Torso" }),
        leftArm = gather({ "LeftUpperArm", "LeftLowerArm", "LeftHand", "Left Arm" }),
        rightArm = gather({ "RightUpperArm", "RightLowerArm", "RightHand", "Right Arm" }),
        leftLeg = gather({ "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "Left Leg" }),
        rightLeg = gather({ "RightUpperLeg", "RightLowerLeg", "RightFoot", "Right Leg" }),
        root = gather({ "HumanoidRootPart" }),
    }

    groups.all = {}
    for _, group in ipairs({ groups.head, groups.torso, groups.leftArm, groups.rightArm, groups.leftLeg, groups.rightLeg, groups.root }) do
        for _, p in ipairs(group) do
            table.insert(groups.all, p)
        end
    end

    return groups
end

local function nearestPart(parts, worldPos)
    local best = nil
    local bestDist = math.huge
    for _, p in ipairs(parts) do
        local d = (p.Position - worldPos).Magnitude
        if d < bestDist then
            best = p
            bestDist = d
        end
    end
    return best
end

local function hasLeftHint(name)
    return name:find("left", 1, true) ~= nil
        or name:match("^l[_%-]") ~= nil
        or name:match("[_%-%s]l[_%-%s]") ~= nil
end

local function hasRightHint(name)
    return name:find("right", 1, true) ~= nil
        or name:match("^r[_%-]") ~= nil
        or name:match("[_%-%s]r[_%-%s]") ~= nil
end

local function pickAttachPart(meshPart, rig, state)
    local n = string.lower(meshPart.Name)

    if n:find("face") or n:find("head") then
        return nearestPart(rig.head, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
    end

    if n:find("arm") or n:find("hand") then
        if hasLeftHint(n) then
            return nearestPart(rig.leftArm, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
        end
        if hasRightHint(n) then
            return nearestPart(rig.rightArm, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
        end

        local rootPart = rig.root[1]
        if rootPart then
            local localPos = rootPart.CFrame:PointToObjectSpace(meshPart.Position)
            if math.abs(localPos.X) > 0.05 then
                if localPos.X < 0 then
                    state.leftArmNeutral += 1
                    return nearestPart(rig.leftArm, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
                else
                    state.rightArmNeutral += 1
                    return nearestPart(rig.rightArm, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
                end
            end
        end

        if state.leftArmNeutral <= state.rightArmNeutral then
            state.leftArmNeutral += 1
            return nearestPart(rig.leftArm, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
        else
            state.rightArmNeutral += 1
            return nearestPart(rig.rightArm, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
        end
    end

    if n:find("leg") or n:find("foot") or n:find("shoe") or n:find("thigh") or n:find("calf") then
        if hasLeftHint(n) then
            return nearestPart(rig.leftLeg, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
        end
        if hasRightHint(n) then
            return nearestPart(rig.rightLeg, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
        end

        if state.leftLegNeutral <= state.rightLegNeutral then
            state.leftLegNeutral += 1
            return nearestPart(rig.leftLeg, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
        else
            state.rightLegNeutral += 1
            return nearestPart(rig.rightLeg, meshPart.Position) or nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
        end
    end

    if n:find("torso") or n:find("chest") or n:find("cloth") or n:find("body") or n:find("hood") or n:find("cape") or n:find("accessor") then
        return nearestPart(rig.torso, meshPart.Position) or nearestPart(rig.head, meshPart.Position) or nearestPart(rig.all, meshPart.Position)
    end

    return nearestPart(rig.all, meshPart.Position)
end

local function attachVisualToRig(character, visualModel)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    local anchor = Instance.new("Part")
    anchor.Name = ANCHOR_NAME
    anchor.Size = Vector3.new(1, 1, 1)
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Massless = true
    anchor.CFrame = root.CFrame
    anchor.Parent = character

    local rootWeld = Instance.new("WeldConstraint")
    rootWeld.Part0 = root
    rootWeld.Part1 = anchor
    rootWeld.Parent = anchor

    local rig = collectBodyParts(character)
    local state = {
        leftArmNeutral = 0,
        rightArmNeutral = 0,
        leftLegNeutral = 0,
        rightLegNeutral = 0,
    }

    for _, d in ipairs(visualModel:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.Massless = true

            local attachTo = pickAttachPart(d, rig, state) or anchor
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = attachTo
            weld.Part1 = d
            weld.Parent = d
        end
    end
end

local function applyAsin3Visual(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    local template = getTemplateModel()

    if not humanoid or not root or not template then
        return
    end

    clearLegacyAppearance(character)

    local visual = template:Clone()
    visual.Name = VISUAL_NAME
    visual.Parent = character

    if not visual.PrimaryPart then
        visual.PrimaryPart = firstBasePart(visual)
    end

    scaleModelToTargetHeight(visual, TARGET_HEIGHT)
    visual:PivotTo(root.CFrame)

    local bboxCf, size = visual:GetBoundingBox()
    local desiredBottomY = root.Position.Y - (humanoid.HipHeight + (root.Size.Y * 0.5))
    local desiredCenter = Vector3.new(root.Position.X, desiredBottomY + (size.Y * 0.5), root.Position.Z)
    local delta = desiredCenter - bboxCf.Position
    visual:PivotTo(visual:GetPivot() + delta)

    attachVisualToRig(character, visual)
    hideDefaultCharacterVisuals(character, visual)
end

local function onCharacterAdded(character)
    task.delay(0.15, function()
        if character.Parent then
            applyAsin3Visual(character)
        end
    end)
end

getTemplateModel()

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(onCharacterAdded)
end)

for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end
