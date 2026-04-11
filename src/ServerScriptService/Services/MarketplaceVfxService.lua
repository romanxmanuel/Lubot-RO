--!strict

local InsertService = game:GetService('InsertService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local MarketplaceVfxService = {
    Name = 'MarketplaceVfxService',
}

local TEMPLATE_FOLDER_NAME = 'MarketplaceVfx7564537285'
local SOURCE_FOLDER_PREFIX = 'MarketplaceAsset_'

local ASSET_BUNDLES = {
    basePack = {
        assetId = 7564537285,
    },
    powerSlashPack = {
        assetId = 121170725728238,
    },
    beamPack = {
        assetId = 139055633559547,
    },
    gojoBluePack = {
        assetId = 104047653740780,
    },
    hollowPurplePack = {
        assetId = 82722798873168,
    },
}

local TEMPLATE_SPECS = {
    PowerSlash = {
        bundle = 'powerSlashPack',
        sourceNames = { 'Model', 'VFX', 'crash3', 'crash4' },
    },
    ArcFlare = {
        bundle = 'basePack',
        sourceNames = { 'FancySlash', 'FancySlashLight', 'FancySlashDark' },
    },
    NovaStrike = {
        bundle = 'beamPack',
        sourceNames = { 'Beam', 'FF', 'Part' },
    },
    VortexSpin = {
        bundle = 'basePack',
        sourceNames = { 'GlitchWind', 'CircleShockwave', 'DecalShockwave' },
    },
    CometDrop = {
        bundle = 'basePack',
        sourceNames = { 'FireBall', 'FireBallB', 'ExplosionB' },
    },
    RazorOrbit = {
        bundle = 'basePack',
        sourceNames = { 'DecalShockwave', 'CircleShockwave', 'FancySphere' },
    },
    GojoBlueBurst = {
        bundle = 'gojoBluePack',
        sourceNames = { 'Blue', 'BlueMo', 'Stuff', 'Wind' },
    },
    HollowPurpleBurst = {
        bundle = 'hollowPurplePack',
        sourceNames = { 'Purple', 'red', 'Blue', 'Main' },
    },
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

local function clearChildren(parent: Instance)
    for _, child in ipairs(parent:GetChildren()) do
        child:Destroy()
    end
end

local function loadAssetContainer(assetId: number)
    local ok, loaded = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)

    if ok and loaded then
        return loaded
    end

    warn(string.format('[MarketplaceVfxService] Failed to load VFX asset %d: %s', assetId, tostring(loaded)))

    local okObjects, loadedObjects = pcall(function()
        return game:GetObjects(string.format('rbxassetid://%d', assetId))
    end)
    if not okObjects then
        warn(string.format('[MarketplaceVfxService] game:GetObjects failed for VFX asset %d: %s', assetId, tostring(loadedObjects)))
        return nil
    end

    if type(loadedObjects) ~= 'table' or #loadedObjects == 0 then
        return nil
    end

    local container = Instance.new('Folder')
    container.Name = string.format('MarketplaceAsset_%d', assetId)
    for _, instance in ipairs(loadedObjects) do
        if typeof(instance) == 'Instance' then
            instance.Parent = container
        end
    end
    return container
end

local function buildSourceBundle(fxRoot: Folder, bundleName: string, assetId: number)
    local sourceFolderName = string.format('%s%d', SOURCE_FOLDER_PREFIX, assetId)
    local sourceFolder = ensureFolder(fxRoot, sourceFolderName)
    local loaded = loadAssetContainer(assetId)
    if loaded then
        clearChildren(sourceFolder)
        for _, child in ipairs(loaded:GetChildren()) do
            child:Clone().Parent = sourceFolder
        end
        loaded:Destroy()
        sourceFolder:SetAttribute('CachedFromInsertService', true)
    elseif #sourceFolder:GetDescendants() > 0 then
        warn(string.format('[MarketplaceVfxService] Using cached source folder for asset %d (InsertService unavailable).', assetId))
    else
        warn(string.format('[MarketplaceVfxService] No source data available for asset %d.', assetId))
    end

    sourceFolder:SetAttribute('MarketplaceAssetId', assetId)
    sourceFolder:SetAttribute('BundleName', bundleName)

    return {
        bundleName = bundleName,
        assetId = assetId,
        sourceFolder = sourceFolder,
        sourcePool = collectSourcePool(sourceFolder),
    }
end

local function buildTemplateFolder()
    local fxRoot = getFxRoot()
    if not fxRoot then
        warn('[MarketplaceVfxService] Missing ReplicatedStorage.GameParts; cannot build templates.')
        return
    end

    local templateFolder = ensureFolder(fxRoot, TEMPLATE_FOLDER_NAME)
    clearChildren(templateFolder)

    local bundles = {}
    for bundleName, bundleDef in pairs(ASSET_BUNDLES) do
        bundles[bundleName] = buildSourceBundle(fxRoot, bundleName, bundleDef.assetId)
    end

    local createdCount = 0
    for templateName, templateSpec in pairs(TEMPLATE_SPECS) do
        local bundle = bundles[templateSpec.bundle]
        local candidate = if bundle then findTemplateCandidate(bundle.sourcePool, templateSpec.sourceNames) else nil
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
        if bundle then
            clone:SetAttribute('SourceAssetId', bundle.assetId)
            clone:SetAttribute('SourceBundle', bundle.bundleName)
        end
        clone.Parent = templateFolder
        createdCount += 1
    end

    templateFolder:SetAttribute('MarketplaceAssetId', ASSET_BUNDLES.basePack.assetId)
    templateFolder:SetAttribute('PowerSlashAssetId', ASSET_BUNDLES.powerSlashPack.assetId)
    templateFolder:SetAttribute('BeamAssetId', ASSET_BUNDLES.beamPack.assetId)
    templateFolder:SetAttribute('GojoBlueAssetId', ASSET_BUNDLES.gojoBluePack.assetId)
    templateFolder:SetAttribute('HollowPurpleAssetId', ASSET_BUNDLES.hollowPurplePack.assetId)
    templateFolder:SetAttribute('TemplateCount', createdCount)
end

function MarketplaceVfxService.init()
    return nil
end

function MarketplaceVfxService.start()
    buildTemplateFolder()
end

return MarketplaceVfxService
