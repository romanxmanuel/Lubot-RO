local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

local PunchSettings

function module.Start() end

function module.Init()
	local datas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
	PunchSettings = require(datas:WaitForChild("Combat"):WaitForChild("PunchSettings", 10))
end

function module:GetSettings()
	return PunchSettings
end

return module
