--!strict

local StatBalanceConfig = require(script.Parent.Parent.Config.StatBalanceConfig)

local CombatFormula = {}

local function clamp(value: number, minimum: number, maximum: number): number
    return math.max(minimum, math.min(maximum, value))
end

local function applyVariance(damage: number, rng: Random?): number
    local roller = rng or Random.new()
    local varied = damage * roller:NextNumber(0.85, 1.15)
    return math.max(math.floor(varied), 1)
end

function CombatFormula.getDefenseMitigation(defense: number): number
    local mitigation = 1 - CombatFormula.getDefenseMultiplier(defense)
    return clamp(mitigation, 0, StatBalanceConfig.Defense.MaxMitigation)
end

function CombatFormula.getDefenseMultiplier(defense: number): number
    local clampedDefense = math.max(defense, 0)
    return 100 / (100 + clampedDefense)
end

function CombatFormula.getHitChance(attackerHit: number, defenderFlee: number): number
    local denominator = math.max(attackerHit + math.max(defenderFlee, 0), 1)
    local chance = attackerHit / denominator
    return clamp(chance, StatBalanceConfig.Hit.MinimumChance, StatBalanceConfig.Hit.MaximumChance)
end

function CombatFormula.getEvadeChance(attackerHit: number, defenderFlee: number): number
    local evadeChance = 0.1 + ((defenderFlee - attackerHit) / 220)
    return clamp(evadeChance, StatBalanceConfig.Evasion.MinimumChance, StatBalanceConfig.Evasion.MaximumChance)
end

function CombatFormula.getCritChance(attackerCritChance: number, defenderCritResist: number?): number
    local chance = attackerCritChance - (defenderCritResist or 0)
    return clamp(chance, 0, StatBalanceConfig.Crit.MaximumChance)
end

function CombatFormula.getCastTime(baseCastSeconds: number, castSpeedMultiplier: number): number
    return math.max(baseCastSeconds * castSpeedMultiplier, 0.1)
end

function CombatFormula.calculatePhysicalRawDamage(attackPower: number, skillMultiplier: number, damageBonus: number?): number
    local rawDamage = attackPower * skillMultiplier * (damageBonus or 1)
    return math.max(math.floor(rawDamage), 1)
end

function CombatFormula.getDefenseReducedDamage(incomingDamage: number, defense: number): number
    local mitigatedDamage = incomingDamage * CombatFormula.getDefenseMultiplier(defense)
    return math.max(math.floor(mitigatedDamage), 1)
end

function CombatFormula.calculatePhysicalDamage(attackPower: number, defense: number, skillMultiplier: number, damageBonus: number?): number
    return applyVariance(CombatFormula.getDefenseReducedDamage(
        CombatFormula.calculatePhysicalRawDamage(attackPower, skillMultiplier, damageBonus),
        defense
    ))
end

function CombatFormula.calculateMagicalDamage(magicAttack: number, magicalDefense: number, skillMultiplier: number, damageBonus: number?): number
    return applyVariance(CombatFormula.getDefenseReducedDamage(
        math.max(math.floor(magicAttack * skillMultiplier * (damageBonus or 1)), 1),
        magicalDefense
    ))
end

function CombatFormula.applyCritical(damage: number, didCrit: boolean, critDamageMultiplier: number): number
    if not didCrit then
        return damage
    end

    return applyVariance(math.max(math.floor(damage * critDamageMultiplier), 1))
end

function CombatFormula.applyStatusResistance(baseDuration: number, resistance: number): number
    return math.max(baseDuration * (1 - resistance), 0)
end

return CombatFormula
