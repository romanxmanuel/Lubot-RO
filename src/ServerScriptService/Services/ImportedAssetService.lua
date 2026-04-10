--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')

local ImportedAssetData = require(ReplicatedStorage.GameData.ImportedAssets.ImportedAssetData)
local ItemData = require(ReplicatedStorage.GameData.Items.ItemData)

local ImportedAssetService = {
    Name = 'ImportedAssetService',
}

local dependencies = nil

local function getGameParts(): Instance?
    return ReplicatedStorage:FindFirstChild('GameParts')
end

local function ensureFolder(parent: Instance, name: string): Folder
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA('Folder') then
        return existing
    end

    local folder = Instance.new('Folder')
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function getImportedRoot(): Folder?
    local gameParts = getGameParts()
    if not gameParts then
        return nil
    end
    local importedRoot = gameParts:FindFirstChild('ImportedAssets')
    if importedRoot and importedRoot:IsA('Folder') then
        return importedRoot
    end
    return nil
end

local function getAssetFolderByItemId(itemId: string): Folder?
    local importedRoot = getImportedRoot()
    if not importedRoot then
        return nil
    end

    for _, assetDef in pairs(ImportedAssetData) do
        if assetDef.itemId == itemId then
            local folder = importedRoot:FindFirstChild(assetDef.folderName)
            if folder and folder:IsA('Folder') then
                return folder
            end
        end
    end

    return nil
end

local function getTemplateTool(itemId: string): Tool?
    local assetFolder = getAssetFolderByItemId(itemId)
    if not assetFolder then
        return nil
    end

    local template = assetFolder:FindFirstChild('ToolTemplate')
    if template and template:IsA('Tool') then
        return template
    end

    return nil
end

local function getPickupFolder(): Folder?
    local maps = Workspace:FindFirstChild('Maps')
    local zoltraak = maps and maps:FindFirstChild('Zoltraak')
    local playerUse = zoltraak and zoltraak:FindFirstChild('PlayerUse')
    if not playerUse then
        return nil
    end
    return ensureFolder(playerUse, 'ImportedAssetPickups')
end

local function grantImportedItem(player: Player, itemId: string)
    dependencies.InventoryService.addItem(player, itemId, 1)
    dependencies.Runtime.SystemMessage:FireClient(player, 'Imported item acquired: ' .. itemId)
end

local function configureImportedLocalScriptActivation(tool: Tool)
    local localScriptStates: { [LocalScript]: boolean } = {}

    for _, descendant in ipairs(tool:GetDescendants()) do
        if descendant:IsA('LocalScript') then
            localScriptStates[descendant] = descendant.Enabled
            descendant.Enabled = false
        end
    end

    if next(localScriptStates) == nil then
        return
    end

    local function setEnabled(isEnabled: boolean)
        for localScript, originalEnabled in pairs(localScriptStates) do
            if localScript.Parent then
                localScript.Enabled = isEnabled and originalEnabled
            end
        end
    end

    setEnabled(false)

    tool.Equipped:Connect(function()
        setEnabled(true)
    end)

    tool.Unequipped:Connect(function()
        setEnabled(false)
    end)

    tool.AncestryChanged:Connect(function()
        if tool.Parent and tool.Parent:IsA('Backpack') then
            setEnabled(false)
        end
    end)
end

