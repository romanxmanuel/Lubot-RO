local ReplicatedStorage = game:GetService("ReplicatedStorage")

local module = {}

-- Cached reference (resolved once in Init)
local NormalAttack = nil

function module:TryAttack()
	if not NormalAttack then
		return
	end
	return NormalAttack:TryAttack()
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
