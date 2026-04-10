--[[
	Size Scaler
	Handles particle size scaling operations with NumberSequence encoding/decoding
--]]

local SizeScaler = {}

--[=[
	Encodes a NumberSequence into a string format (for storing original values)
	@param numberSequence NumberSequence -- The NumberSequence to encode
	@return string -- Encoded string representation
]=]
local function encodeNumberSequence(numberSequence: NumberSequence): string
	local keypoints = numberSequence.Keypoints
	local encoded = {}

	for _, keypoint in ipairs(keypoints) do
		table.insert(encoded, string.format("%f,%f,%f", keypoint.Time, keypoint.Value, keypoint.Envelope))
	end

	return table.concat(encoded, ";")
end

--[=[
	Decodes a string back into a NumberSequence
	@param encoded string -- The encoded string representation
	@return NumberSequence? -- Decoded NumberSequence, or nil if invalid
]=]
local function decodeNumberSequence(encoded: string): NumberSequence?
	if not encoded or encoded == "" then
		return nil
	end

	local keypoints = {}
	local keypointStrings = string.split(encoded, ";")

	for _, keypointStr in ipairs(keypointStrings) do
		local values = string.split(keypointStr, ",")
		if #values >= 2 then
			local time = tonumber(values[1]) or 0
			local value = tonumber(values[2]) or 0
			local envelope = tonumber(values[3]) or 0
			table.insert(keypoints, NumberSequenceKeypoint.new(time, value, envelope))
		end
	end

	if #keypoints > 0 then
		return NumberSequence.new(keypoints)
	end

	return nil
end

--[=[
	Scales a NumberSequence by a multiplier
	@param numberSequence NumberSequence -- The original NumberSequence
	@param scale number -- The scale multiplier
	@return NumberSequence -- Scaled NumberSequence
]=]
local function scaleNumberSequence(numberSequence: NumberSequence, scale: number): NumberSequence
	local keypoints = numberSequence.Keypoints
	local scaledKeypoints = {}

	for _, keypoint in ipairs(keypoints) do
		table.insert(
			scaledKeypoints,
			NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale)
		)
	end

	return NumberSequence.new(scaledKeypoints)
end

--[=[
	Saves original particle emitter Size properties for later restoration/scaling
	Stores the original NumberSequence as a StringValue attribute
	@param object Instance -- The object containing particle emitters
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
]=]
function SizeScaler.SaveOriginalSizes(object: Instance, includeObject: boolean?)
	if not object then
		warn("[ParticleEmitters] SaveOriginalSizes: Invalid object provided")
		return
	end

	-- Check the object itself if requested
	if includeObject and object:IsA("ParticleEmitter") then
		if not object:GetAttribute("OriginalSize") then
			object:SetAttribute("OriginalSize", encodeNumberSequence(object.Size))
		end
	end

	-- Process all descendants
	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			if not v:GetAttribute("OriginalSize") then
				v:SetAttribute("OriginalSize", encodeNumberSequence(v.Size))
			end
		end
	end
end

--[=[
	Scales all particle emitter Size properties by a multiplier
	Automatically saves original sizes if not already saved
	@param object Instance -- The object containing particle emitters
	@param scale number -- The scale multiplier (e.g., 0.5 = half size, 2.0 = double size)
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
]=]
function SizeScaler.ScaleSizes(object: Instance, scale: number, includeObject: boolean?)
	if not object then
		warn("[ParticleEmitters] ScaleSizes: Invalid object provided")
		return
	end

	scale = math.max(0.01, scale) -- Prevent zero/negative scales

	-- Save original sizes first (if not already saved)
	SizeScaler.SaveOriginalSizes(object, includeObject)

	-- Check the object itself if requested
	if includeObject and object:IsA("ParticleEmitter") then
		local originalEncoded = object:GetAttribute("OriginalSize")
		if originalEncoded then
			local originalSize = decodeNumberSequence(originalEncoded)
			if originalSize then
				object.Size = scaleNumberSequence(originalSize, scale)
			end
		end
	end

	-- Process all descendants
	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			local originalEncoded = v:GetAttribute("OriginalSize")
			if originalEncoded then
				local originalSize = decodeNumberSequence(originalEncoded)
				if originalSize then
					v.Size = scaleNumberSequence(originalSize, scale)
				end
			end
		end
	end
end

--[=[
	Resets all particle emitter Size properties to their original values
	@param object Instance -- The object containing particle emitters
	@param includeObject boolean? -- If true, includes the object itself if it's an emitter
]=]
function SizeScaler.ResetSizes(object: Instance, includeObject: boolean?)
	if not object then
		warn("[ParticleEmitters] ResetSizes: Invalid object provided")
		return
	end

	-- Check the object itself if requested
	if includeObject and object:IsA("ParticleEmitter") then
		local originalEncoded = object:GetAttribute("OriginalSize")
		if originalEncoded then
			local originalSize = decodeNumberSequence(originalEncoded)
			if originalSize then
				object.Size = originalSize
			end
			object:SetAttribute("OriginalSize", nil)
		end
	end

	-- Process all descendants
	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			local originalEncoded = v:GetAttribute("OriginalSize")
			if originalEncoded then
				local originalSize = decodeNumberSequence(originalEncoded)
				if originalSize then
					v.Size = originalSize
				end
				v:SetAttribute("OriginalSize", nil)
			end
		end
	end
end

return SizeScaler
