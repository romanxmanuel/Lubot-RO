--!strict

local CadenceProgressionDefs = {
    earlyGame = {
        levelUpTargetMinutes = {
            min = 3,
            max = 6,
        },
        firstSkillUnlockMinutes = {
            min = 10,
            max = 20,
        },
        townReturnMinutes = {
            min = 5,
            max = 10,
        },
        firstEnhancementConsiderationMinutes = {
            min = 10,
            max = 20,
        },
    },
    midGame = {
        levelUpFiveMinuteLoops = {
            min = 2,
            max = 4,
        },
        unlockRankSessions = {
            min = 1,
            max = 3,
        },
        memorableRareEventMinutes = {
            min = 30,
            max = 60,
        },
    },
}

return CadenceProgressionDefs

