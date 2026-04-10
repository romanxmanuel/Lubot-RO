--[[
Formats a numeric value with thousands separators (commas).

- Preserves sign and fractional/decimal part (e.g., "-12,345.67").
- Uses standard US-style grouping: 1,234,567.89.

Parameters:
- n (number | string): Numeric value to format. If a string, it must match the
  pattern ^%-?%d+%.?%d*$ (optional leading minus, digits, optional decimal part).

Returns:
- string: The formatted number string with commas.

Examples:
AddCommasToNumbers(1234567)         --> "1,234,567"
AddCommasToNumbers(-9876543.21)     --> "-9,876,543.21"
AddCommasToNumbers("1000000")       --> "1,000,000"
]]
---@param n number|string
---@return string
local function AddCommasToNumbers(n)
	-- Convert number to string.
	local s = tostring(n)

	-- Split the string into integer and fractional parts.
	-- This pattern captures an optional minus sign, one or more digits for the integer part,
	-- and then the decimal part (if any).
	local integerPart, fractionalPart = s:match("^(%-?%d+)(%.?%d*)$")

	-- Reverse the integer part and insert commas every three digits.
	integerPart = integerPart:reverse():gsub("(%d%d%d)", "%1,"):reverse()

	-- Remove a comma at the beginning if it exists.
	if integerPart:sub(1, 1) == "," then
		integerPart = integerPart:sub(2)
	end

	-- Combine the integer part with the fractional part.
	return integerPart .. fractionalPart
end

return AddCommasToNumbers
