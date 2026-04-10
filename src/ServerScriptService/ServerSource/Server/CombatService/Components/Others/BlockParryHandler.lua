--[[
	BlockParryHandler.lua
	SERVER-SIDE component for the Parry and Block system.
	Validates block requests, manages combat state (Idle/Blocking/Stunned),
	evaluates parry windows on incoming damage, and applies stun on successful parries.
	Uses BuffTimerUtil for all timed effects (stun, block cooldown, block timeout).
	Location: CombatService/Components/Others/BlockParryHandler.lua
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local BlockParryHandler = {}

-- Settings
local ParryBlockSettings

-- Utilities
local BuffTimerUtil
local buffTimer -- BuffTimerUtil instance for stun/cooldown/timeout

-- Knit Services
local CombatService
local StatusEffectService

-- ClientExtension signals (registered in Init)
local BlockConfirmedSignal
local BlockRejectedSignal
local BlockHitSignal
local ParrySuccessSignal
local BlockBreakSignal

-- ClientExtension method (registered in Init)
local RequestBlockMethod

-- Tool registry lookup: toolId → toolDef
local ToolRegistryLookup = {}

-- Default WalkSpeed fallback
local DEFAULT_WALKSPEED = 16

-- Posture regen state: character → { lastHitTime: number }
local _postureState = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function getCharacter(player)
	local char = player.Character
	if not char then
		return nil, nil
	end
	return char, char:FindFirstChildOfClass("Humanoid")
end

--- Returns the ToolId and Tool instance of the first equipped tool.
local function getEquippedToolId(character)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child:GetAttribute("ToolId") or child.Name, child
		end
	end
	return nil, nil
end

--- Looks up BehaviorConfig from the ToolRegistry by toolId.
local function getWeaponBehaviorConfig(toolId)
	if not toolId or toolId == "" then
		return nil
	end
	local def = ToolRegistryLookup[toolId]
	if def and def.BehaviorConfig then
		return def.BehaviorConfig
	end
	return nil
end

local function setWalkSpeed(humanoid, multiplier)
	local baseSpeed = humanoid:GetAttribute("BaseWalkSpeed") or DEFAULT_WALKSPEED
	humanoid.WalkSpeed = baseSpeed * multiplier
end

local function restoreWalkSpeed(humanoid)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local baseSpeed = humanoid:GetAttribute("BaseWalkSpeed") or DEFAULT_WALKSPEED
	humanoid.WalkSpeed = baseSpeed
end

-- ============================================================
-- CORE METHODS
-- ============================================================

--[[
	Validates and starts blocking for a player.
	Called when the client sends RequestBlock(true, blockStartTime).
	The client has ALREADY entered block stance (client prediction).
	If validation fails, a BlockRejected signal is sent so the client can roll back.
]]
function BlockParryHandler:ValidateAndStartBlock(player, clientBlockStartTime)
	local char, humanoid = getCharacter(player)
	if not char or not humanoid or humanoid.Health <= 0 then
		BlockRejectedSignal:Fire(player, "Invalid character")
		return false
	end

	-- Already blocking
	if char:GetAttribute("CombatState") == "Blocking" then
		return false
	end

	-- Stunned → cannot block
	if StatusEffectService:HasEffect(char, "Stun") or StatusEffectService:HasEffect(char, "BlockBreak") then
		BlockRejectedSignal:Fire(player, "Stunned")
		return false
	end

	-- Block cooldown active
	if buffTimer:has(char, "BlockCooldown") then
		BlockRejectedSignal:Fire(player, "On cooldown")
		return false
	end

	-- Check equipped weapon
	local toolId, _tool = getEquippedToolId(char)
	local behaviorConfig = getWeaponBehaviorConfig(toolId)

	if not toolId then
		-- Bare-handed
		if not ParryBlockSettings.Block.AllowBareHanded then
			BlockRejectedSignal:Fire(player, "Cannot block bare-handed")
			return false
		end
	else
		-- Weapon equipped — check CanBlock (defaults to true)
		local canBlock = true
		if behaviorConfig and behaviorConfig.CanBlock ~= nil then
			canBlock = behaviorConfig.CanBlock
		end
		if not canBlock then
			BlockRejectedSignal:Fire(player, "Weapon cannot block")
			return false
		end
	end

	-- Timestamp sanity check (anti-cheat)
	local serverTime = workspace:GetServerTimeNow()
	local blockStartTime = clientBlockStartTime or serverTime
	local drift = math.abs(serverTime - blockStartTime)
	if drift > ParryBlockSettings.Parry.MaxTimestampDrift then
		blockStartTime = serverTime - ParryBlockSettings.Parry.MaxTimestampDrift
	end

	-- Post-attack delay: reject block if player attacked too recently
	local lastAttack = char:GetAttribute("LastAttackTime") or 0
	local postDelay = ParryBlockSettings.Block.PostAttackBlockDelay or 0.3
	if (workspace:GetServerTimeNow() - lastAttack) < postDelay then
		BlockRejectedSignal:Fire(player, "Post-attack cooldown")
		return false
	end

	-- === VALID — set state ===
	char:SetAttribute("CombatState", "Blocking")
	char:SetAttribute("BlockStartTime", blockStartTime)
	char:SetAttribute("BlockingWeaponId", toolId or "")

	-- Movement slow
	setWalkSpeed(humanoid, ParryBlockSettings.Block.MovementSpeedMultiplier)

	BlockConfirmedSignal:Fire(player)
	return true
end

--[[
	Ends blocking for a player.
	Called when the client releases the block key, or on timeout/death.
]]
function BlockParryHandler:EndBlock(player)
	local char, humanoid = getCharacter(player)
	if not char then
		return
	end

	if char:GetAttribute("CombatState") ~= "Blocking" then
		return
	end

	char:SetAttribute("CombatState", "Idle")
	char:SetAttribute("BlockStartTime", 0)
	char:SetAttribute("BlockingWeaponId", "")

	if humanoid and humanoid.Health > 0 then
		restoreWalkSpeed(humanoid)
	end

	-- Cancel block timeout
	buffTimer:remove(char, "BlockTimeout")

	-- Apply block cooldown
	buffTimer:apply(char, "BlockCooldown", ParryBlockSettings.Block.BlockCooldown, {})
end

--[[
	Breaks the block due to posture depletion.
	Ends the block, applies BlockBreak stun, and notifies the client for VFX.
]]
function BlockParryHandler:BreakBlock(player, attackerChar)
	local char, humanoid = getCharacter(player)
	if not char then
		return
	end

	-- End block state
	if char:GetAttribute("CombatState") == "Blocking" then
		char:SetAttribute("CombatState", "Idle")
		char:SetAttribute("BlockStartTime", 0)
		char:SetAttribute("BlockingWeaponId", "")
		buffTimer:remove(char, "BlockTimeout")
	end

	-- Restore walk speed to base BEFORE applying stun so the stun effect
	-- stores the correct base speed (not the reduced block speed)
	if humanoid then
		restoreWalkSpeed(humanoid)
	end

	-- Reset posture to 0 (will be restored after stun ends)
	char:SetAttribute("Posture", 0)

	-- Apply BlockBreak stun via StatusEffectService
	local stunDuration = ParryBlockSettings.Posture.BlockBreakStunDuration
	StatusEffectService:ApplyEffect(char, "BlockBreak", stunDuration)

	-- Fire client signal for VFX
	BlockBreakSignal:Fire(player, attackerChar)
end

--[[
	Evaluates whether incoming damage should be blocked or parried.
	Called by DamageHandler before applying damage.

	@param user Model - The attacker character
	@param target Model - The defender character (potential blocker)
	@param damageInfo table - Damage info table with Damage, DamageType, AttackSubType, Attacker
	@return { result: "none"|"blocked"|"parried", modifiedDamage: number }
]]
function BlockParryHandler:EvaluateDefense(user, target, damageInfo)
	local damage = damageInfo.Damage or 0
	local result = { result = "none", modifiedDamage = damage }

	-- Target must be blocking
	if target:GetAttribute("CombatState") ~= "Blocking" then
		return result
	end

	-- Determine attack type for rules lookup (AttackSubType takes priority over DamageType)
	local attackType = damageInfo.AttackSubType or damageInfo.DamageType
	local rules = ParryBlockSettings.AttackTypeRules[attackType]

	-- Fallback to DamageType if AttackSubType rules not found
	if not rules and damageInfo.AttackSubType then
		rules = ParryBlockSettings.AttackTypeRules[damageInfo.DamageType]
	end

	-- No rules or attack cannot be blocked → pass through
	if not rules or not rules.CanBeBlocked then
		return result
	end

	-- === Attack CAN be blocked ===

	-- Check parry window
	local blockStartTime = target:GetAttribute("BlockStartTime") or 0
	local timeSinceBlock = workspace:GetServerTimeNow() - blockStartTime
	local withinParryWindow = timeSinceBlock < ParryBlockSettings.Parry.ParryWindow

	if withinParryWindow and rules.CanBeParried then
		-- Check defender's weapon CanParry
		local weaponId = target:GetAttribute("BlockingWeaponId") or ""
		local behaviorConfig = getWeaponBehaviorConfig(weaponId)

		local canParry = false
		if weaponId == "" then
			-- Bare-handed cannot parry
			canParry = false
		elseif behaviorConfig then
			if behaviorConfig.CanParry ~= nil then
				canParry = behaviorConfig.CanParry
			else
				-- Default: CanParry = true if weapon has EnableSlash
				canParry = behaviorConfig.EnableSlash or false
			end
		else
			-- Unknown weapon — default to allowing parry
			canParry = true
		end

		if canParry then
			-- === PARRY: negate all damage ===
			result.result = "parried"
			result.modifiedDamage = 0

			-- Recover posture on successful parry
			local postureSettings = ParryBlockSettings.Posture
			local currentPosture = target:GetAttribute("Posture") or postureSettings.MaxPosture
			local newPosture = math.min(currentPosture + postureSettings.ParryPostureRecover, postureSettings.MaxPosture)
			target:SetAttribute("Posture", newPosture)

			-- Notify defender (parry success VFX)
			local defenderPlayer = Players:GetPlayerFromCharacter(target)
			local attackerChar = damageInfo.Attacker or user
			if defenderPlayer then
				ParrySuccessSignal:Fire(defenderPlayer, attackerChar)
			end

			-- Notify attacker (they got parried — for stun VFX)
			local attackerPlayer = Players:GetPlayerFromCharacter(attackerChar)
			if attackerPlayer then
				ParrySuccessSignal:Fire(attackerPlayer, target)
			end

			return result
		end
	end

	-- === BLOCK: reduce damage ===
	local weaponId = target:GetAttribute("BlockingWeaponId") or ""
	local reduction
	if weaponId == "" then
		reduction = ParryBlockSettings.Block.BareHandedReduction
	else
		reduction = ParryBlockSettings.Block.DamageReduction
	end

	result.result = "blocked"
	result.modifiedDamage = damage * (1 - reduction)

	-- === POSTURE DEDUCTION ===
	local postureSettings = ParryBlockSettings.Posture
	local postureDmg
	if weaponId == "" then
		postureDmg = postureSettings.PostureDamageBareHanded
	else
		postureDmg = postureSettings.PostureDamageBase
	end

	local currentPosture = target:GetAttribute("Posture") or postureSettings.MaxPosture
	currentPosture = currentPosture - postureDmg

	-- Track last hit time for regen delay
	_postureState[target] = _postureState[target] or {}
	_postureState[target].lastHitTime = workspace:GetServerTimeNow()

	local attackerChar = damageInfo.Attacker or user

	if currentPosture <= 0 then
		-- Posture broken → block break
		target:SetAttribute("Posture", 0)
		local defenderPlayer = Players:GetPlayerFromCharacter(target)
		if defenderPlayer then
			self:BreakBlock(defenderPlayer, attackerChar)
		end
		-- Still return blocked result for this hit (damage was reduced)
		return result
	end

	target:SetAttribute("Posture", currentPosture)

	-- Notify defender (block hit VFX/sound)
	local defenderPlayer = Players:GetPlayerFromCharacter(target)
	if defenderPlayer then
		BlockHitSignal:Fire(defenderPlayer, attackerChar)
	end

	return result
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

function BlockParryHandler.Start()
	local postureSettings = ParryBlockSettings.Posture

	-- When a character gets stunned while blocking, force end their block
	StatusEffectService.OnEffectApplied:Connect(function(character, effectName, _duration)
		if effectName == "Stun" or effectName == "BlockBreak" then
			local stunPlayer = Players:GetPlayerFromCharacter(character)
			if stunPlayer and character:GetAttribute("CombatState") == "Blocking" then
				BlockParryHandler:EndBlock(stunPlayer)
			end
		end
	end)

	-- When BlockBreak stun ends, reset posture to max
	StatusEffectService.OnEffectRemoved:Connect(function(character, effectName)
		if effectName == "BlockBreak" and postureSettings.ResetOnStunEnd then
			character:SetAttribute("Posture", postureSettings.MaxPosture)
			-- Clear regen delay state
			_postureState[character] = nil
		end
	end)

	-- === POSTURE REGEN LOOP ===
	RunService.Heartbeat:Connect(function(dt)
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			if not char then
				continue
			end
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				continue
			end

			local currentPosture = char:GetAttribute("Posture")
			if not currentPosture or currentPosture >= postureSettings.MaxPosture then
				continue
			end

			-- Don't regen while blocking or stunned
			local combatState = char:GetAttribute("CombatState")
			if combatState == "Blocking" or combatState == "Stunned" then
				continue
			end

			-- Regen delay after last block hit
			local state = _postureState[char]
			if state and state.lastHitTime then
				local elapsed = workspace:GetServerTimeNow() - state.lastHitTime
				if elapsed < postureSettings.RegenDelay then
					continue
				end
			end

			-- Regen posture
			local newPosture = math.min(currentPosture + postureSettings.RegenRate * dt, postureSettings.MaxPosture)
			char:SetAttribute("Posture", newPosture)

			-- Clear state when fully regenerated
			if newPosture >= postureSettings.MaxPosture then
				_postureState[char] = nil
			end
		end
	end)

	-- Set combat state defaults for existing players
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			if not char:GetAttribute("CombatState") then
				char:SetAttribute("CombatState", "Idle")
			end
			char:SetAttribute("BlockStartTime", 0)
			char:SetAttribute("BlockingWeaponId", "")
			char:SetAttribute("Posture", postureSettings.MaxPosture)
			char:SetAttribute("MaxPosture", postureSettings.MaxPosture)
		end
	end

	-- Character setup: set defaults + death cleanup
	local function onCharacterAdded(player, char)
		char:SetAttribute("CombatState", "Idle")
		char:SetAttribute("BlockStartTime", 0)
		char:SetAttribute("BlockingWeaponId", "")
		char:SetAttribute("Posture", postureSettings.MaxPosture)
		char:SetAttribute("MaxPosture", postureSettings.MaxPosture)

		local humanoid = char:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			buffTimer:remove(char, "BlockCooldown")
			buffTimer:remove(char, "BlockTimeout")
			char:SetAttribute("CombatState", "Idle")
			_postureState[char] = nil
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
		-- Handle already-spawned character
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end)

	-- Handle already-connected players
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
	end

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		local char = player.Character
		if char then
			buffTimer:remove(char, "BlockCooldown")
			buffTimer:remove(char, "BlockTimeout")
			char:SetAttribute("CombatState", nil)
			char:SetAttribute("BlockStartTime", nil)
			char:SetAttribute("BlockingWeaponId", nil)
			char:SetAttribute("Posture", nil)
			char:SetAttribute("MaxPosture", nil)
			_postureState[char] = nil
		end
	end)
