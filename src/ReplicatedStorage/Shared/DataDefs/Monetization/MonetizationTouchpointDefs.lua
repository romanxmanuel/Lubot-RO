--!strict

local MonetizationTouchpointDefs = {
    passive = {
        {
            id = 'battle_pass_tick',
            allowedContexts = { 'combat_reward', 'run_complete' },
            category = 'battle_pass',
            interruptive = false,
        },
        {
            id = 'inventory_pressure_hint',
            allowedContexts = { 'town_return', 'inventory_full' },
            category = 'convenience',
            interruptive = false,
        },
    },
    town = {
        {
            id = 'costume_banner',
            allowedContexts = { 'town_hub', 'run_complete' },
            category = 'cosmetic',
            interruptive = false,
        },
        {
            id = 'subscription_daily_reward',
            allowedContexts = { 'daily_login', 'town_hub' },
            category = 'subscription',
            interruptive = false,
        },
        {
            id = 'private_server_invite',
            allowedContexts = { 'party_forming', 'dungeon_queue' },
            category = 'private_server',
            interruptive = false,
        },
    },
}

return MonetizationTouchpointDefs

