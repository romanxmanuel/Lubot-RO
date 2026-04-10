--!strict

local PrivateServerDefs = {
    monthly_private_server = {
        key = 'monthly_private_server',
        productType = 'PrivateServer',
        robloxId = 0,
        priceRobux = 199,
        category = 'Social',
        grants = {
            serverAccess = true,
            inviteCodeSupport = true,
            hostResetTools = true,
        },
        rules = {
            noPrivateServerExclusiveLoot = true,
            noPrivateServerExclusivePower = true,
        },
    },
}

return PrivateServerDefs

