-- MasterConfig (ModuleScript)
-- Location: ReplicatedStorage.MasterConfig
-- Master dial panel: gameplay tuning values consumed by core systems.
return {
    -- PLAYER STATS  [CombatSystem, UIController]
    PlayerMaxHP = 150,
    PlayerHPRegen = 2,
    PlayerRegenDelay = 5,

    -- LEVEL SCALING  [CombatSystem, AttackController]
    LevelDamageScale = 0.10,
    LevelHPScale = 0.15,

    -- ATTACK COMBO  [AttackController, CombatSystem]
    AttackChainWindow = 1.5,
    AttackCooldown = 0.8,
    AutolockReleaseDelay = 2.5,

    -- Per-hit damage/radius for combo hits [1..5]
    HitDamages = { 100, 140, 180, 220, 600 },
    HitRadii = { 8, 20, 26, 13, 32 },

    -- ATTACK ANIMATIONS  [AttackController]
    AttackAnimations = {
        "rbxassetid://125572679859676", -- hit 1
        "rbxassetid://125572679859676", -- hit 2
        "rbxassetid://106167305924743", -- hit 3: Meteor finisher
        "rbxassetid://125572679859676", -- hit 4
        "rbxassetid://106167305924743", -- hit 5: Portal ultra
    },

    -- ATTACK VFX / FEEL  [AttackController]
    AttackShakeIntensity = 1,
    AttackShakeIntensityFinisher = 2.5,
    AttackShakeIntensityUltra = 9,
    AttackShakeDuration = 0.2,
    AttackShakeDurationFinisher = 0.45,
    AttackShakeDurationUltra = 1.1,
    AttackSlowMotionDuration = 0.7,
    AttackSlowMotionSpeed = 0.35,
    AttackSlowMotionDurationUltra = 1.2,
    AttackSlowMotionSpeedUltra = 0.2,

    -- DASH  [DashController, DashHandler]
    Speed = 120,
    Duration = 0.3,
    Cooldown = 0.0,
    DoublePressWindow = 0.3,

    -- JUMP  [AirPhysicsController]
    JumpPower = 150,
    JumpAnimationId = "rbxassetid://89528225806677",

    -- SOUNDS  [AttackController, DashController, AirPhysicsController]
    DashSoundId = "rbxassetid://132482473659637", -- old: rbxassetid://97446969391071
    DashSoundVolume = 1,
    JumpSoundId = "rbxassetid://131227259390218",
    JumpSoundVolume = 1,
    PunchSounds = {
        "rbxassetid://132949532914079", -- hit 1 (old: rbxassetid://78839860221018)
        "rbxassetid://138205601824020", -- hit 2 (old: rbxassetid://95112734054189)
        "rbxassetid://136468342928427", -- hit 3 finisher (old: rbxassetid://89857951233805)
        "rbxassetid://116806174490590", -- hit 4 (old: rbxassetid://75134542001431)
        "rbxassetid://113121674784981", -- hit 5 ultra (old: rbxassetid://83233296435576)
    },
    PunchSoundVolumes = {
        1, -- hit 1
        1, -- hit 2
        1.5, -- hit 3
        1, -- hit 4
        2, -- hit 5 (biggest)
    },

    -- BACKGROUND MUSIC  [BackgroundMusic]
    BackgroundMusicIds = {
        "rbxassetid://138370747424635",
        "rbxassetid://138370747424635",
        "rbxassetid://138370747424635",
    },
    BackgroundMusicVolume = 0.45,
}
