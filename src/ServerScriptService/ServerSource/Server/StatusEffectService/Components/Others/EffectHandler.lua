local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Superbullet = require(ReplicatedStorage.Packages.Superbullet)

local EffectHandler = {}

---- Utilities
local BuffTimerUtil = require(ReplicatedStorage:WaitForChild("SharedSource", 5).Utilities.Timing.BuffTimerUtil)
local StatusEffectSettings = require(ReplicatedStorage:WaitForChild("SharedSource", 5).Datas.StatusEffect.StatusEffectSettings)

---- Superbullet Services
local StatusEffectService

---- State
local buffTimer
local DEFAULT_WALK_SPEED = 16

-- NPC-only animation tracks: { [character] = { [effectName] = AnimationTrack } }
local _npcAnimations = {}

-- NPC-only VFX state: { [character] = { [effectName] = { vfx: Instance, conn: RBXScriptConnection? } } }
local _npcVfx = {}

-- Cached VFX templates resolved from StatusEffectSettings
local _vfxTemplates = {}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function getPlayerFromCharacter(character)
	return Players:GetPlayerFromCharacter(character)
end

--[[
	Stores the humanoid's current WalkSpeed in an attribute (if not already stored),
	then applies the multiplier. This preserves the original speed across re-applications.
]]
local function setWalkSpeed(humanoid, multiplier)
	local originalSpeed = humanoid:GetAttribute("_OriginalWalkSpeed")
	if not originalSpeed then
		originalSpeed = humanoid.WalkSpeed
		if originalSpeed == 0 then
			originalSpeed = DEFAULT_WALK_SPEED
		end
		humanoid:SetAttribute("_OriginalWalkSpeed", originalSpeed)
	end
	humanoid.WalkSpeed = originalSpeed * multiplier
end

--[[
	Restores the humanoid's WalkSpeed from the stored attribute and removes the attribute.
]]
local function restoreWalkSpeed(humanoid)
	local originalSpeed = humanoid:GetAttribute("_OriginalWalkSpeed")
	if originalSpeed then
		humanoid.WalkSpeed = originalSpeed
		humanoid:SetAttribute("_OriginalWalkSpeed", nil)
	end
end

--[[
	Plays an animation on an NPC's humanoid from the server (replicates to all clients).
	Only used for non-player characters.
]]
local function playNpcAnimation(humanoid, config)
	if not config.Animation then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = config.Animation.AssetId
	local track = animator:LoadAnimation(animation)
	track.Looped = config.Animation.Looped or false
	if config.Animation.Priority then
		track.Priority = config.Animation.Priority
	end
	track:Play()
	return track
end

--[[
	Stops and cleans up an NPC's animation track for the given effect.
]]
local function stopNpcAnimation(character, effectName)
	local charAnims = _npcAnimations[character]
	if not charAnims then
		return
	end
	local track = charAnims[effectName]
	if track and track.IsPlaying then
		track:Stop()
	end
	charAnims[effectName] = nil
	if not next(charAnims) then
		_npcAnimations[character] = nil
	end
end

--[[
	Resolves a dot-separated asset path to a Roblox Instance.
]]
local function resolveVfxAsset(pathStr)
	local parts = string.split(pathStr, ".")
	local current = game
	for _, part in ipairs(parts) do
		current = current:FindFirstChild(part)
		if not current then
			return nil
		end
	end
	return current
end

