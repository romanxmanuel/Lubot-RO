--[[
	KillMonsterTester.lua
	
	Testing utilities for the KillMonster quest system
	Use this in Studio to test the monster kill quest functionality
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local KillMonsterTester = {}

---- Knit Services
local QuestService
local ProfileService

--[[
	Start the KillMonster quest for a player
	@param player Player
]]
function KillMonsterTester.StartKillMonsterQuest(player)
	if not QuestService then
		warn("QuestService not initialized")
		return
	end
	
	-- Track the KillMonster quest
	QuestService:TrackSideQuest(player, "SideQuest", "KillMonster")
	print("✅ Started KillMonster quest for:", player.Name)
	print("   Quest: Kill 5x Monster A")
end

--[[
	Check quest progress for a player
	@param player Player
]]
function KillMonsterTester.CheckProgress(player)
	if not ProfileService then
		warn("ProfileService not initialized")
		return
	end
	
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("No profile data for player:", player.Name)
		return
	end
	
	local quest = profileData.SideQuests["KillMonster"]
	if not quest then
		print("❌ KillMonster quest not started for:", player.Name)
		return
	end
	
	print("📊 KillMonster Quest Progress for:", player.Name)
	print("   Quest Name:", quest.Name)
	print("   Completed:", quest.Completed)
	
	if quest.Tasks then
		for taskIndex, taskData in ipairs(quest.Tasks) do
			print(string.format("   Task %d: %d/%d (Completed: %s)", 
				taskIndex, 
				taskData.Progress, 
				taskData.MaxProgress, 
				tostring(taskData.Completed)
			))
		end
	end
end

--[[
	Reset the quest for a player (for testing)
	@param player Player
]]
function KillMonsterTester.ResetQuest(player)
	if not ProfileService then
		warn("ProfileService not initialized")
		return
	end
	
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end
	
	-- Reset quest data
	if profileData.SideQuests["KillMonster"] then
		profileData.SideQuests["KillMonster"] = {
			Name = "KillMonster",
			Completed = false,
			Tasks = {
				{
					Description = "Defeat 5 × Monster A",
					Progress = 0,
					MaxProgress = 5,
					Completed = false,
				}
			}
		}
		
		ProfileService:ChangeData(player, {"SideQuests"}, profileData.SideQuests)
		print("🔄 Reset KillMonster quest for:", player.Name)
	end
end

--[[
	Test the complete flow
	@param player Player
]]
function KillMonsterTester.TestFullFlow(player)
	print("🧪 Testing KillMonster Quest System")
	print("=====================================")
	
	-- Reset first
	KillMonsterTester.ResetQuest(player)
	task.wait(0.5)
	
	-- Start quest
	KillMonsterTester.StartKillMonsterQuest(player)
	task.wait(0.5)
	
	-- Check initial progress
	print("\n📊 Initial Progress:")
	KillMonsterTester.CheckProgress(player)
	
	print("\n✅ Test complete!")
	print("   Now go kill Monster A to test quest progress tracking")
end

-- Initialize
function KillMonsterTester.Init()
	QuestService = Knit.GetService("QuestService")
	ProfileService = Knit.GetService("ProfileService")
end

return KillMonsterTester
