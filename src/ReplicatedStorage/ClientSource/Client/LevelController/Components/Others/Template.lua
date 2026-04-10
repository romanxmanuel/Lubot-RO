-- Template component for LevelController
-- Copy this file to create new components

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Controllers (add as needed)
-- local DataController

---- Configuration
-- local SomeConfig = require(ReplicatedStorage.SharedSource.Datas.SomeConfig)

---- Internal state
-- local someState = {}

-- Initialization function (called when component is loaded)
function module.Start()
	-- Component startup logic
end

-- Initialization function (called during Knit initialization)
function module.Init()
	-- Get controller references
	-- DataController = Knit.GetController("DataController")
end

-- Example public method
function module:ExampleMethod(parameter)
	-- Implementation here
	return "Example result: " .. tostring(parameter)
end

-- Example private method (use underscore prefix for internal methods)
function module:_InternalMethod()
	-- Private implementation
end

return module