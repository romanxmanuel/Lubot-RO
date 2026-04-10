--[[
	QuestModeRouter.lua
	
	Routes quest operations to appropriate handlers based on TrackingMode.
	Provides utility functions to check quest tracking capabilities.
	
	Tracking Modes:
	- "Active": Quest requires explicit tracking and spawns world objectives
	- "Passive": Quest progresses automatically from game events
]]

local QuestModeRouter = {}

--[[
	Get the tracking mode for a quest
	@param questDef table - Quest definition
	@return string - "Active" or "Passive"
]]
function QuestModeRouter:GetQuestMode(questDef)
	if not questDef then
		return "Active" -- Default fallback
	end
	
	return questDef.TrackingMode or "Active" -- Default to Active for backward compatibility
end

--[[
	Check if a quest can be tracked (only Active quests)
	@param questDef table - Quest definition
	@return boolean - True if quest can be tracked
]]
function QuestModeRouter:CanTrack(questDef)
	local mode = self:GetQuestMode(questDef)
	return mode == "Active"
end

--[[
	Check if a quest is passive
	@param questDef table - Quest definition
	@return boolean - True if quest is passive
]]
function QuestModeRouter:IsPassive(questDef)
	local mode = self:GetQuestMode(questDef)
	return mode == "Passive"
end

--[[
	Check if a quest is active
	@param questDef table - Quest definition
	@return boolean - True if quest is active
]]
function QuestModeRouter:IsActive(questDef)
	local mode = self:GetQuestMode(questDef)
	return mode == "Active"
end

--[[
	Validate that a quest can be tracked
	Throws an error with descriptive message if tracking is not allowed
	@param questDef table - Quest definition
	@param questType string - Quest type ("Daily", "Weekly", etc.)
	@param questIdentifier string|number - Quest name or index
]]
function QuestModeRouter:ValidateCanTrack(questDef, questType, questIdentifier)
	if not questDef then
		error("Quest definition not found for " .. questType .. " quest: " .. tostring(questIdentifier))
	end
	
	if self:IsPassive(questDef) then
		error(
			string.format(
				"Cannot track passive quest '%s'. Passive quests progress automatically and don't require tracking.",
				questDef.DisplayName or questDef.Name or "Unknown"
			)
		)
	end
	
	if not questDef.ServerSideQuestName then
		error(
			string.format(
				"Active quest '%s' is missing ServerSideQuestName field.",
				questDef.DisplayName or questDef.Name or "Unknown"
			)
		)
	end
	
	return true
end

--[[
	Get user-friendly tracking mode name
	@param questDef table - Quest definition
	@return string - Display name for the tracking mode
]]
function QuestModeRouter:GetModeDisplayName(questDef)
	local mode = self:GetQuestMode(questDef)
	if mode == "Passive" then
		return "Always Active"
	elseif mode == "Active" then
		return "Manual Tracking"
	else
		return "Unknown"
	end
end

--[[
	Check if a quest requires spawned objectives
	@param questDef table - Quest definition
	@return boolean - True if objectives need to be spawned
]]
function QuestModeRouter:RequiresObjectives(questDef)
	return self:IsActive(questDef) and questDef.ServerSideQuestName ~= nil
end

return QuestModeRouter

