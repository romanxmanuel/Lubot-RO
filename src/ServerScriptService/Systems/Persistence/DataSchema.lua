--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)

local DataSchema = {
    Version = 4,
    BaseProfile = {
        version = 4,
        level = 1,
        experience = 0,
        jobLevel = 1,
        jobExperience = 0,
        statPoints = 0,
        skillPoints = 1,
        zeny = 500,
        premiumCurrency = 0,
        archetypeId = 'knight_path',
        classId = 'knight',
        classStage = 'Base',
        rebirthCount = 0,
        baseStats = {},
        inventory = {},
        inventoryOrder = {},
        inventorySortCounter = 0,
        itemInstances = {},
        equipment = {},
        cards = {},
        cardOrder = {},
        unlockedSkills = {},
        skillRanks = {},
        unlockedCosmetics = {},
        archetypeProgression = {},
        starterPathClaims = {},
        settings = {
            autoLoot = true,
            hotbarSlots = {},
            itemHotbarSlots = {},
            customSkillHotkeys = {},
            hotbarPresetVersion = 2,
            adminNoCooldowns = false,
            equippedAmmoItemId = '',
        },
        runtime = {
            statusAilments = {},
            activeBuffs = {},
            skillCooldowns = {},
            lastZoneId = 'zoltraak',
        },
    },
    ArchetypeStartTemplates = {
        knight_path = {
            classId = 'knight',
            archetypeId = 'knight_path',
            zeny = 500,
            baseStats = {
                STR = 16,
                AGI = 6,
                VIT = 14,
                INT = 2,
                DEX = 12,
                LUK = 4,
            },
            inventory = {
                red_potion = 5,
            },
            starterEquipment = {
                { itemId = 'sword', equipped = true },
                { itemId = 'cotton_shirt', equipped = true },
                { itemId = 'sandals', equipped = true },
            },
        },
        assassin_path = {
            classId = 'assassin',
            archetypeId = 'assassin_path',
            zeny = 500,
            baseStats = {
                STR = 6,
                AGI = 18,
                VIT = 6,
                INT = 2,
                DEX = 12,
                LUK = 10,
            },
            inventory = {
                red_potion = 5,
                fly_wing = 2,
            },
            starterEquipment = {
                { itemId = 'katar', equipped = true },
                { itemId = 'cotton_shirt', equipped = true },
                { itemId = 'sandals', equipped = true },
            },
        },
        mage_path = {
            classId = 'mage',
            archetypeId = 'mage_path',
            zeny = 500,
            baseStats = {
                STR = 2,
                AGI = 4,
                VIT = 6,
                INT = 22,
                DEX = 18,
                LUK = 2,
            },
            inventory = {
                blue_potion = 5,
            },
            starterEquipment = {
                { itemId = 'rod', equipped = true },
                { itemId = 'cotton_shirt', equipped = true },
                { itemId = 'sandals', equipped = true },
            },
        },
        archer_path = {
            classId = 'archer',
            archetypeId = 'archer_path',
            zeny = 500,
            baseStats = {
                STR = 4,
                AGI = 14,
                VIT = 6,
                INT = 2,
                DEX = 22,
                LUK = 6,
            },
            inventory = {
                red_potion = 5,
                arrow_bundle_small = 800,
            },
            starterEquipment = {
                { itemId = 'bow', equipped = true },
                { itemId = 'cotton_shirt', equipped = true },
                { itemId = 'sandals', equipped = true },
            },
        },
        zero_path = {
            classId = 'zero',
            archetypeId = 'zero_path',
            zeny = 500,
            baseStats = {
                STR = 10,
                AGI = 18,
                VIT = 8,
                INT = 2,
                DEX = 18,
                LUK = 6,
            },
            inventory = {
                red_potion = 5,
                fly_wing = 2,
            },
            starterEquipment = {
                { itemId = 'sword', equipped = true },
                { itemId = 'cotton_shirt', equipped = true },
                { itemId = 'sandals', equipped = true },
            },
        },
    },
}

function DataSchema.createDefaultProfile(archetypeId: string?)
    local profile = TableUtil.deepCopy(DataSchema.BaseProfile)
    local template = DataSchema.ArchetypeStartTemplates[archetypeId or profile.archetypeId] or DataSchema.ArchetypeStartTemplates.knight_path

    profile.archetypeId = template.archetypeId
    profile.classId = template.classId
    profile.zeny = template.zeny
    profile.baseStats = TableUtil.deepCopy(template.baseStats)
    profile.inventory = TableUtil.deepCopy(template.inventory)
    profile.runtime.lastZoneId = 'zoltraak'

    return profile
end

function DataSchema.getArchetypeTemplate(archetypeId: string)
    return DataSchema.ArchetypeStartTemplates[archetypeId]
end

return DataSchema
