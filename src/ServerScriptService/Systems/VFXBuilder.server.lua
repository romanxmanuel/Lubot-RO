--[[
	VFXBuilder.server.lua
	Builds VFX template instances in ReplicatedStorage/Assets/Effects at server startup.
	SlashHandler (client) clones these templates at runtime — they must exist before clients join.

	Add new VFX templates here rather than placing raw instances in Studio.
	Location: ServerScriptService/Systems/VFXBuilder.server.lua
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ─── Folder helpers ───────────────────────────────────────────────────────

local function getOrCreate(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	local inst = Instance.new(className or "Folder")
	inst.Name = name
	inst.Parent = parent
	return inst
end

-- ─── ParticleEmitter factory ──────────────────────────────────────────────

local function makeParticle(parent, name, cfg)
	-- Remove any existing one with the same name so this is idempotent
	local old = parent:FindFirstChild(name)
	if old and old:IsA("ParticleEmitter") then old:Destroy() end

	local p = Instance.new("ParticleEmitter")
	p.Name             = name
	p.Enabled          = false   -- templates use manual :Emit(), not auto emission
	p.Rate             = 0

	p.Texture          = cfg.texture
	p.Color            = cfg.color or ColorSequence.new(Color3.fromRGB(255, 255, 255))
	p.LightEmission    = cfg.lightEmission    or 0.8
	p.LightInfluence   = cfg.lightInfluence   or 0
	p.Lifetime         = cfg.lifetime         or NumberRange.new(0.15, 0.3)
	p.Speed            = cfg.speed            or NumberRange.new(6, 12)
	p.SpreadAngle      = cfg.spread           or Vector2.new(10, 10)
	p.Rotation         = NumberRange.new(0, 0)   -- SlashHandler overwrites per combo
	p.RotSpeed         = cfg.rotSpeed         or NumberRange.new(-60, 60)
	p.Size             = cfg.size             or NumberSequence.new({
		NumberSequenceKeypoint.new(0,   3.5, 0),
		NumberSequenceKeypoint.new(0.4, 2.5, 0),
		NumberSequenceKeypoint.new(1,   0,   0),
	})
	p.Transparency     = cfg.alpha            or NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0,   0),
		NumberSequenceKeypoint.new(0.5, 0.3, 0),
		NumberSequenceKeypoint.new(1,   1,   0),
	})
	p.EmissionDirection = Enum.NormalId.Top   -- SlashHandler overwrites per combo
	p.Parent = parent

	-- EmitCount: how many particles to emit on each manual :Emit() call
	p:SetAttribute("EmitCount", cfg.emitCount or 12)
	-- EmitDelay: stagger multiple emitters (optional)
	if cfg.emitDelay then
		p:SetAttribute("EmitDelay", cfg.emitDelay)
	end

	return p
end

-- ─── Part factory (transparent, no collision) ─────────────────────────────

local function makePart(parent, name, size)
	local old = parent:FindFirstChild(name)
	if old and old:IsA("BasePart") then old:Destroy() end

	local p = Instance.new("Part")
	p.Name         = name
	p.Anchored     = true
	p.CanCollide   = false
	p.Transparency = 1
	p.CastShadow   = false
	p.Size         = size or Vector3.new(1, 1, 1)
	p.Parent       = parent
	return p
end

-- ─── Build folder structure ───────────────────────────────────────────────

local assets  = getOrCreate(ReplicatedStorage, "Assets", "Folder")
local effects = getOrCreate(assets,  "Effects", "Folder")
local slashes = getOrCreate(effects, "Slashes", "Folder")
local punches = getOrCreate(effects, "Punches", "Folder")

-- ─── SlashVfx ─────────────────────────────────────────────────────────────
-- SlashHandler looks for ReplicatedStorage.Assets.Effects.Slashes.SlashVfx
-- It clones it, positions it, finds the "Slash" child, and calls :Emit() on
-- all ParticleEmitters inside.

local slashVfx = getOrCreate(slashes, "SlashVfx", "Model")

-- Primary transparent root part (Model needs a PrimaryPart to be positioned)
local rootPart = makePart(slashVfx, "Root", Vector3.new(1, 1, 1))
pcall(function() slashVfx.PrimaryPart = rootPart end)

