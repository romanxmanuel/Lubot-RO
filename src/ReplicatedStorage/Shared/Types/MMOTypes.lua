--!strict

export type InventoryEntry = {
    itemId: string,
    amount: number,
}

export type PlayerProfile = {
    version: number,
    classId: string,
    level: number,
    experience: number,
    zeny: number,
    equippedWeaponId: string,
    inventory: { InventoryEntry },
    unlockedSkills: { string },
    skillLoadout: { string },
    lastWarpId: string,
}

return nil
