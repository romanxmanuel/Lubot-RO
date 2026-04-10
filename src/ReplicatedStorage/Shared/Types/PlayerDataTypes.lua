--!strict

export type CoreStats = {
    STR: number,
    AGI: number,
    VIT: number,
    INT: number,
    DEX: number,
    LUK: number,
}

export type PlayerProfile = {
    version: number,
    level: number,
    experience: number,
    statPoints: number,
    skillPoints: number,
    zeny: number,
    premiumCurrency: number,
    baseStats: CoreStats,
    inventory: { [string]: number },
    equipment: { [string]: string? },
    cards: { [string]: number },
    unlockedSkills: { [string]: boolean },
    skillRanks: { [string]: number },
    unlockedCosmetics: { [string]: boolean },
}

return {}
