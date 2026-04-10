--!strict

local DASH_STEP_SOUND_ID = 'rbxassetid://139994035606058'
local FOOTSTEP_SOUND_ID = 'rbxasset://sounds/action_footsteps_plastic.mp3'
local JUMP_SOUND_ID = 'rbxassetid://87863790669536'
local LAND_SOUND_ID = 'rbxasset://sounds/action_jump_land.mp3'
local FALL_SOUND_ID = 'rbxasset://sounds/action_falling.ogg'
local SWIM_SOUND_ID = 'rbxasset://sounds/action_swim.mp3'
local SPLASH_SOUND_ID = 'rbxasset://sounds/impact_water.mp3'
local GET_UP_SOUND_ID = 'rbxasset://sounds/action_get_up.mp3'

local CombatAudioConfig = {
    basicAttack = {
        soundId = 'rbxassetid://12222216',
        volume = 0.32,
        playbackSpeed = 1.05,
        rollOffMaxDistance = 90,
    },
    basicAttackCrit = {
        soundId = 'rbxassetid://12222225',
        volume = 0.48,
        playbackSpeed = 1.12,
        rollOffMaxDistance = 110,
    },
    lordSunder = {
        soundId = 'rbxassetid://138186576',
        volume = 2.8,
        playbackSpeed = 0.86,
        rollOffMaxDistance = 360,
    },
    skillSounds = {
        dash_step = {
            soundId = DASH_STEP_SOUND_ID,
            volume = 0.65,
            playbackSpeed = 1.0,
            rollOffMaxDistance = 110,
        },
        blink_step = {
            soundId = 'rbxassetid://12222124',
            volume = 0.9,
            playbackSpeed = 1.08,
            rollOffMaxDistance = 150,
        },
        bash = {
            soundId = 'rbxassetid://12222216',
            volume = 0.65,
            playbackSpeed = 0.96,
            rollOffMaxDistance = 120,
        },
        magnum_break = {
            soundId = 'rbxassetid://138186576',
            volume = 1.45,
            playbackSpeed = 1.08,
            rollOffMaxDistance = 180,
        },
        provoke = {
            soundId = 'rbxassetid://12222084',
            volume = 0.62,
            playbackSpeed = 0.92,
            rollOffMaxDistance = 100,
        },
        charge_break = {
            soundId = 'rbxassetid://12222124',
            volume = 1.1,
            playbackSpeed = 0.9,
            rollOffMaxDistance = 170,
        },
        lord_sunder = {
            soundId = 'rbxassetid://138186576',
            volume = 2.8,
            playbackSpeed = 0.86,
            rollOffMaxDistance = 360,
        },
        chaos_cluster = {
            soundId = 'rbxassetid://128912290',
            volume = 1.35,
            playbackSpeed = 1.18,
            rollOffMaxDistance = 180,
        },
        unwing_flyers = {
            soundId = 'rbxassetid://49460592',
            volume = 1.0,
            playbackSpeed = 1.0,
            rollOffMaxDistance = 160,
        },
        fire_bolt = {
            soundId = 'rbxassetid://9113420779',
            volume = 0.78,
            playbackSpeed = 1.15,
            rollOffMaxDistance = 145,
        },
        cold_bolt = {
            soundId = 'rbxassetid://9113420779',
            volume = 0.74,
            playbackSpeed = 0.82,
            rollOffMaxDistance = 145,
        },
        ice_shard = {
            soundId = 'rbxassetid://5859341051',
            volume = 1.0,
            playbackSpeed = 1.0,
            rollOffMaxDistance = 165,
        },
        soul_strike = {
            soundId = 'rbxassetid://9113420779',
            volume = 0.92,
            playbackSpeed = 0.68,
            rollOffMaxDistance = 150,
        },
        fire_wall = {
            soundId = 'rbxassetid://138186576',
            volume = 0.95,
            playbackSpeed = 1.26,
            rollOffMaxDistance = 170,
        },
        double_strafe = {
            soundId = 'rbxassetid://12221976',
            volume = 0.72,
            playbackSpeed = 1.28,
            rollOffMaxDistance = 130,
        },
        arrow_shower = {
            soundId = 'rbxassetid://12221976',
            volume = 0.94,
            playbackSpeed = 0.96,
            rollOffMaxDistance = 170,
        },
        improve_concentration = {
            soundId = 'rbxassetid://12222058',
            volume = 0.6,
            playbackSpeed = 1.22,
            rollOffMaxDistance = 100,
        },
        increase_hp_recovery = {
            soundId = 'rbxassetid://12222058',
            volume = 0.45,
            playbackSpeed = 0.92,
            rollOffMaxDistance = 90,
        },
        owls_eye = {
            soundId = 'rbxassetid://12222058',
            volume = 0.42,
            playbackSpeed = 1.34,
            rollOffMaxDistance = 90,
        },
        sonic_blow = {
            soundId = 'rbxassetid://73267694920608',
            volume = 1.05,
            playbackSpeed = 1.0,
            rollOffMaxDistance = 170,
        },
        level_up = {
            soundId = 'rbxassetid://130041948705232',
            volume = 1.35,
            playbackSpeed = 1.0,
            rollOffMaxDistance = 210,
        },
        forward_slash = {
            soundId = 'rbxassetid://12222216',
            volume = 0.74,
            playbackSpeed = 1.28,
            rollOffMaxDistance = 130,
        },
        circular_slash = {
            soundId = 'rbxassetid://12222124',
            volume = 0.84,
            playbackSpeed = 1.02,
            rollOffMaxDistance = 155,
        },
        evasive_slash = {
            soundId = 'rbxassetid://12222124',
            volume = 0.72,
            playbackSpeed = 1.18,
            rollOffMaxDistance = 145,
        },
        shadow_clone_slash = {
            soundId = 'rbxassetid://12222225',
            volume = 0.9,
            playbackSpeed = 1.08,
            rollOffMaxDistance = 180,
        },
    },
    movementSounds = {
        running = {
            soundId = FOOTSTEP_SOUND_ID,
            volume = 0.18,
            playbackSpeed = 1.0,
            rollOffMinDistance = 5,
            rollOffMaxDistance = 40,
        },
        climbing = {
            soundId = FOOTSTEP_SOUND_ID,
            volume = 0.16,
            playbackSpeed = 0.94,
            rollOffMinDistance = 5,
            rollOffMaxDistance = 36,
        },
        jumping = {
            soundId = JUMP_SOUND_ID,
            volume = 0.65,
            playbackSpeed = 1.0,
            rollOffMinDistance = 6,
            rollOffMaxDistance = 55,
        },
        landing = {
            soundId = LAND_SOUND_ID,
            volume = 0.58,
            playbackSpeed = 1.0,
            rollOffMinDistance = 6,
            rollOffMaxDistance = 55,
        },
        freefalling = {
            soundId = FALL_SOUND_ID,
            volume = 0.08,
            playbackSpeed = 1.0,
            rollOffMinDistance = 8,
            rollOffMaxDistance = 65,
        },
        swimming = {
            soundId = SWIM_SOUND_ID,
            volume = 0.2,
            playbackSpeed = 1.0,
            rollOffMinDistance = 8,
            rollOffMaxDistance = 48,
        },
        splash = {
            soundId = SPLASH_SOUND_ID,
            volume = 0.45,
            playbackSpeed = 1.0,
            rollOffMinDistance = 8,
            rollOffMaxDistance = 60,
        },
        getting_up = {
            soundId = GET_UP_SOUND_ID,
            volume = 0.4,
            playbackSpeed = 1.0,
            rollOffMinDistance = 6,
            rollOffMaxDistance = 45,
        },
        sit = {
            soundId = 'rbxassetid://12222058',
            volume = 0.35,
            playbackSpeed = 0.82,
            rollOffMinDistance = 6,
            rollOffMaxDistance = 40,
        },
        stand = {
            soundId = GET_UP_SOUND_ID,
            volume = 0.34,
            playbackSpeed = 1.08,
            rollOffMinDistance = 6,
            rollOffMaxDistance = 42,
        },
        fly_toggle = {
            soundId = DASH_STEP_SOUND_ID,
            volume = 0.42,
            playbackSpeed = 0.9,
            rollOffMinDistance = 6,
            rollOffMaxDistance = 70,
        },
    },
    uiSounds = {
        upgrade_success = {
            soundId = 'rbxassetid://73465307512601',
            volume = 0.82,
            playbackSpeed = 1.0,
        },
        sell_confirm = {
            soundId = 'rbxassetid://126288699379956',
            volume = 0.78,
            playbackSpeed = 1.0,
        },
        parry_clash = {
            soundId = 'rbxassetid://9120641666',
            volume = 0.9,
            playbackSpeed = 1.0,
        },
        parry_fail = {
            soundId = 'rbxassetid://12222084',
            volume = 0.72,
            playbackSpeed = 0.78,
        },
    },
}

return CombatAudioConfig
