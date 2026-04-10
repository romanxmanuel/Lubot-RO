--[[
    DialogueSettings.lua

    Configuration for the dialogue system.
    All values here are constants and should not be modified at runtime.
]]

local DialogueSettings = {

	--========================================
	-- TYPEWRITER SOUND SETTINGS
	--========================================

	TypewriterSound = {
		-- Enable/disable typewriter sound
		Enabled = true,

		-- Play sound every N characters
		-- Set to 1 to play on every character
		-- Set to 2 to play every 2 characters (recommended)
		CharacterInterval = 2,

		-- Sound path in ReplicatedStorage
		-- Default: "Assets.Sounds.Dialogue"
		SoundPath = "Assets.Sounds.Dialogue",

		-- Default pitch if not specified in dialogue config
		DefaultPitch = 1.0,

		-- Default volume
		DefaultVolume = 0.5,
	},

	--========================================
	-- DIALOGUE UI SETTINGS
	--========================================

	UI = {
		-- Default display order for DialogueKit ScreenGui
		DefaultDisplayOrder = 10,

		-- Default tween time
		DefaultTweenTime = 0.5,
	},
}

-- Make the table read-only to prevent accidental modifications
local function makeReadOnly(tbl, name)
	return setmetatable({}, {
		__index = tbl,
		__newindex = function()
			error("Attempted to modify read-only DialogueSettings." .. (name or ""), 2)
		end,
		__metatable = false,
	})
end

-- Apply read-only protection recursively
local function deepReadOnly(tbl, name)
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			tbl[key] = deepReadOnly(value, (name or "") .. "." .. tostring(key))
		end
	end
	return makeReadOnly(tbl, name)
end

return deepReadOnly(DialogueSettings)
