--[[
    SideQuest.lua
    
    Dedicated side quest definitions - standalone quests that aren't tied to daily/weekly cycles.
    These are persistent quests that players can pick up and complete at any time.
    
    Differences from Daily/Weekly:
    - Not time-gated (no automatic reset)
    - Can be picked up from NPCs, locations, or triggered by events
    - Progress persists until completion
    - May have prerequisites (level, previous quest completion, etc.)
    
    ⭐ MULTI-TASK SUPPORT:
    - ALL quests MUST use Tasks array structure (even single-task quests)
    - TaskMode: "Sequential" (tasks unlock in order) or "Parallel" (all active simultaneously)
    - Each task can have its own ServerSideQuestName for different handlers
    
    Structure:
    - Each quest has a unique Name as the key
    - Tasks array contains one or more task definitions
    - ServerSideQuestName maps to the server execution module in TriggeredQuest/Types/
    - Rewards can be EXP, Cash, Items, or custom rewards
    - Optional Requirements table for level/rebirth/quest prerequisites
    - Optional Repeatable flag for quests that can be done multiple times
]]

local SideQuests = {
	-- ========================================
	-- SINGLE-TASK SIDE QUESTS
	-- ========================================

	["PickupCrates"] = {
		Name = "PickupCrates",
		DisplayName = "Cargo Collection",
		Description = "Collect crates scattered around the island",
		TaskMode = "Sequential",
		Image = "rbxassetid://112130465285368",
		Rewards = {
			EXP = 50,
			Cash = 200,
		},
		Requirements = {
			MinLevel = 1,
		},
		Repeatable = true, -- Can be repeated multiple times
		Category = "Tutorial",
		-- REQUIRED: Tasks array
		Tasks = {
			{
				Description = "Collect 4 crates",
				MaxProgress = 4,
				DisplayText = "Collect crates scattered around the island",
				ServerSideQuestName = "PickUpItems",
				PickupConfig = {
					HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
				},
			},
		},
	},

	["DeliverPackage"] = {
		Name = "DeliverPackage",
		DisplayName = "Special Delivery",
		Description = "Deliver a package to the marked location",
		TaskMode = "Sequential",
		Image = "rbxassetid://0",
		Rewards = {
			EXP = 100,
			Cash = 500,
		},
		Requirements = {
			MinLevel = 1,
		},
		Repeatable = true, -- Can be repeated multiple times
		Category = "Delivery",
		-- REQUIRED: Tasks array
		Tasks = {
			{
				Description = "Deliver 1 package",
				MaxProgress = 1,
				DisplayText = "Deliver a package to the marked location",
				ServerSideQuestName = "Delivery",
				DeliveryConfig = {
					TargetFolder = "Deliver_Test",
					HighlightColor = Color3.fromRGB(0, 255, 0),
					RequireHumanoid = true,
					HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				},
			},
		},
	},

	-- ========================================
	-- MULTI-TASK SIDE QUESTS - SEQUENTIAL
	-- ========================================

	["MultiStepQuest"] = {
		Name = "MultiStepQuest",
		DisplayName = "Island Challenge",
		Description = "Complete multiple challenges across the island",
		TaskMode = "Sequential", -- Tasks unlock in order
		Image = "rbxassetid://112130465285368",
		Rewards = {
			EXP = 500,
			Cash = 2500,
		},
		Requirements = {
			MinLevel = 5,
		},
		Repeatable = true,
		Category = "Challenge",
		-- REQUIRED: Multi-task array
		Tasks = {
			{
				Description = "Collect 10 crates",
				MaxProgress = 4,
				DisplayText = "Collect crates scattered around the island",
				ServerSideQuestName = "PickUpItems",
				PickupConfig = {
					HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
				},
			},
			{
				Description = "Deliver 5 packages",
				MaxProgress = 1,
				DisplayText = "Deliver packages to marked locations",
				ServerSideQuestName = "Delivery",
				DeliveryConfig = {
					TargetFolder = "Deliver_Test",
					HighlightColor = Color3.fromRGB(0, 255, 0),
					RequireHumanoid = true,
					HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				},
			},
		},
	},

	-- ========================================
	-- MULTI-TASK SIDE QUESTS - PARALLEL
	-- ========================================

	["ParallelChallenge"] = {
		Name = "ParallelChallenge",
		DisplayName = "Simultaneous Tasks",
		Description = "Complete multiple tasks at the same time",
		TaskMode = "Parallel", -- All tasks active simultaneously
		Image = "rbxassetid://112130465285368",
		Rewards = {
			EXP = 750,
			Cash = 3500,
		},
		Requirements = {
			MinLevel = 10,
		},
		Repeatable = true,
		Category = "Challenge",
		-- REQUIRED: Multi-task array
		Tasks = {
			{
				Description = "Collect 4 crates",
				MaxProgress = 4,
				DisplayText = "Collect crates around the island",
				ServerSideQuestName = "PickUpItems",
				PickupConfig = {
					HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
				},
			},
			{
				Description = "Deliver 1 packages",
				MaxProgress = 1,
				DisplayText = "Deliver packages to marked locations",
				ServerSideQuestName = "Delivery",
				DeliveryConfig = {
					TargetFolder = "Deliver_Test",
					HighlightColor = Color3.fromRGB(0, 255, 0),
					RequireHumanoid = true,
					HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				},
			},
		},
	},

	["KillMonster"] = {
		Name = "KillMonster",
		DisplayName = "Bandit Hunt",
		Description = "Eliminate 5 bandits terrorizing the area",
		TaskMode = "Sequential",
		Image = "rbxassetid://0",
		Rewards = {
			EXP = 150,
			Cash = 300,
		},
		Requirements = {
			MinLevel = 1,
		},
		Repeatable = true,
		Category = "Combat",
		Tasks = {
			{
				Description = "Defeat 5 bandits",
				MaxProgress = 5,
				DisplayText = "Hunt down the bandits",
				ServerSideQuestName = "KillNPC",
				KillConfig = {
					TargetName = "Bandit",
				},
			},
		},
	},

	-- Example: Future quest types
	--[[
    ["DefeatBanditLeader"] = {
        Name = "DefeatBanditLeader",
        DisplayName = "Bandit Trouble",
        Description = "Eliminate the bandit leader causing trouble in town",
        MaxProgress = 1,
        Image = "rbxassetid://0",
        Rewards = {
            EXP = 1000,
            Cash = 5000,
        },
        ServerSideQuestName = "EliminateTarget",
        Requirements = {
            MinLevel = 10,
            CompletedQuests = {"PickupCrates"}, -- Must complete tutorial first
        },
        Repeatable = false,
        Category = "Combat",
    },
    
    ["MultiStageDelivery"] = {
        Name = "MultiStageDelivery",
        DisplayName = "Urgent Deliveries",
        Description = "Deliver packages to multiple locations across the island",
        MaxProgress = 3, -- Three deliveries
        Image = "rbxassetid://0",
        Rewards = {
            EXP = 300,
            Cash = 1500,
        },
        ServerSideQuestName = "Delivery",
        Requirements = {
            MinLevel = 5,
            CompletedQuests = {"DeliverPackage"}, -- Must complete basic delivery first
        },
        Repeatable = true,
        Category = "Delivery",
        DeliveryConfig = {
            TargetFolder = "Quests.UrgentDeliveries", -- Different folder path for this quest
            HighlightColor = Color3.fromRGB(255, 255, 0), -- Yellow highlight
            RequireHumanoid = true,
            HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
        },
    },
    ]]
}

return SideQuests
