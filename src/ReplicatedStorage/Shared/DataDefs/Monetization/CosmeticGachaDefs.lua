--!strict

local CosmeticGachaDefs = {
    costume_banner_launch = {
        key = 'costume_banner_launch',
        bannerType = 'Costume',
        pity = {
            enabled = true,
            featuredGuaranteeAt = 80,
            rarityGuaranteeAt = 30,
        },
        rewardPool = {
            common = {
                { rewardId = 'town_dye_cream', weight = 3500 },
                { rewardId = 'town_dye_mint', weight = 3500 },
            },
            rare = {
                { rewardId = 'costume_prontera_cape', weight = 900 },
                { rewardId = 'costume_ranger_hat', weight = 900 },
            },
            epic = {
                { rewardId = 'costume_blacksmith_coat', weight = 180 },
                { rewardId = 'weapon_skin_starlit_bow', weight = 180 },
            },
            legendary = {
                { rewardId = 'costume_ragnarok_regalia', weight = 24, featured = true },
                { rewardId = 'weapon_skin_lordflare_blade', weight = 24, featured = true },
            },
        },
        currencyHooks = {
            paidPullProductKey = 'costume_pull_1',
            paidTenPullProductKey = 'costume_pull_10',
            freeTicketItemId = 'cosmetic_ticket',
        },
        rules = {
            cosmeticOnly = true,
            noCombatStats = true,
            transparentRatesRequired = true,
        },
    },
}

return CosmeticGachaDefs
