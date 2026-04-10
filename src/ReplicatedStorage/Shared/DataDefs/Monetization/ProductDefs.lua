--!strict

local DevProductDefs = require(script.Parent.DevProductDefs)
local PassDefs = require(script.Parent.PassDefs)
local PrivateServerDefs = require(script.Parent.PrivateServerDefs)
local SubscriptionDefs = require(script.Parent.SubscriptionDefs)

local ProductDefs = {
    passes = PassDefs,
    devProducts = DevProductDefs,
    subscriptions = SubscriptionDefs,
    privateServers = PrivateServerDefs,
}

return ProductDefs
