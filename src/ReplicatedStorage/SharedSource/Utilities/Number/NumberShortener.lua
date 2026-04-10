--[[
Shortens numbers with abbreviations (K, M, B, T, etc.) for better readability.

This module provides three shortening functions:
- shorten: Shortens without decimals (e.g., "1K", "2M")
- shortenWith2Decimals: Shortens with up to 2 decimal places when needed (e.g., "1.5K", "2.34M")
- shortenWith3Decimals: Shortens with up to 3 decimal places when needed (e.g., "1.234K", "2.345M")

Supported abbreviations (in descending order):
- Sxd (1e51), Qid (1e48), Qd (1e45), Td (1e42), Dd (1e39), Ud (1e36), Dc (1e33)
- N (1e30), Oc (1e27), Sp (1e24), Sx (1e21), Qi (1e18), Qa (1e15)
- T (1e12), B (1e9), M (1e6), K (1e3)

Examples:
NumberShortener.shorten(1500)              --> "1K"
NumberShortener.shortenWith2Decimals(1500) --> "1.5K"
NumberShortener.shortenWith3Decimals(1234) --> "1.234K"
NumberShortener.shorten(999)               --> "999"
]]

local NumberShortener = {}

-- Abbreviation mappings: {threshold, suffix}
-- Ordered from largest to smallest for efficient iteration
local abbreviations = {
	{ 1e51, "Sxd" },
	{ 1e48, "Qid" },
	{ 1e45, "Qd" },
	{ 1e42, "Td" },
	{ 1e39, "Dd" },
	{ 1e36, "Ud" },
	{ 1e33, "Dc" },
	{ 1e30, "N" },
	{ 1e27, "Oc" },
	{ 1e24, "Sp" },
	{ 1e21, "Sx" },
	{ 1e18, "Qi" },
	{ 1e15, "Qa" },
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

--[[
Shortens a number with abbreviations, without decimal places.

Parameters:
- number (number | nil): The number to shorten. If nil, defaults to 0.

Returns:
- string: The shortened number string (e.g., "1K", "2M", "999").

Examples:
shorten(1500)     --> "1K"
shorten(2000000)  --> "2M"
shorten(999)      --> "999"
]]
---@param number number|nil
---@return string
function NumberShortener.shorten(number)
	if not number then
		number = 0
	end

	number = tonumber(number)
	if not number then
		return "0"
	end

	for _, abbrev in ipairs(abbreviations) do
		local factor, suffix = abbrev[1], abbrev[2]
		if number >= factor then
			local formattedNumber = number / factor
			return string.format("%d%s", formattedNumber, suffix)
		end
	end

	return tostring(number)
end

--[[
Shortens a number with abbreviations, including up to 2 decimal places when needed.

Parameters:
- number (number | nil): The number to shorten. If nil, defaults to 0.

Returns:
- string: The shortened number string with decimals when needed (e.g., "1.5K", "2.34M", "999").

Examples:
shortenWith2Decimals(1500)    --> "1.5K"
shortenWith2Decimals(2340000) --> "2.34M"
shortenWith2Decimals(2000)    --> "2K"
]]
---@param number number|nil
---@return string
function NumberShortener.shortenWith2Decimals(number)
	if not number then
		number = 0
	end

	number = tonumber(number)
	if not number then
		return "0"
	end

	for _, abbrev in ipairs(abbreviations) do
		local factor, suffix = abbrev[1], abbrev[2]
		if number >= factor then
			local formattedNumber = number / factor
			if formattedNumber % 1 == 0 then
				return string.format("%d%s", formattedNumber, suffix)
			else
				return string.format("%.2f%s", formattedNumber, suffix)
			end
		end
	end

	return tostring(number)
end

--[[
Shortens a number with abbreviations, including up to 3 decimal places when needed.

Parameters:
- number (number | nil): The number to shorten. If nil, defaults to 0.

Returns:
- string: The shortened number string with decimals when needed (e.g., "1.234K", "2.345M", "999").

Examples:
shortenWith3Decimals(1234)    --> "1.234K"
shortenWith3Decimals(2345000) --> "2.345M"
shortenWith3Decimals(2000)    --> "2K"
]]
---@param number number|nil
---@return string
function NumberShortener.shortenWith3Decimals(number)
	if not number then
		number = 0
	end

	number = tonumber(number)
	if not number then
		return "0"
	end

	for _, abbrev in ipairs(abbreviations) do
		local factor, suffix = abbrev[1], abbrev[2]
		if number >= factor then
			local formattedNumber = number / factor
			if formattedNumber % 1 == 0 then
				return string.format("%d%s", formattedNumber, suffix)
			else
				return string.format("%.3f%s", formattedNumber, suffix)
			end
		end
	end

	return tostring(number)
end

return NumberShortener
