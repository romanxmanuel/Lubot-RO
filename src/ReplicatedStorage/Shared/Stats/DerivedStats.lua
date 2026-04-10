--!strict

local StatFormula = require(script.Parent.StatFormula)
local BaseStats = require(script.Parent.BaseStats)

local DerivedStats = {}

function DerivedStats.fromProfile(profile, runtimeBonuses)
    local statBonuses = runtimeBonuses and runtimeBonuses.statBonuses or runtimeBonuses or {}
    local combatBonuses = runtimeBonuses and runtimeBonuses.secondaryStats or {}
    local totalStats = BaseStats.addBonuses(profile.baseStats, statBonuses)
    local displayAspd = StatFormula.getAspd(totalStats, combatBonuses.aspd)
    local attacksPerSecond = StatFormula.getAttacksPerSecond(totalStats, combatBonuses.aspd)
    local attackIntervalSeconds = StatFormula.getAttackIntervalSeconds(totalStats, combatBonuses.aspd)
    local attackSpeedMultiplier = StatFormula.getAttackSpeedMultiplier(totalStats)

    local debugCombat = profile.runtime and profile.runtime.debugCombat
    if debugCombat then
        if debugCombat.attackIntervalSeconds then
            attackIntervalSeconds = debugCombat.attackIntervalSeconds
            attacksPerSecond = math.max(1 / attackIntervalSeconds, attacksPerSecond)
            attackSpeedMultiplier = math.max(1 / attackIntervalSeconds, attackSpeedMultiplier)
        end
        if debugCombat.displayAspd then
            displayAspd = debugCombat.displayAspd
        end
    end

    return {
        totalStats = totalStats,
        maxHealth = StatFormula.getMaxHealth(totalStats, combatBonuses.maxHealth),
        maxMana = StatFormula.getMaxMana(totalStats, combatBonuses.maxMana),
        hpRegenPerTick = StatFormula.getHpRegenPerTick(totalStats, combatBonuses.hpRegenPerTick),
        spRegenPerTick = StatFormula.getSpRegenPerTick(totalStats, combatBonuses.spRegenPerTick),
        physicalAttack = StatFormula.getPhysicalAttack(totalStats, runtimeBonuses and runtimeBonuses.weaponAttack or 0, combatBonuses.physicalAttack),
        skillAttack = StatFormula.getSkillAttack(totalStats),
        magicAttack = StatFormula.getMagicAttack(totalStats, combatBonuses.magicAttack),
        physicalDefense = StatFormula.getPhysicalDefense(totalStats, combatBonuses.physicalDefense),
        magicalDefense = StatFormula.getMagicalDefense(totalStats, combatBonuses.magicalDefense),
        hit = StatFormula.getHit(totalStats, combatBonuses.hit),
        flee = StatFormula.getFlee(totalStats, combatBonuses.flee),
        critChance = StatFormula.getCritChance(totalStats, combatBonuses.critChance),
        critDamageMultiplier = StatFormula.getCritDamageMultiplier(totalStats, combatBonuses.critDamageMultiplier),
        attackSpeedMultiplier = attackSpeedMultiplier,
        attacksPerSecond = attacksPerSecond,
        attackIntervalSeconds = attackIntervalSeconds,
        displayAspd = displayAspd,
        castSpeedMultiplier = StatFormula.getCastSpeedMultiplier(totalStats),
        carryWeight = StatFormula.getCarryWeight(totalStats, combatBonuses.carryWeight),
        cardFindBonus = StatFormula.getCardFindBonus(totalStats, combatBonuses.cardFindBonus),
        itemFindBonus = StatFormula.getItemFindBonus(totalStats, combatBonuses.itemFindBonus),
        upgradeLuckBonus = StatFormula.getUpgradeLuckBonus(totalStats, combatBonuses.upgradeLuckBonus),
        healingPowerMultiplier = StatFormula.getHealingPowerMultiplier(totalStats),
        perfectDodgeChance = StatFormula.getPerfectDodgeChance(totalStats, combatBonuses.perfectDodgeChance),
        statusResistance = StatFormula.getStatusResistance(totalStats),
    }
end

return DerivedStats
