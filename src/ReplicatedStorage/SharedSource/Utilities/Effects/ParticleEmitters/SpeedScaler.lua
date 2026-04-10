--[[
	Speed Scaler
	Handles particle speed scaling operations with NumberRange encoding/decoding
--]]

local SpeedScaler = {}

--[=[
	Encodes a NumberRange into a string format (for storing original values)
	@param numberRange NumberRange -- The NumberRange to encode
	@return string -- Encoded string representation
]=]
local function encodeNumberRange(numberRange: NumberRange): string
	return string.format("%f,%f", numberRange.Min, numberRange.Max)
end

--[=[
	Decodes a string back into a NumberRange
	@param encoded string -- The encoded string representation
	@return NumberRange? -- Decoded NumberRange, or nil if invalid
]=]
local function decodeNumberRange(encoded: string): NumberRange?
	if not encoded or encoded == "" then
		return nil
	end
	
	local values = string.split(encoded, ",")
	if #values >= 2 then
		local min = tonumber(values[1]) or 0
		local max = tonumber(values[2]) or 0
		return NumberRange.new(min, max)
	end
	
	return nil
end

--[=[
	Scales a NumberRange by a multiplier
	@param numberRange NumberRange -- The original NumberRange
	@param scale number -- The scale multiplier
	@return NumberRange -- Scaled NumberRange
]=]
local function scaleNumberRange(numberRange: NumberRange, scale: number): NumberRange
	return NumberRange.new(numberRange.Min * scale, numberRange.Max * scale)
end

--[=[
	Saves original particle emitter Speed properties for later restoration/scaling
	Stores the original NumberRange as a StringValue attribute
	@param object Instance -- The object containing particle emitters
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
]=]
function SpeedScaler.SaveOriginalSpeeds(object: Instance, includeObject: boolean?)
	if not object then
		warn("[ParticleEmitters] SaveOriginalSpeeds: Invalid object provided")
		return
	end
	
	-- Check the object itself if requested
	if includeObject and object:IsA("ParticleEmitter") then
		if not object:GetAttribute("OriginalSpeed") then
			object:SetAttribute("OriginalSpeed", encodeNumberRange(object.Speed))
		end
	end
	
	-- Process all descendants
	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			if not v:GetAttribute("OriginalSpeed") then
				v:SetAttribute("OriginalSpeed", encodeNumberRange(v.Speed))
			end
		end
	end
end

--[=[
	Scales all particle emitter Speed properties by a multiplier
	Automatically saves original speeds if not already saved
	@param object Instance -- The object containing particle emitters
	@param scale number -- The scale multiplier (e.g., 0.5 = half speed, 2.0 = double speed)
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
]=]
function SpeedScaler.ScaleSpeeds(object: Instance, scale: number, includeObject: boolean?)
	if not object then
		warn("[ParticleEmitters] ScaleSpeeds: Invalid object provided")
		return
	end
	
	scale = math.max(0.01, scale) -- Prevent zero/negative scales
	
	-- Save original speeds first (if not already saved)
	SpeedScaler.SaveOriginalSpeeds(object, includeObject)
	
	-- Check the object itself if requested
	if includeObject and object:IsA("ParticleEmitter") then
		local originalEncoded = object:GetAttribute("OriginalSpeed")
		if originalEncoded then
			local originalSpeed = decodeNumberRange(originalEncoded)
			if originalSpeed then
				object.Speed = scaleNumberRange(originalSpeed, scale)
			end
		end
	end
	
	-- Process all descendants
	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			local originalEncoded = v:GetAttribute("OriginalSpeed")
			if originalEncoded then
				local originalSpeed = decodeNumberRange(originalEncoded)
				if originalSpeed then
					v.Speed = scaleNumberRange(originalSpeed, scale)
				end
			end
		end
	end
end

--[=[
	Resets all particle emitter Speed properties to their original values
	@param object Instance -- The object containing particle emitters
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
]=]
function SpeedScaler.ResetSpeeds(object: Instance, includeObject: boolean?)
	if not object then
		warn("[ParticleEmitters] ResetSpeeds: Invalid object provided")
		return
	end
	
	-- Check the object itself if requested
	if includeObject and object:IsA("ParticleEmitter") then
		local originalEncoded = object:GetAttribute("OriginalSpeed")
		if originalEncoded then
			local originalSpeed = decodeNumberRange(originalEncoded)
			if originalSpeed then
				object.Speed = originalSpeed
			end
			object:SetAttribute("OriginalSpeed", nil)
		end
	end
	
	-- Process all descendants
	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			local originalEncoded = v:GetAttribute("OriginalSpeed")
			if originalEncoded then
				local originalSpeed = decodeNumberRange(originalEncoded)
				if originalSpeed then
					v.Speed = originalSpeed
				end
				v:SetAttribute("OriginalSpeed", nil)
			end
		end
	end
end

return SpeedScaler

