local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local module = {}

---- Utilities
local Calculator = require(script.Parent.Others.Calculator)

---- Knit Services
local ProfileService, LevelService

---- Datas
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

---- Assets

-- Public: Add EXP to a player's active or specified level type
function module:AddExp(player, amount, levelType)
	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then
		return false
	end

	local L = data.Leveling
	local activeType = levelType
	local t = L.Types[activeType]
	if not activeType or not t then
		return false
	end

	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[activeType]) or {}
	local typeScalingConfig = typeCfg.Scaling or { Formula = "Linear" }
	local globalFormulas = (LevelingConfig.Scaling and LevelingConfig.Scaling.Formulas) or {}

	-- Resolve formula parameters with fallback hierarchy:
	-- 1. Inline custom params in type config (highest priority)
	-- 2. Global formula library (fallback)
	-- 3. Default Linear (ultimate fallback)
	local formulaParams = Calculator.ResolveFormulaParams(globalFormulas, typeScalingConfig)

	local oldLevel = t.Level
	local newExp, newLevel, newMax = Calculator.AddExp(t.Exp, t.MaxExp, t.Level, amount, formulaParams)

	-- Check for level up
	local leveledUp = newLevel > oldLevel

	-- Write back via ProfileService:ChangeData
	ProfileService:ChangeData(player, { "Leveling", "Types", activeType, "Exp" }, newExp)
	ProfileService:ChangeData(player, { "Leveling", "Types", activeType, "Level" }, newLevel)
	ProfileService:ChangeData(player, { "Leveling", "Types", activeType, "MaxExp" }, newMax)

	-- Fire level up signal if level increased
	if leveledUp then
		local LevelService = Knit.GetService("LevelService")
		LevelService.Client.LevelUp:Fire(player, activeType, newLevel, oldLevel)
	end

	return true
end

-- Public: Lose EXP from a player's active or specified level type
function module:LoseExp(player, amount, levelType)
	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then
		return false
	end

	local L = data.Leveling
	local activeType = levelType
	local t = L.Types[activeType]
	if not activeType or not t then
		return false
	end

	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[activeType]) or {}
	local typeScalingConfig = typeCfg.Scaling or { Formula = "Linear" }
	local globalFormulas = (LevelingConfig.Scaling and LevelingConfig.Scaling.Formulas) or {}

	-- Resolve formula parameters with fallback hierarchy
	local formulaParams = Calculator.ResolveFormulaParams(globalFormulas, typeScalingConfig)

	local oldLevel = t.Level
	local newExp, newLevel, newMax = Calculator.LoseExp(t.Exp, t.MaxExp, t.Level, amount, formulaParams)

	-- Check for level down
	local leveledDown = newLevel < oldLevel

	-- Write back via ProfileService:ChangeData
	ProfileService:ChangeData(player, { "Leveling", "Types", activeType, "Exp" }, newExp)
	ProfileService:ChangeData(player, { "Leveling", "Types", activeType, "Level" }, newLevel)
	ProfileService:ChangeData(player, { "Leveling", "Types", activeType, "MaxExp" }, newMax)

	-- Could fire a level down signal if needed in the future
	if leveledDown then
		print(
			string.format("[LevelService] %s leveled down: %d -> %d (%s)", player.Name, oldLevel, newLevel, activeType)
		)
	end

	return true
end

-- Public: Add rebirth count to a player's level type
function module:AddRebirth(player, amount, levelType)
	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then
		return false
	end

	local currentRebirths = (data.Leveling.Rebirths and data.Leveling.Rebirths[levelType]) or 0
	local newRebirths = math.max(0, currentRebirths + amount)

	-- Check MaxRebirth limit
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local maxRebirth = typeCfg.MaxRebirth
	if maxRebirth then
		newRebirths = math.min(newRebirths, maxRebirth)
		if currentRebirths >= maxRebirth then
			warn(
				string.format(
					"[LevelService] %s already at max rebirth limit (%d) for %s",
					player.Name,
					maxRebirth,
					levelType
				)
			)
			return false
		end
	end

	-- Write back via ProfileService:ChangeData
	ProfileService:ChangeData(player, { "Leveling", "Rebirths", levelType }, newRebirths)

	print(
		string.format(
			"[LevelService] %s rebirth count changed: %d -> %d (%s)",
			player.Name,
			currentRebirths,
			newRebirths,
			levelType
		)
	)
	return true
end

-- Public: Reset level and exp to starting values (keeps rebirth count)
function module:ResetLevel(player, levelType)
	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then
		return false
	end

	local t = data.Leveling.Types[levelType]
	if not t then
		return false
	end

	-- Get initial MaxExp from formula
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local typeScalingConfig = typeCfg.Scaling or { Formula = "Linear" }
	local globalFormulas = (LevelingConfig.Scaling and LevelingConfig.Scaling.Formulas) or {}
	local formulaParams = Calculator.ResolveFormulaParams(globalFormulas, typeScalingConfig)
	local initialMaxExp = Calculator.GetNextMaxExp(formulaParams, 1)

	-- Reset to starting values
	ProfileService:ChangeData(player, { "Leveling", "Types", levelType, "Exp" }, 0)
	ProfileService:ChangeData(player, { "Leveling", "Types", levelType, "Level" }, 1)
	ProfileService:ChangeData(player, { "Leveling", "Types", levelType, "MaxExp" }, initialMaxExp)

	print(string.format("[LevelService] %s level reset for type: %s", player.Name, levelType))
	return true
