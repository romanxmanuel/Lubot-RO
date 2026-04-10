--[[
    Main.lua
    
    Main quest definitions - progressive story quests that guide players through the game.
    Players complete these in sequential order (1, 2, 3, ...).
    
    Structure:
    - Each quest has a numeric key [1], [2], [3], etc.
    - QuestNum must match the key
    - Tasks array contains objectives to complete
    - Rewards are granted upon quest completion
]]

local MainQuests = {
	[1] = {
		QuestNum = 1,
		Title = "Welcome Aboard",
		Description = "Complete your first steps as a new recruit",
		Tasks = {
			{
				Description = "Reach level %d",
				MaxProgress = 2,
				DisplayText = "Reach level 2",
			},
		},
		Rewards = {
			EXP = 100,
			Cash = 500,
		},
	},

	[2] = {
		QuestNum = 2,
		Title = "Rising Through the Ranks",
		Description = "Continue your training",
		Tasks = {
			{
				Description = "Reach level %d",
				MaxProgress = 6,
				DisplayText = "Reach level 6",
			},
		},
		Rewards = {
			EXP = 250,
			Cash = 1000,
		},
	},
}

return MainQuests