-- "Slash" child — SlashHandler looks for this by name
local slashContainer = makePart(slashVfx, "Slash", Vector3.new(6, 0.1, 6))

-- Layer 1: main arc — large, fast, bright white-blue
makeParticle(slashContainer, "ArcMain", {
	texture       = "rbxassetid://6514291",
	color         = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(200, 230, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(180, 210, 255)),
	}),
	lightEmission  = 1,
	lifetime       = NumberRange.new(0.12, 0.22),
	speed          = NumberRange.new(10, 18),
	spread         = Vector2.new(5, 5),
	rotSpeed       = NumberRange.new(-180, 180),
	size           = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   4, 0),
		NumberSequenceKeypoint.new(0.3, 3, 0),
		NumberSequenceKeypoint.new(1,   0, 0),
	}),
	alpha          = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0,   0),
		NumberSequenceKeypoint.new(0.2, 0.1, 0),
		NumberSequenceKeypoint.new(1,   1,   0),
	}),
	emitCount = 16,
})

-- Layer 2: soft glow bloom — stays slightly longer
makeParticle(slashContainer, "ArcGlow", {
	texture       = "rbxassetid://1319426",
	color         = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	}),
	lightEmission  = 1,
	lifetime       = NumberRange.new(0.2, 0.35),
	speed          = NumberRange.new(4, 8),
	spread         = Vector2.new(20, 20),
	rotSpeed       = NumberRange.new(-90, 90),
	size           = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   5,   0),
		NumberSequenceKeypoint.new(0.5, 3.5, 0),
		NumberSequenceKeypoint.new(1,   0,   0),
	}),
	alpha          = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.2, 0),
		NumberSequenceKeypoint.new(0.6, 0.5, 0),
		NumberSequenceKeypoint.new(1,   1,   0),
	}),
	emitCount = 8,
	emitDelay = 0.02,
})

-- Layer 3: sparks — small, fast scatter for energy feel
makeParticle(slashContainer, "Sparks", {
	texture       = "rbxassetid://6760634",
	color         = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
	lightEmission  = 0.9,
	lightInfluence = 0.1,
	lifetime       = NumberRange.new(0.1, 0.25),
	speed          = NumberRange.new(15, 30),
	spread         = Vector2.new(30, 30),
	rotSpeed       = NumberRange.new(-200, 200),
	size           = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   1.2, 0),
		NumberSequenceKeypoint.new(0.5, 0.6, 0),
		NumberSequenceKeypoint.new(1,   0,   0),
	}),
	alpha          = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0,   0),
		NumberSequenceKeypoint.new(0.3, 0.1, 0),
		NumberSequenceKeypoint.new(1,   1,   0),
	}),
	emitCount = 20,
})

-- ─── PunchEffect ──────────────────────────────────────────────────────────
-- SlashHandler looks for ReplicatedStorage.Assets.Effects.Punches.PunchEffect
-- Used for hit impact burst on the target

local punchEffect = makePart(punches, "PunchEffect", Vector3.new(1, 1, 1))

-- Burst: quick orange-white explosion on impact
makeParticle(punchEffect, "HitBurst", {
	texture       = "rbxassetid://6514291",
	color         = ColorSequence.new(Color3.fromRGB(255, 200, 100)),
	lightEmission  = 1,
	lifetime       = NumberRange.new(0.1, 0.2),
	speed          = NumberRange.new(8, 20),
	spread         = Vector2.new(90, 90),
	rotSpeed       = NumberRange.new(-360, 360),
	size           = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   2.5, 0),
		NumberSequenceKeypoint.new(0.5, 1.5, 0),
		NumberSequenceKeypoint.new(1,   0,   0),
	}),
	emitCount = 18,
})

-- Sparks: small fast scatter on hit
makeParticle(punchEffect, "HitSparks", {
	texture       = "rbxassetid://6760634",
	color         = ColorSequence.new(Color3.fromRGB(255, 240, 180)),
	lightEmission  = 0.8,
	lifetime       = NumberRange.new(0.15, 0.3),
	speed          = NumberRange.new(15, 35),
	spread         = Vector2.new(90, 90),
	size           = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.8, 0),
		NumberSequenceKeypoint.new(1,   0,   0),
	}),
	emitCount = 25,
})

print("[VFXBuilder] SlashVfx and PunchEffect ready in ReplicatedStorage.Assets.Effects")
