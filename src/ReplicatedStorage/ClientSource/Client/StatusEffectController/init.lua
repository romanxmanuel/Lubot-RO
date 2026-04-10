local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Superbullet = require(ReplicatedStorage.Packages.Superbullet)

local StatusEffectController = Superbullet.CreateController({
	Name = "StatusEffectController",
	Instance = script, -- Automatically initializes components
})

--[[
	Returns whether the local player currently has the given status effect active.
	Delegates to the EffectVisualHandler component.
	@param effectName string — key in StatusEffectSettings (e.g. "Stun")
	@return boolean
]]
function StatusEffectController:HasEffect(effectName)
	if not self.Components or not self.Components.EffectVisualHandler then
		return false
	end
	return self.Components.EffectVisualHandler:HasEffect(effectName)
end

--[[
	Returns a list of all currently active effect names on the local player.
	Delegates to the EffectVisualHandler component.
	@return {string}
]]
function StatusEffectController:GetActiveEffects()
	if not self.Components or not self.Components.EffectVisualHandler then
		return {}
	end
	return self.Components.EffectVisualHandler:GetActiveEffects()
end

function StatusEffectController:SuperbulletStart()
end

function StatusEffectController:SuperbulletInit()
end

return StatusEffectController
