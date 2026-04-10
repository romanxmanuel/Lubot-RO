--!strict

local BossDropDefs = {
    sewer_training_grounds = {
        bossId = 'sewer_lord_murmur',
        exclusiveDrops = {
            {
                kind = 'item',
                id = 'murmur_blade',
                rarity = 'Epic',
                weight = 18,
                category = 'Power',
            },
            {
                kind = 'item',
                id = 'murmur_core',
                rarity = 'Rare',
                weight = 120,
                category = 'Utility',
            },
            {
                kind = 'item',
                id = 'murmur_mask',
                rarity = 'Legendary',
                weight = 5,
                category = 'Cosmetic',
                pityGroup = 'boss_cosmetic',
            },
        },
    },
}

return BossDropDefs
