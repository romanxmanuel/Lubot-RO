local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Calculator = {}

-- Lightweight helpers
local function clamp(v, min, max)
	if v < min then
		return min
	end
	if v > max then
		return max
	end
	return v
end

-- Resolves formula parameters with fallback hierarchy:
-- 1. Check typeScalingConfig for inline custom parameters (highest priority)
-- 2. Fall back to globalFormulas library
-- 3. Ultimate fallback to default Linear
-- Returns a table with Base and either Increment or Factor
function Calculator.ResolveFormulaParams(globalFormulas, typeScalingConfig)
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

-- Returns next MaxExp for the given formula parameters and current level
-- Accepts resolved formula params from ResolveFormulaParams
function Calculator.GetNextMaxExp(formulaParams, level)
	if not formulaParams then
		-- Fallback if params weren't resolved
		return math.max(1, 100 + (level - 1) * 25)
	end

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
	return math.max(1, 100 + (level - 1) * 25)
end

-- Adds EXP and increments levels while overflow remains; returns new Exp, Level, MaxExp
-- formulaParams should be the result of ResolveFormulaParams
function Calculator.AddExp(exp, maxExp, level, addAmount, formulaParams)
	addAmount = tonumber(addAmount) or 0
	if addAmount <= 0 then
		return exp, level, maxExp
	end

	exp = exp + addAmount
	while exp >= maxExp do
		exp -= maxExp
		level += 1
		maxExp = Calculator.GetNextMaxExp(formulaParams, level)
	end
	return exp, level, maxExp
end

-- Loses EXP and decrements levels if needed; returns new Exp, Level, MaxExp
-- formulaParams should be the result of ResolveFormulaParams
function Calculator.LoseExp(exp, maxExp, level, loseAmount, formulaParams)
	loseAmount = tonumber(loseAmount) or 0
	if loseAmount <= 0 then
		return exp, level, maxExp
	end

	exp = exp - loseAmount

	-- Handle level-down if EXP goes negative
	while exp < 0 and level > 1 do
		level -= 1
		maxExp = Calculator.GetNextMaxExp(formulaParams, level)
		exp = exp + maxExp
	end

	-- Clamp at level 1 with 0 EXP minimum
	if level == 1 and exp < 0 then
		exp = 0
	end

	return exp, level, maxExp
end

function Calculator.Start()
	-- No-op
end

function Calculator.Init()
	-- No-op
end

return Calculator
