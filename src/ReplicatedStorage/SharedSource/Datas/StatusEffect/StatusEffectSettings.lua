--[[
	StatusEffectSettings.lua
	Central configuration for all status effects.
	
	Each key is an effect name (e.g. "Stun", "Slow", "Freeze").
	The StatusEffectService reads this to determine behaviour, duration,
	movement modifiers, animations, VFX, and sounds for each effect.
	
	To add a new status effect:
	  1. Add a new table entry below with the required fields.
	  2. Place any VFX assets at the path specified in VFX.Asset.
	  3. No code changes required — the system picks it up automatically.
]]

return {
	-----------------------------------------------------------------
	-- STUN
	-- Applied to an attacker when their attack is parried.
	-- Prevents movement, attacking, and blocking for the duration.
	-----------------------------------------------------------------
	Stun = {
		DefaultDuration = 1.5, -- seconds
		BuffMode = "refresh", -- "refresh" | "extend" | "stack"

		-- Character restrictions while effect is active
		MovementSpeedMultiplier = 0, -- 0 = frozen, 0.5 = half speed, etc.
		CanAttack = false,
		CanBlock = false,

		-- Attribute value set on the character while the effect is active.
		-- Set to nil if the effect should not change CombatState.
		CombatState = "Stunned",

		-- Animation played on the affected character
		Animation = {
			AssetId = "rbxassetid://120440352374946",
			Looped = true,
			Priority = Enum.AnimationPriority.Action4,
		},

		-- VFX cloned onto the affected character
		VFX = {
			Asset = "ReplicatedStorage.Assets.Effects.Combat.StunFX",
			AttachTo = "Head", -- child name on the character to parent the VFX to
			RotateSpeed = 120, -- degrees per second (0 = no rotation)
			Offset = { 0, 2, 0 }, -- local offset from attach point
		},

		-- Sound played when the effect is applied (nil = none)
		Sound = nil,
	},

	-----------------------------------------------------------------
	-- BLOCK BREAK
	-- Applied when a blocker's posture is depleted.
	-- Prevents movement, attacking, and blocking for the duration.
	-- VFX is handled manually by BlockParryHandler (the "Block Break" part).
	-----------------------------------------------------------------
	BlockBreak = {
		DefaultDuration = 2, -- seconds (overridden by ParryBlockSettings.Posture.BlockBreakStunDuration)
		BuffMode = "refresh",

		MovementSpeedMultiplier = 0,
		CanAttack = false,
		CanBlock = false,

		CombatState = "Stunned",

		Animation = {
			AssetId = "rbxassetid://120440352374946", -- reuse stun animation
			Looped = true,
			Priority = Enum.AnimationPriority.Action4,
		},

		-- Block Break burst is handled manually by BlockParryHandler;
		-- stun stars reuse the same StunFX so the player sees the spinning VFX during the stun.
		VFX = {
			Asset = "ReplicatedStorage.Assets.Effects.Combat.StunFX",
			AttachTo = "Head",
			RotateSpeed = 120,
			Offset = { 0, 2, 0 },
		},
		Sound = nil,
	},

	-----------------------------------------------------------------
	-- FUTURE EFFECTS (examples — NOT implemented yet)
	-- Uncomment and fill in when ready.
	-----------------------------------------------------------------

	-- Slow = {
	-- 	DefaultDuration = 3,
	-- 	BuffMode = "refresh",
	-- 	MovementSpeedMultiplier = 0.3,
	-- 	CanAttack = true,
	-- 	CanBlock = true,
	-- 	CombatState = nil,
	-- 	Animation = nil,
	-- 	VFX = {
	-- 		Asset = "ReplicatedStorage.Assets.Effects.Combat.SlowFX",
	-- 		AttachTo = "HumanoidRootPart",
	-- 		RotateSpeed = 0,
	-- 		Offset = { 0, 0, 0 },
	-- 	},
	-- 	Sound = "rbxassetid://0000000000",
	-- },

	-- Freeze = {
	-- 	DefaultDuration = 2,
	-- 	BuffMode = "refresh",
	-- 	MovementSpeedMultiplier = 0,
	-- 	CanAttack = false,
	-- 	CanBlock = false,
	-- 	CombatState = "Frozen",
	-- 	Animation = {
	-- 		AssetId = "rbxassetid://0000000000",
	-- 		Looped = true,
	-- 	},
	-- 	VFX = {
	-- 		Asset = "ReplicatedStorage.Assets.Effects.Combat.FreezeFX",
	-- 		AttachTo = "HumanoidRootPart",
	-- 		RotateSpeed = 0,
	-- 		Offset = { 0, 0, 0 },
	-- 	},
	-- 	Sound = "rbxassetid://0000000000",
	-- },

	-- Burn = {
	-- 	DefaultDuration = 4,
	-- 	BuffMode = "refresh",
	-- 	MovementSpeedMultiplier = 0.8,
	-- 	CanAttack = true,
	-- 	CanBlock = true,
	-- 	CombatState = nil,
	-- 	Animation = nil,
	-- 	VFX = {
	-- 		Asset = "ReplicatedStorage.Assets.Effects.Combat.BurnFX",
	-- 		AttachTo = "HumanoidRootPart",
	-- 		RotateSpeed = 0,
	-- 		Offset = { 0, 0, 0 },
	-- 	},
	-- 	Sound = "rbxassetid://0000000000",
	-- },
}
