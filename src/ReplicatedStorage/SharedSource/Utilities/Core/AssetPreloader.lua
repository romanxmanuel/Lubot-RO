--[[

    AssetPreloader.lua
    General-purpose asset preloading utility.

    Supports:
    • Image assets (ImageLabels, ImageButtons, Decals, Textures)
    • Sound assets (Sound instances)
    • Animation assets (Animation instances)
    • Mesh assets (MeshPart, SpecialMesh)
    • Any instance with a ContentId
    • Raw asset strings ("rbxassetid://...")

    Usage:
    -- Basic preload (blocking)
    AssetPreloader.Preload({
        "rbxassetid://12345",
        imageLabel,
        soundInstance,
        { nestedImage, nestedSound },
    })

    -- Preload with progress callback (blocking)
    AssetPreloader.PreloadWithProgress(assets, function(loaded, total)
        print(string.format("Loading: %d/%d", loaded, total))
    end)

    @author Mys7o
    @version 1.0.0

]]

-- Roblox Services
local ContentProvider = game:GetService("ContentProvider")

-- Module
local AssetPreloader = {}

-- Flatten nested tables into a single list
local function flatten(input, outputList)
    for _, item in ipairs(input) do
        if typeof(item) == "table" then
            flatten(item, outputList)
        else
            table.insert(outputList, item)
        end
    end
end

-- Validate if an instance contains a loadable asset
local function isValidAsset(instance: Instance): boolean
    if typeof(instance) ~= "Instance" then
        return false
    end

    if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
        return instance.Image ~= ""
    end

    if instance:IsA("Decal") or instance:IsA("Texture") then
        return instance.Texture ~= ""
    end

    if instance:IsA("Sound") then
        return instance.SoundId ~= ""
    end

    if instance:IsA("Animation") then
        return instance.AnimationId ~= ""
    end

    if instance:IsA("MeshPart") then
        return instance.MeshId ~= ""
    end

    if instance:IsA("SpecialMesh") then
        return instance.MeshId ~= ""
    end

    return false
end

-- Extract the ContentId string from a supported instance
local function extractAsset(instance: Instance): string?
    if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
        return instance.Image
    end

    if instance:IsA("Decal") or instance:IsA("Texture") then
        return instance.Texture
    end

    if instance:IsA("Sound") then
        return instance.SoundId
    end

    if instance:IsA("Animation") then
        return instance.AnimationId
    end

    if instance:IsA("MeshPart") then
        return instance.MeshId
    end

    if instance:IsA("SpecialMesh") then
        return instance.MeshId
    end

    return nil
end

-- Build a flattened and validated list of assets for preloading
local function buildAssetList(assetList: {any}): {any}
    local flattened = {}
    flatten(assetList, flattened)

    local validAssets = {}

    for _, asset in ipairs(flattened) do
        -- Direct string ContentId
        if typeof(asset) == "string" and string.match(asset, "^rbxassetid://") then
            table.insert(validAssets, asset)

        -- Instance-based asset
        elseif typeof(asset) == "Instance" and isValidAsset(asset) then
            local contentId = extractAsset(asset)
            if contentId then
                table.insert(validAssets, asset)
            end

        else
            warn("[AssetPreloader] Ignored invalid asset:", asset)
        end
    end

    return validAssets
end

-- Preload a list of assets (blocking)
function AssetPreloader.Preload(assetList: {any})
    local validAssets = buildAssetList(assetList)
    if #validAssets == 0 then
        warn("[AssetPreloader] No valid assets to preload.")
        return
    end

    local success, err = pcall(function()
        ContentProvider:PreloadAsync(validAssets)
    end)

    if success then
        print(string.format("[AssetPreloader] Preloaded %d asset(s) successfully.", #validAssets))
    else
        warn("[AssetPreloader] Preload failed:", err)
    end
end

-- Preload assets with progress callback (still yields until complete)
function AssetPreloader.PreloadWithProgress(assetList: {any}, onProgress: ((loaded: number, total: number) -> ())?)
    local validAssets = buildAssetList(assetList)
    if #validAssets == 0 then
        warn("[AssetPreloader] No valid assets to preload.")
        return
    end

    local loadedCount = 0
    local totalCount = #validAssets

    local success, err = pcall(function()
        ContentProvider:PreloadAsync(validAssets, function(contentId: string, status: Enum.AssetFetchStatus)
            loadedCount += 1
            if onProgress then
                onProgress(loadedCount, totalCount)
            end
        end)
    end)

    if not success then
        warn("[AssetPreloader] PreloadWithProgress failed:", err)
    else
        print(string.format("[AssetPreloader] Loaded %d/%d assets.", loadedCount, totalCount))
    end
end

return AssetPreloader