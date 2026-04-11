--[[
	SlashHandler.lua
	CLIENT-SIDE component for slash input and visuals (CONSOLIDATED)
	Server handles ClientCast hit detection
	Location: ReplicatedStorage/ClientSource/Client/CombatController/Components/Others/SlashHandler.lua
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SlashHandler = {}

-- Datas
local sharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 5).Datas
local SlashSettings = require(sharedDatas.Combat.SlashSettings)

-- ParryBlockSettings is optional (block system may not be installed)
local ParryBlockSettings = nil
local parryBlockModule = sharedDatas.Combat:FindFirstChild("ParryBlockSettings")
if parryBlockModule then
	ParryBlockSettings = require(parryBlockModule)
end

-- Utilities
local utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
local BuffTimerUtil = require(utilities:WaitForChild("Timing"):WaitForChild("BuffTimerUtil"))
local ParticleEmitters = require(utilities:WaitForChild("Effects"):WaitForChild("ParticleEmitters", 10))
local AssetPreloader = require(utilities:WaitForChild("Core"):WaitForChild("AssetPreloader"))

-- Knit Services
local CombatService

-- Assets
local assets = ReplicatedStorage:WaitForChild("Assets", 10)
local PunchEffect = nil
local BlockHitEffect = nil
local SlashVfx = nil
local SlashBeam = nil  -- Beam-based arc VFX (positioned between two spread parts)

-- Slash VFX rotation configuration per combo index
-- Each entry contains:
--   hrp: CFrame rotation relative to HumanoidRootPart
--   particleRot: Degrees for ParticleEmitter.Rotation (only applied if current rotation is 0..0)
--   emissionDirection: Enum.NormalId for particle emission direction
--   forceForward: (optional) If true, ignores hrp rotation and spawns directly in front of player
local SLASH_ROTATIONS = {
	-- Combo 1: Up-right → Left (Diagonal)
	{
		hrp = CFrame.Angles(0, math.rad(0), math.rad(45)),
		particleRot = -90,
		emissionDirection = Enum.NormalId.Bottom,
		forceForward = false -- Set to true to spawn in front regardless of animation
	},

	-- Combo 2: Left → Right (Horizontal)
	{
		hrp = CFrame.Angles(0, math.rad(90), 0),
		particleRot = -90,
		emissionDirection = Enum.NormalId.Top,
		forceForward = true
	},

	-- Combo 3: Left → Right (Horizontal)
	{
		hrp = CFrame.Angles(0, math.rad(90), 0),
		particleRot = -90,
		emissionDirection = Enum.NormalId.Top,
		forceForward = true
	},

	-- Combo 4: Down → Up (Vertical)
	{
		hrp = CFrame.Angles(math.rad(90), 0, math.rad(90)),
		particleRot = 75,
		emissionDirection = Enum.NormalId.Top,
		forceForward = false
	},

	-- Combo 5: Left → Right (Horizontal)
	{
		hrp = CFrame.Angles(0, math.rad(90), 0),
		particleRot = -90,
		emissionDirection = Enum.NormalId.Top,
		forceForward = true
	},
}

-- Preloaded sound templates (soundId → Sound instance in Assets.Effects.Combat)
local soundTemplates = {}

-- State
SlashHandler._comboIndex = 1
SlashHandler._cooling = false
SlashHandler._buffManager = nil
SlashHandler._equippedTool = nil

-- Helper: Get local humanoid and HumanoidRootPart
local function getLocalHumanoid()
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then
		return nil, nil
	end
	return character:FindFirstChildOfClass("Humanoid"), character:FindFirstChild("HumanoidRootPart")
end

-- Helper: Play animation on humanoid
local function playAnimation(humanoid, animId)
	local animation = Instance.new("Animation")
	animation.AnimationId = animId
	local track = humanoid:LoadAnimation(animation)
	track:Play(0)
	return track
end

-- Helper: Play sound with optional delay (clones preloaded template if available)
local function playSound(soundId, parent, delay)
	local function doPlay()
		local template = soundTemplates[soundId]
		local sound
		if template then
			sound = template:Clone()
		else
			sound = Instance.new("Sound")
			sound.SoundId = soundId
		end
		sound.Parent = parent or workspace
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
		return sound
	end

	if delay and delay > 0 then
		task.delay(delay, doPlay)
		return nil
	end
	return doPlay()
end

-- Helper: Play hit sound on target
local function playHitSound(target)
	local hitSounds = SlashSettings.HitSounds or {}
	if #hitSounds == 0 then
		return
	end

	local _, hrp = getLocalHumanoid()
	local targetHRP = target and target:FindFirstChild("HumanoidRootPart")
	if not hrp or not targetHRP then
		return
	end

	local distance = (targetHRP.Position - hrp.Position).Magnitude
	if distance > 50 then
		return
	end

	local soundId = hitSounds[math.random(1, #hitSounds)]
	playSound(soundId, target)
end

-- Play slash hit effect at target's position
local function playSlashHitEffect(targetCharacter, wasBlocked)
	local effectTemplate = wasBlocked and BlockHitEffect or PunchEffect
	if not effectTemplate then
		return
	end

	local hrp = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	task.delay(0.25, function()
		local effectClone = effectTemplate:Clone()

		if wasBlocked then
			-- Block Hit is a Part: position 2 studs in front and weld to HRP
			effectClone.Anchored = false
			effectClone.CanCollide = false
			effectClone.CFrame = hrp.CFrame * CFrame.new(0, 0, -2)

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = effectClone
			weld.Parent = effectClone

			effectClone.Parent = workspace

			for _, desc in ipairs(effectClone:GetDescendants()) do
				if desc:IsA("ParticleEmitter") then
					local emitCount = desc:GetAttribute("EmitCount") or 15
					desc:Emit(emitCount)
				end
			end
		else
			effectClone.CFrame = hrp.CFrame
			effectClone.Parent = workspace
			ParticleEmitters.PlayEmit(effectClone)
		end

		task.delay(2, function()
			if effectClone and effectClone.Parent then
				effectClone:Destroy()
			end
		end)
	end)
end

-- Particle helper: Set world CFrame for Part or Model
local function setWorldCFrame(instance, cf)
	if instance:IsA("BasePart") then
		instance.CFrame = cf
	elseif instance:IsA("Model") then
		instance:PivotTo(cf)
	else
		warn("SlashVfx must be a BasePart or Model, got:", instance.ClassName)
	end
end

-- Particle helper: Set ParticleEmitter.Rotation only if currently 0..0
local function setParticleRotationIfZero(root, rotationDeg)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			local r = obj.Rotation
			if r.Min == 0 and r.Max == 0 then
				obj.Rotation = NumberRange.new(rotationDeg)
			end
		end
	end
end

-- Particle helper: Set emission direction for all emitters
local function setEmissionDirection(root, direction)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.EmissionDirection = direction
		end
	end
end

-- Particle helper: Emit particles with optional delay
local function emitParticles(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			local emitCount = obj:GetAttribute("EmitCount") or 10
			local emitDelay = obj:GetAttribute("EmitDelay") or 0
			task.delay(emitDelay, function()
				if obj.Parent then
					obj:Emit(emitCount)
				end
			end)
		end
	end
end

-- Play slash VFX with advanced rotation system
local function playSlashVfx(hrp, comboIndex)
	if not SlashVfx or not hrp then
		return
	end

	-- Get rotation config for this combo
	local rotationConfig = SLASH_ROTATIONS[comboIndex] or {
		hrp = CFrame.Angles(0, 0, 0),
		particleRot = 0,
		emissionDirection = Enum.NormalId.Top,
		forceForward = false
	}

	-- Clone the VFX so we don't mutate the template
	local vfxClone = SlashVfx:Clone()
	vfxClone.Parent = workspace

	-- Calculate world CFrame based on forceForward setting
	local worldCF
	if rotationConfig.forceForward then
		-- Use only the Y rotation (looking direction) and ignore animation tilt
		local lookVector = hrp.CFrame.LookVector
		local rightVector = hrp.CFrame.RightVector

		-- Create a flat CFrame facing forward (no tilt from animation)
		local flatCFrame = CFrame.lookAt(
			hrp.Position,
			hrp.Position + Vector3.new(lookVector.X, 0, lookVector.Z)
		)

		-- Rotate 90 degrees to the right (left hand to right hand slash orientation)
		local rotatedCFrame = flatCFrame * CFrame.Angles(0, math.rad(90), 0)

		-- Apply only the slash-specific rotation (e.g., horizontal or vertical swing)
		worldCF = rotatedCFrame * rotationConfig.hrp
	else
		-- Use the full HRP rotation including animation tilt
		worldCF = hrp.CFrame * rotationConfig.hrp
	end

	setWorldCFrame(vfxClone, worldCF)

	-- Find the Slash folder inside the VFX (if it exists)
	local slashFolder = vfxClone:FindFirstChild("Slash")
	local targetFolder = slashFolder or vfxClone

	-- Apply emission direction
	setEmissionDirection(targetFolder, rotationConfig.emissionDirection)

	-- Apply particle rotation (only if emitters have 0..0 rotation)
	setParticleRotationIfZero(targetFolder, rotationConfig.particleRot)

	-- Emit particles
	emitParticles(targetFolder)

	-- Cleanup after particles finish
	task.delay(2, function()
		if vfxClone and vfxClone.Parent then
			vfxClone:Destroy()
		end
	end)
end

-- Play beam slash arc VFX (briefly enables a Beam between two spread parts)
local function playBeamVfx(hrp, comboIndex)
	if not SlashBeam or not hrp then return end

	local clone = SlashBeam:Clone()
	clone.Parent = workspace

	local beamStart = clone:FindFirstChild("BeamStart")
	local beamEnd   = clone:FindFirstChild("BeamEnd")
	local beam      = beamStart and beamStart:FindFirstChildOfClass("Beam")
	if not beamStart or not beamEnd or not beam then
		clone:Destroy()
		return
	end

	-- Spread the two anchor parts around the slash position
	local rotConfig = SLASH_ROTATIONS[comboIndex] or { hrp = CFrame.Angles(0, 0, 0), forceForward = true }

	local baseCF
	if rotConfig.forceForward then
		local look = hrp.CFrame.LookVector
		local flatCF = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(look.X, 0, look.Z))
		baseCF = flatCF * CFrame.new(0, 0, -3)
	else
		baseCF = hrp.CFrame * CFrame.new(0, 0, -3)
	end

	-- Spread 4 studs apart (left → right of swing)
	beamStart.CFrame = baseCF * CFrame.new(-4, 1, 0)
	beamEnd.CFrame   = baseCF * CFrame.new(4, -1, 0)
	beamStart.Anchored = true
	beamEnd.Anchored   = true

	-- Brief flash: enable → fade out → destroy
	beam.Enabled = true
	task.delay(0.08, function()
		if beam and beam.Parent then
			beam.Enabled = false
		end
	end)
	task.delay(0.25, function()
		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
end

-- Movement debuff functions
local function applyMovementDebuff(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local config = SlashSettings.MovementDebuff
	if not config.Enabled then return end

	local base = humanoid:GetAttribute(config.StatName) or humanoid.WalkSpeed
	local reduced = math.max(config.MinWalkSpeed, base * (1 - config.MovementReduction))

	humanoid.WalkSpeed = reduced
end

local function restoreMovement(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local config = SlashSettings.MovementDebuff
	local base = humanoid:GetAttribute(config.StatName) or 16

	-- If still blocking and block system is installed, restore to block speed instead of base
	if ParryBlockSettings and character:GetAttribute("CombatState") == "Blocking" then
		humanoid.WalkSpeed = base * ParryBlockSettings.Block.MovementSpeedMultiplier
	else
		humanoid.WalkSpeed = base
	end
end

-- Main slash function
function SlashHandler:TrySlash()
	if self._cooling then
		return
	end

	local humanoid, hrp = getLocalHumanoid()
	if not humanoid or not hrp then
		return
	end

	local player = Players.LocalPlayer
	local character = player.Character

	-- Set LastAttackTime for post-attack block delay
	if character then
		character:SetAttribute("LastAttackTime", workspace:GetServerTimeNow())
	end

	local anims = SlashSettings.SlashAnimations or {}
	if #anims == 0 then
		return
	end

	local currentCombo = self._comboIndex
	local animId = anims[currentCombo]

	-- Play swing sound with optional delay
	local swingSounds = SlashSettings.SlashSwingSounds or {}
	if #swingSounds > 0 then
		local soundId = swingSounds[1]
		local soundDelay = SlashSettings.SwingSoundDelay or 0
		playSound(soundId, character, soundDelay)
	end

	-- Play slash VFX with optional delay (particles + beam arc)
	local vfxDelay = SlashSettings.SlashVfxDelay or 0
	if vfxDelay > 0 then
		task.delay(vfxDelay, function()
			playSlashVfx(hrp, currentCombo)
			playBeamVfx(hrp, currentCombo)
		end)
	else
		playSlashVfx(hrp, currentCombo)
		playBeamVfx(hrp, currentCombo)
	end

	-- Apply movement debuff
	local debuffConfig = SlashSettings.MovementDebuff
	if debuffConfig.Enabled and self._buffManager then
		self._buffManager:apply(character, debuffConfig.BuffName, debuffConfig.Duration, {
			mode = "refresh",
			onApply = applyMovementDebuff,
			onExpire = restoreMovement,
		})
	end

	-- Play animation
	local track = playAnimation(humanoid, animId)

	-- Notify server
	CombatService:PerformSlash():catch(function() end)

	-- Set cooldown
	self._cooling = true
	local cooldownTime = track.Length > 0 and track.Length or (SlashSettings.SwingDuration or 0.3)
	local isLastCombo = currentCombo >= #anims
	local extraDelay = isLastCombo and (SlashSettings.ComboFinisherCooldown or 0.25) or 0
	task.delay(cooldownTime + (SlashSettings.ClientCooldownBuffer or 0.1) + extraDelay, function()
		self._cooling = false
	end)

	-- Advance combo
	self._comboIndex = isLastCombo and 1 or currentCombo + 1
end

-- Helper: Check if tool is registered in SlashSettings
local function isRegisteredWeapon(toolName)
	local registeredWeapons = SlashSettings.RegisteredWeapons or {}
	for _, weaponName in ipairs(registeredWeapons) do
		if toolName:lower():find(weaponName:lower()) then
			return true
		end
	end
	return false
end

-- Tool equip/unequip handlers
local function onToolEquipped(tool)
	if not tool or not tool:IsA("Tool") then return end

	-- Check if tool is registered in SlashSettings or has EnableSlash attribute
	if tool:GetAttribute("EnableSlash") or isRegisteredWeapon(tool.Name) then
		SlashHandler._equippedTool = tool
	end
end

local function onToolUnequipped(tool)
	if SlashHandler._equippedTool == tool then
		SlashHandler._equippedTool = nil
	end
end

function SlashHandler.Start()
	SlashHandler._buffManager = BuffTimerUtil.new(0.1)

	-- Load effects
	local effectsFolder = assets:FindFirstChild("Effects")
	if effectsFolder then
		local punchesFolder = effectsFolder:FindFirstChild("Punches")
		if punchesFolder then
			PunchEffect = punchesFolder:FindFirstChild("PunchEffect")
		end

		local slashesFolder = effectsFolder:FindFirstChild("Slashes")
		if slashesFolder then
			SlashVfx   = slashesFolder:FindFirstChild("SlashVfx")
			SlashBeam  = slashesFolder:FindFirstChild("SlashBeam")
		end

		local combatFolder = effectsFolder:FindFirstChild("Combat")
		if combatFolder then
			BlockHitEffect = combatFolder:FindFirstChild("Block Hit")
		end
	end

	-- Preload combat sounds into Assets.Effects.Combat
	local combatFolder = effectsFolder and effectsFolder:FindFirstChild("Combat")
	if not combatFolder then
		combatFolder = Instance.new("Folder")
		combatFolder.Name = "Combat"
		combatFolder.Parent = effectsFolder or assets
	end

	local function preloadSound(soundId, name)
		if not soundId or soundId == "" or soundTemplates[soundId] then
			return
		end
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = soundId
		s.Parent = combatFolder
		soundTemplates[soundId] = s
	end

	for i, id in ipairs(SlashSettings.SlashSwingSounds or {}) do
		preloadSound(id, "SlashSwing_" .. i)
	end
	for i, id in ipairs(SlashSettings.HitSounds or {}) do
		preloadSound(id, "SlashHit_" .. i)
	end

	-- Preload slash animations using AssetPreloader
	local slashAnims = SlashSettings.SlashAnimations or {}
	if #slashAnims > 0 then
		task.spawn(function()
			AssetPreloader.PreloadWithProgress(slashAnims, function(loaded, total)
				print(string.format("[SlashHandler] Preloading animations: %d/%d", loaded, total))
			end)
			print("[SlashHandler] All slash animations preloaded!")
		end)
	end

	local player = Players.LocalPlayer

	-- M1 (MouseButton1) triggers slash when holding a registered weapon
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Only slash if holding a registered weapon
			if SlashHandler._equippedTool then
				SlashHandler:TrySlash()
			end
		end
	end)

	-- Helper to wire up tool equip/unequip listeners on a character
	local function setupCharacterListeners(character)
		character.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				onToolEquipped(child)
			end
		end)

		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				onToolUnequipped(child)
			end
		end)

		-- Pick up any tools already in the character
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				onToolEquipped(child)
			end
		end
	end

	player.CharacterAdded:Connect(setupCharacterListeners)

	if player.Character then
		setupCharacterListeners(player.Character)
	end

	-- Connect to server slash effect signals (registered via ClientExtension)
	CombatService.PlaySlashHitSound:Connect(function(target)
		playHitSound(target)
	end)

	CombatService.PlaySlashEffect:Connect(function(targetCharacter, wasBlocked)
		playSlashHitEffect(targetCharacter, wasBlocked)
	end)
end

function SlashHandler.Init()
	CombatService = Knit.GetService("CombatService")
end

return SlashHandler