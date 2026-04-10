--!strict

local StatBalanceConfig = require(script.Parent.Parent.Config.StatBalanceConfig)

local StatFormula = {}

local function clamp(value: number, minimum: number, maximum: number): number
    return math.max(minimum, math.min(maximum, value))
end

local function getNormalizedAgi(agi: number): number
    local aspdConfig = StatBalanceConfig.Aspd
    local clampedAgi = clamp(agi, aspdConfig.MinStatAgi, aspdConfig.MaxStatAgi)
    return clampedAgi / aspdConfig.MaxStatAgi
end

function StatFormula.getMaxHealth(baseStats, bonusHealth: number?)
    return math.floor(
        StatBalanceConfig.Core.BaseHealth
            + baseStats.VIT * StatBalanceConfig.StatWeights.VIT.health
            + (bonusHealth or 0)
    )
end

function StatFormula.getMaxMana(baseStats, bonusMana: number?)
    return math.floor(
        StatBalanceConfig.Core.BaseMana
            + baseStats.INT * StatBalanceConfig.StatWeights.INT.mana
            + (bonusMana or 0)
    )
end

function StatFormula.getHpRegenPerTick(baseStats, flatBonus: number?)
    return math.max(math.floor(5 + baseStats.VIT * 0.5 + (flatBonus or 0)), 1)
end

function StatFormula.getSpRegenPerTick(baseStats, flatBonus: number?)
    return math.max(math.floor(3 + baseStats.INT * 0.3 + (flatBonus or 0)), 1)
end

function StatFormula.getPhysicalAttack(baseStats, weaponAttack: number?, flatAttackBonus: number?)
    local baseAttack = baseStats.STR * StatBalanceConfig.StatWeights.STR.physicalAttack
    local dexSupport = baseStats.DEX / 5
    local totalAttack = baseAttack + dexSupport + (weaponAttack or 0) + (flatAttackBonus or 0)
    return math.max(math.floor(totalAttack * (1 + baseStats.STR / 300)), 1)
end

function StatFormula.getSkillAttack(baseStats)
    return math.floor(
        baseStats.STR * StatBalanceConfig.StatWeights.STR.skillAttack
            + baseStats.DEX * 0.15
    )
end

function StatFormula.getMagicAttack(baseStats, flatMagicBonus: number?)
    return math.floor(
        StatBalanceConfig.Core.BaseMagicAttack
            + baseStats.INT * StatBalanceConfig.StatWeights.INT.magicAttack
            + (flatMagicBonus or 0)
    )
end

function StatFormula.getPhysicalDefense(baseStats, flatDefenseBonus: number?)
    return math.floor(
        StatBalanceConfig.Core.BasePhysicalDefense
            + baseStats.VIT * StatBalanceConfig.StatWeights.VIT.physicalDefense
            + baseStats.STR * StatBalanceConfig.StatWeights.STR.physicalDefense
            + (flatDefenseBonus or 0)
    )
end

function StatFormula.getMagicalDefense(baseStats, flatMagicDefenseBonus: number?)
    return math.floor(
        StatBalanceConfig.Core.BaseMagicDefense
            + baseStats.INT * StatBalanceConfig.StatWeights.INT.magicalDefense
            + baseStats.VIT * StatBalanceConfig.StatWeights.VIT.magicalDefense
            + (flatMagicDefenseBonus or 0)
    )
end

function StatFormula.getHit(baseStats, flatHitBonus: number?)
    return math.floor(
        StatBalanceConfig.Core.BaseHit
            + baseStats.DEX * StatBalanceConfig.StatWeights.DEX.hit
            + baseStats.LUK * StatBalanceConfig.StatWeights.LUK.hit
            + baseStats.AGI * StatBalanceConfig.StatWeights.AGI.hit
            + (flatHitBonus or 0)
    )
end

function StatFormula.getFlee(baseStats, flatFleeBonus: number?)
    return math.floor(
        StatBalanceConfig.Core.BaseFlee
            + baseStats.AGI * StatBalanceConfig.StatWeights.AGI.flee
            + baseStats.LUK * StatBalanceConfig.StatWeights.LUK.flee
            + (flatFleeBonus or 0)
    )
end

function StatFormula.getCritChance(baseStats, flatCritBonus: number?)
    local critChance = (
        StatBalanceConfig.Core.BaseCritChance
        + baseStats.LUK * StatBalanceConfig.StatWeights.LUK.critChance
        + baseStats.DEX * StatBalanceConfig.StatWeights.DEX.critChance
    ) / 100
        + (flatCritBonus or 0)

    return clamp(critChance, 0, StatBalanceConfig.Crit.MaximumChance)
end

function StatFormula.getCritDamageMultiplier(baseStats, flatCritDamageBonus: number?)
    local critDamageMultiplier = StatBalanceConfig.Core.BaseCritDamage
        + baseStats.LUK * StatBalanceConfig.StatWeights.LUK.critDamage
        + (flatCritDamageBonus or 0)

    return clamp(critDamageMultiplier, StatBalanceConfig.Core.BaseCritDamage, StatBalanceConfig.Crit.MaximumDamageMultiplier)
end

