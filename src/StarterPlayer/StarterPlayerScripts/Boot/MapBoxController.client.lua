--!strict

local Lighting = game:GetService('Lighting')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local SoundService = game:GetService('SoundService')
local Workspace = game:GetService('Workspace')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local ZoneAudioConfig = require(ReplicatedStorage.Shared.Config.ZoneAudioConfig)

local localPlayer = Players.LocalPlayer
local zoneSoundName = 'ZoneAmbientTrack'
local legacyZoneFolderName = '_Deleted_TonyController'
local mapsFolderName = 'Maps'
local mapBoxName = 'MapBox'
local zoneVisualOverrideAttributeName = 'ZoneVisualOverrideUntil'
local lubidriumTuneAttributeName = 'LubotLubidriumVisualTuned'

local originalPointBrightnessAttribute = 'LubotOriginalPointBrightness'
local originalPointRangeAttribute = 'LubotOriginalPointRange'
local originalParticleLightEmissionAttribute = 'LubotOriginalParticleLightEmission'
local originalParticleBrightnessAttribute = 'LubotOriginalParticleBrightness'
local originalParticleRateAttribute = 'LubotOriginalParticleRate'
local originalPartTransparencyAttribute = 'LubotOriginalPartTransparency'
local originalPartColorAttribute = 'LubotOriginalPartColor'
local originalPartReflectanceAttribute = 'LubotOriginalPartReflectance'

local SUPPORTED_ZONE_EFFECTS = {
    Atmosphere = {
        className = 'Atmosphere',
        properties = { 'Color', 'Decay', 'Density', 'Glare', 'Haze', 'Offset' },
    },
    BloomEffect = {
        className = 'BloomEffect',
        properties = { 'Enabled', 'Intensity', 'Size', 'Threshold' },
    },
    ColorCorrectionEffect = {
        className = 'ColorCorrectionEffect',
        properties = { 'Enabled', 'Brightness', 'Contrast', 'Saturation', 'TintColor' },
    },
    ColorGradingEffect = {
        className = 'ColorGradingEffect',
        properties = { 'Enabled', 'TonemapperPreset' },
    },
    SunRaysEffect = {
        className = 'SunRaysEffect',
        properties = { 'Enabled', 'Intensity', 'Spread' },
    },
}

type ZoneVolume = BasePart
type ZoneProfile = {
    musicId: string,
    musicVolume: number,
    brightness: number,
    clockTime: number,
    timeOfDay: string,
    lightingStyle: Enum.LightingStyle,
    prioritizeLightingQuality: boolean,
    fogStart: number,
    fogEnd: number,
    ambient: Color3,
    outdoorAmbient: Color3,
    fogColor: Color3,
    colorShiftBottom: Color3,
    colorShiftTop: Color3,
    exposureCompensation: number,
    environmentDiffuseScale: number,
    environmentSpecularScale: number,
    geographicLatitude: number,
    shadowSoftness: number,
    skyAssetId: string,
    skyboxBk: string,
    skyboxDn: string,
    skyboxFt: string,
    skyboxLf: string,
    skyboxRt: string,
    skyboxUp: string,
    sunAngularSize: number,
    moonAngularSize: number,
    celestialBodiesShown: boolean,
    starCount: number,
}

local baseLightingProfile: ZoneProfile = {
    musicId = '',
    musicVolume = 0.4,
    brightness = Lighting.Brightness,
    clockTime = Lighting.ClockTime,
    timeOfDay = Lighting.TimeOfDay,
    lightingStyle = Lighting.LightingStyle,
    prioritizeLightingQuality = Lighting.PrioritizeLightingQuality,
    fogStart = Lighting.FogStart,
    fogEnd = Lighting.FogEnd,
    ambient = Lighting.Ambient,
    outdoorAmbient = Lighting.OutdoorAmbient,
    fogColor = Lighting.FogColor,
    colorShiftBottom = Lighting.ColorShift_Bottom,
    colorShiftTop = Lighting.ColorShift_Top,
    exposureCompensation = Lighting.ExposureCompensation,
    environmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
    environmentSpecularScale = Lighting.EnvironmentSpecularScale,
    geographicLatitude = Lighting.GeographicLatitude,
    shadowSoftness = Lighting.ShadowSoftness,
    skyAssetId = '',
    skyboxBk = '',
    skyboxDn = '',
    skyboxFt = '',
    skyboxLf = '',
    skyboxRt = '',
    skyboxUp = '',
    sunAngularSize = 21,
    moonAngularSize = 11,
    celestialBodiesShown = true,
    starCount = 3000,
}

