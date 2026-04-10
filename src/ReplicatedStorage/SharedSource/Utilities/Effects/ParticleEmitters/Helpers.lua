--[[
	Helpers
	General helper functions and configuration for ParticleEmitters
--]]

local Helpers = {}

-- Quality level storage
Helpers.QualityLevel = 10 -- Default quality level (1-10)

--[=[
	Gets all ParticleEmitters from an object
	@param object Instance -- The object to search
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
	@return {ParticleEmitter} -- Array of ParticleEmitters found
]=]
function Helpers.GetEmitters(object: Instance, includeObject: boolean?): { ParticleEmitter }
	if not object then
		warn("[ParticleEmitters] GetEmitters: Invalid object provided")
		return {}
	end

	local emitters = {}

	if includeObject and object:IsA("ParticleEmitter") then
		table.insert(emitters, object)
	end

	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			table.insert(emitters, v)
		end
	end

	return emitters
end

--[=[
	Sets the global quality level for all future effect operations
	@param level number -- Quality level from 1 (lowest) to 10 (highest)
]=]
function Helpers.SetQualityLevel(level: number)
	Helpers.QualityLevel = math.clamp(level, 1, 10)
end

--[=[
	Gets the current quality level
	@return number -- Current quality level
]=]
function Helpers.GetQualityLevel(): number
	return Helpers.QualityLevel
end

return Helpers

