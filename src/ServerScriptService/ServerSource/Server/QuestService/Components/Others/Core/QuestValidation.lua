--[[
    QuestValidation.lua

    Validates quest structures to ensure they follow the required Tasks array format.
    
    🚨 CRITICAL: Component Module Pattern
    - Must define .Init() and .Start() methods
    - Service references initialized in .Init()
]]

local QuestValidation = {}

---- Service References (initialized in .Init())
local QuestService

--[[
    Validate quest definition structure
    @param questDef table - Quest definition
    @param questName string - Quest name for error messages
    @return boolean, string - Success status and error message if failed
]]
function QuestValidation.ValidateQuestDefinition(questDef, questName)
	if not questDef then
		return false, "Quest definition is nil"
	end

	-- Ensure Tasks array exists
	if not questDef.Tasks then
		return false, string.format("Quest '%s' missing required Tasks array", questName)
	end

	-- Ensure Tasks is a table
	if type(questDef.Tasks) ~= "table" then
		return false, string.format("Quest '%s' Tasks must be a table", questName)
	end

	-- Ensure Tasks is not empty
	if #questDef.Tasks == 0 then
		return false, string.format("Quest '%s' has empty Tasks array", questName)
	end

	-- Validate each task
	for taskIndex, taskDef in ipairs(questDef.Tasks) do
		if not taskDef.MaxProgress or taskDef.MaxProgress <= 0 then
			return false, string.format("Quest '%s' Task %d has invalid MaxProgress", questName, taskIndex)
		end

		if not taskDef.Description or taskDef.Description == "" then
			return false, string.format("Quest '%s' Task %d missing Description", questName, taskIndex)
		end
	end

	-- Ensure TaskMode is valid
	if questDef.TaskMode and questDef.TaskMode ~= "Sequential" and questDef.TaskMode ~= "Parallel" then
		return false, string.format("Quest '%s' has invalid TaskMode: %s", questName, tostring(questDef.TaskMode))
	end

	return true, nil
end

--[[
    Validate player quest data structure
    @param quest table - Player's quest data
    @param questDef table - Quest definition
    @return boolean, string - Success status and error message if failed
]]
function QuestValidation.ValidatePlayerQuestData(quest, questDef)
	if not quest then
		return false, "Player quest data is nil"
	end

	if not quest.Tasks then
		return false, "Player quest data missing Tasks array"
	end

	-- Ensure task count matches definition
	if #quest.Tasks ~= #questDef.Tasks then
		return false,
			string.format("Task count mismatch: Player has %d, Definition has %d", #quest.Tasks, #questDef.Tasks)
	end

	-- Validate each task
	for taskIndex, taskData in ipairs(quest.Tasks) do
		local taskDef = questDef.Tasks[taskIndex]

		if not taskDef then
			return false, string.format("Task %d missing in quest definition", taskIndex)
		end

		if taskData.Progress > taskDef.MaxProgress then
			return false,
				string.format(
					"Task %d progress (%d) exceeds MaxProgress (%d)",
					taskIndex,
					taskData.Progress,
					taskDef.MaxProgress
				)
		end

		if taskData.Progress < 0 then
			return false, string.format("Task %d has negative progress: %d", taskIndex, taskData.Progress)
		end
	end

	return true, nil
end

--[[
    Get current active task for a sequential quest
    @param quest table - Player's quest data
    @return number - Task index (1-based), or nil if all tasks completed
]]
function QuestValidation.GetCurrentActiveTask(quest)
	if not quest or not quest.Tasks then
		return nil
	end

	-- Find first incomplete task
	for i, task in ipairs(quest.Tasks) do
		if not task.Completed then
			return i
		end
	end

	-- All tasks completed
	return nil
end

--[[
    Validate all quests in a quest definition table
    @param questDefinitions table - Table of quest definitions
    @param questType string - Type name for error messages (e.g., "Daily", "Weekly")
    @return boolean, table - Success status and table of errors (if any)
]]
function QuestValidation.ValidateAllQuests(questDefinitions, questType)
	local errors = {}
	local allValid = true

	for questName, questDef in pairs(questDefinitions) do
		local isValid, errorMsg = QuestValidation.ValidateQuestDefinition(questDef, questName)

		if not isValid then
			allValid = false
			table.insert(errors, {
				QuestType = questType,
				QuestName = questName,
				Error = errorMsg,
			})
		end
	end

	return allValid, errors
end

--[[
    🚨 COMPONENT LIFECYCLE METHODS
    Component modules MUST implement .Start() and .Init()
]]

-- Called after all components initialized (deferred)
function QuestValidation.Start() end

-- Called during component initialization
function QuestValidation.Init()
	local Knit = require(game.ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

	---- Knit Services
	QuestService = Knit.GetService("QuestService")
end

return QuestValidation
