local module = {}

-- Reset damage tracking for a target
function module.ResetDamageTracking(target)
	local targetHum = target:FindFirstChild("Humanoid")
	if not targetHum then
		return
	end

	local damagerRecorders = targetHum:FindFirstChild("DamagerRecorders")
	if damagerRecorders then
		damagerRecorders:Destroy()
	end
end

function module.Start() end

function module.Init() end

return module
