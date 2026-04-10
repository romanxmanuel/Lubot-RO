--!strict

local PassDefs = {
    adventurer_pack = {
        key = 'adventurer_pack',
        productType = 'GamePass',
        robloxId = 0,
        priceRobux = 199,
        category = 'Convenience',
        grants = {
            inventorySlots = 40,
        },
        marketing = {
            shortName = 'Adventurer Pack',
            playerValue = 'More inventory space for longer farming sessions.',
        },
    },
    wardrobe_unlock = {
        key = 'wardrobe_unlock',
        productType = 'GamePass',
        robloxId = 0,
        priceRobux = 149,
        category = 'Cosmetic',
        grants = {
            cosmeticPresetSlots = 3,
        },
        marketing = {
            shortName = 'Wardrobe Unlock',
            playerValue = 'Save more looks and swap town style faster.',
        },
    },
    party_leader_tools = {
        key = 'party_leader_tools',
        productType = 'GamePass',
        robloxId = 0,
        priceRobux = 99,
        category = 'Social',
        grants = {
            partyBoardMarkers = true,
            quickInviteTools = true,
        },
        marketing = {
            shortName = 'Party Leader Tools',
            playerValue = 'Organize dungeon groups faster.',
        },
    },
    blacksmith_ledger = {
        key = 'blacksmith_ledger',
        productType = 'GamePass',
        robloxId = 0,
        priceRobux = 99,
        category = 'Cosmetic',
        grants = {
            forgeHistoryPanel = true,
            forgeVfxVariant = 'golden_sparks',
        },
        marketing = {
            shortName = 'Blacksmith Ledger',
            playerValue = 'Track enhancement history and unlock extra forge flair.',
        },
    },
}

return PassDefs

