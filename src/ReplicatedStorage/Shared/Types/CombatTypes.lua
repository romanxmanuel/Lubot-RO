--!strict

export type DamagePacket = {
    sourceId: string,
    targetId: string,
    amount: number,
    damageType: string,
    isCrit: boolean,
    skillId: string?,
}

export type RewardPacket = {
    experience: number,
    zeny: number,
    itemDrops: { string },
    cardDrops: { string },
}

local PlayerParryState = {
    IDLE     = 'IDLE',
    ACTIVE   = 'ACTIVE',
    STUNNED  = 'STUNNED',
    COOLDOWN = 'COOLDOWN',
}

local BossState = {
    IDLE             = 'IDLE',
    WINDING_UP       = 'WINDING_UP',
    STRIKING         = 'STRIKING',
    PARRY_STAGGERED  = 'PARRY_STAGGERED',
}

return {
    PlayerParryState = PlayerParryState,
    BossState = BossState,
}

