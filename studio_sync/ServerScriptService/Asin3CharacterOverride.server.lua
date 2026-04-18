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

local function attachVisualToRoot(character, visualModel)
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

    for _, d in ipairs(visualModel:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
            d.Massless = true

            local weld = Instance.new("WeldConstraint")
            weld.Part0 = anchor
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

    local _, size = visual:GetBoundingBox()
    local pivot = visual:GetPivot()
    local desiredBottomY = root.Position.Y - (humanoid.HipHeight + (root.Size.Y * 0.5))
    local currentBottomY = pivot.Position.Y - (size.Y * 0.5)
    visual:PivotTo(pivot * CFrame.new(0, desiredBottomY - currentBottomY, 0))

    attachVisualToRoot(character, visual)
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
