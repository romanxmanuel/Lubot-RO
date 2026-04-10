--!strict
-- Swords.lua
-- All sword tool definitions
return {
	sword_katana = {
		-- === IDENTIFICATION ===
		ToolId = "sword_katana",
		AssetName = "Katana",
		-- === ORGANIZATION ===
		Category = "Weapons",
		Subcategory = "Swords",
		-- === GAMEPLAY STATS ===
		Stats = {
			Damage = 15,
			Range = 10,
			Cooldown = 0.8,
		},
		-- === BEHAVIOR CONFIGURATION ===
		BehaviorConfig = {
			ActivationType = "Click",
			EnableSlash = true, -- Crucial for SlashHandler detection
			-- Melee-specific data
			MeleeData = {
				HitboxSize = Vector3.new(2, 4, 8),
				HitboxOffset = Vector3.new(0, 0, -4),
				SwingDuration = 0.3,
			},
		},
		-- === OPTIONAL PROPERTIES ===
		RequiredLevel = 1,
		Rarity = "Common",
        Description = "A sleek, curved blade capable of rapid slashes.",
    },

    sword_classic = {
        -- === IDENTIFICATION ===
        ToolId = "sword_classic",
        AssetName = "ClassicSword", -- Matches Tool instance name in Assets folder
        -- === ORGANIZATION ===
        Category = "Weapons",
        Subcategory = "Swords",
        -- Asset location: ReplicatedStorage.Assets.Tools.Weapons.Swords.ClassicSword

        -- === GAMEPLAY STATS ===
        Stats = {
            Damage = 25,
            Range = 8,
            Cooldown = 0.8,
        },

        -- === BEHAVIOR CONFIGURATION ===
        BehaviorConfig = {
            ActivationType = "Click",

            -- Melee-specific data
            MeleeData = {
                HitboxSize = Vector3.new(3, 3, 6),
                HitboxOffset = Vector3.new(0, 0, -3),
                SwingDuration = 0.4,
            },
        },

        -- === OPTIONAL PROPERTIES ===
        RequiredLevel = 1,
        Rarity = "Common",
        Tradeable = true,
        MaxStack = 1,
        Description = "The classic Roblox sword. Simple but effective.",
    },
}