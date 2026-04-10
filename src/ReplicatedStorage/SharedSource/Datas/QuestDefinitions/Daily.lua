--[[
    Daily.lua
    
    Daily quest definitions - time-gated quests that reset every 24 hours.
    Players can have multiple active daily quests simultaneously.
    
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

local DailyQuests = {
	-- ========================================
	-- ACTIVE MODE QUESTS - SINGLE TASK
	-- Require explicit tracking and spawn world objectives
	-- ========================================

	["CollectCrates"] = {
		Name = "CollectCrates",
		DisplayName = "Cargo Collection",
		Description = "Collect crates scattered around the island",
		TrackingMode = "Active", -- Explicit tracking required
		TaskMode = "Sequential", -- Required field
		Image = "rbxassetid://112130465285368",
		Rewards = {
			BaseEXP = 150,
			BaseCash = 800,
		},
		-- REQUIRED: Tasks array (even for single-task quests)
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
	["DailyDeliverPackage"] = {
		Name = "DailyDeliverPackage",
		DisplayName = "Daily Delivery",
		Description = "Deliver a package to the marked location",
		TrackingMode = "Active", -- Explicit tracking required
		TaskMode = "Sequential",
		Image = "rbxassetid://0",
		Rewards = {
			BaseEXP = 200,
			BaseCash = 1000,
		},
		Requirements = {
			MinLevel = 1,
		},
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
	-- PASSIVE MODE QUESTS - SINGLE TASK
	-- Same objectives as active quests, but progress automatically without tracking
	-- ========================================

	["CollectCrates_Passive"] = {
		Name = "CollectCrates_Passive",
		DisplayName = "Cargo Collection (Auto)",
		Description = "Collect crates scattered around the island",
		TrackingMode = "Passive", -- Automatic progress tracking
		TaskMode = "Sequential",
		Image = "rbxassetid://112130465285368",
		Rewards = {
			BaseEXP = 150,
			BaseCash = 800,
		},
		-- REQUIRED: Tasks array
		Tasks = {
			{
				Description = "Collect 4 crates",
				MaxProgress = 4,
				DisplayText = "Collect crates scattered around the island",
				ProgressEvent = "ItemCollected", -- Event to listen for
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
	["DailyDeliverPackage_Passive"] = {
		Name = "DailyDeliverPackage_Passive",
		DisplayName = "Daily Delivery (Auto)",
		Description = "Deliver a package to the marked location",
		TrackingMode = "Passive", -- Automatic progress tracking
		TaskMode = "Sequential",
		Image = "rbxassetid://0",
		Rewards = {
			BaseEXP = 200,
			BaseCash = 1000,
		},
		Requirements = {
			MinLevel = 1,
		},
		Category = "Delivery",
		-- REQUIRED: Tasks array
		Tasks = {
			{
				Description = "Deliver 1 package",
				MaxProgress = 1,
				DisplayText = "Deliver a package to the marked location",
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

	["DailyAdventure"] = {
		Name = "DailyAdventure",
		DisplayName = "Island Adventure",
		Description = "Complete a series of challenges around the island",
		TrackingMode = "Active",
		TaskMode = "Sequential", -- Tasks unlock in sequence
		Image = "rbxassetid://112130465285368",
		Rewards = {
			BaseEXP = 500,
			BaseCash = 2500,
		},
		Requirements = {
			MinLevel = 5,
		},
		-- REQUIRED: Multi-task array
		Tasks = {
			{
				Description = "Collect 5 crates",
				MaxProgress = 5,
				DisplayText = "Collect crates scattered around the island",
				ServerSideQuestName = "PickUpItems",
				PickupConfig = {
					HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
				},
			},
			{
				Description = "Deliver 2 packages",
				MaxProgress = 2,
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

	["DailyChallenges"] = {
		Name = "DailyChallenges",
		DisplayName = "Daily Challenges",
		Description = "Complete multiple challenges simultaneously",
		TrackingMode = "Active",
		TaskMode = "Parallel", -- All tasks active at once
		Image = "rbxassetid://112130465285368",
		Rewards = {
			BaseEXP = 600,
			BaseCash = 3000,
		},
		Requirements = {
			MinLevel = 10,
		},
		-- REQUIRED: Multi-task array
		Tasks = {
			{
				Description = "Collect 3 crates",
				MaxProgress = 3,
				DisplayText = "Collect crates around the island",
				ServerSideQuestName = "PickUpItems",
				PickupConfig = {
					HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
				},
			},
			{
				Description = "Deliver 2 packages",
				MaxProgress = 2,
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

return DailyQuests