local zoneSky: Sky?
local baseZoneEffects = {}
local baseSkyProfile = {
    skyboxBk = '',
    skyboxDn = '',
    skyboxFt = '',
    skyboxLf = '',
    skyboxRt = '',
    skyboxUp = '',
    sunAngularSize = 21,
    moonAngularSize = 11,
    celestialBodiesShown = true,
    starCount = 3000,
}

local function getRootPart(): BasePart?
    local character = localPlayer.Character
    if not character then
        return nil
    end
    return character:FindFirstChild('HumanoidRootPart') :: BasePart?
end

local function findLightingEffectByClass(className: string): Instance?
    for _, child in ipairs(Lighting:GetChildren()) do
        if child.ClassName == className then
            return child
        end
    end
    return nil
end

local function captureEffectProfile(effect: Instance, spec)
    local profile = {
        exists = true,
        name = effect.Name,
        properties = {},
    }

    for _, propertyName in ipairs(spec.properties) do
        profile.properties[propertyName] = effect[propertyName]
    end

    return profile
end

local function createEffectByClass(className: string): Instance
    local effect = Instance.new(className)
    effect.Name = 'Zone' .. className
    effect.Parent = Lighting
    return effect
end

local function applyEffectProfile(target: Instance, effectProfile, spec)
    if effectProfile.name and target.Name ~= effectProfile.name then
        target.Name = effectProfile.name
    end

    for _, propertyName in ipairs(spec.properties) do
        local value = effectProfile.properties[propertyName]
        if value ~= nil then
            target[propertyName] = value
        end
    end
end

local function initializeBaseZoneEffects()
    for effectKey, spec in pairs(SUPPORTED_ZONE_EFFECTS) do
        local existing = findLightingEffectByClass(spec.className)
        if existing then
            baseZoneEffects[effectKey] = captureEffectProfile(existing, spec)
        else
            baseZoneEffects[effectKey] = {
                exists = false,
                name = 'Zone' .. spec.className,
                properties = {},
            }
        end
    end
end

local function captureSkyProfile(sky: Sky)
    return {
        skyboxBk = sky.SkyboxBk,
        skyboxDn = sky.SkyboxDn,
        skyboxFt = sky.SkyboxFt,
        skyboxLf = sky.SkyboxLf,
        skyboxRt = sky.SkyboxRt,
        skyboxUp = sky.SkyboxUp,
        sunAngularSize = sky.SunAngularSize,
        moonAngularSize = sky.MoonAngularSize,
        celestialBodiesShown = sky.CelestialBodiesShown,
        starCount = sky.StarCount,
    }
end

local function isWithinZone(position: Vector3, zoneConfig): boolean
    local halfSize = zoneConfig.size * 0.5
    return math.abs(position.X - zoneConfig.center.X) <= halfSize.X
        and math.abs(position.Z - zoneConfig.center.Z) <= halfSize.Y
end

local function isInsideZoneVolume(position: Vector3, zonePart: BasePart): boolean
    local localPosition = zonePart.CFrame:PointToObjectSpace(position)
    local halfSize = zonePart.Size * 0.5
    local zoneShape = string.lower(tostring(zonePart:GetAttribute('ZoneShape') or 'box'))

    if zoneShape == 'cylinder' then
        local axis = string.upper(tostring(zonePart:GetAttribute('ZoneAxis') or 'X'))
        local radius = 0
        local heightCheck = 0
        local radialA = 0
        local radialB = 0

        if axis == 'Y' then
            radius = math.min(halfSize.X, halfSize.Z)
            heightCheck = math.abs(localPosition.Y)
            radialA = localPosition.X
            radialB = localPosition.Z
        elseif axis == 'Z' then
            radius = math.min(halfSize.X, halfSize.Y)
            heightCheck = math.abs(localPosition.Z)
            radialA = localPosition.X
            radialB = localPosition.Y
        else
            radius = math.min(halfSize.Y, halfSize.Z)
            heightCheck = math.abs(localPosition.X)
            radialA = localPosition.Y
            radialB = localPosition.Z
        end

        local radialDistance = math.sqrt((radialA * radialA) + (radialB * radialB))
        return radialDistance <= radius
            and heightCheck <= (axis == 'Y' and halfSize.Y or axis == 'Z' and halfSize.Z or halfSize.X)
    end

    return math.abs(localPosition.X) <= halfSize.X
        and math.abs(localPosition.Y) <= halfSize.Y
        and math.abs(localPosition.Z) <= halfSize.Z
