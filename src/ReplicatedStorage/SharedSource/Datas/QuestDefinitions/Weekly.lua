--[[
    Weekly.lua
    
    Weekly quest definitions - time-gated quests that reset every 7 days.
    These quests typically have higher progress requirements and better rewards.
    
    ⭐ MULTI-TASK SUPPORT:
    - ALL quests MUST use Tasks array structure (even single-task quests)
    - TaskMode: "Sequential" (tasks unlock in order) or "Parallel" (all active simultaneously)
    - Each task can have its own ServerSideQuestName for different handlers
    
    Structure:
    - Each quest has a unique Name as the key
    - Tasks array contains one or more task definitions
    - Rewards use BaseEXP/BaseCash (scaled by player level)
    - Optional Requirements table for level/rebirth gates
]]

local WeeklyQuests = {
	-- ========================================
	-- ACTIVE MODE QUESTS - SINGLE TASK
	-- Require explicit tracking and spawn world objectives
	-- ========================================

	["WeeklyCollectCrates"] = {
		Name = "WeeklyCollectCrates",
		DisplayName = "Major Cargo Operation",
		Description = "Collect 4 crates throughout the week",
		TrackingMode = "Active", -- Explicit tracking required
		TaskMode = "Sequential",
		Image = "rbxassetid://112130465285368",
		Rewards = {
			BaseEXP = 1000,
			BaseCash = 5000,
		},
		Requirements = {
			MinLevel = 10,
		},
		-- REQUIRED: Tasks array
		Tasks = {
			{
				Description = "Collect 4 crates",
				MaxProgress = 4,
				DisplayText = "Collect crates throughout the week",
				ServerSideQuestName = "PickUpItems",
				PickupConfig = {
					HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
				},
			},
		},
	},
	["WeeklyDeliverPackage"] = {
		Name = "WeeklyDeliverPackage",
		DisplayName = "Weekly Delivery Service",
		Description = "Complete 3 package deliveries throughout the week",
		TrackingMode = "Active", -- Explicit tracking required
		TaskMode = "Sequential",
		Image = "rbxassetid://0",
		Rewards = {
			BaseEXP = 1500,
			BaseCash = 7500,
		},
		Requirements = {
			MinLevel = 10,
		},
		Category = "Delivery",
		-- REQUIRED: Tasks array
		Tasks = {
			{
				Description = "Deliver 3 packages",
				MaxProgress = 3,
				DisplayText = "Complete package deliveries throughout the week",
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
	-- PASSIVE MODE QUESTS - SINGLE TASK
	-- Same objectives as active quests, but progress automatically without tracking
	-- ========================================

	["WeeklyCollectCrates_Passive"] = {
		Name = "WeeklyCollectCrates_Passive",
		DisplayName = "Major Cargo Operation (Auto)",
		Description = "Collect 4 crates throughout the week",
		TrackingMode = "Passive", -- Automatic progress tracking
		TaskMode = "Sequential",
		Image = "rbxassetid://112130465285368",
		Rewards = {
			BaseEXP = 1000,
			BaseCash = 5000,
		},
		Requirements = {
			MinLevel = 10,
		},
		-- REQUIRED: Tasks array
		Tasks = {
			{
				Description = "Collect 4 crates",
				MaxProgress = 4,
				DisplayText = "Collect crates throughout the week",
				ProgressEvent = "ItemCollected",
				PassiveConfig = {
					ShowProgressNotifications = true,
					NotificationThrottle = 0.25,
				},
				ProgressFilter = function(eventData)
					return eventData.ItemId == "Crate" or eventData.ItemType == "Crate"
				end,
			},
		},
	},
	["WeeklyDeliverPackage_Passive"] = {
		Name = "WeeklyDeliverPackage_Passive",
		DisplayName = "Weekly Delivery Service (Auto)",
		Description = "Complete 3 package deliveries throughout the week",
		TrackingMode = "Passive", -- Automatic progress tracking
		TaskMode = "Sequential",
		Image = "rbxassetid://0",
		Rewards = {
			BaseEXP = 1500,
			BaseCash = 7500,
		},
		Requirements = {
			MinLevel = 10,
		},
		Category = "Delivery",
		-- REQUIRED: Tasks array
		Tasks = {
			{
				Description = "Deliver 3 packages",
				MaxProgress = 3,
				DisplayText = "Complete package deliveries throughout the week",
				ProgressEvent = "ItemCollected",
				PassiveConfig = {
					ShowProgressNotifications = true,
					NotificationThrottle = 0.25,
				},
				ProgressFilter = function(eventData)
					return eventData.ItemId == "Package" or eventData.ItemType == "Delivery"
				end,
			},
		},
	},

	-- ========================================
	-- MULTI-TASK QUESTS - SEQUENTIAL MODE
	-- Tasks must be completed in order
	-- ========================================

	["WeeklyChallenge"] = {
		Name = "WeeklyChallenge",
		DisplayName = "Weekly Challenge",
		Description = "Complete multiple challenges throughout the week",
		TrackingMode = "Active",
		TaskMode = "Sequential", -- Tasks unlock in sequence
		Image = "rbxassetid://112130465285368",
		Rewards = {
			BaseEXP = 2000,
			BaseCash = 10000,
		},
		Requirements = {
			MinLevel = 15,
		},
		-- REQUIRED: Multi-task array
		Tasks = {
			{
				Description = "Collect 10 crates",
				MaxProgress = 10,
				DisplayText = "Collect crates scattered around the island",
				ServerSideQuestName = "PickUpItems",
				PickupConfig = {
					HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
				},
			},
			{
				Description = "Deliver 5 packages",
				MaxProgress = 5,
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
	-- MULTI-TASK QUESTS - PARALLEL MODE
	-- All tasks available simultaneously
	-- ========================================

	["WeeklyMegaChallenge"] = {
		Name = "WeeklyMegaChallenge",
		DisplayName = "Mega Challenge",
		Description = "Complete all challenges simultaneously for mega rewards",
		TrackingMode = "Active",
		TaskMode = "Parallel", -- All tasks active at once
		Image = "rbxassetid://112130465285368",
		Rewards = {
			BaseEXP = 3000,
			BaseCash = 15000,
		},
		Requirements = {
			MinLevel = 20,
		},
		-- REQUIRED: Multi-task array
		Tasks = {
			{
				Description = "Collect 15 crates",
				MaxProgress = 15,
				DisplayText = "Collect crates around the island",
				ServerSideQuestName = "PickUpItems",
				PickupConfig = {
					HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
				},
			},
			{
				Description = "Deliver 8 packages",
				MaxProgress = 8,
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
}

return WeeklyQuests
