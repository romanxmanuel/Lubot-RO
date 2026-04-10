--[[
	QuestFactory.lua
	
	Factory pattern for creating quest instances.
	Routes quest creation to appropriate subclass based on type.
]]

local QuestFactory = {}

local questClasses = {}

--[[
	Register a quest class type
	@param questType string - Type identifier
	@param questClass table - Class constructor
]]
function QuestFactory.Register(questType, questClass)
	questClasses[questType] = questClass
end

--[[
	Create a quest instance
	@param questType string - "Main", "Daily", "Weekly", etc.
	@param questNum number | string - Quest identifier (optional)
	@return QuestBase - Quest instance or nil if type not found
]]
function QuestFactory.Create(questType, questNum)
	local questClass = questClasses[questType]
	
	if not questClass then
		warn("Invalid quest type: " .. tostring(questType))
		return nil
	end
	
	-- Create new instance
	return questClass.new(questNum)
end

--[[
	Initialize factory with available quest types
	Called during module initialization
]]
function QuestFactory.Init()
	local ComponentsFolder = script.Parent.Parent
	
	-- Register quest types
	local ProgressiveQuest = require(ComponentsFolder.ProgressiveQuest)
	QuestFactory.Register("Main", ProgressiveQuest)
	
	local RecurringQuest = require(ComponentsFolder.RecurringQuest)
	QuestFactory.Register("Daily", {
		new = function()
			return RecurringQuest.CreateDaily()
		end
	})
	QuestFactory.Register("Weekly", {
		new = function()
			return RecurringQuest.CreateWeekly()
		end
	})
end

return QuestFactory
