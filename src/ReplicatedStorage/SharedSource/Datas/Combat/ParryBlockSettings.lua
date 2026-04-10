--!strict
-- ParryBlockSettings.lua
-- Central configuration for the Parry and Block system
-- All timing, damage, and behavior values are tunable here without code changes

return {
	Block = {
		DamageReduction = 0.5, -- 50% damage negated while blocking
		MovementSpeedMultiplier = 0.4, -- 40% WalkSpeed while blocking
		MaxBlockDuration = 5, -- Max seconds you can hold block before auto-release
		BlockCooldown = 0.3, -- Cooldown after releasing block before re-blocking
		PostAttackBlockDelay = 0.3, -- Seconds after attacking before blocking is allowed
		AllowBareHanded = true, -- Can block without a weapon equipped?
		BareHandedReduction = 0.25, -- 25% reduction when bare-handed
	},

	Posture = {
		MaxPosture = 100, -- Maximum posture value
		PostureDamageBase = 30, -- Posture lost per blocked hit (weapon)
		PostureDamageBareHanded = 40, -- Posture lost per blocked hit (bare-handed)
		RegenRate = 15, -- Posture regen per second (when NOT blocking)
		RegenDelay = 2, -- Seconds after last block hit before regen starts
		BlockBreakStunDuration = 2, -- Stun duration when posture breaks
		ResetOnStunEnd = true, -- Reset posture to max after block break stun ends
		ParryPostureRecover = 30, -- Posture recovered on successful parry
	},

	Parry = {
		ParryWindow = 0.2, -- 200ms timing window at start of block
		-- StunDuration moved to StatusEffectSettings.Stun.DefaultDuration
		DamageNegation = 1.0, -- 100% damage negated on parry
		MaxTimestampDrift = 0.5, -- Max seconds client BlockStartTime can differ from server time (anti-cheat)
	},

	-- Stun config moved to StatusEffectSettings.lua

	-- Maps AttackSubType (or DamageType fallback) to parry/block eligibility
	AttackTypeRules = {
		punch = { CanBeParried = true, CanBeBlocked = true },
		slash = { CanBeParried = true, CanBeBlocked = true },
		ranged = { CanBeParried = false, CanBeBlocked = false },
		ability = { CanBeParried = false, CanBeBlocked = true },
		area = { CanBeParried = false, CanBeBlocked = false },
		environment = { CanBeParried = false, CanBeBlocked = false },
	},

	-- Input configuration
	Input = {
		PCKey = Enum.KeyCode.F, -- Key to block on PC
		-- Mobile button is handled in BlockInputUI (Phase 6B)
	},

	-- Animation asset IDs (placeholder — replace with final assets)
	Animations = {
		BlockIdle = "rbxassetid://118498108638438", -- Sword block idle
		BlockIdleBareHanded = "rbxassetid://129915923876817", -- Punch/bare-handed block idle
		ParrySuccess = "rbxassetid://77610325663367",
		-- Stunned animation moved to StatusEffectSettings.Stun.Animation
	},

	-- Sound asset IDs (placeholder — replace with final assets)
	Sounds = {
		BlockStart = "rbxassetid://78782032774139",
		BlockHit = "rbxassetid://71357566422110",
		ParrySuccess = "rbxassetid://108491375740099",
		BlockBreak = "rbxassetid://121847830871796",
	},

	-- VFX asset paths in ReplicatedStorage (clone and parent to character)
	VFX = {
		ParryFlash = "ReplicatedStorage.Assets.Effects.Combat.Parry", -- Clone → HumanoidRootPart, emit particles
		BlockBreak = "ReplicatedStorage.Assets.Effects.Combat.Block Break", -- Clone → HumanoidRootPart, emit particles on posture break
		-- StunFX moved to StatusEffectSettings.Stun.VFX
	},
}