--[[
	Spawns VFX on an NPC from the server (replicates to all clients).
]]
local function spawnNpcVfx(character, effectName, config)
	if not config.VFX or not _vfxTemplates[effectName] then
		return
	end

	local template = _vfxTemplates[effectName]
	local clone = template:Clone()

	local attachPointName = config.VFX.AttachTo or "Head"
	local attachPoint = character:FindFirstChild(attachPointName)
	if not attachPoint or not attachPoint:IsA("BasePart") then
		clone.Parent = character
		return
	end

	local rotateSpeed = config.VFX.RotateSpeed or 0
	local entry = { vfx = clone, conn = nil }

	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = false
		clone.Parent = workspace

		if rotateSpeed > 0 then
			local rotAngle = 0
			entry.conn = RunService.Heartbeat:Connect(function(dt)
				if not clone or not clone.Parent or not attachPoint or not attachPoint.Parent then
					if entry.conn then
						entry.conn:Disconnect()
					end
					return
				end
				rotAngle = rotAngle + dt * rotateSpeed
				clone.CFrame = CFrame.new(attachPoint.Position) * CFrame.Angles(0, math.rad(rotAngle), 0)
			end)
		else
			clone.CFrame = attachPoint.CFrame
		end
	elseif clone:IsA("Model") then
		clone.Parent = workspace

		if rotateSpeed > 0 then
			local rotAngle = 0
			entry.conn = RunService.Heartbeat:Connect(function(dt)
				if not clone or not clone.Parent or not attachPoint or not attachPoint.Parent then
					if entry.conn then
						entry.conn:Disconnect()
					end
					return
				end
				rotAngle = rotAngle + dt * rotateSpeed
				clone:PivotTo(CFrame.new(attachPoint.Position) * CFrame.Angles(0, math.rad(rotAngle), 0))
			end)
		else
			clone:PivotTo(attachPoint.CFrame)
		end
	else
		clone.Parent = attachPoint
	end

	-- Enable all ParticleEmitters
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = true
		end
	end

	if not _npcVfx[character] then
		_npcVfx[character] = {}
	end
	_npcVfx[character][effectName] = entry
end

--[[
	Cleans up NPC VFX for the given effect.
]]
local function cleanupNpcVfx(character, effectName)
	local charVfx = _npcVfx[character]
	if not charVfx then
		return
	end
	local entry = charVfx[effectName]
	if not entry then
		return
	end
	if entry.conn then
		entry.conn:Disconnect()
	end
	if entry.vfx and entry.vfx.Parent then
		entry.vfx:Destroy()
	end
	charVfx[effectName] = nil
	if not next(charVfx) then
		_npcVfx[character] = nil
	end
end

--------------------------------------------------------------------------------
-- Core Methods
--------------------------------------------------------------------------------

