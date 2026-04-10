--[[
	LevelTaskHandler.lua
	
	Handles "Reach level X" tasks.
	Checks player's current level from their profile.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local TaskHandlerBase = require(script.Parent.TaskHandlerBase)

local LevelTaskHandler = setmetatable({}, {__index = TaskHandlerBase})
LevelTaskHandler.__index = LevelTaskHandler

---- Knit Services
local ProfileService

--[[
	Constructor
]]
function LevelTaskHandler.new()
	local self = setmetatable(TaskHandlerBase.new("Reach level"), LevelTaskHandler)
	return self
end

--[[
	Get player's current level
	@param player Player
	@return number
]]
function LevelTaskHandler:GetProgress(player)
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return 0
	end
	
	-- Use new leveling system
	if profileData.Leveling and profileData.Leveling.Types and profileData.Leveling.Types.levels then
		return profileData.Leveling.Types.levels.Level or 1
	end
	
	return 1
end

-- Initialize ProfileService reference
function LevelTaskHandler.Init()
	ProfileService = Knit.GetService("ProfileService")
end

-- Auto-initialize
LevelTaskHandler.Init()

return LevelTaskHandler
