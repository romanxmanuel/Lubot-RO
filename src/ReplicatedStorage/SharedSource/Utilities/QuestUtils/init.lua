--[[
    QuestUtils.lua

    Utility functions for working with quest data.
    
    Methods:
    - GetQuestByName(questType, questName) - Get quest by name for Daily/Weekly
    - GetMainQuestByNum(questNum) - Get main quest by number
    - GetQuestCount(questType) - Get total quest count for a type
    - GetAvailableQuests(questType, playerLevel, playerRebirth) - Get filtered quests
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

local QuestUtils = {}

--========================================
-- QUEST RETRIEVAL
--========================================

--[[
    Get quest by name (for Daily/Weekly quests).
    
    @param questType string - "Daily" or "Weekly"
    @param questName string - The quest name to find
    @return table|nil - Quest data or nil if not found
]]
function QuestUtils.GetQuestByName(questType, questName)
    local questList = QuestDefinitions[questType]
    if not questList then
        return nil
    end

    -- Daily and Weekly quests are dictionaries with questName as key
    return questList[questName]
end

--[[
    Get main quest by number.
    
    @param questNum number - The quest number (1-indexed)
    @return table|nil - Quest data or nil if not found
]]
function QuestUtils.GetMainQuestByNum(questNum)
    return QuestDefinitions.Main[questNum]
end

--[[
    Get total quest count for a quest type.
    
    @param questType string - "Main", "Daily", or "Weekly"
    @return number - Total count of quests for this type
]]
function QuestUtils.GetQuestCount(questType)
    local questList = QuestDefinitions[questType]
    if not questList then
        return 0
    end
    
    -- Main quests use array structure, Daily/Weekly use dictionary
    if questType == "Main" then
        return #questList
    else
        -- Count dictionary keys
        local count = 0
        for _ in pairs(questList) do
            count = count + 1
        end
        return count
    end
end

--[[
    Get filtered quests by player requirements.
    
    @param questType string - "Main", "Daily", or "Weekly"
    @param playerLevel number - Player's current level
    @param playerRebirth number - Player's current rebirth count
    @return table - Array of quests that meet requirements
]]
function QuestUtils.GetAvailableQuests(questType, playerLevel, playerRebirth)
    local questList = QuestDefinitions[questType]
    if not questList then
        return {}
    end

    local available = {}
    
    -- Main quests use array structure, Daily/Weekly use dictionary
    local iterator = questType == "Main" and ipairs or pairs
    
    for _, quest in iterator(questList) do
        local meetsRequirements = true

        if quest.Requirements then
            if quest.Requirements.MinLevel and playerLevel < quest.Requirements.MinLevel then
                meetsRequirements = false
            end
            if quest.Requirements.MinRebirth and playerRebirth < quest.Requirements.MinRebirth then
                meetsRequirements = false
            end
        end

        if meetsRequirements then
            table.insert(available, quest)
        end
    end

    return available
end

return QuestUtils
