--!strict

local LootPresentationConfig = {
    PickupMaxDistance = 7,
    DespawnSeconds = 45,
    BillboardMaxDistance = 78,
    PromptActionText = 'Pick',
    PromptObjectText = '',
    PromptHintMaxDistance = 12,
    AnnouncedRarities = {
        Epic = true,
        Legendary = true,
        Mythic = true,
    },
    DropSound = {
        soundId = 'rbxassetid://12222058',
        volume = 0.55,
        playbackSpeed = 1.08,
        rollOffMaxDistance = 80,
    },
    PickupSound = {
        soundId = 'rbxassetid://99298705791213',
        volume = 0.72,
        playbackSpeed = 1.0,
        rollOffMaxDistance = 85,
    },
    RarityVisuals = {
        Common = {
            color = Color3.fromRGB(242, 244, 248),
            darkColor = Color3.fromRGB(90, 98, 112),
            lightBrightness = 0.14,
            lightRange = 4.5,
            partTransparency = 0.28,
            glowTransparency = 0.62,
            lineThickness = 0.02,
            material = Enum.Material.Neon,
        },
        Uncommon = {
            color = Color3.fromRGB(122, 214, 154),
            darkColor = Color3.fromRGB(36, 96, 65),
            lightBrightness = 0.2,
            lightRange = 5.25,
            partTransparency = 0.26,
            glowTransparency = 0.56,
            lineThickness = 0.024,
            material = Enum.Material.Neon,
        },
        Rare = {
            color = Color3.fromRGB(104, 174, 255),
            darkColor = Color3.fromRGB(35, 74, 139),
            lightBrightness = 0.28,
            lightRange = 6,
            partTransparency = 0.24,
            glowTransparency = 0.5,
            lineThickness = 0.028,
            material = Enum.Material.Neon,
        },
        Epic = {
            color = Color3.fromRGB(166, 122, 236),
            darkColor = Color3.fromRGB(83, 50, 132),
            lightBrightness = 0.36,
            lightRange = 6.5,
            partTransparency = 0.22,
            glowTransparency = 0.44,
            lineThickness = 0.032,
            material = Enum.Material.Neon,
        },
        Legendary = {
            color = Color3.fromRGB(233, 194, 102),
            darkColor = Color3.fromRGB(120, 84, 26),
            lightBrightness = 0.45,
            lightRange = 7.2,
            partTransparency = 0.2,
            glowTransparency = 0.36,
            lineThickness = 0.038,
            material = Enum.Material.Neon,
        },
        Mythic = {
            color = Color3.fromRGB(224, 92, 122),
            darkColor = Color3.fromRGB(122, 29, 58),
            lightBrightness = 0.52,
            lightRange = 7.6,
            partTransparency = 0.18,
            glowTransparency = 0.3,
            lineThickness = 0.042,
            material = Enum.Material.Neon,
        },
    },
}

function LootPresentationConfig.getRarityVisual(rarity: string?)
    return LootPresentationConfig.RarityVisuals[rarity or ''] or LootPresentationConfig.RarityVisuals.Common
end

function LootPresentationConfig.getRarityColor(rarity: string?)
    return LootPresentationConfig.getRarityVisual(rarity).color
end

function LootPresentationConfig.getRarityDarkColor(rarity: string?)
    return LootPresentationConfig.getRarityVisual(rarity).darkColor
end

function LootPresentationConfig.shouldAnnounceDrop(drop)
    if type(drop) ~= 'table' then
        return false
    end

    if drop.kind == 'card' then
        return true
    end

    if drop.chaseDrop == true then
        return true
    end

    local rarity = tostring(drop.rarity or 'Common')
    return LootPresentationConfig.AnnouncedRarities[rarity] == true
end

return LootPresentationConfig
