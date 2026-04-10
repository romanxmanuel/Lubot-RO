--[[
	Emitter Operations
	Handles emit-based particle effects (PlayEmit, CloneEffect, PlaySequence)
--]]

local Emitter = {}

-- Reference to Core module (will be set by init.lua)
Emitter.Core = nil

-- Reference to quality level (will be set by init.lua)
Emitter.GetQualityLevel = nil

--[=[
	Plays a one-shot emit effect on all ParticleEmitters with EmitCount attribute
	@param effect Instance -- The effect object containing ParticleEmitters
	@param bypassQualityLevel boolean? -- If true, ignores quality scaling
	@param customQualityLevel number? -- Custom quality level override (1-10)
]=]
function Emitter.PlayEmit(effect: Instance, bypassQualityLevel: boolean?, customQualityLevel: number?)
	if not effect then
		warn("[ParticleEmitters] PlayEmit: Invalid effect provided")
		return
	end

	local qualityLevel = customQualityLevel or Emitter.GetQualityLevel()

	for _, v in pairs(effect:GetDescendants()) do
		if not v:IsA("ParticleEmitter") then
			continue
		end

		local emitCount = v:GetAttribute("EmitCount")
		if not emitCount then
			-- If no EmitCount, skip this emitter
			continue
		end

		local toEmit = emitCount
		if not bypassQualityLevel then
			-- Scale emit count based on quality level
			toEmit = math.max(1, math.floor(emitCount * (qualityLevel / 10)))
		end

		local emitDelay = v:GetAttribute("EmitDelay") or 0
		if emitDelay == 0 then
			v:Emit(toEmit)
		else
			task.delay(emitDelay, function()
				if v and v.Parent then
					v:Emit(toEmit)
				end
			end)
		end
	end
end

--[=[
	Clones an effect and parents it to a target location
	@param effect Instance -- The effect to clone
	@param parent Instance -- The parent for the cloned effect
	@param autoPlay boolean? -- If true, automatically plays the effect
	@param autoCleanup boolean? -- If true, automatically destroys after playing
	@return Instance? -- The cloned effect, or nil if failed
]=]
function Emitter.CloneEffect(effect: Instance, parent: Instance, autoPlay: boolean?, autoCleanup: boolean?)
	if not effect or not parent then
		warn("[ParticleEmitters] CloneEffect: Invalid effect or parent provided")
		return nil
	end

	local clonedEffect = effect:Clone()
	clonedEffect.Parent = parent

	if autoPlay then
		-- Check if it's an emit-based effect
		local hasEmitCount = false
		for _, v in pairs(clonedEffect:GetDescendants()) do
			if v:IsA("ParticleEmitter") and v:GetAttribute("EmitCount") then
				hasEmitCount = true
				break
			end
		end

		if hasEmitCount then
			Emitter.PlayEmit(clonedEffect)

			if autoCleanup then
				-- Calculate max lifetime for cleanup
				local maxLifetime = 0
				for _, v in pairs(clonedEffect:GetDescendants()) do
					if v:IsA("ParticleEmitter") then
						local emitDelay = v:GetAttribute("EmitDelay") or 0
						local totalTime = v.Lifetime.Max + emitDelay + 2
						maxLifetime = math.max(maxLifetime, totalTime)
					end
				end

				task.delay(maxLifetime, function()
					if clonedEffect and clonedEffect.Parent then
						clonedEffect:Destroy()
					end
				end)
			end
		else
			-- Continuous effect
			if Emitter.Core then
				Emitter.Core.EnableDescendants(clonedEffect, autoCleanup, true)
			end
		end
	end

	return clonedEffect
end

--[=[
	Plays multiple effects in sequence with delays
	@param effects table -- Array of effect instances
	@param delays table? -- Array of delays between effects (in seconds)
	@param parent Instance? -- Optional parent for cloned effects
]=]
function Emitter.PlaySequence(effects: { Instance }, delays: { number }?, parent: Instance?)
	if not effects or #effects == 0 then
		warn("[ParticleEmitters] PlaySequence: No effects provided")
		return
	end

	delays = delays or {}

	task.spawn(function()
		for i, effect in ipairs(effects) do
			local delay = delays[i] or 0
			if delay > 0 then
				task.wait(delay)
			end

			if parent then
				Emitter.CloneEffect(effect, parent, true, true)
			else
				Emitter.PlayEmit(effect)
			end
		end
	end)
end

return Emitter
