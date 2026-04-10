--!strict

local SkillProgressionDefs = {
    knight_path = {
        milestones = {
            { classId = 'knight', unlockAtLevel = 1, skillId = 'bash', recommendedRank = 1 },
            { classId = 'knight', unlockAtLevel = 1, skillId = 'ice_shard', recommendedRank = 1 },
            { classId = 'knight', unlockAtLevel = 4, skillId = 'increase_hp_recovery', recommendedRank = 1 },
            { classId = 'knight', unlockAtLevel = 6, skillId = 'magnum_break', recommendedRank = 1 },
            { classId = 'knight', unlockAtLevel = 10, skillId = 'provoke', recommendedRank = 1 },
            { classId = 'high_knight', unlockAtLevel = 15, skillId = 'charge_break', recommendedRank = 1 },
            { classId = 'lord_knight', unlockAtLevel = 25, skillId = 'lord_sunder', recommendedRank = 1 },
        },
    },
    assassin_path = {
        milestones = {
            { classId = 'assassin', unlockAtLevel = 1, skillId = 'katar_mastery', recommendedRank = 1 },
            { classId = 'assassin', unlockAtLevel = 4, skillId = 'cloaking', recommendedRank = 1 },
            { classId = 'assassin', unlockAtLevel = 6, skillId = 'grimtooth', recommendedRank = 1 },
            { classId = 'assassin', unlockAtLevel = 10, skillId = 'sonic_blow', recommendedRank = 1 },
            { classId = 'assassin_cross', unlockAtLevel = 15, skillId = 'advanced_katar_mastery', recommendedRank = 1 },
            { classId = 'assassin_cross', unlockAtLevel = 25, skillId = 'enchant_deadly_poison', recommendedRank = 1 },
        },
    },
    archer_path = {
        milestones = {
            { classId = 'archer', unlockAtLevel = 1, skillId = 'double_strafe', recommendedRank = 1 },
            { classId = 'archer', unlockAtLevel = 4, skillId = 'owls_eye', recommendedRank = 1 },
            { classId = 'archer', unlockAtLevel = 6, skillId = 'arrow_shower', recommendedRank = 1 },
            { classId = 'archer', unlockAtLevel = 10, skillId = 'improve_concentration', recommendedRank = 1 },
        },
    },
    mage_path = {
        milestones = {
            { classId = 'mage', unlockAtLevel = 1, skillId = 'fire_bolt', recommendedRank = 1 },
            { classId = 'mage', unlockAtLevel = 4, skillId = 'cold_bolt', recommendedRank = 1 },
            { classId = 'mage', unlockAtLevel = 8, skillId = 'soul_strike', recommendedRank = 1 },
            { classId = 'mage', unlockAtLevel = 12, skillId = 'fire_wall', recommendedRank = 1 },
        },
    },
    zero_path = {
        milestones = {
            { classId = 'zero', unlockAtLevel = 1, skillId = 'forward_slash', recommendedRank = 1 },
            { classId = 'zero', unlockAtLevel = 4, skillId = 'circular_slash', recommendedRank = 1 },
            { classId = 'high_zero', unlockAtLevel = 15, skillId = 'evasive_slash', recommendedRank = 1 },
            { classId = 'transcendent_zero', unlockAtLevel = 25, skillId = 'shadow_clone_slash', recommendedRank = 1 },
        },
    },
    valkyrie_path = {
        milestones = {
            { classId = 'valkyrie', unlockAtLevel = 1, skillId = 'divine_ascent', recommendedRank = 1 },
            { classId = 'valkyrie', unlockAtLevel = 1, skillId = 'sky_piercer', recommendedRank = 1 },
            { classId = 'valkyrie', unlockAtLevel = 4, skillId = 'feather_barrage', recommendedRank = 1 },
            { classId = 'valkyrie', unlockAtLevel = 8, skillId = 'zephyr_veil', recommendedRank = 1 },
            { classId = 'high_valkyrie', unlockAtLevel = 15, skillId = 'sonic_dive', recommendedRank = 1 },
            { classId = 'high_valkyrie', unlockAtLevel = 25, skillId = 'gale_cutter', recommendedRank = 1 },
            { classId = 'valkyrie_rebirthed', unlockAtLevel = 35, skillId = 'storm_overdrive', recommendedRank = 1 },
            { classId = 'seraphim', unlockAtLevel = 45, skillId = 'celestial_sovereignty', recommendedRank = 1 },
            { classId = 'seraphim', unlockAtLevel = 55, skillId = 'judgment_descent', recommendedRank = 1 },
        },
    },
}

return SkillProgressionDefs
