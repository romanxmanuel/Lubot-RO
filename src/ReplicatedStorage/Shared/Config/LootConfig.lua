--!strict

local LootConfig = {
    Categories = {
        Power = 'Power',
        Cosmetic = 'Cosmetic',
        Utility = 'Utility',
    },
    Pity = {
        AllowPowerPity = false,
        AllowMonsterCardPity = false,
        CosmeticPityThreshold = 30,
        CosmeticFeaturedGuaranteeThreshold = 80,
        BossCosmeticPityThreshold = 15,
    },
    Affixes = {
        BaseRollChance = 0.22,
        RareRollBonus = 0.08,
        EpicRollBonus = 0.14,
        LegendaryRollBonus = 0.2,
        MaxAffixesByRarity = {
            Common = 0,
            Uncommon = 1,
            Rare = 2,
            Epic = 3,
            Legendary = 4,
        },
    },
}

return LootConfig
