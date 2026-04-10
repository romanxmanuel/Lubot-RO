--[[
	Scaler
	Combined scaling operations that use SizeScaler and SpeedScaler
--]]

local Scaler = {}

-- References to other modules (will be set by init.lua)
Scaler.SizeScaler = nil
Scaler.SpeedScaler = nil

--[=[
	Scales both Size and Speed properties of particle emitters by a multiplier
	Convenience function that calls ScaleSizes and ScaleSpeeds
	@param object Instance -- The object containing particle emitters
	@param scale number -- The scale multiplier
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
]=]
function Scaler.ScaleParticles(object: Instance, scale: number, includeObject: boolean?)
	if Scaler.SizeScaler then
		Scaler.SizeScaler.ScaleSizes(object, scale, includeObject)
	end
	if Scaler.SpeedScaler then
		Scaler.SpeedScaler.ScaleSpeeds(object, scale, includeObject)
	end
end

--[=[
	Resets both Size and Speed properties of particle emitters to original values
	Convenience function that calls ResetSizes and ResetSpeeds
	@param object Instance -- The object containing particle emitters
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
]=]
function Scaler.ResetParticles(object: Instance, includeObject: boolean?)
	if Scaler.SizeScaler then
		Scaler.SizeScaler.ResetSizes(object, includeObject)
	end
	if Scaler.SpeedScaler then
		Scaler.SpeedScaler.ResetSpeeds(object, includeObject)
	end
end

return Scaler

