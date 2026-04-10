--[[
	SlashHandler.lua
	SERVER-SIDE component for processing slash attacks using ClientCast (CONSOLIDATED)
	Uses the actual weapon's Blade mesh with DmgPoint attachments for hit detection
	Location: ServerScriptService/ServerSource/Server/CombatService/Components/Others/SlashHandler.lua
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Promise = require(ReplicatedStorage.Packages._Index["evaera_promise@4.0.0"]["promise"])

local SlashHandler = {}

-- State
SlashHandler._settings = nil
SlashHandler._cooldowns = {} -- [player] = lastSlashTime (os.clock)
SlashHandler._activeCasters = {} -- [player] = caster
SlashHandler._activeConnections = {} -- [player] = connection

-- Knit Services
local CombatService

-- ClientExtension signals and methods (registered in Init)
local PlaySlashEffectSignal
local PlaySlashHitSoundSignal
local PerformSlashMethod

-- Utilities
local DamageUtils
local KnockbackHandler
local ClientCast

local function now()
	return os.clock()
end

--[[
	Finds the weapon's Blade mesh with DmgPoint attachments from the player's equipped tool.
	@param character Model - The player's character
	@return BasePart|nil - The Blade mesh with DmgPoint attachments, or nil if not found
]]
local function findWeaponBlade(character: Model): BasePart?
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local blade = child:FindFirstChild("Blade")
			if blade and blade:IsA("BasePart") then
				local hasDmgPoint = false
				for _, attachment in ipairs(blade:GetChildren()) do
					if attachment:IsA("Attachment") and attachment.Name == "DmgPoint" then
						hasDmgPoint = true
						break
					end
				end

				if hasDmgPoint then
					return blade
				end
			end
		end
	end

	return nil
end

--[[
	Cleans up any existing slash resources for a player.
	@param player Player - The player to clean up for
]]
local function cleanupPlayerSlash(player: Player)
	if SlashHandler._activeCasters[player] then
		pcall(function()
			SlashHandler._activeCasters[player]:Stop()
			SlashHandler._activeCasters[player]:Destroy()
		end)
		SlashHandler._activeCasters[player] = nil
	end

	if SlashHandler._activeConnections[player] then
		pcall(function()
			SlashHandler._activeConnections[player]:Disconnect()
		end)
		SlashHandler._activeConnections[player] = nil
	end
end

-- Main slash processing function (exposed to CombatService)
function SlashHandler:PerformSlash(player: Player)
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

	-- Clean up any existing slash resources
	cleanupPlayerSlash(player)

	-- Find the weapon's Blade mesh with DmgPoint attachments
	local blade = findWeaponBlade(char)
	if not blade then
		warn("[SlashHandler] No weapon with Blade and DmgPoint attachments found")
		return Promise.resolve(false)
	end

	-- Setup ClientCast raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {char}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	-- Create ClientCast caster using the actual weapon's Blade mesh
	local caster = ClientCast.new(blade, raycastParams, player)
	caster:SetRecursive(false)
	self._activeCasters[player] = caster

	-- Track hit targets
	local hitTargets = {}
	local targetSet = {}

	-- Connect to ClientCast collision events
	local connection = caster.HumanoidCollided:Connect(function(raycastResult, targetHumanoid)
		local targetCharacter = targetHumanoid.Parent
		if targetCharacter and not targetSet[targetCharacter] then
			targetSet[targetCharacter] = true
			table.insert(hitTargets, targetCharacter)
		end
	end)
	self._activeConnections[player] = connection

	-- Start the caster
	caster:Start()

	-- Let ClientCast detect hits during swing duration
	local swingDuration = self._settings.SwingDuration or 0.3
	task.delay(swingDuration, function()
		-- Stop caster and clean up
		cleanupPlayerSlash(player)

		-- Apply damage to hit targets using DamageUtils
		local damage = self._settings.DamagePerHit or 15
		local damagedTargets, blockedTargets = DamageUtils.ApplyDamageToTargets(hitTargets, damage, char, { AttackSubType = "slash", Attacker = char })

		-- Apply knockback to damaged targets
		if #damagedTargets > 0 and hrp and hrp.Parent then
			KnockbackHandler:ApplyKnockbackToTargets(damagedTargets, hrp.Position, player)
		end

		-- Send effects to ALL clients via ClientExtension signals (pass blocked flag for block hit VFX)
		if #hitTargets > 0 then
			for _, target in ipairs(hitTargets) do
				local wasBlocked = blockedTargets[target] or false
				PlaySlashEffectSignal:FireAll(target, wasBlocked)
			end

			-- Trigger hit sounds for damaged targets
			if #damagedTargets > 0 then
				for _, target in ipairs(damagedTargets) do
					PlaySlashHitSoundSignal:FireAll(target)
				end
			end
		end
	end)

	return Promise.resolve(true)
end

function SlashHandler.Start()
	-- Register ClientExtension signals for slash effects
	PlaySlashEffectSignal = Knit.RegisterClientSignal(CombatService, "PlaySlashEffect")
	PlaySlashHitSoundSignal = Knit.RegisterClientSignal(CombatService, "PlaySlashHitSound")

	-- Register ClientExtension method for performing slash attacks
	PerformSlashMethod = Knit.RegisterClientMethod(CombatService, "PerformSlash")
	PerformSlashMethod.OnServerInvoke = function(self, player)
		return SlashHandler:PerformSlash(player)
	end

	-- Clean up player resources when they leave
	Players.PlayerRemoving:Connect(function(player)
		cleanupPlayerSlash(player)
		SlashHandler._cooldowns[player] = nil
	end)
end

function SlashHandler.Init()
	-- Get Knit services
	CombatService = Knit.GetService("CombatService")

	-- Load settings
	local datas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
	SlashHandler._settings = require(datas:WaitForChild("Combat"):WaitForChild("SlashSettings", 10))

	-- Load utilities
	local Others = script.Parent
	DamageUtils = require(Others:WaitForChild("DamageUtils"))
	KnockbackHandler = require(Others:WaitForChild("KnockbackHandler"))

	-- Load ClientCast
	local utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
	ClientCast = require(utilities:WaitForChild("ClientCast"))
end

return SlashHandler