end

function BlockParryHandler.Init()
	-- Load settings
	local datas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
	ParryBlockSettings = require(datas:WaitForChild("Combat"):WaitForChild("ParryBlockSettings", 10))

	-- Load BuffTimerUtil and create timer instance
	local utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
	BuffTimerUtil = require(utilities:WaitForChild("Timing"):WaitForChild("BuffTimerUtil"))
	buffTimer = BuffTimerUtil.new(0.05) -- 50ms tick for tight parry timing

	-- Get Knit Service references
	CombatService = Knit.GetService("CombatService")
	StatusEffectService = Knit.GetService("StatusEffectService")

	-- Build tool registry lookup for weapon config checks
	local toolDefsFolder = datas
		:WaitForChild("ToolDefinitions")
		:WaitForChild("ToolRegistry")
		:WaitForChild("Categories")
	for _, categoryFolder in ipairs(toolDefsFolder:GetChildren()) do
		if categoryFolder:IsA("Folder") then
			for _, subcategoryModule in ipairs(categoryFolder:GetChildren()) do
				if subcategoryModule:IsA("ModuleScript") then
					local ok, defs = pcall(require, subcategoryModule)
					if ok and type(defs) == "table" then
						for toolId, def in pairs(defs) do
							ToolRegistryLookup[toolId] = def
						end
					end
				end
			end
		end
	end

	-- === Register ClientExtension signals ===
	BlockConfirmedSignal = Knit.RegisterClientSignal(CombatService, "BlockConfirmed")
	BlockRejectedSignal = Knit.RegisterClientSignal(CombatService, "BlockRejected")
	BlockHitSignal = Knit.RegisterClientSignal(CombatService, "BlockHit")
	ParrySuccessSignal = Knit.RegisterClientSignal(CombatService, "ParrySuccess")
	BlockBreakSignal = Knit.RegisterClientSignal(CombatService, "BlockBreak")

	-- === Register ClientExtension method ===
	RequestBlockMethod = Knit.RegisterClientMethod(CombatService, "RequestBlock")
	RequestBlockMethod.OnServerInvoke = function(_self, player, isBlocking, clientBlockStartTime)
		-- Validate input types
		if type(isBlocking) ~= "boolean" then
			return false
		end

		if isBlocking then
			if clientBlockStartTime ~= nil and type(clientBlockStartTime) ~= "number" then
				return false
			end
			return BlockParryHandler:ValidateAndStartBlock(player, clientBlockStartTime)
		else
			BlockParryHandler:EndBlock(player)
			return true
		end
	end
end

return BlockParryHandler
