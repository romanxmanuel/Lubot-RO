--!strict

local SubscriptionDefs = {
    bloom_club = {
        key = 'bloom_club',
        productType = 'Subscription',
        robloxId = 0,
        priceRobux = 499,
        category = 'Subscription',
        grants = {
            dailyCosmeticTicket = 1,
            dailyZeny = 500,
            extraWardrobeSlots = 2,
            monthlyTitle = 'Bloom Club',
            subscriberAuraColor = 'gold_warm',
        },
        rules = {
            noExclusiveCombatPower = true,
            noRequiredProgressionAccess = true,
        },
    },
}

return SubscriptionDefs

