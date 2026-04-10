local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local CombatController = Knit.CreateController({
	Name = "CombatController",
	Instance = script,
})

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 10)
CombatController.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	CombatController.Components[v.Name] = require(v)
end
CombatController.GetComponent = require(componentsFolder["Get()"])
CombatController.SetComponent = require(componentsFolder["Set()"])

--- Knit Services

--- Knit Controllers

function CombatController:KnitStart()
	-- Post-init hooks handled by components
end

function CombatController:KnitInit()
	componentsInitializer(script)
end

return CombatController
