--[[
	CombatConfig.lua
	
	Contains all combat-related configuration including knockback settings.
	Adjust these values to balance combat gameplay.
]]

local CombatConfig = {
	-- Knockback Settings
	Knockback = {
		-- Duration of knockback force (seconds)
		Duration = 0.1,

		-- Whether NPC attacks knock back players (false = NPCs don't push players around)
		NPCKnockbackPlayers = false,

		-- Base knockback force strength
		-- Higher values = stronger pushback
		BasePower = 50,
		
		-- Maximum knockback force cap
		MaxPower = 150,
		
		-- Network ownership settings for NPCs
		NPC = {
			-- How long the attacker maintains network ownership of NPC (seconds)
			-- This reduces server physics stress during knockback
			OwnershipDuration = 1.0,
		},
		
		-- LinearVelocity settings
		LinearVelocity = {
			-- Maximum force the LinearVelocity can apply
			MaxForce = 200000,
			
			-- How the velocity is applied relative to world/attachment
			RelativeTo = Enum.ActuatorRelativeTo.World,
			
			-- Priority for physics solver
			VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
		},
	},
}

return CombatConfig
