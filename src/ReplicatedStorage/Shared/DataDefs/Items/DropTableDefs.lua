--!strict

local DropTableDefs = {
    poring = {
        tableType = 'Monster',
        sourceId = 'poring',
        pools = {
            { id = 'apple', category = 'Utility', rolls = 1, chance = 0.65, entries = { { kind = 'item', id = 'apple', rarity = 'Common', weight = 1 } } },
            { id = 'jellopy', category = 'Utility', rolls = 1, chance = 0.55, entries = { { kind = 'item', id = 'jellopy', rarity = 'Common', weight = 1 } } },
            { id = 'empty_bottle', category = 'Utility', rolls = 1, chance = 0.18, entries = { { kind = 'item', id = 'empty_bottle', rarity = 'Common', weight = 1 } } },
            { id = 'poring_hat', category = 'Power', rolls = 1, chance = 0.05, entries = { { kind = 'item', id = 'poring_hood', rarity = 'Rare', weight = 1 } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0001, entries = { { kind = 'card', id = 'poring_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    lunatic = {
        tableType = 'Monster',
        sourceId = 'lunatic',
        pools = {
            { id = 'carrot', category = 'Utility', rolls = 1, chance = 0.60, entries = { { kind = 'item', id = 'carrot', rarity = 'Common', weight = 1 } } },
            { id = 'clover', category = 'Utility', rolls = 1, chance = 0.40, entries = { { kind = 'item', id = 'clover', rarity = 'Common', weight = 1 } } },
            { id = 'feather', category = 'Utility', rolls = 1, chance = 0.15, entries = { { kind = 'item', id = 'feather', rarity = 'Common', weight = 1 } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0001, entries = { { kind = 'card', id = 'lunatic_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    willow = {
        tableType = 'Monster',
        sourceId = 'willow',
        pools = {
            { id = 'tree_root', category = 'Utility', rolls = 1, chance = 0.58, entries = { { kind = 'item', id = 'tree_root', rarity = 'Common', weight = 1 } } },
            { id = 'resin', category = 'Utility', rolls = 1, chance = 0.35, entries = { { kind = 'item', id = 'resin', rarity = 'Common', weight = 1 } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0001, entries = { { kind = 'card', id = 'willow_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    rocker = {
        tableType = 'Monster',
        sourceId = 'rocker',
        pools = {
            { id = 'grasshopper_leg', category = 'Utility', rolls = 1, chance = 0.58, entries = { { kind = 'item', id = 'grasshopper_leg', rarity = 'Common', weight = 1 } } },
            { id = 'singing_flower', category = 'Utility', rolls = 1, chance = 0.18, entries = { { kind = 'item', id = 'singing_flower', rarity = 'Uncommon', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0001, entries = { { kind = 'card', id = 'rocker_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    andre = {
        tableType = 'Monster',
        sourceId = 'andre',
        pools = {
            { id = 'shell', category = 'Utility', rolls = 1, chance = 0.50, entries = { { kind = 'item', id = 'shell', rarity = 'Common', weight = 1 } } },
            { id = 'worm_peeling', category = 'Utility', rolls = 1, chance = 0.30, entries = { { kind = 'item', id = 'worm_peeling', rarity = 'Common', weight = 1 } } },
            { id = 'stiletto', category = 'Power', rolls = 1, chance = 0.02, entries = { { kind = 'item', id = 'stiletto', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0001, entries = { { kind = 'card', id = 'andre_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    deniro = {
        tableType = 'Monster',
        sourceId = 'deniro',
        pools = {
            { id = 'chrysalis', category = 'Utility', rolls = 1, chance = 0.48, entries = { { kind = 'item', id = 'chrysalis', rarity = 'Common', weight = 1 } } },
            { id = 'green_herb', category = 'Utility', rolls = 1, chance = 0.35, entries = { { kind = 'item', id = 'green_herb', rarity = 'Common', weight = 1 } } },
            { id = 'chain_mail', category = 'Power', rolls = 1, chance = 0.015, entries = { { kind = 'item', id = 'chain_mail', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0001, entries = { { kind = 'card', id = 'deniro_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    piere = {
        tableType = 'Monster',
        sourceId = 'piere',
        pools = {
            { id = 'sticky_mucus', category = 'Utility', rolls = 1, chance = 0.48, entries = { { kind = 'item', id = 'sticky_mucus', rarity = 'Common', weight = 1 } } },
            { id = 'yellow_herb', category = 'Utility', rolls = 1, chance = 0.18, entries = { { kind = 'item', id = 'yellow_herb', rarity = 'Uncommon', weight = 1 } } },
            { id = 'crossbow', category = 'Power', rolls = 1, chance = 0.02, entries = { { kind = 'item', id = 'crossbow', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0001, entries = { { kind = 'card', id = 'piere_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    vitata = {
        tableType = 'Monster',
        sourceId = 'vitata',
        pools = {
            { id = 'honey', category = 'Utility', rolls = 1, chance = 0.22, entries = { { kind = 'item', id = 'honey', rarity = 'Uncommon', weight = 1 } } },
            { id = 'royal_jelly', category = 'Utility', rolls = 1, chance = 0.02, entries = { { kind = 'item', id = 'royal_jelly', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'mantle', category = 'Power', rolls = 1, chance = 0.01, entries = { { kind = 'item', id = 'mantle', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0001, entries = { { kind = 'card', id = 'vitata_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    sewer_boss_murmur = {
        tableType = 'Boss',
        sourceId = 'sewer_lord_murmur',
        pools = {
            {
                id = 'boss_baseline',
                category = 'Utility',
                rolls = 2,
                entries = {
                    { kind = 'item', id = 'green_poring_mucus', rarity = 'Uncommon', weight = 2500, quantity = { min = 2, max = 4 } },
                    { kind = 'item', id = 'murmur_core', rarity = 'Rare', weight = 420, quantity = { min = 1, max = 2 } },
                    { kind = 'item', id = 'old_anvil_fragment', rarity = 'Epic', weight = 35, quantity = { min = 1, max = 1 }, chaseDrop = true },
                },
            },
            {
                id = 'boss_power_exclusive',
                category = 'Power',
                rolls = 1,
                chance = 0.45,
                entries = {
                    { kind = 'item', id = 'murmur_blade', rarity = 'Epic', weight = 18, affixEligible = true, exclusive = true },
                    { kind = 'card', id = 'sewer_lord_murmur_card', rarity = 'Mythic', weight = 1, exclusive = true, chaseDrop = true },
                },
            },
            {
                id = 'boss_cosmetic',
                category = 'Cosmetic',
                rolls = 1,
                chance = 0.08,
                entries = {
                    { kind = 'item', id = 'murmur_mask', rarity = 'Legendary', weight = 1, exclusive = true, pityGroup = 'boss_cosmetic' },
                },
            },
        },
    },
    maya_purple_trial = {
        tableType = 'Boss',
        sourceId = 'maya_purple_trial',
        pools = {
            {
                id = 'maya_trial_core',
                category = 'Utility',
                rolls = 3,
                entries = {
                    { kind = 'item', id = 'royal_jelly', rarity = 'Rare', weight = 1000, quantity = { min = 1, max = 3 } },
                    { kind = 'item', id = 'blue_potion', rarity = 'Uncommon', weight = 900, quantity = { min = 2, max = 4 } },
                    { kind = 'item', id = 'butterfly_wing', rarity = 'Uncommon', weight = 700, quantity = { min = 1, max = 2 } },
                    { kind = 'item', id = 'murmur_core', rarity = 'Rare', weight = 520, quantity = { min = 1, max = 2 } },
                    { kind = 'item', id = 'old_anvil_fragment', rarity = 'Epic', weight = 90, quantity = { min = 1, max = 1 }, chaseDrop = true },
                },
            },
            {
                id = 'maya_power',
                category = 'Power',
                rolls = 1,
                chance = 0.78,
                entries = {
                    { kind = 'item', id = 'maya_purple_carapace', rarity = 'Legendary', weight = 12, exclusive = true, chaseDrop = true },
                    { kind = 'item', id = 'murmur_blade', rarity = 'Epic', weight = 18, affixEligible = true, exclusive = true, chaseDrop = true },
                    { kind = 'item', id = 'chain_mail', rarity = 'Rare', weight = 46, exclusive = true },
                    { kind = 'item', id = 'leather_jacket', rarity = 'Rare', weight = 24, exclusive = true, affixEligible = true },
                },
            },
            {
                id = 'maya_relics',
                category = 'Cosmetic',
                rolls = 1,
                chance = 0.26,
                entries = {
                    { kind = 'item', id = 'murmur_mask', rarity = 'Legendary', weight = 4, exclusive = true, chaseDrop = true },
                    { kind = 'item', id = 'poring_hood', rarity = 'Rare', weight = 14, exclusive = true },
                },
            },
            {
                id = 'maya_card_chase',
                category = 'Power',
                rolls = 1,
                chance = 0.004,
                entries = {
                    { kind = 'card', id = 'maya_purple_card', rarity = 'Mythic', weight = 1, exclusive = true, chaseDrop = true },
                },
            },
        },
    },
    lude = {
        tableType = 'Monster',
        sourceId = 'lude',
        pools = {
            { id = 'toy_key', category = 'Utility', rolls = 1, chance = 0.62, entries = { { kind = 'item', id = 'toy_key', rarity = 'Common', weight = 1 } } },
            { id = 'candy_shard', category = 'Utility', rolls = 1, chance = 0.42, entries = { { kind = 'item', id = 'candy_shard', rarity = 'Common', weight = 1 } } },
            { id = 'creepy_doll_cap', category = 'Power', rolls = 1, chance = 0.018, entries = { { kind = 'item', id = 'creepy_doll_cap', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0002, entries = { { kind = 'card', id = 'lude_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    quve = {
        tableType = 'Monster',
        sourceId = 'quve',
        pools = {
            { id = 'black_ribbon', category = 'Utility', rolls = 1, chance = 0.58, entries = { { kind = 'item', id = 'black_ribbon', rarity = 'Common', weight = 1 } } },
            { id = 'mourning_cloth', category = 'Utility', rolls = 1, chance = 0.24, entries = { { kind = 'item', id = 'mourning_cloth', rarity = 'Uncommon', weight = 1 } } },
            { id = 'mourning_ribbon', category = 'Power', rolls = 1, chance = 0.015, entries = { { kind = 'item', id = 'mourning_ribbon', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0002, entries = { { kind = 'card', id = 'quve_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    hylozoist = {
        tableType = 'Monster',
        sourceId = 'hylozoist',
        pools = {
            { id = 'puppet_string', category = 'Utility', rolls = 1, chance = 0.57, entries = { { kind = 'item', id = 'puppet_string', rarity = 'Common', weight = 1 } } },
            { id = 'possessed_shard', category = 'Utility', rolls = 1, chance = 0.22, entries = { { kind = 'item', id = 'possessed_shard', rarity = 'Uncommon', weight = 1 } } },
            { id = 'puppet_coat', category = 'Power', rolls = 1, chance = 0.013, entries = { { kind = 'item', id = 'puppet_coat', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0002, entries = { { kind = 'card', id = 'hylozoist_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    gibbet = {
        tableType = 'Monster',
        sourceId = 'gibbet',
        pools = {
            { id = 'rusted_shackle', category = 'Utility', rolls = 1, chance = 0.55, entries = { { kind = 'item', id = 'rusted_shackle', rarity = 'Common', weight = 1 } } },
            { id = 'executioner_rope', category = 'Utility', rolls = 1, chance = 0.23, entries = { { kind = 'item', id = 'executioner_rope', rarity = 'Uncommon', weight = 1 } } },
            { id = 'gibbet_armor', category = 'Power', rolls = 1, chance = 0.014, entries = { { kind = 'item', id = 'gibbet_armor', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0002, entries = { { kind = 'card', id = 'gibbet_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    dullahan = {
        tableType = 'Monster',
        sourceId = 'dullahan',
        pools = {
            { id = 'cursed_helm_shard', category = 'Utility', rolls = 1, chance = 0.52, entries = { { kind = 'item', id = 'cursed_helm_shard', rarity = 'Common', weight = 1 } } },
            { id = 'phantom_steel', category = 'Utility', rolls = 1, chance = 0.25, entries = { { kind = 'item', id = 'phantom_steel', rarity = 'Uncommon', weight = 1 } } },
            { id = 'dullahan_blade', category = 'Power', rolls = 1, chance = 0.014, entries = { { kind = 'item', id = 'dullahan_blade', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0002, entries = { { kind = 'card', id = 'dullahan_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    disguise = {
        tableType = 'Monster',
        sourceId = 'disguise',
        pools = {
            { id = 'veil_fragment', category = 'Utility', rolls = 1, chance = 0.56, entries = { { kind = 'item', id = 'veil_fragment', rarity = 'Common', weight = 1 } } },
            { id = 'phantom_cloth', category = 'Utility', rolls = 1, chance = 0.23, entries = { { kind = 'item', id = 'phantom_cloth', rarity = 'Uncommon', weight = 1 } } },
            { id = 'specter_veil', category = 'Power', rolls = 1, chance = 0.015, entries = { { kind = 'item', id = 'specter_veil', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0002, entries = { { kind = 'card', id = 'disguise_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    bloody_murderer = {
        tableType = 'Monster',
        sourceId = 'bloody_murderer',
        pools = {
            { id = 'bloodied_knife_fragment', category = 'Utility', rolls = 1, chance = 0.52, entries = { { kind = 'item', id = 'bloodied_knife_fragment', rarity = 'Common', weight = 1 } } },
            { id = 'murderer_coat_scrap', category = 'Utility', rolls = 1, chance = 0.22, entries = { { kind = 'item', id = 'murderer_coat_scrap', rarity = 'Uncommon', weight = 1 } } },
            { id = 'bloody_edge', category = 'Power', rolls = 1, chance = 0.012, entries = { { kind = 'item', id = 'bloody_edge', rarity = 'Epic', weight = 1, chaseDrop = true, affixEligible = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0002, entries = { { kind = 'card', id = 'bloody_murderer_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    loli_ruri = {
        tableType = 'Monster',
        sourceId = 'loli_ruri',
        pools = {
            { id = 'ruri_ribbon', category = 'Utility', rolls = 1, chance = 0.55, entries = { { kind = 'item', id = 'ruri_ribbon', rarity = 'Common', weight = 1 } } },
            { id = 'ghost_kimono_scrap', category = 'Utility', rolls = 1, chance = 0.25, entries = { { kind = 'item', id = 'ghost_kimono_scrap', rarity = 'Uncommon', weight = 1 } } },
            { id = 'ruri_kimono', category = 'Power', rolls = 1, chance = 0.015, entries = { { kind = 'item', id = 'ruri_kimono', rarity = 'Rare', weight = 1, chaseDrop = true } } },
            { id = 'card', category = 'Power', rolls = 1, chance = 0.0002, entries = { { kind = 'card', id = 'loli_ruri_card', rarity = 'Legendary', weight = 1, chaseDrop = true } } },
        },
    },
    lord_of_the_dead = {
        tableType = 'Boss',
        sourceId = 'lord_of_the_dead',
        pools = {
            {
                id = 'lord_core',
                category = 'Utility',
                rolls = 3,
                entries = {
                    { kind = 'item', id = 'dead_branch_relic', rarity = 'Rare', weight = 1200, quantity = { min = 1, max = 2 } },
                    { kind = 'item', id = 'reaper_lantern', rarity = 'Epic', weight = 460, quantity = { min = 1, max = 1 }, chaseDrop = true },
                    { kind = 'item', id = 'blue_potion', rarity = 'Uncommon', weight = 840, quantity = { min = 2, max = 4 } },
                    { kind = 'item', id = 'royal_jelly', rarity = 'Rare', weight = 620, quantity = { min = 1, max = 2 } },
                },
            },
            {
                id = 'lord_power',
                category = 'Power',
                rolls = 1,
                chance = 0.82,
                entries = {
                    { kind = 'item', id = 'lord_of_dead_mantle', rarity = 'Legendary', weight = 16, exclusive = true, chaseDrop = true },
                    { kind = 'item', id = 'gravebone_crown', rarity = 'Legendary', weight = 14, exclusive = true, chaseDrop = true },
                    { kind = 'item', id = 'bloody_edge', rarity = 'Epic', weight = 28, exclusive = true, affixEligible = true, chaseDrop = true },
                },
            },
            {
                id = 'lord_card_chase',
                category = 'Power',
                rolls = 1,
                chance = 0.005,
                entries = {
                    { kind = 'card', id = 'lord_of_the_dead_card', rarity = 'Mythic', weight = 1, exclusive = true, chaseDrop = true },
                },
            },
        },
    },
}

return DropTableDefs
