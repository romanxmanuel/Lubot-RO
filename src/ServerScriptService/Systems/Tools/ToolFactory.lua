--!strict

local ToolFactory = {}

local function makeBladeHandle(itemDef)
    local handle = Instance.new('Part')
    handle.Name = 'Handle'
    handle.Size = Vector3.new(0.65, 4.25, 0.75)
    handle.Color = itemDef.handleColor or Color3.fromRGB(196, 205, 214)
    handle.Material = Enum.Material.Metal
    handle.CanCollide = false

    local guard = Instance.new('Part')
    guard.Name = 'Guard'
    guard.Size = Vector3.new(2.2, 0.25, 0.5)
    guard.Color = itemDef.accentColor or Color3.fromRGB(78, 138, 255)
    guard.Material = Enum.Material.Metal
    guard.CanCollide = false
    guard.Massless = true
    guard.Parent = handle

    local weld = Instance.new('WeldConstraint')
    weld.Part0 = handle
    weld.Part1 = guard
    weld.Parent = guard

    guard.CFrame = handle.CFrame * CFrame.new(0, -1.25, 0)

    return handle
end

local function buildToolBase(name: string, tooltip: string)
    local tool = Instance.new('Tool')
    tool.Name = name
    tool.ToolTip = tooltip
    tool.CanBeDropped = false
    tool.RequiresHandle = false
    return tool
end

local function makeItemHandle(itemDef)
    local handle = Instance.new('Part')
    handle.Name = 'Handle'
    handle.Size = Vector3.new(1.1, 1.1, 1.1)
    handle.Color = itemDef.handleColor or Color3.fromRGB(214, 224, 239)
    handle.Material = Enum.Material.SmoothPlastic
    handle.CanCollide = false

    local mesh = Instance.new('SpecialMesh')
    mesh.MeshType = itemDef.toolKind == 'card' and Enum.MeshType.Brick or Enum.MeshType.Sphere
    mesh.Scale = itemDef.toolKind == 'card' and Vector3.new(0.9, 1.2, 0.12) or Vector3.new(0.9, 0.9, 0.9)
    mesh.Parent = handle

    local accent = Instance.new('Part')
    accent.Name = 'Accent'
    accent.Size = itemDef.toolKind == 'card' and Vector3.new(0.9, 0.12, 0.08) or Vector3.new(0.35, 0.35, 0.35)
    accent.Color = itemDef.accentColor or Color3.fromRGB(245, 248, 255)
    accent.Material = itemDef.toolKind == 'card' and Enum.Material.Neon or Enum.Material.ForceField
    accent.CanCollide = false
    accent.Massless = true
    accent.Parent = handle

    local weld = Instance.new('WeldConstraint')
    weld.Part0 = handle
    weld.Part1 = accent
    weld.Parent = accent

    accent.CFrame = handle.CFrame * (itemDef.toolKind == 'card' and CFrame.new(0, 0.42, -0.02) or CFrame.new(0, 0.18, 0))

    return handle
end

local function applyItemAttributes(tool: Tool, itemDef)
    if itemDef.animationStyleOverride then
        tool:SetAttribute('AnimationStyleOverride', itemDef.animationStyleOverride)
    end
    if itemDef.allowsCombatStyleOnly then
        tool:SetAttribute('AllowsCombatStyleOnly', true)
    end
end

function ToolFactory.createWeaponTool(itemId: string, itemDef, onActivated)
    local tool = buildToolBase(itemDef.displayName, itemDef.description)
    tool.RequiresHandle = true
    tool:SetAttribute('ToolKind', 'Weapon')
    tool:SetAttribute('ItemId', itemId)

    local handle = makeBladeHandle(itemDef)
    handle.Parent = tool

    tool.Activated:Connect(function()
        onActivated(tool)
    end)

    return tool
end

function ToolFactory.createSkillTool(skillId: string, skillDef, onActivated)
    local tool = buildToolBase(skillDef.displayName, skillDef.description)
    tool:SetAttribute('ToolKind', 'Skill')
    tool:SetAttribute('SkillId', skillId)

    tool.Activated:Connect(function()
        onActivated(tool)
    end)

    return tool
end

function ToolFactory.createConsumableTool(itemId: string, itemDef, amount: number, onActivated)
    local tool = buildToolBase(string.format('%s x%d', itemDef.displayName, amount), itemDef.description)
    tool:SetAttribute('ToolKind', 'Consumable')
    tool:SetAttribute('ItemId', itemId)
    tool:SetAttribute('Amount', amount)

    tool.Activated:Connect(function()
        onActivated(tool)
    end)

    return tool
end

function ToolFactory.createSkinTool(itemId: string, itemDef, onActivated)
    local tool = buildToolBase(itemDef.displayName, itemDef.description)
    tool.RequiresHandle = true
    tool:SetAttribute('ToolKind', 'Skin')
    tool:SetAttribute('ItemId', itemId)
    applyItemAttributes(tool, itemDef)
    if itemDef.skinTemplateId then
        tool:SetAttribute('SkinTemplateId', itemDef.skinTemplateId)
    end

    local handle = makeItemHandle(itemDef)
    handle.Parent = tool

    tool.Activated:Connect(function()
        onActivated(tool)
    end)

    return tool
end

function ToolFactory.createInventoryItemTool(itemId: string, itemDef, amount: number)
    local tool = buildToolBase(string.format('%s x%d', itemDef.displayName, amount), itemDef.description)
    tool.RequiresHandle = true
    tool:SetAttribute('ToolKind', itemDef.toolKind or 'Item')
    tool:SetAttribute('ItemId', itemId)
    tool:SetAttribute('Amount', amount)
    applyItemAttributes(tool, itemDef)

    local handle = makeItemHandle(itemDef)
    handle.Parent = tool

    return tool
end

return ToolFactory
