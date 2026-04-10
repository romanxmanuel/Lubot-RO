local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local module = {}

---- Utilities
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

---- Knit Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ProfileService

---- Datas

---- Assets

function module.Start()
	-- No-op
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

-- Public: return table of all types with display names merged from config
function module:GetAllTypesData(player)
	local _, data = ProfileService:GetProfile(player)
	if not data or not data.Leveling then return {} end
	local out = {}
	for levelType, t in pairs(data.Leveling.Types) do
		local names = (LevelingConfig.Types and LevelingConfig.Types[levelType]) or {}
		out[levelType] = {
			Exp = t.Exp,
			Level = t.Level,
			MaxExp = t.MaxExp,
			Rebirths = (data.Leveling.Rebirths and data.Leveling.Rebirths[levelType]) or 0,
			Name = names.Name,
			ExpName = names.ExpName,
		}
	end
	return out
end

return module
