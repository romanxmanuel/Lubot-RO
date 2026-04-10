--!strict

local RarityDefs = {
    Order = {
        'Common',
        'Uncommon',
        'Rare',
        'Epic',
        'Legendary',
        'Mythic',
    },
    Common = {
        id = 'Common',
        weightBand = 'baseline',
        dopamine = 'steady',
        color = '#C8C8C8',
    },
    Uncommon = {
        id = 'Uncommon',
        weightBand = 'noticeable',
        dopamine = 'small_pop',
        color = '#72D66B',
    },
    Rare = {
        id = 'Rare',
        weightBand = 'surprise',
        dopamine = 'inspect_now',
        color = '#55B8FF',
    },
    Epic = {
        id = 'Epic',
        weightBand = 'session_maker',
        dopamine = 'screenshot',
        color = '#C377FF',
    },
    Legendary = {
        id = 'Legendary',
        weightBand = 'story',
        dopamine = 'town_flex',
        color = '#FFB347',
    },
    Mythic = {
        id = 'Mythic',
        weightBand = 'ultra_story',
        dopamine = 'discord_ping',
        color = '#FF6B6B',
    },
}

return RarityDefs
