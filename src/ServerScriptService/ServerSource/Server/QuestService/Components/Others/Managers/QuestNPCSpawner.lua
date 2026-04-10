--[[
	QuestNPCSpawner.lua

	Server-side component that manages spawning/despawning of quest NPCs
	using NPC_Service. Spawns melee Bandit NPCs near the Kill_Bandit_Quest Spawner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestNPCSpawner = {}

-- Folder containing the spawner part
local QUEST_FOLDER_NAME = "Kill_Bandit_Quest"

-- Number of NPCs to spawn
local NPC_COUNT = 5

-- Offsets so NPCs don't stack on top of each other
local SPAWN_OFFSETS = {
	Vector3.new(0, 0, 0),
	Vector3.new(8, 0, 8),
	Vector3.new(-8, 0, 8),
	Vector3.new(8, 0, -8),
	Vector3.new(-8, 0, -8),
}

-- NPC_Service reference
local NPC_Service

-- Track spawned NPC models (exposed for KillNPC to read)
QuestNPCSpawner.SpawnedNPCs = {}

--[[
	Show all monsters by spawning NPCs via NPC_Service
]]
function QuestNPCSpawner:ShowAllMonsters()
	-- Clean up any existing NPCs first
	self:HideAllMonsters()

	local questFolder = workspace:FindFirstChild(QUEST_FOLDER_NAME)
	if not questFolder then
		warn("[QuestNPCSpawner] Quest folder not found:", QUEST_FOLDER_NAME)
		return false
	end

	local spawner = questFolder:FindFirstChild("Spawner")
	if not spawner or not spawner:IsA("BasePart") then
		warn("[QuestNPCSpawner] Spawner part not found in", QUEST_FOLDER_NAME)
		return false
	end

	if not NPC_Service then
		warn("[QuestNPCSpawner] NPC_Service not available")
		return false
	end

	local spawnerPos = spawner.Position

	for i = 1, NPC_COUNT do
		local offset = SPAWN_OFFSETS[i] or Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
		local spawnPos = spawnerPos + offset

		local npcModel = NPC_Service:SpawnNPC({
			Name = "Bandit",
			Position = spawnPos,
			ModelPath = ReplicatedStorage.Assets.NPCs.Characters.Rig,
			MaxHealth = 100,
			MovementMode = "Melee",
			SightRange = 50,
			SightMode = "Omnidirectional",
			CustomData = { Faction = "Enemy", EnemyType = "Melee" },
		})

		if npcModel then
			table.insert(QuestNPCSpawner.SpawnedNPCs, npcModel)
		end
	end

	print("[QuestNPCSpawner] Spawned", #QuestNPCSpawner.SpawnedNPCs, "Bandit NPCs")
	return true
end

--[[
	Hide all monsters by destroying spawned NPCs via NPC_Service
]]
function QuestNPCSpawner:HideAllMonsters()
	if not NPC_Service then return false end

	for _, npcModelOrID in ipairs(QuestNPCSpawner.SpawnedNPCs) do
		if typeof(npcModelOrID) == "string" then
			-- UseClientPhysics NPC (stored as string ID)
			NPC_Service:DestroyNPC(npcModelOrID)
		elseif npcModelOrID and npcModelOrID.Parent then
			-- Traditional server-physics NPC (stored as Model)
			NPC_Service:DestroyNPC(npcModelOrID)
		end
	end

	QuestNPCSpawner.SpawnedNPCs = {}
	print("[QuestNPCSpawner] All Bandit NPCs destroyed")
	return true
end

--[[
	Initialize - get NPC_Service reference
]]
function QuestNPCSpawner.Init()
	NPC_Service = Knit.GetService("NPC_Service")
	print("[QuestNPCSpawner] Initialized")
end

function QuestNPCSpawner.Start()
	-- Component started
end

return QuestNPCSpawner
