--[[
	EffectVisualHandler.lua
	Core component for StatusEffectController.
	Handles all visual feedback (animations, VFX, movement, sounds) for status
	effects applied by the server's StatusEffectService.
	Listens to StatusEffectService client signals and manages per-effect visual state.

	Location: StatusEffectController/Components/Others/EffectVisualHandler.lua
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SuperbulletModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Superbullet")
local Superbullet = require(SuperbulletModule)

---- Utilities (safe at top-level)
local StatusEffectSettings = require(
	ReplicatedStorage:WaitForChild("SharedSource", 5).Datas.StatusEffect.StatusEffectSettings
)

local EffectVisualHandler = {}

---- Superbullet Services
local StatusEffectService

---- Superbullet Controllers
local StatusEffectController

---- State
local player = Players.LocalPlayer
local DEFAULT_WALK_SPEED = 16

-- Per-effect active state:
-- { [effectName] = { track: AnimationTrack?, vfx: Instance?, vfxConn: RBXScriptConnection?, sound: Sound? } }
local _activeEffects = {}

-- Cached VFX templates loaded from StatusEffectSettings in .Start()
local _vfxTemplates = {}

-- ============================================================
-- Helper Functions
-- ============================================================

--[[
	Resolves a dot-separated asset path (e.g. "ReplicatedStorage.Assets.Effects.Combat.StunFX")
	to the actual Roblox Instance. Returns nil if any part of the path is not found.
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
	Returns the local player's character and humanoid, or nil if dead/not loaded.
]]
local function getCharacterAndHumanoid()
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return character, humanoid
end

--[[
	Sets the humanoid's WalkSpeed to the original value multiplied by the given multiplier.
	Stores the original WalkSpeed in an attribute so it can be restored later.
]]
local function setWalkSpeed(humanoid, multiplier)
	if not humanoid:GetAttribute("_OriginalWalkSpeed") then
		humanoid:SetAttribute("_OriginalWalkSpeed", humanoid.WalkSpeed)
	end
	local original = humanoid:GetAttribute("_OriginalWalkSpeed")
	humanoid.WalkSpeed = original * multiplier
end

--[[
	Restores the humanoid's WalkSpeed from the stored original value attribute.
]]
local function restoreWalkSpeed(humanoid)
	local original = humanoid:GetAttribute("_OriginalWalkSpeed")
	if original then
		humanoid.WalkSpeed = original
		humanoid:SetAttribute("_OriginalWalkSpeed", nil)
	end
end

--[[
	Creates an Animation, loads it on the humanoid's Animator, plays it, and returns the track.
	Uses Animator if available (modern pattern), otherwise falls back to humanoid:LoadAnimation().
]]
local function playAnimation(humanoid, assetId, looped, priority)
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = assetId
	local track = animator:LoadAnimation(animation)
	track.Looped = looped or false
	if priority then
		track.Priority = priority
	end
	track:Play()
	return track
end

--[[
	Safely stops an AnimationTrack if it exists and is playing.
]]
local function stopAnimation(track)
	if track and track.IsPlaying then
		track:Stop()
	end
end

-- ============================================================
-- Core Methods
-- ============================================================

--[[
	Applies all visual feedback for the given status effect on the local player's character.
	Reads configuration from StatusEffectSettings.
	@param effectName string — key in StatusEffectSettings (e.g. "Stun")
	@param duration number — effect duration in seconds (from server)
]]
function EffectVisualHandler:ApplyVisuals(effectName, duration)
	local character, humanoid = getCharacterAndHumanoid()
	if not character or not humanoid then
		return
	end

	local config = StatusEffectSettings[effectName]
	if not config then
		warn("[StatusEffectController] Unknown effect: " .. tostring(effectName))
		return
	end

	-- If effect is already active, clean it up first before re-applying
	if _activeEffects[effectName] then
		self:RemoveVisuals(effectName)
	end

	-- Create active effect entry
	local entry = {}
	_activeEffects[effectName] = entry

	-- CombatState attribute
	if config.CombatState then
		character:SetAttribute("CombatState", config.CombatState)
	end

	-- Animation
	if config.Animation then
		local track = playAnimation(humanoid, config.Animation.AssetId, config.Animation.Looped, config.Animation.Priority)
		entry.track = track
	end

	-- Movement
	if config.MovementSpeedMultiplier ~= nil then
		setWalkSpeed(humanoid, config.MovementSpeedMultiplier)
	end

	-- VFX
	if config.VFX and _vfxTemplates[effectName] then
		local template = _vfxTemplates[effectName]
		local clone = template:Clone()

		local attachPointName = config.VFX.AttachTo or "Head"
		local attachPoint = character:FindFirstChild(attachPointName)
		if attachPoint and attachPoint:IsA("BasePart") then
			if clone:IsA("BasePart") then
				-- BasePart VFX: parent to workspace, position at attach point, rotate
				clone.Anchored = true
				clone.CanCollide = false
				clone.Parent = workspace

				local rotateSpeed = config.VFX.RotateSpeed or 0
				if rotateSpeed > 0 then
					local rotAngle = 0
					local conn
					conn = RunService.RenderStepped:Connect(function(dt)
						if not clone or not clone.Parent or not attachPoint or not attachPoint.Parent then
							if conn then
								conn:Disconnect()
							end
							return
						end
						rotAngle = rotAngle + dt * rotateSpeed
						clone.CFrame = CFrame.new(attachPoint.Position) * CFrame.Angles(0, math.rad(rotAngle), 0)
					end)
					entry.vfxConn = conn
				else
					clone.CFrame = attachPoint.CFrame
				end
			elseif clone:IsA("Model") then
				-- Model VFX: parent to workspace, PivotTo at attach point, rotate
				clone.Parent = workspace

				local rotateSpeed = config.VFX.RotateSpeed or 0
				if rotateSpeed > 0 then
					local rotAngle = 0
					local conn
					conn = RunService.RenderStepped:Connect(function(dt)
						if not clone or not clone.Parent or not attachPoint or not attachPoint.Parent then
							if conn then
								conn:Disconnect()
							end
							return
						end
						rotAngle = rotAngle + dt * rotateSpeed
						clone:PivotTo(CFrame.new(attachPoint.Position) * CFrame.Angles(0, math.rad(rotAngle), 0))
					end)
					entry.vfxConn = conn
				else
					clone:PivotTo(attachPoint.CFrame)
				end
			else
				-- Fallback: parent to the attach point directly
				clone.Parent = attachPoint
			end

			-- Enable all ParticleEmitters inside the VFX clone
			for _, desc in ipairs(clone:GetDescendants()) do
				if desc:IsA("ParticleEmitter") then
					desc.Enabled = true
				end
			end
		else
			-- Attach point not found or not a BasePart, parent directly to character
			clone.Parent = character
		end

		entry.vfx = clone
	end

	-- Sound
	if config.Sound then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local sound = Instance.new("Sound")
			sound.SoundId = config.Sound
			sound.Parent = hrp
			sound:Play()
			entry.sound = sound

			-- Auto-cleanup when sound finishes (for non-looping sounds)
			sound.Ended:Once(function()
				if entry.sound == sound then
					sound:Destroy()
					entry.sound = nil
				end
			end)
		end
	end
end

--[[
	Removes all visual feedback for the given status effect from the local player's character.
	Cleans up animations, VFX, movement, sounds, and CombatState attribute.
	@param effectName string — key in StatusEffectSettings
]]
function EffectVisualHandler:RemoveVisuals(effectName)
	local entry = _activeEffects[effectName]
	if not entry then
		return
	end

	local character, humanoid = getCharacterAndHumanoid()
	local config = StatusEffectSettings[effectName]

	-- Animation
	if entry.track then
		stopAnimation(entry.track)
		entry.track = nil
	end

	-- Movement
	if config and config.MovementSpeedMultiplier ~= nil and humanoid then
		restoreWalkSpeed(humanoid)
	end

	-- VFX rotation connection
	if entry.vfxConn then
		entry.vfxConn:Disconnect()
		entry.vfxConn = nil
	end

	-- VFX instance
	if entry.vfx then
		if entry.vfx.Parent then
			entry.vfx:Destroy()
		end
		entry.vfx = nil
	end

	-- Sound
	if entry.sound then
		entry.sound:Stop()
		entry.sound:Destroy()
		entry.sound = nil
	end

	-- CombatState attribute
	if config and config.CombatState and character then
		local currentState = character:GetAttribute("CombatState")
		if currentState == config.CombatState then
			character:SetAttribute("CombatState", "Idle")
		end
	end

	-- Clear entry
	_activeEffects[effectName] = nil
end

--[[
	Returns whether the local player currently has the given effect active.
	@param effectName string
	@return boolean
]]
function EffectVisualHandler:HasEffect(effectName)
	return _activeEffects[effectName] ~= nil
end

--[[
	Returns a list of all currently active effect names on the local player.
	@return {string}
]]
function EffectVisualHandler:GetActiveEffects()
	local effects = {}
	for effectName, _ in pairs(_activeEffects) do
		table.insert(effects, effectName)
	end
	return effects
end

--[[
	Clears all active effects, cleaning up animations, VFX, movement, and sounds.
	Used on respawn to ensure a clean slate.
]]
function EffectVisualHandler:ClearAllEffects()
	-- Collect keys first to avoid modifying table during iteration
	local effectNames = {}
	for effectName, _ in pairs(_activeEffects) do
		table.insert(effectNames, effectName)
	end
	for _, effectName in ipairs(effectNames) do
		self:RemoveVisuals(effectName)
	end
end

-- ============================================================
-- Lifecycle
-- ============================================================

function EffectVisualHandler.Start()
	-- Preload VFX templates from StatusEffectSettings
	for effectName, config in pairs(StatusEffectSettings) do
		if config.VFX and config.VFX.Asset then
			local template = resolveVfxAsset(config.VFX.Asset)
			if template then
				_vfxTemplates[effectName] = template
			else
				warn(
					"[StatusEffectController] VFX asset not found for "
						.. effectName
						.. ": "
						.. config.VFX.Asset
				)
			end
		end
	end

	-- Listen for server-applied effects
	StatusEffectService.EffectApplied:Connect(function(effectName, duration)
		EffectVisualHandler:ApplyVisuals(effectName, duration)
	end)

	StatusEffectService.EffectRemoved:Connect(function(effectName)
		EffectVisualHandler:RemoveVisuals(effectName)
	end)

	-- Respawn cleanup: clear all active effects on new character
	player.CharacterAdded:Connect(function()
		EffectVisualHandler:ClearAllEffects()
	end)
end

function EffectVisualHandler.Init()
	StatusEffectService = Superbullet.GetService("StatusEffectService")
	StatusEffectController = Superbullet.GetController("StatusEffectController")
end

return EffectVisualHandler