end

local function getZoneVolumes(): { ZoneVolume }
    local zoneVolumes = {}

    local mapsFolder = Workspace:FindFirstChild(mapsFolderName)
    if mapsFolder then
        for _, descendant in ipairs(mapsFolder:GetDescendants()) do
            if descendant:IsA('BasePart') and descendant.Name == mapBoxName then
                table.insert(zoneVolumes, descendant)
            end
        end
    end

    local deduped = {}
    local uniqueZoneVolumes = {}
    for _, zoneVolume in ipairs(zoneVolumes) do
        if not deduped[zoneVolume] then
            deduped[zoneVolume] = true
            table.insert(uniqueZoneVolumes, zoneVolume)
        end
    end

    table.sort(uniqueZoneVolumes, function(left, right)
        local leftPriority = left:GetAttribute('Priority') or 0
        local rightPriority = right:GetAttribute('Priority') or 0
        if leftPriority ~= rightPriority then
            return leftPriority > rightPriority
        end

        local leftArea = left.Size.X * left.Size.Z
        local rightArea = right.Size.X * right.Size.Z
        if leftArea ~= rightArea then
            return leftArea < rightArea
        end

        return left:GetFullName() < right:GetFullName()
    end)

    return uniqueZoneVolumes
end

local function resolveZoneVolume(position: Vector3): ZoneVolume?
    for _, zoneVolume in ipairs(getZoneVolumes()) do
        if isInsideZoneVolume(position, zoneVolume) then
            return zoneVolume
        end
    end
    return nil
end

local function parseLightingStyleValue(value: any, fallback: Enum.LightingStyle): Enum.LightingStyle
    if typeof(value) == 'EnumItem' and value.EnumType == Enum.LightingStyle then
        return value
    end

    if typeof(value) == 'string' then
        local enumName = value:match('Enum%.LightingStyle%.(.+)') or value
        local parsed = Enum.LightingStyle[enumName]
        if parsed then
            return parsed
        end
    end

    return fallback
end

local function isLubidriumZoneKey(zoneKey: string): boolean
    local lowered = string.lower(zoneKey)
    return string.find(lowered, 'lubidrium', 1, true) ~= nil
        or string.find(lowered, 'ludibrium', 1, true) ~= nil
end

local function raisePartTransparency(part: BasePart, amount: number, maxTransparency: number)
    local originalTransparency = part:GetAttribute(originalPartTransparencyAttribute)
    if typeof(originalTransparency) ~= 'number' then
        originalTransparency = part.Transparency
        part:SetAttribute(originalPartTransparencyAttribute, originalTransparency)
    end

    part.Transparency = math.clamp((originalTransparency :: number) + amount, 0, maxTransparency)
end

