--[[
    KillNPC.lua

    Side quest type: Kill specific NPCs (monsters/rigs).
    Now listens to DamageService.Killed event for NPC kills.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local QuestSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

-- Knit Services
local ProfileService
local QuestService
local DamageService

-- Components
local SideQuestBase = require(script.Parent.Parent.SideQuestBase)
local QuestProgressHandler
local QuestNPCSpawner

local KillNPC = {}
KillNPC.__index = KillNPC

-- Inherit from SideQuestBase
setmetatable(KillNPC, { __index = SideQuestBase })

KillNPC.ActiveKills = {}

KillNPC.KilledConnection = nil

-- Track recent kills to prevent duplicate registration from both DamageService and client ReportKill
-- { [player] = { [taskIndex] = { [victimName] = lastKillTime } } }
KillNPC.RecentKills = {}

-- Cooldown in seconds to prevent duplicate kill registration
local KILL_DEDUP_COOLDOWN = 1.0

-- Forward declaration for IsDuplicateKill (defined after helper functions)
local IsDuplicateKill

--[[
	Return registration config for QuestTypeManager auto-discovery
	This enables zero-touch signal/method registration in QuestService
	@return table - Registration configuration
]]
function KillNPC.GetRegistration()
	return {
		Name = "KillNPC",
		Signals = { "TrackKillTargets", "ClearKillTargets" },
		ClientMethods = {
			{ Name = "ReportKill", Handler = "Client_ReportKill" },
		},
	}
end

--[[
	Client method to report a kill from the client-side death detection.
	Validates that the player has an active kill task for this target.
	@param player Player - The player reporting the kill
	@param victimName string - The name of the killed NPC
	@param taskIndex number - The task index for this kill quest
	@return boolean - Whether the kill was registered successfully
]]
function KillNPC:Client_ReportKill(player, victimName, taskIndex)
	-- Validate inputs
	if not player or type(victimName) ~= "string" or type(taskIndex) ~= "number" then
		return false
	end
	
	-- Check if player has active kills
	if not KillNPC.ActiveKills[player] then
		return false
	end
	
	-- Check if the task exists for this player
	local killData = KillNPC.ActiveKills[player][taskIndex]
	if not killData then
		return false
	end
	
	-- Validate the target name matches
	if killData.TargetName ~= victimName then
		return false
	end
	
	-- Check for duplicate kill (prevents double registration from DamageService + client ReportKill)
	if IsDuplicateKill(player, taskIndex, victimName) then
		return false
	end
	
	-- Register the kill progress
	local success = QuestProgressHandler.IncrementTaskProgress(
		player,
		killData.QuestType,
		killData.QuestNum,
		taskIndex,
		1
	)
	
	if success then
		self:TryCompleteQuest(player, killData.QuestType, killData.QuestNum)
	end
	
	return success
end

function KillNPC.new()
	local self = SideQuestBase.new()
	setmetatable(self, KillNPC)
	return self
end

function KillNPC:SpawnObjectivesForTask(player, questType, questNum, taskIndex, taskDef)
	local killConfig = taskDef.KillConfig or {}
	local targetName = killConfig.TargetName

	if not targetName then
		return
	end

	KillNPC.ActiveKills[player] = KillNPC.ActiveKills[player] or {}
	KillNPC.ActiveKills[player][taskIndex] = {
		QuestType = questType,
		QuestNum = questNum,
		TargetName = targetName,
	}

	-- Spawn NPCs using QuestNPCSpawner
	if QuestNPCSpawner then
		QuestNPCSpawner:ShowAllMonsters()
	end

	-- Get spawned NPC models from QuestNPCSpawner
	local monsters = QuestNPCSpawner and QuestNPCSpawner.SpawnedNPCs or {}

	if #monsters > 0 then
		local highlightConfig = killConfig.HighlightConfig or {
			FillColor = Color3.fromRGB(255, 0, 0),
			OutlineColor = Color3.fromRGB(255, 255, 255),
			FillTransparency = 0.5,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		}

		if QuestService and QuestService.Client.TrackKillTargets then
			QuestService.Client.TrackKillTargets:Fire(player, {
				Monsters = monsters,
				Config = highlightConfig,
				TaskIndex = taskIndex,
				TargetName = targetName,
			})
		end
	end
end

-- Helper function to check if a model is an NPC (not a player character)
local function IsNPC(model)
	if not model or not model:IsA("Model") then
		return false
	end

	-- Check if it's a player's character
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		return false -- It's a player, not an NPC
	end

	-- It's not a player character, so it's an NPC
	return true
end

--[[
	Check if a kill was recently registered (deduplication).
	Returns true if this is a duplicate kill, false if it's new.
	@param player Player
	@param taskIndex number
	@param victimName string
	@return boolean - true if duplicate (should skip), false if new kill
]]
IsDuplicateKill = function(player, taskIndex, victimName)
	local currentTime = os.clock()
	
	-- Initialize tracking tables if needed
	if not KillNPC.RecentKills[player] then
		KillNPC.RecentKills[player] = {}
	end
	if not KillNPC.RecentKills[player][taskIndex] then
		KillNPC.RecentKills[player][taskIndex] = {}
	end
	
	local lastKillTime = KillNPC.RecentKills[player][taskIndex][victimName]
	
	-- Check if this kill was recently registered
	if lastKillTime and (currentTime - lastKillTime) < KILL_DEDUP_COOLDOWN then
		return true -- Duplicate kill, skip it
	end
	
	-- Record this kill time
	KillNPC.RecentKills[player][taskIndex][victimName] = currentTime
	return false -- New kill, process it
end

function KillNPC:OnKilled(killer, victim, damageInfo)
	-- Only process if victim is an NPC (not a player)
	if not IsNPC(victim) then
		return
	end

	if not killer or not victim then
		return
	end

	-- Get the player from the killer character
	local player = Players:GetPlayerFromCharacter(killer)
	if not player then
		return -- Killer is not a player
	end

	local npcName = victim.Name

	if not KillNPC.ActiveKills[player] then
		return
	end

	-- Get total damage dealt by this player to calculate credit
	local totalDamage = 0
	if DamageService then
		totalDamage = DamageService:GetDamageDealt(killer, victim) or 0
	end

	for taskIndex, killData in pairs(KillNPC.ActiveKills[player]) do
		if npcName == killData.TargetName then
			-- Check for duplicate kill (prevents double registration from DamageService + client ReportKill)
			if IsDuplicateKill(player, taskIndex, npcName) then
				continue
			end
			
			local success = QuestProgressHandler.IncrementTaskProgress(
				player,
				killData.QuestType,
				killData.QuestNum,
				taskIndex,
				1
			)

			if success then
				self:TryCompleteQuest(player, killData.QuestType, killData.QuestNum)
			end
		end
	end
end

function KillNPC:CleanUpTask(player, taskIndex)
	if KillNPC.ActiveKills[player] then
		KillNPC.ActiveKills[player][taskIndex] = nil
	end
	
	-- Clean up recent kills tracking for this task
	if KillNPC.RecentKills[player] then
		KillNPC.RecentKills[player][taskIndex] = nil
	end

	if QuestService and QuestService.Client.ClearKillTargets then
		QuestService.Client.ClearKillTargets:Fire(player, taskIndex)
	end
end

function KillNPC:CleanUp(player)
	KillNPC.ActiveKills[player] = nil

	-- Clean up all recent kills tracking for this player
	KillNPC.RecentKills[player] = nil

	-- Despawn quest NPCs using QuestNPCSpawner
	if QuestNPCSpawner then
		QuestNPCSpawner:HideAllMonsters()
	end

	if QuestService and QuestService.Client.ClearKillTargets then
		QuestService.Client.ClearKillTargets:Fire(player, nil)
	end
end

function KillNPC.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService  = Knit.GetService("QuestService")
	DamageService = Knit.GetService("DamageService")

	local ComponentsFolder = script.Parent.Parent.Parent.Parent
	QuestProgressHandler = require(ComponentsFolder.Others.Core.QuestProgressHandler)

	-- Load QuestNPCSpawner for spawning/despawning quest NPCs
	local ManagersFolder = ComponentsFolder.Others.Managers
	local spawnerModule = ManagersFolder:FindFirstChild("QuestNPCSpawner")
	if spawnerModule then
		QuestNPCSpawner = require(spawnerModule)
		if QuestNPCSpawner.Init then
			task.spawn(function()
				QuestNPCSpawner.Init()
			end)
		end
	else
		warn("⚠️ KillNPC: QuestNPCSpawner not found - quest NPCs won't spawn")
	end

	-- Listen to the Killed signal from DamageService
	if DamageService and DamageService.Killed then
		local instance = KillNPC.new()

		KillNPC.KilledConnection = DamageService.Killed:Connect(function(killer, victim, damageInfo)
			instance:OnKilled(killer, victim, damageInfo)
		end)

		print("✅ KillNPC quest system initialized and listening to DamageService.Killed")
	else
		warn("⚠️ DamageService.Killed signal not found! KillNPC quests will not work.")
	end
end

local instance = KillNPC.new()

return instance