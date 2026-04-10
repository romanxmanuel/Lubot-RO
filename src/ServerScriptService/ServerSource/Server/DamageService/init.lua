local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local DamageService = Knit.CreateService({
	Name = "DamageService",
	Client = {
		ApplyDamage = Knit.CreateSignal(),
	},
	Instance = script,

	-- Signal fired when a character is killed
	-- Args: (killer: Model, victim: Model, damageInfo: table)
	Killed = Signal.new(),
})

---- Component Handlers

---- Knit Services

-- Expose ApplyDamage method through the service

function DamageService:ApplyDamage(user, target, damageInfo)
	--[[
		Applies damage from user to target according to damageInfo parameters.

		Returns:
			(success: boolean, message: string)
			If successful, success is true and message is "Damage applied".
			If not successful, success is false and message describes the failure reason.
	]]

	return DamageService.Components.DamageHandler.ApplyDamage(user, target, damageInfo)
end

-- Client API for applying damage
-- PS: Do not expose this to client. Use :ApplyDamage() on the server instead.
-- Example: In Skill Systems, damage must be handled server-side to prevent exploits.

-- Expose GetDamageDealt method through the service
-- Utility function to get total damage dealt by a user to a target
-- Returns nil if user has not damaged target, otherwise returns the damage amount
function DamageService:GetDamageDealt(user, target)
	return DamageService.GetComponent.GetDamageDealt(user, target)
end

-- Expose GetAllDamagers method through the service
-- Returns a dictionary of all characters that damaged the target and their damage dealt
-- Format: { [characterModel] = damageDealt }
function DamageService:GetAllDamagers(target)
	return DamageService.GetComponent.GetAllDamagers(target)
end

-- Expose ResetDamageTracking method through the service
-- Reset damage tracking for a target
function DamageService:ResetDamageTracking(target)
	return DamageService.SetComponent.ResetDamageTracking(target)
end

function DamageService:KnitStart()
	-- TESTER: Damage Workspace.Rig every 5 seconds with 5 damage
	-- task.spawn(function()
	-- 	while true do
	-- 		task.wait(5)
	-- 		local rig = workspace:WaitForChild("Rig", 1)
	-- 		local tester = Players:GetPlayers()[1].Character
	-- 		print(tester)
	-- 		if rig and tester then
	-- 			local result, resp = DamageService:ApplyDamage(tester, rig, {
	-- 				Damage = 5,
	-- 				DamageType = "tester",
	-- 				CanDamageSelf = true,
	-- 				TeamCheck = false,
	-- 				InvincibilityCheck = false,
	-- 			})

	-- 			print(result, resp)
	-- 		end
	-- 	end
	-- end)
end

function DamageService:KnitInit() end

return DamageService