local function createPickupModel(assetDef, itemDef): Model
    local model = Instance.new('Model')
    model.Name = assetDef.pickupName

    local root = Instance.new('Part')
    root.Name = 'PickupRoot'
    root.Anchored = true
    root.CanCollide = false
    root.Transparency = 1
    root.Size = Vector3.new(4, 5, 4)
    root.Parent = model
    model.PrimaryPart = root

    local pedestal = Instance.new('Part')
    pedestal.Name = 'Pedestal'
    pedestal.Anchored = true
    pedestal.CanCollide = true
    pedestal.Material = Enum.Material.Slate
    pedestal.Color = Color3.fromRGB(67, 76, 92)
    pedestal.Size = Vector3.new(4.6, 1.1, 4.6)
    pedestal.Parent = model

    local rune = Instance.new('Part')
    rune.Name = 'Rune'
    rune.Anchored = true
    rune.CanCollide = false
    rune.Shape = Enum.PartType.Cylinder
    rune.Material = Enum.Material.Neon
    rune.Color = itemDef.accentColor or Color3.fromRGB(255, 142, 84)
    rune.Transparency = 0.12
    rune.Size = Vector3.new(0.14, 4.9, 4.9)
    rune.Parent = model

    local previewTool = getTemplateTool(assetDef.itemId)
    local previewHandle = previewTool and previewTool:FindFirstChild('Handle')
    if previewHandle and previewHandle:IsA('BasePart') then
        local display = previewHandle:Clone()
        display.Name = 'DisplayHandle'
        display.Anchored = true
        display.CanCollide = false
        for _, descendant in ipairs(display:GetDescendants()) do
            if descendant:IsA('Script') or descendant:IsA('LocalScript') or descendant:IsA('ModuleScript') then
                descendant:Destroy()
            end
        end
        display.Parent = model
    end

    local prompt = Instance.new('ProximityPrompt')
    prompt.Name = 'PickupPrompt'
    prompt.ActionText = 'Pick Up'
    prompt.ObjectText = assetDef.pickupPrompt
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 12
    prompt.Parent = root

    prompt.Triggered:Connect(function(player)
        grantImportedItem(player, assetDef.itemId)
    end)

    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'PickupLabel'
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 34
    billboard.Size = UDim2.fromOffset(210, 50)
    billboard.StudsOffset = Vector3.new(0, 6.8, 0)
    billboard.Parent = root

    local frame = Instance.new('Frame')
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
    frame.BackgroundTransparency = 0.18
    frame.BorderSizePixel = 0
    frame.Parent = billboard

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new('UIStroke')
    stroke.Color = itemDef.accentColor or Color3.fromRGB(255, 142, 84)
    stroke.Thickness = 1.1
    stroke.Transparency = 0.12
    stroke.Parent = frame

    local label = Instance.new('TextLabel')
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = itemDef.displayName
    label.TextSize = 15
    label.TextColor3 = Color3.fromRGB(255, 246, 226)
    label.Parent = frame

    return model
end

local function positionPickupModel(model: Model, cframe: CFrame)
    local root = model.PrimaryPart
    if not root then
        return
    end

    root.CFrame = cframe

    local pedestal = model:FindFirstChild('Pedestal')
    if pedestal and pedestal:IsA('BasePart') then
        pedestal.CFrame = cframe * CFrame.new(0, -2.2, 0)
    end

    local rune = model:FindFirstChild('Rune')
    if rune and rune:IsA('BasePart') then
        rune.CFrame = cframe * CFrame.new(0, -2.66, 0) * CFrame.Angles(0, 0, math.rad(90))
    end

    local display = model:FindFirstChild('DisplayHandle')
    if display and display:IsA('BasePart') then
        display.CFrame = cframe * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-8), math.rad(25), math.rad(90))
    end
end

function ImportedAssetService.init(deps)
    dependencies = deps
end

function ImportedAssetService.start()
    local pickupFolder = getPickupFolder()
    if not pickupFolder then
        return
    end

    for _, assetDef in pairs(ImportedAssetData) do
        local itemDef = ItemData[assetDef.itemId]
        if itemDef and assetDef.pickupCFrame then
            local existing = pickupFolder:FindFirstChild(assetDef.pickupName)
            if existing then
                existing:Destroy()
            end
            local model = createPickupModel(assetDef, itemDef)
            positionPickupModel(model, assetDef.pickupCFrame)
            model.Parent = pickupFolder
        end
    end
end

function ImportedAssetService.createToolClone(itemId: string): Tool?
    local template = getTemplateTool(itemId)
    if not template then
        return nil
    end

    local clone = template:Clone()
    local itemDef = ItemData[itemId]
    if itemDef and itemDef.displayName then
        clone.Name = itemDef.displayName
    end
    clone:SetAttribute('ImportedAssetId', template:GetAttribute('ImportedAssetId') or itemId)
    clone:SetAttribute('ImportedToolTemplate', template.Name)
    clone:SetAttribute('ImportedInputPriority', true)
    configureImportedLocalScriptActivation(clone)
    return clone
end

return ImportedAssetService
