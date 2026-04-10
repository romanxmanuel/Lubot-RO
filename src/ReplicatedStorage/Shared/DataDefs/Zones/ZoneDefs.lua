--!strict

local ZoneDefs = {
    prontera_field = {
        id = 'prontera_field',
        name = 'prontera field',
        zoneType = 'Field',
        recommendedLevel = 1,
        enemyPool = { 'poring', 'lunatic', 'willow', 'rocker' },
        chaseDrops = {
            'singing_flower',
            'rocker_card',
        },
    },
    tower_of_ascension = {
        id = 'tower_of_ascension',
        name = 'Tower_of_Ascension',
        zoneType = 'Tower',
        recommendedLevel = 17,
        enemyPool = {},
        chaseDrops = {},
    },
    prontera_outskirts = {
        id = 'prontera_outskirts',
        name = 'Prontera Outskirts',
        zoneType = 'Field',
        recommendedLevel = 1,
        enemyPool = { 'poring', 'lunatic' },
        chaseDrops = {
            'poring_card',
        },
    },
    niffheim = {
        id = 'niffheim',
        name = 'Niffheim',
        zoneType = 'Field',
        recommendedLevel = 40,
        enemyPool = {
            'lude',
            'quve',
            'hylozoist',
            'gibbet',
            'dullahan',
            'disguise',
            'bloody_murderer',
            'loli_ruri',
            'lord_of_the_dead',
        },
        chaseDrops = {
            'creepy_doll_cap',
            'mourning_ribbon',
            'puppet_coat',
            'dullahan_blade',
            'bloody_edge',
            'lord_of_dead_mantle',
            'lord_of_the_dead_card',
        },
    },
}

return ZoneDefs
