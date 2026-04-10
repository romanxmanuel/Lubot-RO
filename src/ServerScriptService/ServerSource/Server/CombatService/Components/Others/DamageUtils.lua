local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local DamageUtils = {}

---- Knit Services
local DamageService

function DamageUtils.ApplyAreaDamage(originPos: Vector3, maxRange: number, damage: number, attackerChar: Model?, options: any?)
	local Workspace = game:GetService("Workspace")
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Humanoid") then
			local hum = descendant
			local model = hum.Parent
			if model and hum.Health > 0 and (not attackerChar or model ~= attackerChar) then
				local hrp = model:FindFirstChild("HumanoidRootPart")
				if hrp then
					local dist = (hrp.Position - originPos).Magnitude
					if dist <= maxRange then
						-- Use DamageService instead of direct TakeDamage
						DamageService:ApplyDamage(attackerChar, model, {
							Damage = damage,
							DamageType = "area",
							CanDamageSelf = false,
							TeamCheck = true,
							InvincibilityCheck = true,
							AttackSubType = options and options.AttackSubType or nil,
							Attacker = options and options.Attacker or attackerChar,
						})
					end
				end
			end
		end
	end
end

function DamageUtils.ApplyDamageToTargets(targets: { Model }, damage: number, attackerChar: Model?, options: any?)
	local damagedTargets = {}
	local blockedTargets = {}
	for _, target in ipairs(targets) do
		if target and target:IsA("Model") then
			local humanoid = target:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				-- Use DamageService instead of direct TakeDamage
				local success, message, wasBlocked = DamageService:ApplyDamage(attackerChar, target, {
					Damage = damage,
					DamageType = "melee",
					CanDamageSelf = false,
					TeamCheck = true,
					InvincibilityCheck = true,
					AttackSubType = options and options.AttackSubType or nil,
					Attacker = options and options.Attacker or attackerChar,
				})

				if success then
					table.insert(damagedTargets, target)
					if wasBlocked then
						blockedTargets[target] = true
					end
				end
			end
		end
	end
	return damagedTargets, blockedTargets
end

function DamageUtils.Init()
	---- Knit Services
	DamageService = Knit.GetService("DamageService")
end

function DamageUtils.Start() end

return DamageUtils
