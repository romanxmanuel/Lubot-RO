local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Utilities
local GetBaseMaxExp = require(script.Parent.GetBaseMaxExp)

---- Datas
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

local BuildProfileTemplate = {}

-- Automatically builds the Leveling section of ProfileTemplate from LevelingConfig
-- This ensures Types and Rebirths are always in sync with the config
function BuildProfileTemplate.GenerateLevelingData()
	local types = {}
	local rebirths = {}
	
	-- Auto-generate Types and Rebirths from LevelingConfig
	if LevelingConfig.Types then
		for levelType, _ in pairs(LevelingConfig.Types) do
			-- Calculate correct base MaxExp using formula
			local baseMaxExp = GetBaseMaxExp.ForType(levelType)
			
			-- Initialize type data
			types[levelType] = {
				Exp = 0,
				Level = 1,
				MaxExp = baseMaxExp,
			}
			
			-- Initialize rebirth counter
			rebirths[levelType] = 0
		end
	end
	
	return {
		Types = types,
		Rebirths = rebirths,
	}
end

return BuildProfileTemplate
