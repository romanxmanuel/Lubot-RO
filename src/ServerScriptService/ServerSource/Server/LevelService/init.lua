local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

---- Utilities
local ProfileSeeder = require(ReplicatedStorage.SharedSource.Utilities.Levels.ProfileSeeder)

local LevelService = Knit.CreateService({
	Name = "LevelService",
	Instance = script,
	Client = {
		AddExp = Knit.CreateSignal(),
		GetAllTypesData = Knit.CreateProperty({}),
		LevelUp = Knit.CreateSignal(),
		Rebirthed = Knit.CreateSignal(),
	},
})

---- Remote Events
local addExpRemote
local getLevelDataRemote

---- Knit Services
local ProfileService

-- Thin service methods delegating to components
function LevelService:AddExp(player, amount, levelType)
	return LevelService.SetComponent:AddExp(player, amount, levelType)
end

function LevelService:LoseExp(player, amount, levelType)
	return LevelService.SetComponent:LoseExp(player, amount, levelType)
end

function LevelService:AddRebirth(player, amount, levelType)
	return LevelService.SetComponent:AddRebirth(player, amount, levelType)
end

function LevelService:ResetLevel(player, levelType)
	return LevelService.SetComponent:ResetLevel(player, levelType)
end

function LevelService:SetRebirthCount(player, count, levelType)
	return LevelService.SetComponent:SetRebirthCount(player, count, levelType)
end

function LevelService:SetLevel(player, targetLevel, levelType)
	return LevelService.SetComponent:SetLevel(player, targetLevel, levelType)
end

function LevelService:CanRebirth(player, levelType)
	return LevelService.SetComponent:CanRebirth(player, levelType)
end

function LevelService:PerformRebirth(player, levelType)
	return LevelService.SetComponent:PerformRebirth(player, levelType)
end

-- Removed single ActiveLevelType setter; now all types are tracked.
function LevelService:GetAllTypesData(player)
	return LevelService.GetComponent:GetAllTypesData(player)
end

function LevelService.Client:GetAllTypesData(player)
	return LevelService:GetAllTypesData(player)
end

function LevelService.Client:CanRebirth(player, levelType)
	return LevelService:CanRebirth(player, levelType)
end

function LevelService.Client:PerformRebirth(player, levelType)
	return LevelService:PerformRebirth(player, levelType)
end

function LevelService:KnitStart()
	-- Seed level types for existing players
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(function()
			local _, data = ProfileService:GetProfile(player)
			if data and data.Leveling then
				local seededTypes = ProfileSeeder.EnsureAllTypesExist(data.Leveling)
				if #seededTypes > 0 then
					print(
						string.format(
							"[LevelService] Seeded types for %s: %s",
							player.Name,
							table.concat(seededTypes, ", ")
						)
					)
				end
			end
		end)
	end

	-- Seed level types for new players
	Players.PlayerAdded:Connect(function(player)
		task.wait(1) -- Wait for profile to load
		local _, data = ProfileService:GetProfile(player)
		if data and data.Leveling then
			local seededTypes = ProfileSeeder.EnsureAllTypesExist(data.Leveling)
			if #seededTypes > 0 then
				print(
					string.format(
						"[LevelService] Seeded types for %s: %s",
						player.Name,
						table.concat(seededTypes, ", ")
					)
				)
			end
		end
	end)
end

function LevelService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
end

return LevelService
