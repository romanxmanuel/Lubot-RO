--[[
	TaskHandlerBase.lua
	
	Abstract base class for task handlers.
	Each handler implements logic for checking progress of a specific task type.
]]

local TaskHandlerBase = {}
TaskHandlerBase.__index = TaskHandlerBase

--[[
	Constructor
	@param taskPattern string - Pattern to match in task descriptions
]]
function TaskHandlerBase.new(taskPattern)
	local self = setmetatable({}, TaskHandlerBase)
	self.TaskPattern = taskPattern
	return self
end

--[[
	Check if this handler matches a task description
	@param taskDescription string
	@return boolean
]]
function TaskHandlerBase:Matches(taskDescription)
	return taskDescription:match(self.TaskPattern) ~= nil
end

--[[
	Get current progress for this task type (must be implemented by subclasses)
	@param player Player
	@return number - Current progress value
]]
function TaskHandlerBase:GetProgress(player)
	error("Must implement GetProgress() in subclass")
end

return TaskHandlerBase