local function tuneLubidriumMapVisuals()
    local mapsFolder = Workspace:FindFirstChild(mapsFolderName)
    if not mapsFolder then
        return
    end

    local lubidriumFolder = mapsFolder:FindFirstChild('Lubidrium')
    if not lubidriumFolder then
        return
    end

    local mapFolder = lubidriumFolder:FindFirstChild('Map')
    if not mapFolder then
        return
    end

    local zoneModel = mapFolder:FindFirstChild('LudibriumCosmicZone')
    if not zoneModel then
        zoneModel = mapFolder:FindFirstChild('LubidriumCosmicZone')
    end
    if not zoneModel then
        return
    end

    if zoneModel:GetAttribute(lubidriumTuneAttributeName) == true then
        return
    end

    for _, descendant in ipairs(zoneModel:GetDescendants()) do
        if descendant:IsA('PointLight') then
            local originalBrightness = descendant:GetAttribute(originalPointBrightnessAttribute)
            if typeof(originalBrightness) ~= 'number' then
                originalBrightness = descendant.Brightness
                descendant:SetAttribute(originalPointBrightnessAttribute, originalBrightness)
            end

            local originalRange = descendant:GetAttribute(originalPointRangeAttribute)
            if typeof(originalRange) ~= 'number' then
                originalRange = descendant.Range
                descendant:SetAttribute(originalPointRangeAttribute, originalRange)
            end

            descendant.Brightness = math.max(0.03, (originalBrightness :: number) * 0.24)
            descendant.Range = math.max(3, (originalRange :: number) * 0.45)
            descendant.Shadows = false
        elseif descendant:IsA('ParticleEmitter') then
            local originalLightEmission = descendant:GetAttribute(originalParticleLightEmissionAttribute)
            if typeof(originalLightEmission) ~= 'number' then
                originalLightEmission = descendant.LightEmission
                descendant:SetAttribute(originalParticleLightEmissionAttribute, originalLightEmission)
            end

            local originalBrightness = descendant:GetAttribute(originalParticleBrightnessAttribute)
            if typeof(originalBrightness) ~= 'number' then
                originalBrightness = descendant.Brightness
                descendant:SetAttribute(originalParticleBrightnessAttribute, originalBrightness)
            end

            local originalRate = descendant:GetAttribute(originalParticleRateAttribute)
            if typeof(originalRate) ~= 'number' then
                originalRate = descendant.Rate
                descendant:SetAttribute(originalParticleRateAttribute, originalRate)
            end

            descendant.LightEmission = math.max(0, (originalLightEmission :: number) * 0.1)
            descendant.Brightness = math.max(0, (originalBrightness :: number) * 0.22)
            descendant.Rate = math.max(0, (originalRate :: number) * 0.4)
        elseif descendant:IsA('BasePart') and descendant.Material == Enum.Material.Neon then
            local originalColor = descendant:GetAttribute(originalPartColorAttribute)
            if typeof(originalColor) ~= 'Color3' then
                originalColor = descendant.Color
                descendant:SetAttribute(originalPartColorAttribute, originalColor)
            end

            local originalReflectance = descendant:GetAttribute(originalPartReflectanceAttribute)
            if typeof(originalReflectance) ~= 'number' then
                originalReflectance = descendant.Reflectance
                descendant:SetAttribute(originalPartReflectanceAttribute, originalReflectance)
            end

            local hue, saturation, value = (originalColor :: Color3):ToHSV()
            descendant.Color = Color3.fromHSV(hue, math.clamp(saturation * 0.85, 0.1, 1), math.clamp(value * 0.62, 0, 0.56))
            descendant.Reflectance = math.max(0, (originalReflectance :: number) * 0.2)
            raisePartTransparency(descendant, 0.35, 0.9)
        end
    end

    zoneModel:SetAttribute(lubidriumTuneAttributeName, true)
end

local function getLubidriumZoneModel(): Model?
    local mapsFolder = Workspace:FindFirstChild(mapsFolderName)
    if not mapsFolder then
        return nil
    end

    local lubidriumFolder = mapsFolder:FindFirstChild('Lubidrium')
    if not lubidriumFolder then
        return nil
    end

    local mapFolder = lubidriumFolder:FindFirstChild('Map')
    if not mapFolder then
        return nil
    end

    local zoneModel = mapFolder:FindFirstChild('LudibriumCosmicZone')
    if zoneModel and zoneModel:IsA('Model') then
        return zoneModel
    end

    zoneModel = mapFolder:FindFirstChild('LubidriumCosmicZone')
    if zoneModel and zoneModel:IsA('Model') then
        return zoneModel
    end

    return nil
end

local function isInsideModelBounds(position: Vector3, model: Model): boolean
    local boundsCFrame, boundsSize = model:GetBoundingBox()
    local localPosition = boundsCFrame:PointToObjectSpace(position)
    local halfSize = boundsSize * 0.5

    return math.abs(localPosition.X) <= halfSize.X
        and math.abs(localPosition.Y) <= halfSize.Y
        and math.abs(localPosition.Z) <= halfSize.Z
end

