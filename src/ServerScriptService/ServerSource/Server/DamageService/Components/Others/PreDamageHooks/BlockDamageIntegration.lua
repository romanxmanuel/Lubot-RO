--[[
	BlockDamageIntegration.lua
	Bridges the Block/Parry system into the vanilla DamageHandler via a pre-damage hook.
	If CombatService or its BlockParryHandler is absent, this component is a no-op
	and the damage pipeline remains vanilla.
	Location: DamageService/Components/Others/BlockDamageIntegration.lua
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local CombatService
local StatusEffectService

---- DamageHandler reference (sibling component)
local DamageHandler

function module.Start()
	-- Only register the hook if BlockParryHandler actually exists
	local BlockParryHandler = CombatService and CombatService.Components
		and CombatService.Components.BlockParryHandler
	if not BlockParryHandler then
		return
	end

	DamageHandler.RegisterPreDamageHook(function(user, target, damageInfo, damageState)
		local defense = BlockParryHandler:EvaluateDefense(user, target, damageInfo)

		if defense.result == "parried" then
			-- Parry: negate all damage, stun attacker
			local attackerChar = damageInfo.Attacker or user
			StatusEffectService:ApplyEffect(attackerChar, "Stun")
			return false, "Attack was parried"
		elseif defense.result == "blocked" then
			-- Block: use reduced damage
			damageState.damage = defense.modifiedDamage
			damageState.blocked = true
		end

		return true
	end)
end

function module.Init()
	CombatService = Knit.GetService("CombatService")
	StatusEffectService = Knit.GetService("StatusEffectService")

	-- Grab sibling DamageHandler component
	local DamageService = Knit.GetService("DamageService")
	DamageHandler = DamageService.Components.DamageHandler
end

return module
