local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Utilities
local GetBaseMaxExp = require(script.Parent.GetBaseMaxExp)

---- Datas
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

local ProfileSeeder = {}

-- Ensures a player's profile has all configured level types with correct initial values
-- Call this during profile initialization or when adding new level types to the config
-- Returns: table of seeded types (newly added or corrected types)
function ProfileSeeder.EnsureAllTypesExist(levelingData)
	if not levelingData then
		warn("[ProfileSeeder] No Leveling data provided")
		return {}
	end
	
	-- Ensure Types and Rebirths tables exist
	levelingData.Types = levelingData.Types or {}
	levelingData.Rebirths = levelingData.Rebirths or {}
	
	local seededTypes = {}
	
	-- Iterate through all configured level types
	if LevelingConfig.Types then
		for levelType, _ in pairs(LevelingConfig.Types) do
			local wasSeeded = false
			
			-- Ensure the type exists in Types table
			if not levelingData.Types[levelType] then
				local baseMaxExp = GetBaseMaxExp.ForType(levelType)
				levelingData.Types[levelType] = {
					Exp = 0,
					Level = 1,
					MaxExp = baseMaxExp,
				}
				wasSeeded = true
			else
				-- Type exists, but verify MaxExp matches formula for Level 1
				local currentType = levelingData.Types[levelType]
				if currentType.Level == 1 then
					local correctMaxExp = GetBaseMaxExp.ForType(levelType)
					if currentType.MaxExp ~= correctMaxExp then
						warn(string.format(
							"[ProfileSeeder] Correcting MaxExp for %s: %d -> %d",
							levelType,
							currentType.MaxExp,
							correctMaxExp
						))
						currentType.MaxExp = correctMaxExp
						wasSeeded = true
					end
				end
			end
			
			-- Ensure rebirth counter exists
			if levelingData.Rebirths[levelType] == nil then
				levelingData.Rebirths[levelType] = 0
				wasSeeded = true
			end
			
			if wasSeeded then
				table.insert(seededTypes, levelType)
			end
		end
	end
	
	return seededTypes
end

-- Validates that a specific level type has correct base MaxExp for Level 1
-- Returns: true if valid, false if corrected
function ProfileSeeder.ValidateTypeMaxExp(levelingData, levelType)
	if not levelingData or not levelingData.Types then
		return false
	end
	
	local typeData = levelingData.Types[levelType]
	if not typeData or typeData.Level ~= 1 then
		return true -- Not at Level 1, so base MaxExp doesn't apply
	end
	
	local correctMaxExp = GetBaseMaxExp.ForType(levelType)
	if typeData.MaxExp == correctMaxExp then
		return true -- Already correct
	end
	
	-- Correct the MaxExp
	warn(string.format(
		"[ProfileSeeder] Correcting MaxExp for %s: %d -> %d",
		levelType,
		typeData.MaxExp,
		correctMaxExp
	))
	typeData.MaxExp = correctMaxExp
	return false
end

-- Gets default values for a new level type
-- Returns: { Exp, Level, MaxExp } table
function ProfileSeeder.GetDefaultTypeData(levelType)
	local baseMaxExp = GetBaseMaxExp.ForType(levelType)
	return {
		Exp = 0,
		Level = 1,
		MaxExp = baseMaxExp,
	}
end

return ProfileSeeder