local function applyLubidriumLightingPass(zoneKey: string)
    if not isLubidriumZoneKey(zoneKey) then
        return
    end

    Lighting.ExposureCompensation = math.min(Lighting.ExposureCompensation, -0.55)
    Lighting.Brightness = math.min(Lighting.Brightness, 1.25)
    Lighting.EnvironmentSpecularScale = math.min(Lighting.EnvironmentSpecularScale, 0.18)

    local bloom = findLightingEffectByClass('BloomEffect')
    if bloom and bloom:IsA('BloomEffect') then
        bloom.Intensity = math.min(bloom.Intensity, 0.015)
        bloom.Size = math.min(bloom.Size, 10)
        bloom.Threshold = math.max(bloom.Threshold, 3)
    end

    local sunRays = findLightingEffectByClass('SunRaysEffect')
    if sunRays and sunRays:IsA('SunRaysEffect') then
        sunRays.Intensity = math.min(sunRays.Intensity, 0.005)
        sunRays.Spread = math.min(sunRays.Spread, 0.5)
    end

    local colorCorrection = findLightingEffectByClass('ColorCorrectionEffect')
    if colorCorrection and colorCorrection:IsA('ColorCorrectionEffect') then
        colorCorrection.Brightness = math.min(colorCorrection.Brightness, -0.11)
        colorCorrection.Contrast = math.min(colorCorrection.Contrast, 0.12)
        colorCorrection.Saturation = math.min(colorCorrection.Saturation, -0.22)
    end

    local atmosphere = findLightingEffectByClass('Atmosphere')
    if atmosphere and atmosphere:IsA('Atmosphere') then
        atmosphere.Density = math.min(atmosphere.Density, 0.14)
        atmosphere.Glare = math.min(atmosphere.Glare, 0)
        atmosphere.Haze = math.min(atmosphere.Haze, 0.35)
    end
end

local function resolveFallbackProfile(zoneId: string): ZoneProfile?
    local zoneConfig = ZoneAudioConfig.zoneTracks[zoneId]
    if not zoneConfig then
        return nil
    end

    return {
        musicId = zoneConfig.soundId or '',
        musicVolume = zoneConfig.volume or 0.4,
        brightness = baseLightingProfile.brightness,
        clockTime = baseLightingProfile.clockTime,
        timeOfDay = baseLightingProfile.timeOfDay,
        lightingStyle = baseLightingProfile.lightingStyle,
        prioritizeLightingQuality = baseLightingProfile.prioritizeLightingQuality,
        fogStart = baseLightingProfile.fogStart,
        fogEnd = baseLightingProfile.fogEnd,
        ambient = baseLightingProfile.ambient,
        outdoorAmbient = baseLightingProfile.outdoorAmbient,
        fogColor = baseLightingProfile.fogColor,
        colorShiftBottom = baseLightingProfile.colorShiftBottom,
        colorShiftTop = baseLightingProfile.colorShiftTop,
        exposureCompensation = baseLightingProfile.exposureCompensation,
        environmentDiffuseScale = baseLightingProfile.environmentDiffuseScale,
        environmentSpecularScale = baseLightingProfile.environmentSpecularScale,
        geographicLatitude = baseLightingProfile.geographicLatitude,
        shadowSoftness = baseLightingProfile.shadowSoftness,
        skyAssetId = baseLightingProfile.skyAssetId,
        skyboxBk = baseLightingProfile.skyboxBk,
        skyboxDn = baseLightingProfile.skyboxDn,
        skyboxFt = baseLightingProfile.skyboxFt,
        skyboxLf = baseLightingProfile.skyboxLf,
        skyboxRt = baseLightingProfile.skyboxRt,
        skyboxUp = baseLightingProfile.skyboxUp,
        sunAngularSize = baseSkyProfile.sunAngularSize,
        moonAngularSize = baseSkyProfile.moonAngularSize,
        celestialBodiesShown = baseSkyProfile.celestialBodiesShown,
        starCount = baseSkyProfile.starCount,
    }
end

