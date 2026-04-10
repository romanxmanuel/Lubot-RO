local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Superbullet = require(ReplicatedStorage.Packages.Superbullet)
local Signal = require(ReplicatedStorage.Packages.Signal)

local StatusEffectService = Superbullet.CreateService({
	Name = "StatusEffectService",
	Instance = script,
	Client = {
		EffectApplied = Superbullet.CreateSignal(),
		EffectRemoved = Superbullet.CreateSignal(),
	},
})

---- Server-side Signals (for inter-service communication)
StatusEffectService.OnEffectApplied = Signal.new()
StatusEffectService.OnEffectRemoved = Signal.new()

--[[
	Applies a status effect to the given character.
	@param character Model — the target character (player or NPC)
	@param effectName string — key in StatusEffectSettings (e.g. "Stun")
	@param durationOverride number? — optional override for the default duration
]]
function StatusEffectService:ApplyEffect(character, effectName, durationOverride)
	self.Components.EffectHandler:ApplyEffect(character, effectName, durationOverride)
end

--[[
	Manually removes a status effect from the given character.
	Performs cleanup (CombatState, WalkSpeed) and fires removal signals.
	@param character Model — the target character
	@param effectName string — key in StatusEffectSettings
]]
function StatusEffectService:RemoveEffect(character, effectName)
	self.Components.EffectHandler:RemoveEffect(character, effectName)
end

--[[
	Checks whether the character currently has the given status effect.
	@param character Model
	@param effectName string
	@return boolean
]]
function StatusEffectService:HasEffect(character, effectName)
	return self.Components.EffectHandler:HasEffect(character, effectName)
end

--[[
	Returns a table of all active effect names on the character.
	@param character Model
	@return {string: true}
]]
function StatusEffectService:GetActiveEffects(character)
	return self.Components.EffectHandler:GetActiveEffects(character)
end

function StatusEffectService:SuperbulletStart()
end

function StatusEffectService:SuperbulletInit()
end

return StatusEffectService
