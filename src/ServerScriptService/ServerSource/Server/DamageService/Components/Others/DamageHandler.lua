local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Knit Services
local TeamService
local DamageService

---- Pre-damage hooks
-- Registered by external components (e.g. BlockDamageIntegration).
-- Each hook is called as hook(user, target, damageInfo, damageState) and may:
--   • Modify damageState.damage
--   • Set damageState.blocked = true
--   • Return false, "reason" to cancel the damage entirely
local _preDamageHooks = {}

function module.RegisterPreDamageHook(hook)
	table.insert(_preDamageHooks, hook)
end

-- Universal damage function that can be used by any system
function module.ApplyDamage(user, target, damageInfo)
	-- damageInfo = {
	--   Damage = number,
	--   DamageType = "melee" | "ranged" | "ability" | "environment",
	--   CanDamageSelf = boolean (default: false),
	--   TeamCheck = boolean (default: true),
	--   InvincibilityCheck = boolean (default: true),
	--   OnDamage = function(user, target, damage, prevHealth, newHealth),
	--   OnKill = function(user, target, totalDamage)
	-- }

	local userHum = user:FindFirstChild("Humanoid")
	local targetHum = target:FindFirstChild("Humanoid")

	-- Basic validation
	if not targetHum or not userHum then
		return false, "Invalid characters"
	end

	if userHum.Health <= 0 then
		return false, "User is dead"
	end

	-- Invincibility check (false = bypasses invincibility)
	if damageInfo.InvincibilityCheck ~= false and target:GetAttribute("Invincible") then
		return false, "Target is invincible"
	end

	-- Self damage check
	if user == target and not (damageInfo.CanDamageSelf or false) then
		return false, "Cannot damage self"
	end

	-- Team check (if TeamService is available) (false = friendly fire enabled)
	if damageInfo.TeamCheck ~= false and TeamService then
		local userTeam = TeamService:GetTeam(user)
		local targetTeam = TeamService:GetTeam(target)

		if userTeam and targetTeam and userTeam == targetTeam then
			return false, "Same team"
		end
	end

	local prevHealth = targetHum.Health
	local damageState = {
		damage = damageInfo.Damage or 0,
		blocked = false,
	}

	-- Run pre-damage hooks (e.g. block/parry integration)
	for _, hook in ipairs(_preDamageHooks) do
		local success, reason = hook(user, target, damageInfo, damageState)
		if success == false then
			return false, reason
		end
	end

	-- Apply damage
	targetHum:TakeDamage(damageState.damage)

	-- Track damage for kill attribution
	local damagerRecorders = targetHum:FindFirstChild("DamagerRecorders")
	if not damagerRecorders then
		damagerRecorders = Instance.new("Folder")
		damagerRecorders.Name = "DamagerRecorders"
		damagerRecorders.Parent = targetHum
	end

	local numVal = damagerRecorders:FindFirstChild(user.Name)
	if not numVal then
		numVal = Instance.new("NumberValue")
		numVal.Value = damageState.damage
		numVal.Name = user.Name
		numVal.Parent = damagerRecorders

		-- Set up kill tracking
		target.Humanoid.HealthChanged:Connect(function(health)
			if health <= 0 then
				if damageInfo.OnKill then
					damageInfo.OnKill(user, target, numVal.Value)
				end
			end
		end)
	else
		numVal.Value += damageState.damage
	end

	-- Call damage callback
	if damageInfo.OnDamage then
		damageInfo.OnDamage(user, target, damageState.damage, prevHealth, targetHum.Health)
	end

	-- Handle kill
	if prevHealth > 0 and targetHum.Health <= 0 then
		-- Fire the global Killed signal
		DamageService.Killed:Fire(user, target, damageInfo)

		-- Call the optional OnKill callback
		if damageInfo.OnKill then
			damageInfo.OnKill(user, target, numVal.Value)
		end
	end

	return true, "Damage applied", damageState.blocked
end

function module.Start()
	-- Get DamageService reference after Knit starts
	DamageService = Knit.GetService("DamageService")
end

function module.Init(teamService)
	TeamService = teamService
end

return module
