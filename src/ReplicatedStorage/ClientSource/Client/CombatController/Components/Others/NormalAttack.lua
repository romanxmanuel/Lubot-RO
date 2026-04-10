local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local NormalAttack = {}

-- Resolved at Init
local CombatService
local NPC_Service
local NPC_Controller
local PunchSettings
local ParticleEmitters
local PunchEffect
local BlockHitEffect

-- Preloaded sound templates (soundId → Sound instance in Assets.Effects.Combat)
local soundTemplates = {}

-- State
NormalAttack._comboIndex = 1
NormalAttack._cooling = false

local function getLocalHumanoid()
	local plr = Players.LocalPlayer
	local char = plr and plr.Character
	if not char then
		return nil, nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return humanoid, hrp
end

local function playAnimation(humanoid, animId)
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = humanoid:LoadAnimation(anim)
	track:Play(0)
	return track
end

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

local function playHitSound(parent)
	local hitSounds = PunchSettings.HitSounds or {}
	if #hitSounds > 0 then
		local soundId = hitSounds[math.random(1, #hitSounds)]
		playSound(soundId, parent)
	end
end

-- Find a client-physics NPC visual model by npcID
local function findNPCVisualModel(npcID)
	local npcsFolder = workspace:FindFirstChild("Characters")
	npcsFolder = npcsFolder and npcsFolder:FindFirstChild("NPCs")
	if not npcsFolder then
		return nil
	end
	for _, model in ipairs(npcsFolder:GetChildren()) do
		if model:GetAttribute("ClientPhysicsNPCID") == npcID then
			return model
		end
	end
	return nil
end

local function playPunchHitEffect(targetCharacter, wasBlocked)
	-- Fall back to PunchEffect if BlockHitEffect doesn't exist
	local effectTemplate = (wasBlocked and BlockHitEffect) or PunchEffect
	if not effectTemplate then
		warn("[NormalAttack] PunchEffect not loaded!")
		return
	end
	-- If we wanted block effect but it's missing, use normal effect instead
	if wasBlocked and not BlockHitEffect then
		wasBlocked = false
	end

	local hrp = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("[NormalAttack] No HumanoidRootPart found on target")
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

-- Original client-physics NPC detection (no server model exists, detection must be fully client-side)
local function startClientPhysicsNPCDetection(hrp, plr)
	local RunService = game:GetService("RunService")
	local hitboxSize = PunchSettings.ClientHitboxSize or Vector3.new(5, 5, 5)
	local swingDuration = PunchSettings.SwingDuration or 0.7
	local hitSet = {} -- Track unique NPC IDs already hit

	local startTime = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() - startTime >= swingDuration then
			connection:Disconnect()
			return
		end

		if not hrp or not hrp.Parent then
			connection:Disconnect()
			return
		end

		local hitboxCF = hrp.CFrame + hrp.CFrame.LookVector * (hitboxSize.Z / 2)
		local parts = workspace:GetPartBoundsInBox(hitboxCF, hitboxSize)

		for i = 1, #parts do
			local character = parts[i].Parent
			if character and character ~= plr.Character and not hitSet[character] then
				local npcID = character:GetAttribute("ClientPhysicsNPCID")
				if npcID and NPC_Service then
					hitSet[character] = true
					NPC_Service:HitClientPhysicsNPC(npcID, "punch")
					playPunchHitEffect(character)
					playHitSound(character)
				end
			end
		end
	end)
end

-- Server-physics NPC detection (models exist on server, client reports hits for immediate validation)
local function startServerNPCHitboxDetection(hrp, plr)
	local RunService = game:GetService("RunService")
	local hitboxSize = PunchSettings.ClientHitboxSize or Vector3.new(5, 5, 5)
	local swingDuration = PunchSettings.SwingDuration or 0.7
	local hitboxStartDelay = PunchSettings.HitboxStartDelay or 0.4
	local hitSet = {}

	local startTime = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= swingDuration then
			connection:Disconnect()
			return
		end

		if not hrp or not hrp.Parent then
			connection:Disconnect()
			return
		end

		if elapsed < hitboxStartDelay then
			return
		end

		local hitboxCF = hrp.CFrame + hrp.CFrame.LookVector * (hitboxSize.Z / 2)
		local parts = workspace:GetPartBoundsInBox(hitboxCF, hitboxSize)

		for i = 1, #parts do
			local character = parts[i].Parent
			if character and character ~= plr.Character and not hitSet[character] then
				-- Skip client-physics NPCs (handled by startClientPhysicsNPCDetection)
				if character:GetAttribute("ClientPhysicsNPCID") then
					continue
				end

				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					local isPlayer = Players:GetPlayerFromCharacter(character)
					if not isPlayer then
						hitSet[character] = true
						CombatService:HitServerNPC(character)
						playPunchHitEffect(character)
					end
				end
			end
		end
	end)
end

