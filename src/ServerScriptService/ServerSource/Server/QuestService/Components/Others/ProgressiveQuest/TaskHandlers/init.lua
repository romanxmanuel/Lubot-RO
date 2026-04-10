--[[
	TaskHandlers/init.lua
	
	Registry for pluggable task handlers.
	Maps task description patterns to handler implementations.
]]

local TaskHandlerRegistry = {}

local handlers = {}

--[[
	Register handlers on initialization
]]
function TaskHandlerRegistry.Init()
	-- Load task handlers
	local LevelTaskHandler = require(script.LevelTaskHandler)
	
	-- Register handlers
	table.insert(handlers, LevelTaskHandler.new())
	
	-- Future handlers can be added here:
	-- table.insert(handlers, RebirthTaskHandler.new())
	-- table.insert(handlers, ArmoryTaskHandler.new())
	-- etc.
end

--[[
	Get handler for a task description
	@param taskDescription string - Task description pattern
	@return TaskHandlerBase | nil
]]
function TaskHandlerRegistry.GetHandler(taskDescription)
	for _, handler in ipairs(handlers) do
		if handler:Matches(taskDescription) then
			return handler
		end
	end
	return nil
end

-- Initialize on module load
TaskHandlerRegistry.Init()

return TaskHandlerRegistry
