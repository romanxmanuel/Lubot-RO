local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

local RebirthHelpers = {}

--- Get the rebirth type for a given level type
-- @param levelType string - The level type (e.g., "levels", "ranks")
-- @return string|nil - The rebirth type (e.g., "rebirth", "ascension") or nil if not found
function RebirthHelpers.GetRebirthType(levelType)
	if not LevelingConfig.Rebirths or not LevelingConfig.Rebirths.enabled then
		return nil
	end
	-- Read rebirth type directly from the level type config
	local typeConfig = LevelingConfig.Types and LevelingConfig.Types[levelType]
	if not typeConfig then
		return nil
	end
	return typeConfig.RebirthType
end

--- Get the rebirth configuration for a given level type
-- @param levelType string - The level type (e.g., "levels", "ranks")
-- @return table|nil - The rebirth configuration or nil if not found
function RebirthHelpers.GetRebirthConfig(levelType)
	local rebirthType = RebirthHelpers.GetRebirthType(levelType)
	if not rebirthType then
		return nil
	end
	return LevelingConfig.Rebirths.Types[rebirthType]
end

--- Get the action name for a rebirth button (e.g., "REBIRTH", "ASCEND")
-- @param levelType string - The level type (e.g., "levels", "ranks")
-- @return string - The action name in uppercase (defaults to "REBIRTH")
function RebirthHelpers.GetRebirthActionName(levelType)
	local rebirthConfig = RebirthHelpers.GetRebirthConfig(levelType)
	if not rebirthConfig then
		return "REBIRTH"
	end
	return (rebirthConfig.ActionName or "REBIRTH"):upper()
end

--- Get the full button text with star emoji for a rebirth button
-- @param levelType string - The level type (e.g., "levels", "ranks")
-- @return string - The button text (e.g., "⭐ REBIRTH", "⭐ ASCEND")
function RebirthHelpers.GetRebirthButtonText(levelType)
	local actionName = RebirthHelpers.GetRebirthActionName(levelType)
	return "⭐ " .. actionName
end

--- Get the display name for the rebirth type (e.g., "Rebirths", "Ascensions")
-- @param levelType string - The level type (e.g., "levels", "ranks")
-- @return string - The display name or empty string if not found
function RebirthHelpers.GetRebirthDisplayName(levelType)
	local rebirthConfig = RebirthHelpers.GetRebirthConfig(levelType)
	if not rebirthConfig then
		return ""
	end
	return rebirthConfig.Name or ""
end

--- Get the short name for the rebirth type (e.g., "R", "A")
-- @param levelType string - The level type (e.g., "levels", "ranks")
-- @return string - The short name or empty string if not found
function RebirthHelpers.GetRebirthShortName(levelType)
	local rebirthConfig = RebirthHelpers.GetRebirthConfig(levelType)
	if not rebirthConfig then
		return ""
	end
	return rebirthConfig.ShortName or ""
end

--- Check if rebirth is enabled for a specific level type
-- @param levelType string - The level type (e.g., "levels", "ranks")
-- @return boolean - True if rebirth is enabled for this level type, false otherwise
function RebirthHelpers.IsRebirthEnabled(levelType)
	-- Check if rebirths are enabled globally
	if not LevelingConfig.Rebirths or not LevelingConfig.Rebirths.enabled then
		return false
	end

	-- Check if this specific level type has rebirth enabled
	local typeConfig = LevelingConfig.Types and LevelingConfig.Types[levelType]
	if not typeConfig or not typeConfig.RebirthType then
		return false
	end

	-- Check if the rebirth type exists in the config
	local rebirthType = typeConfig.RebirthType
	if not LevelingConfig.Rebirths.Types[rebirthType] then
		return false
	end

	return true
end

return RebirthHelpers
