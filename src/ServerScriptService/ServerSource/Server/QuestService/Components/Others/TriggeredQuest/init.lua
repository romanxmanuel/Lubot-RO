--[[
	TriggeredQuest/init.lua
	
	Coordinator for side quests that are manually triggered by players.
	Routes quest tracking to appropriate type-specific handlers.
]]

local TriggeredQuest = {}

--[[
	Start a side quest
	@param player Player
	@param questType string - "Daily" or "Weekly"
	@param questNum number - Index in quest array
]]
function TriggeredQuest.StartQuest(player, questType, questNum)
	-- Delegated to specific quest type handlers in Types/ folder
	-- Called from SetComponent:TrackSideQuest()
end

return TriggeredQuest
