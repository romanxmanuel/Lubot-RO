-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Datas
local CurrencySettings = require(ReplicatedStorage.SharedSource.Datas.CurrencySettings)

-- Module
local ProfileTemplate = {}

-- Add all currencies from settings with their default values
ProfileTemplate.Currencies = {}
for _, currency in ipairs(CurrencySettings.Currencies) do
	ProfileTemplate.Currencies[currency.Id] = currency.DefaultValue
end

-- Main Quest Progress
ProfileTemplate.MainQuests = {
    QuestNum = 1, -- Current main quest number
    Tasks = {}, -- Progress for each task in current quest
}

-- Daily Quest Progress
ProfileTemplate.DailyQuests = {
    LastResetTime = 0, -- Unix timestamp of last reset
    Quests = {}, -- Array of active daily quests
}

-- Weekly Quest Progress
ProfileTemplate.WeeklyQuests = {
    LastResetTime = 0, -- Unix timestamp of last reset
    Quests = {}, -- Array of active weekly quests
}

-- Standalone Side Quest Progress (repeatable quests)
ProfileTemplate.SideQuests = {
    -- Dictionary of quest progress by quest name
    -- Quest Structure (Multi-Task Support):
    -- ["QuestName"] = {
    --     Name = "QuestName",
    --     Completed = false,
    --     Tasks = {
    --         [1] = {
    --             Description = "Task description",
    --             Progress = 0,
    --             MaxProgress = 5,
    --             Completed = false,
    --         },
    --     },
    -- }
}

-- Side Quest Tracking
ProfileTemplate.CurrentSideQuestTracked = {
    QuestType = nil, -- "Daily", "Weekly", or "SideQuest" (nil = no quest tracked)
    QuestNum = nil, -- Index in Quests array (or quest name for SideQuest)
}

return ProfileTemplate
