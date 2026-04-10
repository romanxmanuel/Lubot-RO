local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Promise = require(ReplicatedStorage.Packages._Index["evaera_promise@4.0.0"]["promise"])

local NormalAttack = {}

-- State
NormalAttack._settings = nil
NormalAttack._cooldowns = {} -- [player] = lastAttackTime (os.clock)
NormalAttack._activeCasters = {} -- [player] = caster
NormalAttack._activeConnections = {} -- [player] = connection
NormalAttack._comboIndices = {} -- [player] = comboIndex
NormalAttack._clientHitCooldowns = {} -- [player] = { [target] = lastHitTime }

-- Knit Services
local CombatService

-- Utilities
local DamageUtils
local KnockbackHandler
local ClientCast

local function now()
	return os.clock()
end

--[[
	Create a temporary DmgPoint attachment on the player's attacking hand.
	Combo 1 uses RightHand, combo 2 uses LeftHand.

	@param character Model - Player's character
	@param comboIndex number - Current combo index (1 or 2)
	@return Attachment? - The created DmgPoint attachment, or nil
]]
local function createHandDmgPoint(character, comboIndex)
	local handName = comboIndex == 1 and "RightHand" or "LeftHand"
	local hand = character:FindFirstChild(handName, true)
	if not hand then
		-- Fallback: try R15 naming, then R6 naming
		hand = character:FindFirstChild("RightHand", true) or character:FindFirstChild("Right Arm", true)
	end
	if not hand or not hand:IsA("BasePart") then
		return nil, nil
	end

	local dmgPoint = Instance.new("Attachment")
	dmgPoint.Name = "DmgPoint"
	dmgPoint.Parent = hand
	return dmgPoint, hand
end

--[[
	Cleans up any existing punch resources for a player.
	@param player Player - The player to clean up for
]]
local function cleanupPlayerPunch(player)
	if NormalAttack._activeCasters[player] then
		pcall(function()
			NormalAttack._activeCasters[player]:Stop()
			NormalAttack._activeCasters[player]:Destroy()
		end)
		NormalAttack._activeCasters[player] = nil
	end

	if NormalAttack._activeConnections[player] then
		pcall(function()
			NormalAttack._activeConnections[player]:Disconnect()
		end)
		NormalAttack._activeConnections[player] = nil
	end
end

--[[
	Handle a client-reported hit on a server-physics NPC.
	Validates range, cooldown, and target state before applying damage.

	@param player Player - The attacking player
	@param targetNPC Model - The NPC character model reported as hit
]]
function NormalAttack:HandleClientHitNPC(player, targetNPC)
	-- Validate target is a Model with a Humanoid (basic type check)
	if not targetNPC or not targetNPC:IsA("Model") then
		return
	end

	local targetHumanoid = targetNPC:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end

	-- Reject if target is actually a player character (prevent exploiting this for PvP)
	if Players:GetPlayerFromCharacter(targetNPC) then
		return
	end

	-- Validate attacker is alive
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not hrp then
		return
	end

	-- Validate range
	local targetHRP = targetNPC:FindFirstChild("HumanoidRootPart")
	if not targetHRP then return end
	local maxRange = self._settings.ServerMaxHitRange or 15
	local distance = (targetHRP.Position - hrp.Position).Magnitude
	if distance > maxRange then
		return
	end

	-- Per-player per-target cooldown to prevent spam
	if not self._clientHitCooldowns[player] then
		self._clientHitCooldowns[player] = {}
	end
	local cooldown = self._settings.ServerAttackCooldown or 0.5
	local lastHit = self._clientHitCooldowns[player][targetNPC]
	if lastHit and (now() - lastHit) < cooldown then
		return
	end
	self._clientHitCooldowns[player][targetNPC] = now()

	-- Apply damage
	local damage = self._settings.DamagePerHit or 10
	local damagedTargets = DamageUtils.ApplyDamageToTargets({targetNPC}, damage, char, { AttackSubType = "punch", Attacker = char })

	-- Apply knockback
	if #damagedTargets > 0 and hrp.Parent then
		KnockbackHandler:ApplyKnockbackToTargets(damagedTargets, hrp.Position, player)
	end

	-- Broadcast effects to all clients
	CombatService.Client.PlayPunchEffect:FireAll(targetNPC)
	CombatService.Client.PlayHitSound:FireAll(targetNPC)
end

