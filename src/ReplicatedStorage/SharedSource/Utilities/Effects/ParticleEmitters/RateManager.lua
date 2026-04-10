--[[
	Rate Manager
	Handles particle emission rate management
--]]

local RateManager = {}

--[=[
	Sets the rate multiplier for all ParticleEmitters in an object
	@param object Instance -- The object containing emitters
	@param multiplier number -- The multiplier to apply to emission rates
]=]
function RateManager.SetRateMultiplier(object: Instance, multiplier: number)
	if not object then
		warn("[ParticleEmitters] SetRateMultiplier: Invalid object provided")
		return
	end

	multiplier = math.max(0, multiplier)

	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			local originalRate = v:GetAttribute("OriginalRate") or v.Rate
			v:SetAttribute("OriginalRate", originalRate)
			v.Rate = originalRate * multiplier
		end
	end
end

--[=[
	Resets all ParticleEmitters to their original emission rates
	@param object Instance -- The object containing emitters
]=]
function RateManager.ResetRates(object: Instance)
	if not object then
		warn("[ParticleEmitters] ResetRates: Invalid object provided")
		return
	end

	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			local originalRate = v:GetAttribute("OriginalRate")
			if originalRate then
				v.Rate = originalRate
				v:SetAttribute("OriginalRate", nil)
			end
		end
	end
end

return RateManager

