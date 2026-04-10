local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Datas
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

local GetBaseMaxExp = {}

-- Resolves formula parameters with fallback hierarchy:
-- 1. Check typeScalingConfig for inline custom parameters (highest priority)
-- 2. Fall back to globalFormulas library
-- 3. Ultimate fallback to default Linear
local function ResolveFormulaParams(globalFormulas, typeScalingConfig)
	-- Priority 1: Inline custom parameters in type config
	if typeScalingConfig.Base then
		return {
			Base = typeScalingConfig.Base,
			Increment = typeScalingConfig.Increment,
			Factor = typeScalingConfig.Factor,
		}
	end
	
	-- Priority 2: Global formula library lookup
	local formulaName = typeScalingConfig.Formula
	if formulaName and globalFormulas and globalFormulas[formulaName] then
		return globalFormulas[formulaName]
	end
	
	-- Priority 3: Ultimate fallback (Linear with standard values)
	return { Base = 100, Increment = 25 }
end

-- Calculates MaxExp for Level 1 (base MaxExp) using formula parameters
local function CalculateMaxExpForLevel1(formulaParams)
	if not formulaParams then
		return 100 -- Fallback
	end
	
	local level = 1
	
	-- Linear formula: Base + (level - 1) * Increment
	if formulaParams.Increment then
		local base = formulaParams.Base or 100
		local increment = formulaParams.Increment
		return math.floor(base + (level - 1) * increment)
	end
	
	-- Exponential formula: Base * (Factor ^ (level - 1))
	if formulaParams.Factor then
		local base = formulaParams.Base or 50
		local factor = formulaParams.Factor
		return math.floor(base * (factor ^ (level - 1)))
	end
	
	-- Unknown formula structure → simple fallback
	return 100
end

-- Public: Get the base MaxExp for a given level type at Level 1
-- This is the initial MaxExp value that should be used when creating new profiles
function GetBaseMaxExp.ForType(levelType)
	-- Get type configuration
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local typeScalingConfig = typeCfg.Scaling or { Formula = "Linear" }
	local globalFormulas = (LevelingConfig.Scaling and LevelingConfig.Scaling.Formulas) or {}
	
	-- Resolve formula parameters
	local formulaParams = ResolveFormulaParams(globalFormulas, typeScalingConfig)
	
	-- Calculate MaxExp for Level 1
	return CalculateMaxExpForLevel1(formulaParams)
end

-- Public: Get base MaxExp for all configured level types
-- Returns a table keyed by levelType with MaxExp values
function GetBaseMaxExp.ForAllTypes()
	local result = {}
	
	if not LevelingConfig.Types then
		return result
	end
	
	for levelType, _ in pairs(LevelingConfig.Types) do
		result[levelType] = GetBaseMaxExp.ForType(levelType)
	end
	
	return result
end

-- Public: Get formula parameters for a level type (advanced usage)
-- Returns the resolved formula params: { Base, Increment or Factor }
function GetBaseMaxExp.GetFormulaParams(levelType)
	local typeCfg = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
	local typeScalingConfig = typeCfg.Scaling or { Formula = "Linear" }
	local globalFormulas = (LevelingConfig.Scaling and LevelingConfig.Scaling.Formulas) or {}
	
	return ResolveFormulaParams(globalFormulas, typeScalingConfig)
end

return GetBaseMaxExp