end

-- Public: Set rebirth count directly (for testing/admin)
function module:SetRebirthCount(player, count, levelType)
	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then
		return false
	end

	count = math.max(0, math.floor(tonumber(count) or 0))

	-- Check MaxRebirth limit
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local maxRebirth = typeCfg.MaxRebirth
	if maxRebirth then
		if count > maxRebirth then
			warn(
				string.format(
					"[LevelService] Cannot set %s rebirth count to %d - exceeds max limit of %d (%s)",
					player.Name,
					count,
					maxRebirth,
					levelType
				)
			)
			count = maxRebirth
		end
	end

	-- Write back via ProfileService:ChangeData
	ProfileService:ChangeData(player, { "Leveling", "Rebirths", levelType }, count)

	print(string.format("[LevelService] %s rebirth count set to %d (%s)", player.Name, count, levelType))
	return true
end

-- Public: Set level directly to a specific value (for testing/admin)
function module:SetLevel(player, targetLevel, levelType)
	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then
		return false
	end

	local t = data.Leveling.Types[levelType]
	if not t then
		return false
	end

	-- Ensure target level is valid
	targetLevel = math.max(1, math.floor(tonumber(targetLevel) or 1))

	-- Get formula parameters
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local typeScalingConfig = typeCfg.Scaling or { Formula = "Linear" }
	local globalFormulas = (LevelingConfig.Scaling and LevelingConfig.Scaling.Formulas) or {}
	local formulaParams = Calculator.ResolveFormulaParams(globalFormulas, typeScalingConfig)

	-- Calculate the MaxExp for the target level
	local newMaxExp = Calculator.GetNextMaxExp(formulaParams, targetLevel)

	-- Set EXP to 0 for the new level
	local newExp = 0

	-- Write back via ProfileService:ChangeData
	ProfileService:ChangeData(player, { "Leveling", "Types", levelType, "Exp" }, newExp)
	ProfileService:ChangeData(player, { "Leveling", "Types", levelType, "Level" }, targetLevel)
	ProfileService:ChangeData(player, { "Leveling", "Types", levelType, "MaxExp" }, newMaxExp)

	print(string.format("[LevelService] %s level set to %d (%s)", player.Name, targetLevel, levelType))
	return true
end

-- Public: Check if player can rebirth for a level type
function module:CanRebirth(player, levelType)
	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then
		return false
	end

	-- Check if rebirths are enabled
	if not LevelingConfig.Rebirths or not LevelingConfig.Rebirths.enabled then
		return false
	end

	-- Get current level and max level
	local t = data.Leveling.Types[levelType]
	if not t then
		return false
	end

	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}

	-- Check if this level type has rebirth enabled
	local rebirthType = typeCfg.RebirthType
	if not rebirthType then
		return false
	end
	local maxLevel = typeCfg.MaxLevel

	if not maxLevel then
		warn(string.format("[LevelService] No MaxLevel defined for type: %s", levelType))
		return false
	end

	-- Check if at max level
	if t.Level < maxLevel then
		return false
	end

	-- Check if MaxRebirth limit has been reached
	local maxRebirth = typeCfg.MaxRebirth
	if maxRebirth then
		local currentRebirths = (data.Leveling.Rebirths and data.Leveling.Rebirths[levelType]) or 0
		if currentRebirths >= maxRebirth then
			return false
		end
	end

	return true
end

-- Public: Perform rebirth for a level type
function module:PerformRebirth(player, levelType)
	-- Check eligibility first
	if not self:CanRebirth(player, levelType) then
		return false, "Not eligible for rebirth"
	end

	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then
		return false, "Invalid profile data"
	end

	-- Get rebirth info
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local rebirthType = typeCfg.RebirthType
	if not rebirthType then
		return false, "Rebirth disabled for this level type"
	end
	local rebirthConfig = LevelingConfig.Rebirths.Types[rebirthType]
	local currentRebirths = (data.Leveling.Rebirths and data.Leveling.Rebirths[levelType]) or 0

	-- Increment rebirth count
	local success = self:AddRebirth(player, 1, levelType)
	if not success then
		return false, "Failed to add rebirth"
	end

	-- Reset level to 1
	local resetSuccess = self:ResetLevel(player, levelType)
	if not resetSuccess then
		return false, "Failed to reset level"
	end

	-- Fire rebirth signal
	LevelService.Client.Rebirthed:Fire(player, levelType, currentRebirths + 1)

	print(
		string.format(
			"[LevelService] %s rebirthed! %s: %d -> %d",
			player.Name,
			rebirthConfig.Name,
			currentRebirths,
			currentRebirths + 1
		)
	)

	return true, "Rebirth successful"
end

-- Removed: Previously used single ActiveLevelType concept. With multi-type active design,
-- callers should pass an explicit levelType to AddExp or query all via GetAllTypesData.
function module:SetActiveLevelType()
	return false
end

function module.Start()
	-- No-op
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
	LevelService = Knit.GetService("LevelService")
end

return module
