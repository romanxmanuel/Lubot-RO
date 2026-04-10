local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages._Index["evaera_promise@4.0.0"]["promise"])

local module = {}

-- Cached reference (resolved once in Init)
local NormalAttack = nil

-- Public API used by CombatService
function module:PerformAttack(player)
	if not NormalAttack then
		return Promise.resolve(false)
	end
	return NormalAttack:PerformAttack(player)
end

function module.Start()
end

function module.Init()
	-- Try to load NormalAttack if it exists; vanilla combat works without it
	local Others = script.Parent:FindFirstChild("Others")
	if Others then
		local normalAttackModule = Others:FindFirstChild("NormalAttack")
		if normalAttackModule then
			NormalAttack = require(normalAttackModule)
		end
	end
end

return module