--[[
	Applies a status effect to the given character.
	Uses BuffTimerUtil internally — onApply fires on first application,
	refresh/extend modes only reset the timer without re-firing onApply.
	@param character Model
	@param effectName string — key in StatusEffectSettings
	@param durationOverride number? — optional override for DefaultDuration
]]
function EffectHandler:ApplyEffect(character, effectName, durationOverride)
	if not character or not character:IsA("Model") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local config = StatusEffectSettings[effectName]
	if not config then
		warn("StatusEffectService: Unknown effect: " .. tostring(effectName))
		return
	end

	local duration = durationOverride or config.DefaultDuration

	buffTimer:apply(character, effectName, duration, {
		mode = config.BuffMode,

		onApply = function(entity)
			-- Set CombatState attribute
			if config.CombatState then
				character:SetAttribute("CombatState", config.CombatState)
			end

			-- Adjust movement speed
			if config.MovementSpeedMultiplier ~= nil then
				setWalkSpeed(humanoid, config.MovementSpeedMultiplier)
			end

			-- Fire client signal (players only) / play animation server-side (NPCs only)
			local player = getPlayerFromCharacter(character)
			if player then
				StatusEffectService.Client.EffectApplied:Fire(player, effectName, duration)
			else
				-- NPC: play animation and VFX from server so it replicates to all clients
				local track = playNpcAnimation(humanoid, config)
				if track then
					if not _npcAnimations[character] then
						_npcAnimations[character] = {}
					end
					_npcAnimations[character][effectName] = track
				end
				spawnNpcVfx(character, effectName, config)
			end

			-- Fire server signal (all characters)
			StatusEffectService.OnEffectApplied:Fire(character, effectName, duration)
		end,

		onExpire = function(entity)
			-- Restore CombatState (only if still in the effect's state)
			if config.CombatState and character:GetAttribute("CombatState") == config.CombatState then
				character:SetAttribute("CombatState", "Idle")
			end

			-- Restore movement speed
			if config.MovementSpeedMultiplier ~= nil then
				restoreWalkSpeed(humanoid)
			end

			-- Fire client signal (players only) / stop animation server-side (NPCs only)
			local player = getPlayerFromCharacter(character)
			if player then
				StatusEffectService.Client.EffectRemoved:Fire(player, effectName)
			else
				stopNpcAnimation(character, effectName)
				cleanupNpcVfx(character, effectName)
			end

			-- Fire server signal (all characters)
			StatusEffectService.OnEffectRemoved:Fire(character, effectName)
		end,
	})
end

--[[
	Manually removes a status effect from the given character.
	Performs cleanup (CombatState restore, WalkSpeed restore) and fires removal signals.
	Note: buffTimer:remove() does NOT trigger onExpire, so we clean up manually first.
	@param character Model
	@param effectName string
]]
function EffectHandler:RemoveEffect(character, effectName)
	if not buffTimer:has(character, effectName) then
		return
	end

	local config = StatusEffectSettings[effectName]
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	-- Manual cleanup (mirrors onExpire logic)
	if config then
		if config.CombatState and character:GetAttribute("CombatState") == config.CombatState then
			character:SetAttribute("CombatState", "Idle")
		end

		if config.MovementSpeedMultiplier ~= nil and humanoid then
			restoreWalkSpeed(humanoid)
		end
	end

	-- Fire removal signals (players) / stop animation (NPCs)
	local player = getPlayerFromCharacter(character)
	if player then
		StatusEffectService.Client.EffectRemoved:Fire(player, effectName)
	else
		stopNpcAnimation(character, effectName)
		cleanupNpcVfx(character, effectName)
	end
	StatusEffectService.OnEffectRemoved:Fire(character, effectName)

	-- Clear the buff timer entry (does NOT trigger onExpire callback)
	buffTimer:remove(character, effectName)
end

--[[
	Returns whether the character currently has the given effect active.
	@param character Model
	@param effectName string
	@return boolean
]]
function EffectHandler:HasEffect(character, effectName)
	return buffTimer:has(character, effectName)
end

--[[
	Returns a table of all currently active effect names on the character.
	@param character Model
	@return {[string]: true}
]]
function EffectHandler:GetActiveEffects(character)
	local active = {}
	for effectName, _ in pairs(StatusEffectSettings) do
		if buffTimer:has(character, effectName) then
			active[effectName] = true
		end
	end
	return active
end

--------------------------------------------------------------------------------
-- Cleanup Helper
--------------------------------------------------------------------------------

local function removeAllEffects(character)
	for effectName, _ in pairs(StatusEffectSettings) do
		EffectHandler:RemoveEffect(character, effectName)
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function EffectHandler.Start()
	-- Preload VFX templates from StatusEffectSettings
	for effectName, config in pairs(StatusEffectSettings) do
		if config.VFX and config.VFX.Asset then
			local template = resolveVfxAsset(config.VFX.Asset)
			if template then
				_vfxTemplates[effectName] = template
			else
				warn("[StatusEffectService] VFX asset not found for " .. effectName .. ": " .. config.VFX.Asset)
			end
		end
	end

	-- Connect cleanup for newly joining players
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				removeAllEffects(character)
			end)
		end)
	end)

	-- Handle players who joined before this system started
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Connect(function()
					removeAllEffects(player.Character)
				end)
			end
		end

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				removeAllEffects(character)
			end)
		end)
	end

	-- Cleanup when player leaves the game
	Players.PlayerRemoving:Connect(function(player)
		if player.Character then
			removeAllEffects(player.Character)
		end
	end)
end

function EffectHandler.Init()
	StatusEffectService = Superbullet.GetService("StatusEffectService")
	buffTimer = BuffTimerUtil.new(0.05)
end

return EffectHandler
