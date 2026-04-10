--!strict

local LootPresentationConfig = {
    PickupMaxDistance = 12,
    DespawnSeconds = 45,
    BillboardMaxDistance = 120,
    PromptActionText = 'Pick',
    PromptObjectText = '',
    PromptHintMaxDistance = 18,
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
            lightBrightness = 0.54,
            lightRange = 7,
            partTransparency = 0.14,
            glowTransparency = 0.22,
            lineThickness = 0.045,
            material = Enum.Material.Neon,
        },
        Uncommon = {
            color = Color3.fromRGB(122, 214, 154),
            darkColor = Color3.fromRGB(36, 96, 65),
            lightBrightness = 0.82,
            lightRange = 10,
            partTransparency = 0.13,
            glowTransparency = 0.16,
            lineThickness = 0.058,
            material = Enum.Material.Neon,
        },
        Rare = {
            color = Color3.fromRGB(104, 174, 255),
            darkColor = Color3.fromRGB(35, 74, 139),
            lightBrightness = 1.06,
            lightRange = 12,
            partTransparency = 0.1,
            glowTransparency = 0.13,
            lineThickness = 0.07,
            material = Enum.Material.Neon,
        },
        Epic = {
            color = Color3.fromRGB(166, 122, 236),
            darkColor = Color3.fromRGB(83, 50, 132),
            lightBrightness = 1.34,
            lightRange = 13,
            partTransparency = 0.09,
            glowTransparency = 0.09,
            lineThickness = 0.088,
            material = Enum.Material.Neon,
        },
        Legendary = {
            color = Color3.fromRGB(233, 194, 102),
            darkColor = Color3.fromRGB(120, 84, 26),
            lightBrightness = 1.74,
            lightRange = 16,
            partTransparency = 0.07,
            glowTransparency = 0.05,
            lineThickness = 0.108,
            material = Enum.Material.Neon,
        },
        Mythic = {
            color = Color3.fromRGB(224, 92, 122),
            darkColor = Color3.fromRGB(122, 29, 58),
            lightBrightness = 2.08,
            lightRange = 18,
            partTransparency = 0.05,
            glowTransparency = 0.03,
            lineThickness = 0.122,
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
