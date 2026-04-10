local PunchSettings = {
	AttackAnimations = {
		"rbxassetid://134557878504562", -- Right Attack Animation
		"rbxassetid://95924136659368", -- Left Attack Animation
	},
	-- Attack sounds play when swinging (air sounds before hitting)
	AttackSounds = {
		"rbxassetid://5835032207", -- Punch swing sound 1 (whoosh/air sound)
		"rbxassetid://101467914599270", -- Punch swing sound 2 (whoosh/air sound)
	},

	-- Delay before playing punch swing sound (in seconds)
	PunchSoundDelay = 0,
	-- Hit sounds play when punch connects with target
	HitSounds = {
		"rbxassetid://8595980577", -- Punch impact sound (when hitting target)
		"rbxassetid://8278630896", -- Punch impact sound (when hitting target)
		"rbxassetid://9117969717", -- Punch impact sound (when hitting target)
	},
	SwingDuration = 0.7,
	HitboxStartDelay = 0.4, -- Delay before hitbox activates (matches animation wind-up)
	ClientHitboxSize = Vector3.new(5, 5, 5),
	ClientCooldownBuffer = 0.1,
	ServerAttackCooldown = 0.5,
	ServerMaxHitRange = 15,
	DamagePerHit = 10,
}

return PunchSettings
