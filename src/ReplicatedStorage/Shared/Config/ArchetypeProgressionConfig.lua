--!strict

local ArchetypeProgressionConfig = {
    BaseStageSuggestedLevel = 30,
    HighStageSuggestedLevel = 50,
    RebirthStageSuggestedLevel = 70,
    AdvancedStageSuggestedLevel = 110,
    StageOrder = {
        'Base',
        'High',
        'Rebirth',
        'Advanced',
    },
    MinimumMilestoneSpacing = 3,
    FlashinessCurve = {
        Base = 1,
        High = 2,
        Rebirth = 3,
        Advanced = 4,
    },
}

return ArchetypeProgressionConfig
