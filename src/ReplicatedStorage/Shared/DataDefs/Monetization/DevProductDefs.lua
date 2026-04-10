--!strict

local DevProductDefs = {
    costume_pull_1 = {
        key = 'costume_pull_1',
        productType = 'DevProduct',
        robloxId = 0,
        priceRobux = 79,
        category = 'Cosmetic',
        grants = {
            gachaPulls = 1,
            bannerType = 'costume',
        },
    },
    costume_pull_10 = {
        key = 'costume_pull_10',
        productType = 'DevProduct',
        robloxId = 0,
        priceRobux = 699,
        category = 'Cosmetic',
        grants = {
            gachaPulls = 10,
            bannerType = 'costume',
            bonusPulls = 1,
        },
    },
    dungeon_retry_token = {
        key = 'dungeon_retry_token',
        productType = 'DevProduct',
        robloxId = 0,
        priceRobux = 49,
        category = 'Convenience',
        grants = {
            retryTokens = 1,
        },
    },
    bonus_reward_claim_token = {
        key = 'bonus_reward_claim_token',
        productType = 'DevProduct',
        robloxId = 0,
        priceRobux = 39,
        category = 'Convenience',
        grants = {
            bonusRewardClaims = 1,
        },
    },
    town_teleport_ticket_pack = {
        key = 'town_teleport_ticket_pack',
        productType = 'DevProduct',
        robloxId = 0,
        priceRobux = 29,
        category = 'Convenience',
        grants = {
            townTeleportTickets = 5,
        },
    },
    name_change_scroll = {
        key = 'name_change_scroll',
        productType = 'DevProduct',
        robloxId = 0,
        priceRobux = 99,
        category = 'Utility',
        grants = {
            nameChange = 1,
        },
    },
}

return DevProductDefs

