--!strict

local InsertService = game:GetService('InsertService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local MarketplaceVfxService = {
    Name = 'MarketplaceVfxService',
}

local VFX_ASSET_ID = 7564537285
local TEMPLATE_FOLDER_NAME = 'MarketplaceVfx7564537285'

local TEMPLATE_SOURCES = {
    ArcFlare = { 'FancySlash', 'FancySlashLight', 'FancySlashDark' },
    NovaStrike = { 'FancyBall', 'GravityBallShockwave', 'CircleShockwave' },
    VortexSpin = { 'GlitchWind', 'CircleShockwave', 'DecalShockwave' },
    CometDrop = { 'FireBall', 'FireBallB', 'ExplosionB' },
    RazorOrbit = { 'DecalShockwave', 'CircleShockwave', 'FancySphere' },
}

local function ensureFolder(parent: Instance, name: string): Folder
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA('Folder') then
        return existing
    end

    if existing then
        existing:Destroy()
    end

    local folder = Instance.new('Folder')
    folder.Name = name
    folder.Parent = parent
    return folder
end

local function getFxRoot(): Folder?
    local gameParts = ReplicatedStorage:FindFirstChild('GameParts')
    if not gameParts then
        return nil
    end
    return ensureFolder(gameParts, 'FX')
end

local function stripScripts(root: Instance)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA('Script') or descendant:IsA('LocalScript') or descendant:IsA('ModuleScript') then
            descendant:Destroy()
        end
    end
end

local function normalizePart(part: BasePart)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Massless = true
end

local function normalizeTemplate(instance: Instance)
    if instance:IsA('BasePart') then
        normalizePart(instance)
    end

    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA('BasePart') then
            normalizePart(descendant)
        end
    end
end

local function createFallbackTemplate(name: string): BasePart
    local fallback = Instance.new('Part')
    fallback.Name = name
    fallback.Shape = Enum.PartType.Ball
    fallback.Size = Vector3.new(2, 2, 2)
    fallback.Material = Enum.Material.Neon
    fallback.Color = Color3.fromRGB(124, 237, 255)
    fallback.Transparency = 0.2
    normalizePart(fallback)
    return fallback
end

local function collectSourcePool(container: Instance): { Instance }
    local pool = {}
    table.insert(pool, container)
    for _, descendant in ipairs(container:GetDescendants()) do
        table.insert(pool, descendant)
    end
    return pool
end

local function findTemplateCandidate(pool: { Instance }, names: { string }): Instance?
    for _, sourceName in ipairs(names) do
        for _, instance in ipairs(pool) do
            if instance.Name == sourceName and (instance:IsA('BasePart') or instance:IsA('Model')) then
                return instance
            end
        end
    end
    return nil
end

local function loadAssetContainer()
    local ok, loaded = pcall(function()
        return InsertService:LoadAsset(VFX_ASSET_ID)
    end)

    if not ok then
        warn(string.format('[MarketplaceVfxService] Failed to load VFX asset %d: %s', VFX_ASSET_ID, tostring(loaded)))
        return nil
    end

    return loaded
end

local function buildTemplateFolder()
    local fxRoot = getFxRoot()
    if not fxRoot then
        warn('[MarketplaceVfxService] Missing ReplicatedStorage.GameParts; cannot build templates.')
        return
    end

    local templateFolder = ensureFolder(fxRoot, TEMPLATE_FOLDER_NAME)
    for _, child in ipairs(templateFolder:GetChildren()) do
        child:Destroy()
    end

    local loaded = loadAssetContainer()
    local sourcePool = {}
    if loaded then
        sourcePool = collectSourcePool(loaded)
    end

    local createdCount = 0
    for templateName, sourceNames in pairs(TEMPLATE_SOURCES) do
        local candidate = findTemplateCandidate(sourcePool, sourceNames)
        local clone: Instance
        if candidate then
            clone = candidate:Clone()
        else
            warn(string.format('[MarketplaceVfxService] Missing source template for %s. Using fallback.', templateName))
            clone = createFallbackTemplate(templateName)
        end

        clone.Name = templateName
        stripScripts(clone)
        normalizeTemplate(clone)
        clone.Parent = templateFolder
        createdCount += 1
    end

    if loaded then
        loaded:Destroy()
    end

    templateFolder:SetAttribute('MarketplaceAssetId', VFX_ASSET_ID)
    templateFolder:SetAttribute('TemplateCount', createdCount)
end

function MarketplaceVfxService.init()
    return nil
end

function MarketplaceVfxService.start()
    buildTemplateFolder()
end

return MarketplaceVfxService
