--[[
    SoundPlayer.lua
    
    Quest-specific sound management component.
    Automatically initializes quest sounds from QuestSettings configuration on client startup.
    
    Features:
    - Reads sound configuration from QuestSettings.lua
    - Automatically applies SoundIds and properties to Sound objects
    - Provides convenience functions for playing quest sounds
    - Clean component lifecycle integration (.Init() and .Start())
    
    Usage Example:
        -- Get a quest sound by name
        local sound = QuestController.Components.SoundPlayer.GetSound("Completed")
        
        -- Play a quest sound with optional overrides
        QuestController.Components.SoundPlayer.PlayQuestSound("QuestRewardStart", { Volume = 0.8 })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- Datas
local QuestSettings = require(ReplicatedStorage.SharedSource.Datas.GameSettings.QuestSettings)

local SoundPlayer = {}

---- References
local questSoundsFolder

--[[
    Parses a parent path string and returns the instance, creating folders if needed
    
    @param pathString string - Path like "ReplicatedStorage.Assets.Sounds.Quests"
    @return Instance? - The found/created instance or nil
]]
local function ParsePath(pathString)
	if not pathString or pathString == "" then
		return nil
	end

	-- Split path by dots
	local parts = string.split(pathString, ".")
	local current = game

	for i, part in ipairs(parts) do
		local found = current:FindFirstChild(part)
		if not found then
			-- Only create folders if we're past the service level (e.g., past "ReplicatedStorage")
			if i > 1 then
				-- Create a new Folder
				found = Instance.new("Folder")
				found.Name = part
				found.Parent = current
			else
				warn(string.format("[QuestController.SoundPlayer] Service not found: '%s' in '%s'", part, pathString))
				return nil
			end
		end
		current = found
	end

	return current
end

--[[
    Converts a RollOffMode string to the appropriate Enum value
    
    @param modeValue any - Either an Enum.RollOffMode value or string
    @return Enum.RollOffMode - The RollOffMode enum value
]]
local function ConvertRollOffMode(modeValue)
	-- If already an enum, return it
	if typeof(modeValue) == "EnumItem" and modeValue.EnumType == Enum.RollOffMode then
		return modeValue
	end

	-- Try to convert string to enum
	if type(modeValue) == "string" then
		local success, enum = pcall(function()
			return Enum.RollOffMode[modeValue]
		end)
		if success then
			return enum
		end
	end

	-- Default fallback
	warn(
		string.format(
			"[QuestController.SoundPlayer] Invalid RollOffMode value '%s', defaulting to Inverse",
			tostring(modeValue)
		)
	)
	return Enum.RollOffMode.Inverse
end

--[[
    Initialize sounds from configuration
    
    @param soundsConfig table - Sound configuration from QuestSettings
    @param parentPath string - Parent path for sound objects
    @return boolean, string? - Success status and optional error message
]]
function SoundPlayer.InitializeSounds(soundsConfig, parentPath)
	if not soundsConfig or not parentPath then
		return false, "Missing soundsConfig or parentPath"
	end

	-- Parse parent path
	local parentInstance = ParsePath(parentPath)
	if not parentInstance then
		return false, string.format("Failed to find parent path: %s", parentPath)
	end

	-- Store reference for later use
	questSoundsFolder = parentInstance

	local successCount = 0
	local errorCount = 0
	local errors = {}

	-- Iterate through sound configs (skip Config table)
	for soundName, soundConfig in soundsConfig do
		-- Skip the Config table
		if soundName == "Config" then
			continue
		end

		-- Validate sound config
		if type(soundConfig) ~= "table" or not soundConfig.SoundId then
			table.insert(errors, string.format("Invalid config for '%s'", soundName))
			errorCount += 1
			continue
		end

		-- Find or create Sound object
		local soundObject = parentInstance:FindFirstChild(soundName)
		if not soundObject then
			-- Create new Sound object
			soundObject = Instance.new("Sound")
			soundObject.Name = soundName
			soundObject.Parent = parentInstance
		end

		-- Apply sound properties from config
		local applySuccess, applyError = pcall(function()
			soundObject.SoundId = soundConfig.SoundId or ""

			if soundConfig.Volume then
				soundObject.Volume = soundConfig.Volume
			end

			if soundConfig.PlaybackSpeed then
				soundObject.PlaybackSpeed = soundConfig.PlaybackSpeed
			end

			if soundConfig.Looped ~= nil then
				soundObject.Looped = soundConfig.Looped
			end

			if soundConfig.RollOffMaxDistance then
				soundObject.RollOffMaxDistance = soundConfig.RollOffMaxDistance
			end

			if soundConfig.RollOffMinDistance then
				soundObject.RollOffMinDistance = soundConfig.RollOffMinDistance
			end

			if soundConfig.RollOffMode then
				soundObject.RollOffMode = ConvertRollOffMode(soundConfig.RollOffMode)
			end
		end)

		if applySuccess then
			successCount += 1
		else
			errorCount += 1
			table.insert(errors, string.format("Failed to apply config for '%s': %s", soundName, tostring(applyError)))
			warn(
				string.format(
					"[QuestController.SoundPlayer] Error configuring '%s': %s",
					soundName,
					tostring(applyError)
				)
			)
		end
	end

	-- Return summary
	local summary = string.format("Initialized %d sounds (%d errors)", successCount, errorCount)
	if errorCount > 0 then
		return false, string.format("%s\nErrors: %s", summary, table.concat(errors, "; "))
	end

	return true, summary
end

--[[
    Get a quest sound by name
    
    @param soundName string - Name of the sound (e.g., "Completed", "QuestRewardStart")
    @return Sound? - The Sound object or nil if not found
]]
function SoundPlayer.GetSound(soundName)
	if not questSoundsFolder then
		warn("[QuestController.SoundPlayer] Quest sounds folder not initialized")
		return nil
	end

	local sound = questSoundsFolder:FindFirstChild(soundName)
	if not sound then
		warn(string.format("[QuestController.SoundPlayer] Sound '%s' not found", soundName))
	end

	return sound
end

--[[
    Play a quest sound with optional property overrides
    
    @param soundName string - Name of the sound to play
    @param properties table? - Optional table of properties to override (e.g., {Volume = 0.8})
    @param parent Instance? - Optional parent to play the sound from (defaults to workspace)
]]
function SoundPlayer.PlayQuestSound(soundName, properties, parent)
	local sound = SoundPlayer.GetSound(soundName)
	if not sound then
		return
	end

	-- Apply property overrides if provided
	if properties then
		for prop, value in pairs(properties) do
			local success, err = pcall(function()
				sound[prop] = value
			end)
			if not success then
				warn(
					string.format(
						"[QuestController.SoundPlayer] Failed to set property '%s' on sound '%s': %s",
						prop,
						soundName,
						err
					)
				)
			end
		end
	end

	-- Play the sound
	sound:Play()
end

--[[
    Component lifecycle: Called after all components initialized
    Automatically configures quest sounds from QuestSettings configuration
]]
function SoundPlayer.Start()
	-- Check if quest sounds are enabled
	if not QuestSettings.Sounds then
		warn("[QuestController.SoundPlayer] No sound configuration found in QuestSettings")
		return
	end

	if not QuestSettings.Sounds.Config.EnableQuestSounds then
		return
	end

	-- Initialize sounds from configuration
	local success, result = SoundPlayer.InitializeSounds(QuestSettings.Sounds, QuestSettings.Sounds.Config.ParentPath)

	if not success then
		warn(string.format("❌ [QuestController.SoundPlayer] Failed to initialize quest sounds: %s", result))
	end
end

function SoundPlayer.Init() end

return SoundPlayer
