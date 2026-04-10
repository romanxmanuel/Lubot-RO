--!strict

local EnhancementConfig = {
    SafeTierMax = 3,
    RiskyTierStart = 4,
    DestructiveTierStart = 7,
    MaximumEnhancementLevel = 10,
    MaximumLuckBonus = 0.06,
    Audit = {
        SuspiciousFailureThreshold = 25,
        SuspiciousSuccessThreshold = 15,
        RepeatedRequestWindowSeconds = 2,
        RepeatedRequestThreshold = 8,
    },
    Presentation = {
        AnticipationSeconds = 1.8,
        ResultRevealSeconds = 0.9,
        SpectacleThreshold = 7,
        BroadcastThreshold = 8,
    },
    Protection = {
        destroyProtection = {
            prevents = { 'Destroy' },
            consumesOnUse = true,
        },
        downgradeProtection = {
            prevents = { 'Downgrade' },
            consumesOnUse = true,
        },
        premiumAnvilBlessing = {
            prevents = { 'Destroy', 'Downgrade' },
            consumesOnUse = true,
        },
    },
}

return EnhancementConfig
