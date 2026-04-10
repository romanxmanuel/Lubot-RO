--!strict

local LoopCadenceConfig = {
    Combat = {
        targetBasicAttackSeconds = {
            min = 0.6,
            max = 1.2,
        },
        targetNormalEnemyTimeToKillSeconds = {
            min = 4,
            max = 8,
        },
        targetKillsPer30Seconds = {
            min = 3,
            max = 5,
        },
        earlySkillUseIntervalSeconds = {
            min = 6,
            max = 12,
        },
        targetKillsPer5Minutes = {
            min = 20,
            max = 40,
        },
    },
    Loot = {
        commonDropPerKill = true,
        notableDropWindowMinutes = {
            min = 3,
            max = 5,
        },
        inspectWorthItemWindowMinutes = {
            min = 10,
            max = 20,
        },
        memorableRareEventWindowMinutes = {
            min = 30,
            max = 60,
        },
    },
    Experience = {
        expBarMovementSeconds = {
            min = 15,
            max = 30,
        },
        earlyLevelUpMinutes = {
            min = 3,
            max = 6,
        },
        midgameLevelUpPerFiveMinuteLoops = {
            min = 2,
            max = 4,
        },
    },
    Skills = {
        firstUnlockMinutes = {
            min = 10,
            max = 20,
        },
        earlyUnlockPerSessionWindow = {
            min = 1,
            max = 3,
        },
    },
    Town = {
        fieldReturnMinutes = {
            min = 5,
            max = 10,
        },
        requiredReturnPer20MinuteSession = 1,
    },
    Blacksmith = {
        considerEnhancementMinutes = {
            min = 10,
            max = 20,
        },
        earlyUpgradeAttemptsPerSessions = {
            min = 1,
            max = 2,
        },
        weeklyUpgradeSessions = {
            min = 2,
            max = 5,
        },
    },
    Social = {
        targetAmbientPlayerVisibility = true,
        weeklyFlexMoments = {
            'visible_glow_weapon',
            'rare_card_drop',
            'costume_piece_completion',
            'fast_dungeon_clear',
        },
    },
    Monetization = {
        combatLoopInterruptionsAllowed = false,
        preferredExposureMoments = {
            'town_return',
            'run_completion',
            'daily_claim',
            'season_pass_progress',
        },
        allowedProductCategories = {
            'cosmetic',
            'convenience',
            'subscription',
            'private_server',
            'battle_pass',
        },
    },
}

return LoopCadenceConfig