local function resolveZoneVolumeProfile(zoneVolume: ZoneVolume?): ZoneProfile?
    if not zoneVolume then
        return nil
    end

    local localSkyAssetId = zoneVolume:GetAttribute('SkyAssetId') or ''
    local localSky = zoneVolume:FindFirstChildWhichIsA('Sky')
    local skyboxBk = zoneVolume:GetAttribute('SkyboxBk') or localSkyAssetId
    local skyboxDn = zoneVolume:GetAttribute('SkyboxDn') or localSkyAssetId
    local skyboxFt = zoneVolume:GetAttribute('SkyboxFt') or localSkyAssetId
    local skyboxLf = zoneVolume:GetAttribute('SkyboxLf') or localSkyAssetId
    local skyboxRt = zoneVolume:GetAttribute('SkyboxRt') or localSkyAssetId
    local skyboxUp = zoneVolume:GetAttribute('SkyboxUp') or localSkyAssetId

    if localSky then
        skyboxBk = localSky.SkyboxBk
        skyboxDn = localSky.SkyboxDn
        skyboxFt = localSky.SkyboxFt
        skyboxLf = localSky.SkyboxLf
        skyboxRt = localSky.SkyboxRt
        skyboxUp = localSky.SkyboxUp
    end

    local sunAngularSize = localSky and localSky.SunAngularSize or baseSkyProfile.sunAngularSize
    local moonAngularSize = localSky and localSky.MoonAngularSize or baseSkyProfile.moonAngularSize
    local celestialBodiesShown = localSky and localSky.CelestialBodiesShown
    if celestialBodiesShown == nil then
        celestialBodiesShown = baseSkyProfile.celestialBodiesShown
    end
    local starCount = localSky and localSky.StarCount or baseSkyProfile.starCount

    return {
        musicId = zoneVolume:GetAttribute('MusicId') or '',
        musicVolume = zoneVolume:GetAttribute('MusicVolume') or 0.4,
        brightness = zoneVolume:GetAttribute('Brightness') or baseLightingProfile.brightness,
        clockTime = zoneVolume:GetAttribute('ClockTime') or baseLightingProfile.clockTime,
        timeOfDay = zoneVolume:GetAttribute('TimeOfDay') or baseLightingProfile.timeOfDay,
        lightingStyle = parseLightingStyleValue(zoneVolume:GetAttribute('LightingStyle'), baseLightingProfile.lightingStyle),
        prioritizeLightingQuality = if zoneVolume:GetAttribute('PrioritizeLightingQuality') == nil then baseLightingProfile.prioritizeLightingQuality else zoneVolume:GetAttribute('PrioritizeLightingQuality'),
        fogStart = zoneVolume:GetAttribute('FogStart') or baseLightingProfile.fogStart,
        fogEnd = zoneVolume:GetAttribute('FogEnd') or baseLightingProfile.fogEnd,
        ambient = zoneVolume:GetAttribute('Ambient') or baseLightingProfile.ambient,
        outdoorAmbient = zoneVolume:GetAttribute('OutdoorAmbient') or baseLightingProfile.outdoorAmbient,
        fogColor = zoneVolume:GetAttribute('FogColor') or baseLightingProfile.fogColor,
        colorShiftBottom = zoneVolume:GetAttribute('ColorShiftBottom') or baseLightingProfile.colorShiftBottom,
        colorShiftTop = zoneVolume:GetAttribute('ColorShiftTop') or baseLightingProfile.colorShiftTop,
        exposureCompensation = zoneVolume:GetAttribute('ExposureCompensation') or baseLightingProfile.exposureCompensation,
        environmentDiffuseScale = zoneVolume:GetAttribute('EnvironmentalDiffuseScale') or baseLightingProfile.environmentDiffuseScale,
        environmentSpecularScale = zoneVolume:GetAttribute('EnvironmentalSpecularScale') or baseLightingProfile.environmentSpecularScale,
        geographicLatitude = zoneVolume:GetAttribute('GeographicLatitude') or baseLightingProfile.geographicLatitude,
        shadowSoftness = zoneVolume:GetAttribute('ShadowSoftness') or baseLightingProfile.shadowSoftness,
        skyAssetId = localSkyAssetId,
        skyboxBk = skyboxBk,
        skyboxDn = skyboxDn,
        skyboxFt = skyboxFt,
        skyboxLf = skyboxLf,
        skyboxRt = skyboxRt,
        skyboxUp = skyboxUp,
        sunAngularSize = sunAngularSize,
        moonAngularSize = moonAngularSize,
        celestialBodiesShown = celestialBodiesShown,
        starCount = starCount,
    }
end