function StatFormula.getAttackSpeedMultiplier(baseStats)
    local interval = StatFormula.getAttackIntervalSeconds(baseStats)
    return StatBalanceConfig.Aspd.BaseAttackInterval / interval
end

function StatFormula.getAspd(baseStats, flatBonus: number?)
    local aspdConfig = StatBalanceConfig.Aspd
    local normalizedAgi = getNormalizedAgi(baseStats.AGI)
    local bonusAspd = clamp(flatBonus or 0, 0, aspdConfig.FlatBonusCap)
    local aspd = aspdConfig.MinAspd
        + (aspdConfig.MaxAspd - aspdConfig.MinAspd) * math.pow(normalizedAgi, aspdConfig.AgiExponent)
        + (baseStats.DEX / aspdConfig.DexContributionDivisor)
        + bonusAspd

    return clamp(aspd, aspdConfig.MinAspd, aspdConfig.MaxAspd)
end

function StatFormula.getAttacksPerSecond(baseStats, flatBonus: number?)
    local aspdConfig = StatBalanceConfig.Aspd
    local aspd = StatFormula.getAspd(baseStats, flatBonus)
    local normalized = clamp((aspd - aspdConfig.MinAspd) / (aspdConfig.MaxAspd - aspdConfig.MinAspd), 0, 1)
    return aspdConfig.BaseAttacksPerSecond
        + (aspdConfig.MaxAttacksPerSecond - aspdConfig.BaseAttacksPerSecond) * math.pow(normalized, aspdConfig.ApsCurvePower)
end

function StatFormula.getAttackIntervalSeconds(baseStats, flatBonus: number?)
    local attacksPerSecond = StatFormula.getAttacksPerSecond(baseStats, flatBonus)
    local interval = 1 / math.max(attacksPerSecond, 0.001)
    return clamp(interval, StatBalanceConfig.Aspd.MinAttackInterval, StatBalanceConfig.Aspd.BaseAttackInterval)
end

function StatFormula.getCastSpeedMultiplier(baseStats)
    local multiplier = 1 - (baseStats.DEX / 300)

    return clamp(multiplier, StatBalanceConfig.Core.MinCastMultiplier, 1)
end

function StatFormula.getCarryWeight(baseStats, flatCarryBonus: number?)
    return math.floor(
        StatBalanceConfig.Core.BaseCarryWeight
            + baseStats.STR * StatBalanceConfig.StatWeights.STR.carryWeight
            + (flatCarryBonus or 0)
    )
end

function StatFormula.getCardFindBonus(baseStats, flatBonus: number?)
    return baseStats.LUK * StatBalanceConfig.StatWeights.LUK.cardFind + (flatBonus or 0)
end

function StatFormula.getItemFindBonus(baseStats, flatBonus: number?)
    return baseStats.LUK * StatBalanceConfig.StatWeights.LUK.itemFind + (flatBonus or 0)
end

function StatFormula.getUpgradeLuckBonus(baseStats, flatBonus: number?)
    return baseStats.LUK * StatBalanceConfig.StatWeights.LUK.upgradeLuck
        + baseStats.STR * StatBalanceConfig.StatWeights.STR.upgradeLuck
        + (flatBonus or 0)
end

function StatFormula.getHealingPowerMultiplier(baseStats)
    return 1 + baseStats.VIT * StatBalanceConfig.StatWeights.VIT.healingPower + baseStats.INT * 0.004
end

function StatFormula.getPerfectDodgeChance(baseStats, flatBonus: number?)
    local perfectDodge = ((baseStats.LUK * StatBalanceConfig.StatWeights.LUK.perfectDodge) / 100) + (flatBonus or 0)
    return clamp(perfectDodge, 0, 0.35)
end

function StatFormula.getStatusResistance(baseStats)
    local generic = clamp(
        baseStats.VIT * StatBalanceConfig.StatWeights.VIT.statusResist
            + baseStats.INT * StatBalanceConfig.StatWeights.INT.statusResist
            + baseStats.LUK * StatBalanceConfig.StatWeights.LUK.statusResist
            + baseStats.AGI * StatBalanceConfig.StatWeights.AGI.statusResist,
        0,
        StatBalanceConfig.StatusResistance.Maximum
    )

    return {
        stun = clamp(generic + baseStats.VIT * 0.002, 0, StatBalanceConfig.StatusResistance.Maximum),
        freeze = clamp(generic + baseStats.INT * 0.002, 0, StatBalanceConfig.StatusResistance.Maximum),
        silence = clamp(generic + baseStats.INT * 0.0015 + baseStats.DEX * 0.0005, 0, StatBalanceConfig.StatusResistance.Maximum),
        poison = clamp(generic + baseStats.VIT * 0.0015, 0, StatBalanceConfig.StatusResistance.Maximum),
        blind = clamp(generic + baseStats.DEX * 0.0015, 0, StatBalanceConfig.StatusResistance.Maximum),
        slow = clamp(generic + baseStats.AGI * 0.0015, 0, StatBalanceConfig.StatusResistance.Maximum),
        curse = clamp(generic + baseStats.LUK * 0.002, 0, StatBalanceConfig.StatusResistance.Maximum),
    }
end

return StatFormula
