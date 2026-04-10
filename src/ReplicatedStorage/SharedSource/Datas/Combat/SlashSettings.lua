--[[
	SlashSettings.lua
	Configuration for the slash combat system
	Location: ReplicatedStorage/SharedSource/Datas/Combat/SlashSettings.lua
]]

local SlashSettings = {
	-- Registered weapon names that can perform slash attacks
	-- Add tool names here to enable slash functionality
	RegisteredWeapons = {
		"Sword",
		"Katana",
		"Blade",
		"Dagger",
		-- Add more weapon names as needed
	},
	-- Basic slash parameters
	Damage = 15,
	DamagePerHit = 15,
	Range = 10,
	Cooldown = 0.8,
	SwingDuration = 0.3,

	-- Server validation
	ServerMaxHitRange = 15,
	ServerAttackCooldown = 0.5,

	-- ClientCast parameters
	AttachmentName = "DmgPoint", -- Must match ClientCast settings
	DebugMode = false,

	-- Hitbox configuration (DEPRECATED - now uses weapon's Blade mesh with DmgPoint attachments)
	-- ClientHitboxSize = Vector3.new(6, 6, 3), -- No longer used - weapon Blade is the hitbox

	-- Visual parameters
	TrailColor = Color3.fromRGB(255, 100, 100),
	TrailLength = 0.5,

	-- Animation IDs (5 slash animations from the rbxl)
	SlashAnimations = {
		"rbxassetid://140510417943005", -- Replace with animations from rbxl
		"rbxassetid://95897032968575",
		"rbxassetid://109687665399881",
		"rbxassetid://72131621841350",
		"rbxassetid://99168332374440",
	},

	-- Sound IDs
	-- Swing sound plays EVERY slash (even if no hit)
	SlashSwingSounds = {
		"rbxassetid://78724764285169", -- Replace with your swing sound
	},

	-- Delay before playing swing sound (in seconds)
	SwingSoundDelay = 0.25,

	-- VFX timing
	SlashVfxDelay = 0.2, -- Delay before playing slash VFX (in seconds)

	-- Hit sounds play ONLY when hitting something (random between 2)
	HitSounds = {
		"rbxassetid://220833967", -- Slash-1
		"rbxassetid://220833976", -- Slash-2
	},

	-- Movement debuff settings (client-side only)
	MovementDebuff = {
		Enabled = true,
		MovementReduction = 0.5, -- 20% slower (80% of normal speed)
		Duration = 0.6, -- Duration of debuff
		MinWalkSpeed = 4, -- Minimum walkspeed clamp
		BuffName = "SlashAttackSlow",
		StatName = "BaseMoveSpeed", -- Optional stat reference
	},

	-- Cooldown buffer for client
	ClientCooldownBuffer = 0.05,

	-- Extra cooldown after completing the full combo (5th slash)
	ComboFinisherCooldown = 0.5,
}

return SlashSettings