-- Exposed to Set().lua delegator
function NormalAttack:PerformAttack(player)
	-- Validate player
	local char = player.Character
	if not char then
		return Promise.resolve(false)
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		return Promise.resolve(false)
	end

	-- Cooldown check (per-attack-type)
	local last = self._cooldowns[player] or 0
	local cd = self._settings.ServerAttackCooldown or 0.5
	if (now() - last) < cd then
		return Promise.resolve(false)
	end

	-- Shared cooldown: prevent punch→slash weapon swap exploit
	local lastAttack = char:GetAttribute("LastAttackTime") or 0
	if (workspace:GetServerTimeNow() - lastAttack) < cd then
		return Promise.resolve(false)
	end

	self._cooldowns[player] = now()
	char:SetAttribute("LastAttackTime", workspace:GetServerTimeNow())

	-- Clean up any existing punch resources
	cleanupPlayerPunch(player)

	-- Determine combo index (server-tracked)
	local maxCombo = #(self._settings.AttackAnimations or {})
	if maxCombo == 0 then maxCombo = 2 end
	local comboIndex = self._comboIndices[player] or 1

	-- Create DmgPoint on attacking hand
	local dmgPoint, hand = createHandDmgPoint(char, comboIndex)
	if not dmgPoint or not hand then
		warn("[NormalAttack] No hand found for DmgPoint")
		return Promise.resolve(false)
	end

	-- Advance combo for next attack
	self._comboIndices[player] = comboIndex % maxCombo + 1

	-- Setup ClientCast raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {char}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	-- Create ClientCast caster on the hand, owner=player (client does raycasts)
	local caster = ClientCast.new(hand, raycastParams, player)
	caster:SetRecursive(false)
	self._activeCasters[player] = caster

	-- Track hit targets
	local hitTargets = {}
	local targetSet = {}

	-- Connect to ClientCast collision events (players only — NPC hits use client hitbox path)
	local connection = caster.HumanoidCollided:Connect(function(raycastResult, targetHumanoid)
		local targetCharacter = targetHumanoid.Parent
		if targetCharacter and not targetSet[targetCharacter] then
			-- Only track player targets; NPCs are handled by HitServerNPC
			if Players:GetPlayerFromCharacter(targetCharacter) then
				targetSet[targetCharacter] = true
				table.insert(hitTargets, targetCharacter)
			end
		end
	end)
	self._activeConnections[player] = connection

	-- Start the caster
	caster:Start()

	-- Let ClientCast detect hits during swing duration
	local swingDuration = self._settings.SwingDuration or 0.3
	task.delay(swingDuration, function()
		-- Stop caster and clean up
		cleanupPlayerPunch(player)
		if dmgPoint then
			dmgPoint:Destroy()
		end

		-- Re-validate player character is still alive
		if not char or not char.Parent then return end
		if not humanoid or humanoid.Health <= 0 then return end

		-- Apply damage to hit targets using DamageUtils
		local damage = self._settings.DamagePerHit or 10
		local damagedTargets, blockedTargets = DamageUtils.ApplyDamageToTargets(hitTargets, damage, char, { AttackSubType = "punch", Attacker = char })
		blockedTargets = blockedTargets or {} -- block system may not exist

		-- Apply knockback to damaged targets
		if #damagedTargets > 0 and hrp and hrp.Parent then
			KnockbackHandler:ApplyKnockbackToTargets(damagedTargets, hrp.Position, player)
		end

		-- Send effects to ALL clients (pass blocked flag for block hit VFX)
		if #hitTargets > 0 then
			for _, target in ipairs(hitTargets) do
				local wasBlocked = blockedTargets[target] or false
				CombatService.Client.PlayPunchEffect:FireAll(target, wasBlocked)
			end

			-- Trigger hit sounds for damaged targets
			if #damagedTargets > 0 then
				for _, target in ipairs(damagedTargets) do
					CombatService.Client.PlayHitSound:FireAll(target)
				end
			end
		end
	end)

	return Promise.resolve(true)
end

function NormalAttack.Start()
	-- Clean up player resources when they leave
	Players.PlayerRemoving:Connect(function(player)
		cleanupPlayerPunch(player)
		NormalAttack._cooldowns[player] = nil
		NormalAttack._comboIndices[player] = nil
		NormalAttack._clientHitCooldowns[player] = nil
	end)
end

function NormalAttack.Init()
	local datas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
	NormalAttack._settings = require(datas:WaitForChild("Combat"):WaitForChild("PunchSettings", 10))

	-- Get Knit services
	CombatService = Knit.GetService("CombatService")

	-- Load utilities
	local Others = script.Parent
	DamageUtils = require(Others:WaitForChild("DamageUtils"))
	KnockbackHandler = require(Others:WaitForChild("KnockbackHandler"))

	-- Load ClientCast
	local utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
	ClientCast = require(utilities:WaitForChild("ClientCast"))
end

return NormalAttack
