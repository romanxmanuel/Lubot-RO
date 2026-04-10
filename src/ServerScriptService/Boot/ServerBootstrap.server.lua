--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local Services = script.Parent.Parent.Services
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local loadedServices = {
    PersistenceService = require(Services.PersistenceService),
    CharacterService = require(Services.CharacterService),
    CharacterSkinService = require(Services.CharacterSkinService),
    LootService = require(Services.LootService),
    EnemyService = require(Services.EnemyServiceV2),
    CombatService = require(Services.CombatServiceV2),
    SkillService = require(Services.SkillService),
    InventoryService = require(Services.InventoryServiceV2),
    WorldService = require(Services.WorldServiceV2),
}

local orderedServices = {
    loadedServices.PersistenceService,
    loadedServices.CharacterService,
    loadedServices.CharacterSkinService,
    loadedServices.LootService,
    loadedServices.EnemyService,
    loadedServices.CombatService,
    loadedServices.SkillService,
    loadedServices.InventoryService,
    loadedServices.WorldService,
}

local dependencies = table.clone(loadedServices)
dependencies.Runtime = MMONet.ensureServerRuntime()

for _, service in ipairs(orderedServices) do
    if service.init then
        local ok, err = pcall(service.init, dependencies)
        if not ok then
            warn(string.format('ServerBootstrap init failed: %s -> %s', tostring(service), tostring(err)))
        end
    end
end

for _, service in ipairs(orderedServices) do
    if service.start then
        local ok, err = pcall(service.start)
        if not ok then
            warn(string.format('ServerBootstrap start failed: %s -> %s', tostring(service), tostring(err)))
        end
    end
end

return nil