local function applyZoneSky(zoneProfile: ZoneProfile)
    zoneSky = zoneSky or getOrCreateZoneSky()
    if not zoneSky then
        return
    end
    zoneSky.SkyboxBk = zoneProfile.skyboxBk or ''
    zoneSky.SkyboxDn = zoneProfile.skyboxDn or ''
    zoneSky.SkyboxFt = zoneProfile.skyboxFt or ''
    zoneSky.SkyboxLf = zoneProfile.skyboxLf or ''
    zoneSky.SkyboxRt = zoneProfile.skyboxRt or ''
    zoneSky.SkyboxUp = zoneProfile.skyboxUp or ''
    zoneSky.SunAngularSize = zoneProfile.sunAngularSize
    zoneSky.MoonAngularSize = zoneProfile.moonAngularSize
    zoneSky.CelestialBodiesShown = zoneProfile.celestialBodiesShown
    zoneSky.StarCount = zoneProfile.starCount
end

local function silenceZoneAttachedSounds()
    local mapsFolder = Workspace:FindFirstChild(mapsFolderName)
    if mapsFolder then
        for _, descendant in ipairs(mapsFolder:GetDescendants()) do
            if descendant:IsA('BasePart') and descendant.Name == mapBoxName then
                for _, child in ipairs(descendant:GetDescendants()) do
                    if child:IsA('Sound') then
                        child:Stop()
                        child.Playing = false
                    end
                end
            end
        end
    end

    local legacyZoneFolder = Workspace:FindFirstChild(legacyZoneFolderName)
    if not legacyZoneFolder then
        return
    end

    for _, descendant in ipairs(legacyZoneFolder:GetDescendants()) do
        if descendant:IsA('Sound') then
            descendant:Stop()
            descendant.Playing = false
        end
    end
end

local function syncZoneEffects(zoneVolume: ZoneVolume?)
    for effectKey, spec in pairs(SUPPORTED_ZONE_EFFECTS) do
        local zoneEffect = nil
        if zoneVolume then
            for _, child in ipairs(zoneVolume:GetChildren()) do
                if child.ClassName == spec.className then
                    zoneEffect = child
                    break
                end
            end
        end

        local liveEffect = findLightingEffectByClass(spec.className)
        if zoneEffect then
            liveEffect = liveEffect or createEffectByClass(spec.className)
            applyEffectProfile(liveEffect, captureEffectProfile(zoneEffect, spec), spec)
        else
            local baseProfile = baseZoneEffects[effectKey]
            if baseProfile and baseProfile.exists then
                liveEffect = liveEffect or createEffectByClass(spec.className)
                applyEffectProfile(liveEffect, baseProfile, spec)
            elseif liveEffect then
                liveEffect:Destroy()
            end
        end
    end
end

local function resolveZoneId(position: Vector3): string
    for _, zoneId in ipairs(ZoneAudioConfig.zoneOrder or {}) do
        local zoneConfig = ZoneAudioConfig.zoneTracks[zoneId]
        if zoneConfig and isWithinZone(position, zoneConfig) then
            return zoneId
        end
    end
    return ZoneAudioConfig.fallbackZoneId or 'town'
end

local function getOrCreateZoneSound(): Sound
    local existing = SoundService:FindFirstChild(zoneSoundName)
    if existing and existing:IsA('Sound') then
        return existing
    end

    local sound = Instance.new('Sound')
    sound.Name = zoneSoundName
    sound.Looped = true
    sound.RollOffMode = Enum.RollOffMode.Linear
    sound.Parent = SoundService
    return sound
end

local function getOrCreateZoneSky(): Sky
    local existing = Lighting:FindFirstChild('ZoneSky')
    if existing and existing:IsA('Sky') then
        return existing
    end

    local sky = Lighting:FindFirstChildOfClass('Sky')
    if sky then
        sky.Name = 'ZoneSky'
        return sky
    end

    sky = Instance.new('Sky')
    sky.Name = 'ZoneSky'
    sky.Parent = Lighting
    return sky
end

local zoneSound = getOrCreateZoneSound()
zoneSky = getOrCreateZoneSky()
if zoneSky then
    baseSkyProfile = captureSkyProfile(zoneSky)
    baseLightingProfile.skyboxBk = baseSkyProfile.skyboxBk
    baseLightingProfile.skyboxDn = baseSkyProfile.skyboxDn
    baseLightingProfile.skyboxFt = baseSkyProfile.skyboxFt
    baseLightingProfile.skyboxLf = baseSkyProfile.skyboxLf
    baseLightingProfile.skyboxRt = baseSkyProfile.skyboxRt
    baseLightingProfile.skyboxUp = baseSkyProfile.skyboxUp
