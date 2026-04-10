--[[
	TimeFormatter
	
	A utility module for formatting time values into human-readable strings.
	Provides various formatting options for displaying seconds as minutes, hours, days, etc.
]]

local TimeFormatter = {}

--[[
	Pads a number with leading zeros to ensure it's at least 2 digits.
	@param number number - The number to format
	@return string - The formatted number (e.g., 5 becomes "05")
]]
function TimeFormatter.PadNumber(number: number): string
	return string.format("%02i", number)
end

--[[
	Converts seconds to MM:SS format.
	@param seconds number - Total seconds to convert
	@return string - Formatted time string (e.g., "05:30")
]]
function TimeFormatter.ToMinutesSeconds(seconds: number): string
	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60

	return TimeFormatter.PadNumber(minutes) .. ":" .. TimeFormatter.PadNumber(seconds)
end

--[[
	Converts seconds to "Mm Ss" format with unit labels.
	@param seconds number - Total seconds to convert
	@return string - Formatted time string (e.g., "05m 30s")
]]
function TimeFormatter.ToMinutesSecondsLabeled(seconds: number): string
	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60

	return TimeFormatter.PadNumber(minutes) .. "m " .. TimeFormatter.PadNumber(seconds) .. "s"
end

--[[
	Converts seconds to "Dd Hh Mm Ss" format with unit labels.
	@param seconds number - Total seconds to convert
	@return string - Formatted time string (e.g., "01d 05h 30m 45s")
]]
function TimeFormatter.ToDaysHoursMinutesSeconds(seconds: number): string
	local days = math.floor(seconds / 86400)
	seconds = seconds % 86400

	local hours = math.floor(seconds / 3600)
	seconds = seconds % 3600

	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60

	return TimeFormatter.PadNumber(days)
		.. "d "
		.. TimeFormatter.PadNumber(hours)
		.. "h "
		.. TimeFormatter.PadNumber(minutes)
		.. "m "
		.. TimeFormatter.PadNumber(seconds)
		.. "s"
end

return TimeFormatter





