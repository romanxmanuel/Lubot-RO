--!strict

export type CoreStats = {
    STR: number,
    AGI: number,
    VIT: number,
    INT: number,
    DEX: number,
    LUK: number,
}

export type StatBonuses = {
    STR: number?,
    AGI: number?,
    VIT: number?,
    INT: number?,
    DEX: number?,
    LUK: number?,
}

export type StatusResistanceMap = {
    stun: number,
    freeze: number,
    silence: number,
    poison: number,
    blind: number,
    slow: number,
    curse: number,
}

export type DerivedStats = {
    maxHealth: number,
    maxMana: number,
    hpRegenPerTick: number,
    spRegenPerTick: number,
    physicalAttack: number,
    magicAttack: number,
    physicalDefense: number,
    magicalDefense: number,
    hit: number,
    flee: number,
    critChance: number,
    critDamageMultiplier: number,
    perfectDodgeChance: number,
    displayAspd: number,
    attackSpeedMultiplier: number,
    attacksPerSecond: number,
    attackIntervalSeconds: number,
    castSpeedMultiplier: number,
    carryWeight: number,
    cardFindBonus: number,
    itemFindBonus: number,
    upgradeLuckBonus: number,
    healingPowerMultiplier: number,
    statusResistance: StatusResistanceMap,
}

export type ScalingProfile = {
    strength: number?,
    agility: number?,
    vitality: number?,
    intelligence: number?,
    dexterity: number?,
    luck: number?,
}

return {}
