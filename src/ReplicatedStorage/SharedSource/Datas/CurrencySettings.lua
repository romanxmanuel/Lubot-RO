--[[

	CurrencySettings.lua

	This module defines all available currencies in the game.
	Each currency must have a unique ID and should be added to the ProfileTemplate as well.

	Currency Definition Structure:
	{
		Name = "Display Name",        -- Human-readable name shown in UI
		Id = "unique_identifier",     -- Unique string ID used in code (lowercase recommended)
		DefaultValue = 0,             -- Starting amount for new players
	}

	Usage Examples:
	- Adding a new currency: Add entry to Currencies array and update ProfileTemplate.lua
	- Currency IDs should match keys in ProfileTemplate.lua
	- Use descriptive names for better UX

	@author Froredion
	@version 1.1.0

--]]

local CurrencySettings = {
	-- Array of all available currencies in the game
	-- Add more currencies here as needed
	Currencies = {
		{
			Name = "Cash", -- Display name in UI
			Id = "cash", -- Unique identifier (must match ProfileTemplate key)
			DefaultValue = 0, -- Starting amount for new players
		},

		-- Example of additional currency:
		-- {
		--     Name = "Gems",
		--     Id = "gems",
		--     DefaultValue = 0,
		-- },

		-- {
		--     Name = "Coins",
		--     Id = "coins",
		--     DefaultValue = 100,
		-- }
	},
}

return CurrencySettings