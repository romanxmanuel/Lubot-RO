--[[
    QuestSettings.lua

    Global game configuration settings.
    All values here are constants and should not be modified at runtime.
]]

local QuestSettings = {

	--========================================
	-- QUEST SYSTEM SETTINGS
	--========================================

	DailyAndWeeklyQuests = {
		-- Maximum number of daily quests a player can have active
		DailyMax = 3,

		-- Maximum number of weekly quests a player can have active
		WeeklyMax = 1,

		-- Time intervals (in seconds)
		DailyResetInterval = 24 * 60 * 60, -- 24 hours
		WeeklyResetInterval = 7 * 24 * 60 * 60, -- 7 days

		-- Reward multipliers
		RewardScaling = {
			-- EXP reward scales with player level
			ExpScalePerLevel = 1.05, -- 5% increase per level

			-- Cash reward scales with player level
			CashScalePerLevel = 1.08, -- 8% increase per level

			-- Weekly quests give bonus rewards
			WeeklyExpMultiplier = 2.5,
			WeeklyCashMultiplier = 3.0,
		},

		-- Default passive quest settings (can be overridden per-quest in PassiveConfig)
		PassiveQuestDefaults = {
			ShowProgressNotifications = true,
			NotificationThrottle = 0.25, -- seconds between notifications
			CompletionCheckInterval = 5, -- seconds
		},
	},

	MainQuests = {
		-- Starting quest number for new players
		StartingQuestNum = 1,

		-- Whether to auto-advance to next quest on completion
		AutoAdvance = true,

		-- Delay before auto-advancing (seconds)
		AutoAdvanceDelay = 2,

		-- Maximum quest number (for validation)
		-- ⚠️ IMPORTANT: Update this when you add new main quests in QuestDefinitions/Main.lua
		MaxQuestNum = 2, -- Currently 2 quests defined (Quest 1 and Quest 2)

		-- Animation Settings
		AnimationDuration = 4.5, -- Total animation duration (2 + 0.75 + 0.5 + 1 = 4.25, rounded to 4.5)
		EnableCompletionAnimation = true, -- Can be toggled for testing
	},

	SideQuests = {
		-- Maximum simultaneous tracked side quests per player
		MaxTrackedQuests = 1,

		-- Cooldown between starting side quests (seconds)
		StartCooldown = 5,

		-- Time before despawning quest objectives after completion (seconds)
		ObjectiveDespawnTime = 10,

		-- Automatically check side quest progress and completion
		-- When enabled, the system will continuously monitor quest progress
		-- When disabled, quests will only check progress on manual triggers
		EnableAutoCompletion = true,

		-- Item collection settings
		PickUpItems = {
			-- Minimum distance between spawned items
			MinSpawnDistance = 50,

			-- Maximum spawn radius from spawn point
			MaxSpawnRadius = 100,

			-- Item despawn time if not collected (seconds)
			ItemLifetime = 300, -- 5 minutes
		},
	},

	--========================================
	-- QUEST VALIDATION SETTINGS
	--========================================

	Validation = {
		-- Run validation on server startup
		ValidateOnStartup = true,

		-- Auto-reset invalid player quests on join
		AutoResetInvalidQuests = true,

		-- Warn if quest pool is too small for max quests
		WarnOnSmallQuestPool = true,
	},

	--========================================
	-- QUEST SCHEDULER SETTINGS
	--========================================

	Scheduler = {
		-- How often to check for quest resets (seconds)
		CheckInterval = 60, -- Once per minute

		-- Grace period for reset checks (seconds)
		-- Prevents missing resets due to server lag
		ResetGracePeriod = 5,
	},

	--========================================
	-- QUEST UI SETTINGS
	--========================================

	UI = {
		-- Animation durations (seconds)
		QuestStartAnimationDuration = 1,
		QuestCompleteAnimationDuration = 2,
		QuestProgressAnimationDuration = 0.5,

		-- Quest notification settings
		ShowQuestNotifications = true,
		NotificationDuration = 5,

		-- Quest tracker settings
		ShowQuestTracker = true,
		TrackerUpdateInterval = 1, -- Update tracker every second
	},

	--========================================
	-- QUEST SOUND SETTINGS
	--========================================

	Sounds = {
		-- Quest completion sound (plays when any quest is completed)
		Completed = {
			SoundId = "rbxassetid://4612383790",
			Volume = 0.2,
			PlaybackSpeed = 1.0,
			Looped = false,
			RollOffMaxDistance = 10000,
			RollOffMinDistance = 10,
			RollOffMode = Enum.RollOffMode.Inverse,
		},

		-- Quest reward animation sounds
		QuestRewardStart = {
			SoundId = "rbxassetid://109834429162104",
			Volume = 0.5,
			PlaybackSpeed = 1.0,
			Looped = false,
			RollOffMaxDistance = 10000,
			RollOffMinDistance = 10,
			RollOffMode = Enum.RollOffMode.InverseTapered,
		},

		QuestRewardEnd = {
			SoundId = "rbxassetid://135827493262206",
			Volume = 0.5,
			PlaybackSpeed = 1.0,
			Looped = false,
			RollOffMaxDistance = 10000,
			RollOffMinDistance = 10,
			RollOffMode = Enum.RollOffMode.InverseTapered,
		},

		-- New task added sound (currently exists but not yet implemented in quest flow)
		NewTaskAdded = {
			SoundId = "rbxassetid://98808933033389",
			Volume = 0.5,
			PlaybackSpeed = 1.0,
			Looped = false,
			RollOffMaxDistance = 10000,
			RollOffMinDistance = 10,
			RollOffMode = Enum.RollOffMode.InverseTapered,
		},

		-- Sound configuration options
		Config = {
			-- Parent location for sound instances
			ParentPath = "ReplicatedStorage.Assets.Sounds.Quests",

			-- Enable/disable quest sounds globally
			EnableQuestSounds = true,

			-- Fallback sound if specific sound fails to load
			FallbackSoundId = "rbxassetid://0",
		},
	},
}

return QuestSettings
