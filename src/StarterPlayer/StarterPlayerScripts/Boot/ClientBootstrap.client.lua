--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local StarterPlayer = game:GetService('StarterPlayer')

local Controllers = StarterPlayer.StarterPlayerScripts.Controllers
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local loadedControllers = {
    BackpackBridgeController = require(Controllers.BackpackBridgeController),
    TargetingController = require(Controllers.TargetingController),
    EffectsController = require(Controllers.EffectsController),
    ChatController = require(Controllers.ChatController),
    HUDController = require(Controllers.HUDController),
    CharacterAnimationController = require(Controllers.CharacterAnimationController),
    CombatHandler = require(Controllers.CombatHandler),
    QuickCastController = require(Controllers.QuickCastController),
    InputController = require(Controllers.InputController),
}

local orderedControllers = {
    loadedControllers.BackpackBridgeController,
    loadedControllers.TargetingController,
    loadedControllers.EffectsController,
    loadedControllers.ChatController,
    loadedControllers.HUDController,
    loadedControllers.CharacterAnimationController,
    loadedControllers.CombatHandler,
    loadedControllers.QuickCastController,
    loadedControllers.InputController,
}

local dependencies = table.clone(loadedControllers)
dependencies.Runtime = MMONet.getClientRuntime()

for _, controller in ipairs(orderedControllers) do
    if controller.init then
        controller.init(dependencies)
    end
end

for _, controller in ipairs(orderedControllers) do
    if controller.start then
        controller.start()
    end
end
