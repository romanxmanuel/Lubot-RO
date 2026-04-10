--[[
    QuestDefinitions/init.lua

    Central database for all quest definitions.
    Each quest type is separated into its own dedicated file for better organization.

    Quest Types:
    - Main: Progressive story quests (linear progression) - see Main.lua
    - Daily: Time-gated quests that reset every 24 hours - see Daily.lua
    - Weekly: Time-gated quests that reset every 7 days - see Weekly.lua
    - SideQuest: Standalone quests not tied to time cycles - see SideQuest.lua

    Adding New Quests:
    1. Edit the appropriate file (Main.lua, Daily.lua, or Weekly.lua)
    2. Ensure all required fields are present
    3. Update GameSettings.MainQuests.MaxQuestNum if adding main quests
    4. Run QuestValidator.ValidateAllQuestData() in Studio to verify
]]

local RunService = game:GetService("RunService")

local QuestDefinitions = {}

-- Load quest data from separate files
QuestDefinitions.Main = require(script:WaitForChild("Main", 10))
QuestDefinitions.Daily = require(script:WaitForChild("Daily", 10))
QuestDefinitions.Weekly = require(script:WaitForChild("Weekly", 10))
QuestDefinitions.SideQuest = require(script:WaitForChild("SideQuest", 10))

--========================================
-- DATA VALIDATION
--========================================

if RunService:IsStudio() then
    local function validateQuestData()
        local errors = {}

        -- Validate Main Quests have sequential QuestNum
        for i, quest in ipairs(QuestDefinitions.Main) do
            if quest.QuestNum ~= i then
                table.insert(errors, string.format(
                    "Main Quest #%d has QuestNum=%d (should be %d)",
                    i, quest.QuestNum, i
                ))
            end
        end

        -- Validate Daily Quests have unique names
        local dailyNames = {}
        for questName, quest in pairs(QuestDefinitions.Daily) do
            if dailyNames[questName] then
                table.insert(errors, string.format(
                    "Duplicate Daily Quest name: %s",
                    questName
                ))
            end
            dailyNames[questName] = true
        end

        -- Validate Weekly Quests have unique names
        local weeklyNames = {}
        for questName, quest in pairs(QuestDefinitions.Weekly) do
            if weeklyNames[questName] then
                table.insert(errors, string.format(
                    "Duplicate Weekly Quest name: %s",
                    questName
                ))
            end
            weeklyNames[questName] = true
        end

        -- Validate SideQuests have unique names
        local sideQuestNames = {}
        for questName, quest in pairs(QuestDefinitions.SideQuest) do
            if sideQuestNames[questName] then
                table.insert(errors, string.format(
                    "Duplicate SideQuest name: %s",
                    questName
                ))
            end
            sideQuestNames[questName] = true
        end

        if #errors > 0 then
            warn("⚠️ QuestDefinitions Validation Warnings:")
            for _, err in ipairs(errors) do
                warn("  - " .. err)
            end
        end
    end

    validateQuestData()
end

return QuestDefinitions