function NormalAttack:TryAttack()
	if NormalAttack._cooling then
		return
	end
	local humanoid, hrp = getLocalHumanoid()
	if not humanoid or not hrp then
		return
	end

	-- Set LastAttackTime for post-attack block delay
	local plrChar = Players.LocalPlayer and Players.LocalPlayer.Character
	if plrChar then
		plrChar:SetAttribute("LastAttackTime", workspace:GetServerTimeNow())
	end

	-- Determine current animation
	local anims = PunchSettings.AttackAnimations or {}
	if #anims == 0 then
		return
	end
	local animId = anims[NormalAttack._comboIndex]

	-- Play attack sound with optional delay (parented to user's character)
	local attackSounds = PunchSettings.AttackSounds or {}
	if #attackSounds > 0 then
		local soundId = attackSounds[math.min(NormalAttack._comboIndex, #attackSounds)]
		local plr = Players.LocalPlayer
		local char = plr and plr.Character
		local soundDelay = PunchSettings.PunchSoundDelay or 0
		playSound(soundId, char, soundDelay)
	end

	-- Play animation locally
	local track = playAnimation(humanoid, animId)

	-- Tell server to start ClientCast hit detection (no targets sent)
	CombatService:PerformAttack():andThen(function(_ok) end)

	-- Detect NPC hits over swing duration via client-side hitbox
	startClientPhysicsNPCDetection(hrp, Players.LocalPlayer)
	startServerNPCHitboxDetection(hrp, Players.LocalPlayer)

	-- Wait for cooldown based on animation length
	local length = track.Length > 0 and track.Length or 0.3
	NormalAttack._cooling = true
	task.delay(length + (PunchSettings.ClientCooldownBuffer or 0.1), function()
		NormalAttack._cooling = false
	end)

	-- Advance combo
	NormalAttack._comboIndex += 1
	if NormalAttack._comboIndex > #anims then
		NormalAttack._comboIndex = 1
	end
end

-- Helper: Check if player is holding a tool
local function isHoldingTool()
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then return false end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return true
		end
	end
	return false
end

function NormalAttack.Start()
	-- Bind input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Only allow punch when NOT holding a tool
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not isHoldingTool() then
				NormalAttack:TryAttack()
			end
		end
	end)

	-- Listen for hit sound events from server
	CombatService.PlayHitSound:Connect(function(target)
		local plr = Players.LocalPlayer
		local char = plr and plr.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local targetHRP = target and target:FindFirstChild("HumanoidRootPart")
			if hrp and targetHRP then
				local distance = (targetHRP.Position - hrp.Position).Magnitude
				if distance <= 50 then
					playHitSound(target)
				end
			end
		end
	end)

	-- Listen for punch hit effects from server (fires to ALL clients)
	CombatService.PlayPunchEffect:Connect(function(targetCharacter, wasBlocked)
		playPunchHitEffect(targetCharacter, wasBlocked)
	end)

	-- Listen for client-physics NPC hit effects (fired to all OTHER clients)
	-- The attacking client already plays effects locally in startClientPhysicsNPCDetection
	if NPC_Service then
		NPC_Service.NPCHitEffectTriggered:Connect(function(npcID, _damageType)
			local npcModel = findNPCVisualModel(npcID)
			if npcModel then
				playPunchHitEffect(npcModel)
				playHitSound(npcModel)
			end
		end)
	end
end

function NormalAttack.Init()
	CombatService = Knit.GetService("CombatService")
	local ok, service = pcall(function()
		return Knit.GetService("NPC_Service")
	end)
	if ok then
		NPC_Service = service
	end
	local datas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
	PunchSettings = require(datas:WaitForChild("Combat"):WaitForChild("PunchSettings", 10))

	-- Load ParticleEmitters utility
	local utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
	ParticleEmitters = require(utilities:WaitForChild("Effects"):WaitForChild("ParticleEmitters", 10))

	-- Load PunchEffect asset
	local assets = ReplicatedStorage:WaitForChild("Assets", 10)
local effectsFolder = assets:WaitForChild("Effects", 10)
local punchesFolder = effectsFolder and effectsFolder:WaitForChild("Punches", 10)
PunchEffect = punchesFolder and punchesFolder:WaitForChild("PunchEffect", 10)

-- Load Block Hit effect
local combatEffects = effectsFolder and effectsFolder:WaitForChild("Combat", 10)
if combatEffects then
	BlockHitEffect = combatEffects:WaitForChild("Block Hit", 10)
end

	-- Preload combat sounds into Assets.Effects.Combat
	local combatFolder = assets:WaitForChild("Effects"):FindFirstChild("Combat")
	if not combatFolder then
		combatFolder = Instance.new("Folder")
		combatFolder.Name = "Combat"
		combatFolder.Parent = assets.Effects
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

	for i, id in ipairs(PunchSettings.AttackSounds or {}) do
		preloadSound(id, "PunchSwing_" .. i)
	end
	for i, id in ipairs(PunchSettings.HitSounds or {}) do
		preloadSound(id, "PunchHit_" .. i)
	end
end

return NormalAttack
