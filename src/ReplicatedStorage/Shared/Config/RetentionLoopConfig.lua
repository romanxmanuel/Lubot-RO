--!strict

local RetentionLoopConfig = {
    Day7 = {
        expectedMajorGearUpgrades = {
            min = 1,
            max = 2,
        },
        expectedMeaningfulRareEvents = {
            min = 1,
            max = 3,
        },
        targetIdentityOutcomes = {
            'agi_crit_build',
            'vit_frontliner',
            'int_skill_spammer',
            'dex_precision_build',
        },
        weeklyTownRituals = {
            'enhancement_session',
            'daily_claims',
            'party_regroup',
            'cosmetic_browse',
        },
    },
    Day30 = {
        targetLongTailGoals = {
            'prestige_weapon_tier',
            'card_collection_progress',
            'costume_set_completion',
            'season_pass_completion',
            'class_mastery_progress',
        },
        targetStatusSignals = {
            'enhancement_glow',
            'rare_card_set',
            'signature_costume',
            'dungeon_clear_reputation',
        },
        monetizationSupportGoals = {
            'identity_expression',
            'social_organization',
            'session_convenience',
            'retention_rewards',
        },
    },
}

return RetentionLoopConfig

