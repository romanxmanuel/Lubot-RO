local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Controllers
local DataController

---- Config
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

---- Utils
function module.Start()
	-- No-op
end

function module.Init()
	DataController = Knit.GetController("DataController")
end

-- Get level data for a specific type
function module:GetLevelData(levelType)
	local data = DataController:GetPlayerData()
	if not data or not data.Leveling or not data.Leveling.Types then
		return nil
	end

	local levelData = data.Leveling.Types[levelType]
	if not levelData then
		return nil
	end

	-- Get display names from config
	local config = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}

	return {
		Exp = levelData.Exp or 0,
		Level = levelData.Level or 1,
		MaxExp = levelData.MaxExp or 100,
		Rebirths = (data.Leveling.Rebirths and data.Leveling.Rebirths[levelType]) or 0,
		Name = config.Name or levelType,
		ExpName = config.ExpName or "EXP",
	}
end

-- Get all level data
function module:GetAllLevelData()
	local data = DataController:GetPlayerData()
	if not data or not data.Leveling or not data.Leveling.Types then
		return {}
	end

	local allData = {}
	for levelType, levelData in pairs(data.Leveling.Types) do
		local config = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}

		allData[levelType] = {
			Exp = levelData.Exp or 0,
			Level = levelData.Level or 1,
			MaxExp = levelData.MaxExp or 100,
			Rebirths = (data.Leveling.Rebirths and data.Leveling.Rebirths[levelType]) or 0,
			Name = config.Name or levelType,
			ExpName = config.ExpName or "EXP",
		}
	end

	return allData
end

-- Get progress percentage (0-1) for a level type
function module:GetProgressPercent(levelType)
	local levelData = self:GetLevelData(levelType)
	if not levelData then
		return 0
	end

	if levelData.MaxExp == 0 then
		return 1
	end
	return math.min(levelData.Exp / levelData.MaxExp, 1)
end

-- Check if a level type exists
function module:IsLevelType(levelType)
	local data = DataController:GetPlayerData()
	if not data or not data.Leveling or not data.Leveling.Types then
		return false
	end

	return data.Leveling.Types[levelType] ~= nil
end

-- Get rebirth info for a level type
function module:GetRebirthInfo(levelType)
	if not LevelingConfig.Rebirths or not LevelingConfig.Rebirths.enabled then
		return nil
	end

	-- Read rebirth type directly from the level type config
	local typeConfig = LevelingConfig.Types and LevelingConfig.Types[levelType]
	if not typeConfig then
		return nil
	end

	local rebirthType = typeConfig.RebirthType
	if not rebirthType then
		return nil
	end

	local rebirthConfig = LevelingConfig.Rebirths.Types[rebirthType]
	if not rebirthConfig then
		return nil
	end

	local data = DataController:GetPlayerData()
	local rebirthCount = (data and data.Leveling and data.Leveling.Rebirths and data.Leveling.Rebirths[levelType]) or 0

	return {
		Type = rebirthType,
		Count = rebirthCount,
		Name = rebirthConfig.Name,
		ShortName = rebirthConfig.ShortName,
	}
end

-- Get formatted level display string
function module:GetFormattedLevel(levelType)
	local levelData = self:GetLevelData(levelType)
	if not levelData then
		return "N/A"
	end

	local rebirthInfo = self:GetRebirthInfo(levelType)
	if rebirthInfo and rebirthInfo.Count > 0 then
		return string.format("[%s%d] %d", rebirthInfo.ShortName, rebirthInfo.Count, levelData.Level)
	else
		return tostring(levelData.Level)
	end
end

-- Get formatted exp display string
function module:GetFormattedExp(levelType)
	local levelData = self:GetLevelData(levelType)
	if not levelData then
		return "0/0"
	end

	-- Format large numbers
	local function formatNumber(num)
		if num >= 1000000 then
			return string.format("%.1fM", num / 1000000)
		elseif num >= 1000 then
			return string.format("%.1fK", num / 1000)
		else
			return tostring(num)
		end
	end

	return string.format("%s/%s %s", formatNumber(levelData.Exp), formatNumber(levelData.MaxExp), levelData.ExpName)
end

-- Check if player can rebirth for a level type
function module:CanRebirth(levelType)
	if not LevelingConfig.Rebirths or not LevelingConfig.Rebirths.enabled then
		return false
	end

	-- Check if this level type has rebirth enabled
	local typeConfig = LevelingConfig.Types and LevelingConfig.Types[levelType]
	if not typeConfig or not typeConfig.RebirthType then
		return false
	end

	-- Get max level
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local maxLevel = typeCfg.MaxLevel
	if not maxLevel then
		return false
	end

	-- Get current level
	local levelData = self:GetLevelData(levelType)
	if not levelData then
		return false
	end

	return levelData.Level >= maxLevel
end

-- Get max level for a level type
function module:GetMaxLevel(levelType)
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	return typeCfg.MaxLevel
end

-- Get rebirth eligibility info
function module:GetRebirthEligibility(levelType)
	if not LevelingConfig.Rebirths or not LevelingConfig.Rebirths.enabled then
		return {
			eligible = false,
			reason = "Rebirths disabled",
		}
	end

	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local rebirthType = typeCfg.RebirthType
	if not rebirthType then
		return {
			eligible = false,
			reason = "Rebirth disabled for this level type",
		}
	end
	local maxLevel = typeCfg.MaxLevel
	if not maxLevel then
		return {
			eligible = false,
			reason = "No max level defined",
		}
	end

	local levelData = self:GetLevelData(levelType)
	if not levelData then
		return {
			eligible = false,
			reason = "No level data",
		}
	end

	local rebirthConfig = LevelingConfig.Rebirths.Types[rebirthType]
	local canRebirth = levelData.Level >= maxLevel

	-- Check MaxRebirth limit
	local maxRebirth = typeCfg.MaxRebirth
	if maxRebirth then
		local currentRebirths = levelData.Rebirths or 0
		if currentRebirths >= maxRebirth then
			return {
				eligible = false,
				currentLevel = levelData.Level,
				maxLevel = maxLevel,
				rebirthCount = currentRebirths,
				maxRebirthCount = maxRebirth,
				rebirthName = rebirthConfig and rebirthConfig.Name or "Rebirth",
				reason = string.format("Max rebirth limit reached (%d/%d)", currentRebirths, maxRebirth),
				isMaxRebirth = true,
			}
		end
	end

	return {
		eligible = canRebirth,
		currentLevel = levelData.Level,
		maxLevel = maxLevel,
		rebirthCount = levelData.Rebirths,
		maxRebirthCount = maxRebirth,
		rebirthName = rebirthConfig and rebirthConfig.Name or "Rebirth",
		reason = canRebirth and "Ready" or string.format("Reach level %d", maxLevel),
		isMaxRebirth = false,
	}
end

return module
