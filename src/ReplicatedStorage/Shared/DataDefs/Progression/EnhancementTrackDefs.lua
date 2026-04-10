--!strict

local EnhancementTrackDefs = {
    weapon_basic = {
        trackId = 'weapon_basic',
        itemTags = { 'weapon', 'starter' },
        levels = {
            [1] = { successRate = 1.0, onFail = 'None', zenyCost = 60, materials = { green_poring_mucus = 1 } },
            [2] = { successRate = 0.95, onFail = 'None', zenyCost = 100, materials = { green_poring_mucus = 2 } },
            [3] = { successRate = 0.9, onFail = 'None', zenyCost = 160, materials = { green_poring_mucus = 3 } },
            [4] = { successRate = 0.78, onFail = 'NoChange', zenyCost = 240, materials = { green_poring_mucus = 4 } },
            [5] = { successRate = 0.62, onFail = 'Downgrade', zenyCost = 360, materials = { green_poring_mucus = 5, murmur_core = 1 } },
            [6] = { successRate = 0.48, onFail = 'Downgrade', zenyCost = 520, materials = { green_poring_mucus = 6, murmur_core = 1 } },
            [7] = { successRate = 0.34, onFail = 'Destroy', zenyCost = 760, materials = { green_poring_mucus = 8, murmur_core = 2 } },
            [8] = { successRate = 0.22, onFail = 'Destroy', zenyCost = 1080, materials = { green_poring_mucus = 10, murmur_core = 3 } },
            [9] = { successRate = 0.14, onFail = 'Destroy', zenyCost = 1520, materials = { green_poring_mucus = 12, murmur_core = 4 } },
            [10] = { successRate = 0.09, onFail = 'Destroy', zenyCost = 2100, materials = { green_poring_mucus = 15, murmur_core = 5 } },
        },
    },
    weapon_precision = {
        trackId = 'weapon_precision',
        itemTags = { 'weapon', 'precision' },
        levels = {
            [1] = { successRate = 1.0, onFail = 'None', zenyCost = 90, materials = { green_poring_mucus = 1 } },
            [2] = { successRate = 0.96, onFail = 'None', zenyCost = 150, materials = { green_poring_mucus = 2 } },
            [3] = { successRate = 0.91, onFail = 'None', zenyCost = 220, materials = { green_poring_mucus = 3 } },
            [4] = { successRate = 0.8, onFail = 'NoChange', zenyCost = 320, materials = { green_poring_mucus = 4 } },
            [5] = { successRate = 0.66, onFail = 'Downgrade', zenyCost = 470, materials = { green_poring_mucus = 5, murmur_core = 1 } },
            [6] = { successRate = 0.5, onFail = 'Downgrade', zenyCost = 650, materials = { green_poring_mucus = 6, murmur_core = 2 } },
            [7] = { successRate = 0.36, onFail = 'Destroy', zenyCost = 900, materials = { green_poring_mucus = 8, murmur_core = 2 } },
            [8] = { successRate = 0.24, onFail = 'Destroy', zenyCost = 1260, materials = { green_poring_mucus = 10, murmur_core = 3 } },
            [9] = { successRate = 0.16, onFail = 'Destroy', zenyCost = 1750, materials = { green_poring_mucus = 12, murmur_core = 4 } },
            [10] = { successRate = 0.11, onFail = 'Destroy', zenyCost = 2400, materials = { green_poring_mucus = 15, murmur_core = 6 } },
        },
    },
    armor_light = {
        trackId = 'armor_light',
        itemTags = { 'armor', 'light' },
        levels = {
            [1] = { successRate = 1.0, onFail = 'None', zenyCost = 50, materials = { green_poring_mucus = 1 } },
            [2] = { successRate = 0.96, onFail = 'None', zenyCost = 90, materials = { green_poring_mucus = 1 } },
            [3] = { successRate = 0.92, onFail = 'None', zenyCost = 140, materials = { green_poring_mucus = 2 } },
            [4] = { successRate = 0.82, onFail = 'NoChange', zenyCost = 220, materials = { green_poring_mucus = 3 } },
            [5] = { successRate = 0.7, onFail = 'Downgrade', zenyCost = 320, materials = { green_poring_mucus = 4, murmur_core = 1 } },
            [6] = { successRate = 0.56, onFail = 'Downgrade', zenyCost = 470, materials = { green_poring_mucus = 5, murmur_core = 1 } },
            [7] = { successRate = 0.4, onFail = 'Destroy', zenyCost = 680, materials = { green_poring_mucus = 6, murmur_core = 2 } },
            [8] = { successRate = 0.28, onFail = 'Destroy', zenyCost = 960, materials = { green_poring_mucus = 8, murmur_core = 2 } },
            [9] = { successRate = 0.18, onFail = 'Destroy', zenyCost = 1320, materials = { green_poring_mucus = 10, murmur_core = 3 } },
            [10] = { successRate = 0.12, onFail = 'Destroy', zenyCost = 1800, materials = { green_poring_mucus = 12, murmur_core = 4 } },
        },
    },
    weapon_boss = {
        trackId = 'weapon_boss',
        itemTags = { 'weapon', 'boss' },
        levels = {
            [1] = { successRate = 1.0, onFail = 'None', zenyCost = 120, materials = { green_poring_mucus = 2, murmur_core = 1 } },
            [2] = { successRate = 0.96, onFail = 'None', zenyCost = 220, materials = { green_poring_mucus = 3, murmur_core = 1 } },
            [3] = { successRate = 0.9, onFail = 'None', zenyCost = 340, materials = { green_poring_mucus = 4, murmur_core = 1 } },
            [4] = { successRate = 0.78, onFail = 'NoChange', zenyCost = 500, materials = { green_poring_mucus = 5, murmur_core = 2 } },
            [5] = { successRate = 0.62, onFail = 'Downgrade', zenyCost = 760, materials = { green_poring_mucus = 6, murmur_core = 2 } },
            [6] = { successRate = 0.46, onFail = 'Downgrade', zenyCost = 1060, materials = { green_poring_mucus = 8, murmur_core = 3 } },
            [7] = { successRate = 0.3, onFail = 'Destroy', zenyCost = 1460, materials = { green_poring_mucus = 10, murmur_core = 4, old_anvil_fragment = 1 } },
            [8] = { successRate = 0.2, onFail = 'Destroy', zenyCost = 2000, materials = { green_poring_mucus = 12, murmur_core = 5, old_anvil_fragment = 2 } },
            [9] = { successRate = 0.12, onFail = 'Destroy', zenyCost = 2700, materials = { green_poring_mucus = 14, murmur_core = 6, old_anvil_fragment = 3 } },
            [10] = { successRate = 0.07, onFail = 'Destroy', zenyCost = 3600, materials = { green_poring_mucus = 16, murmur_core = 8, old_anvil_fragment = 4 } },
        },
    },
}

return EnhancementTrackDefs
