--[[
	AddExternalTypes
	
	Helper utility to add external entity configs (pets, weapons, skills, etc.)
	to LevelingConfig.Types dynamically.
	
	Usage:
		local AddExternalTypes = require(ReplicatedStorage.SharedSource.Utilities.Levels.AddExternalTypes)
		local PetConfig = require(ReplicatedStorage.SharedSource.Datas.PetConfig)
		
		AddExternalTypes(LevelingConfig, PetConfig, "_level")
]]

local AddExternalTypes = {}

--[[
	Adds external entity configs to LevelingConfig.Types
	
	@param levelingConfig - The LevelingConfig table to modify
	@param externalConfig - External config table (e.g., PetConfig, WeaponConfig)
	@param typeSuffix - Optional suffix for type keys (default: "_level")
	
	Example externalConfig structure:
	{
		dragon = {
			LevelName = "Dragon Level",
			ExpName = "Dragon EXP",
			MaxLevel = 100,
			MaxRebirth = nil,
			RebirthType = nil,
			Scaling = { Formula = "Exponential", Base = 100, Factor = 1.3 }
		},
		cat = { ... }
	}
	
	This will create type keys like "dragon_level", "cat_level", etc.
]]
function AddExternalTypes.Add(levelingConfig, externalConfig, typeSuffix)
	if not levelingConfig or not levelingConfig.Types then
		warn("[AddExternalTypes] Invalid LevelingConfig provided")
		return
	end

	if not externalConfig or type(externalConfig) ~= "table" then
		warn("[AddExternalTypes] Invalid externalConfig provided")
		return
	end

	typeSuffix = typeSuffix or "_level"

	local addedCount = 0
	for entityID, entityData in pairs(externalConfig) do
		if type(entityData) == "table" then
			local typeKey = entityID .. typeSuffix

			levelingConfig.Types[typeKey] = {
				Name = entityData.LevelName or "Level",
				ExpName = entityData.ExpName or "EXP",
				MaxLevel = entityData.MaxLevel,
				MaxRebirth = entityData.MaxRebirth,
				RebirthType = entityData.RebirthType,
				Scaling = entityData.Scaling or { Formula = "Linear" },
			}

			addedCount += 1
		end
	end

	if addedCount > 0 then
		print(string.format("[AddExternalTypes] Added %d types with suffix '%s'", addedCount, typeSuffix))
	end
end

return AddExternalTypes
