local LevelingConfig = {
	-- Level system configuration
	Types = {
		-- Main level progression system
		levels = {
			Name = "Level",
			ExpName = "EXP",
			MaxLevel = 100, -- Max level before rebirth becomes available
			MaxRebirth = 10, -- Max number of rebirths (nil = unlimited)
			RebirthType = "rebirth", -- Which rebirth type to use (set to nil to disable rebirth)
			Scaling = { Formula = "Linear" },
		},
	},

	-- Rebirth system configuration
	Rebirths = {
		enabled = true, -- Set to false to disable rebirth system
		Types = {
			rebirth = { Name = "Rebirths", ShortName = "R", ActionName = "Rebirth" },
		},
	},

	-- Scaling formula configuration
	Scaling = {
		Formulas = {
			Linear = { Base = 100, Increment = 25 },
		},
	},
}

return LevelingConfig