end
initializeBaseZoneEffects()
silenceZoneAttachedSounds()
tuneLubidriumMapVisuals()
local currentZoneKey = nil
local nextRefreshAt = 0

local legacyTownTheme = SoundService:FindFirstChild('TownTheme')
if legacyTownTheme and legacyTownTheme:IsA('Sound') then
    legacyTownTheme:Stop()
end

local function isZoneVisualOverrideActive(): boolean
    local expiresAt = Lighting:GetAttribute(zoneVisualOverrideAttributeName)
    return typeof(expiresAt) == 'number' and expiresAt > Workspace:GetServerTimeNow()
end

local function applyZoneProfile(zoneKey: string, zoneProfile: ZoneProfile?)
    if not zoneProfile then
        return
    end

    Lighting.Brightness = zoneProfile.brightness
    Lighting.ClockTime = zoneProfile.clockTime
    Lighting.TimeOfDay = zoneProfile.timeOfDay
    pcall(function()
        Lighting.LightingStyle = zoneProfile.lightingStyle
    end)
    pcall(function()
        Lighting.PrioritizeLightingQuality = zoneProfile.prioritizeLightingQuality
    end)
    Lighting.FogStart = zoneProfile.fogStart
    Lighting.FogEnd = zoneProfile.fogEnd
    Lighting.Ambient = zoneProfile.ambient
    Lighting.OutdoorAmbient = zoneProfile.outdoorAmbient
    Lighting.FogColor = zoneProfile.fogColor
    Lighting.ColorShift_Bottom = zoneProfile.colorShiftBottom
    Lighting.ColorShift_Top = zoneProfile.colorShiftTop
    Lighting.ExposureCompensation = zoneProfile.exposureCompensation
    Lighting.EnvironmentDiffuseScale = zoneProfile.environmentDiffuseScale
    Lighting.EnvironmentSpecularScale = zoneProfile.environmentSpecularScale
    Lighting.GeographicLatitude = zoneProfile.geographicLatitude
    Lighting.ShadowSoftness = zoneProfile.shadowSoftness
    applyZoneSky(zoneProfile)
    applyLubidriumLightingPass(zoneKey)

    if not zoneProfile.musicId or zoneProfile.musicId == '' then
        zoneSound:Stop()
        currentZoneKey = zoneKey
        return
    end

    if currentZoneKey ~= zoneKey then
        zoneSound:Stop()
        zoneSound.TimePosition = 0
        zoneSound.SoundId = zoneProfile.musicId
        zoneSound.Volume = zoneProfile.musicVolume or 0.4
        zoneSound:Play()
        currentZoneKey = zoneKey
        return
    end

    if zoneSound.SoundId ~= zoneProfile.musicId then
        zoneSound.SoundId = zoneProfile.musicId
    end
    zoneSound.Volume = zoneProfile.musicVolume or 0.4
    if not zoneSound.IsPlaying then
        zoneSound:Play()
    end
end

RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now < nextRefreshAt then
        return
    end
    nextRefreshAt = now + 0.25

    tuneLubidriumMapVisuals()
    local rootPart = getRootPart()
    if not rootPart then
        return
    end
    local lubidriumZoneModel = getLubidriumZoneModel()
    local inLubidriumBounds = lubidriumZoneModel ~= nil and isInsideModelBounds(rootPart.Position, lubidriumZoneModel)

    silenceZoneAttachedSounds()

    if isZoneVisualOverrideActive() then
        return
    end

    local zoneVolume = resolveZoneVolume(rootPart.Position)
    if zoneVolume then
        local zoneName = zoneVolume:GetAttribute('ZoneId') or zoneVolume.Name
        syncZoneEffects(zoneVolume)
        applyZoneProfile('volume:' .. tostring(zoneName), resolveZoneVolumeProfile(zoneVolume))
        if inLubidriumBounds then
            applyLubidriumLightingPass('map:lubidrium')
        end
        return
    end

    local zoneId = resolveZoneId(rootPart.Position)
    syncZoneEffects(nil)
    applyZoneProfile('config:' .. zoneId, resolveFallbackProfile(zoneId))
    if inLubidriumBounds then
        applyLubidriumLightingPass('map:lubidrium')
    end
end)
