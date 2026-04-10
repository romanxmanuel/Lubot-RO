--[[
	PickUpItems.lua
	
	Side quest type: Collect items from the world.
	Spawns collectible items that players must touch to collect.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Knit = require(ReplicatedStorage.Packages.Knit)

---- Datas
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local QuestSettings = require(SharedDatas:WaitForChild("GameSettings", 10):WaitForChild("QuestSettings", 10))
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

---- Knit Services
local ProfileService
local QuestService

---- Components
local SideQuestBase = require(script.Parent.Parent.SideQuestBase)
local QuestProgressHandler

local PickUpItems = {}
PickUpItems.__index = PickUpItems

-- Set up inheritance from SideQuestBase
setmetatable(PickUpItems, { __index = SideQuestBase })

--[[
	Return registration config for QuestTypeManager auto-discovery
	This enables zero-touch signal/method registration in QuestService
	@return table - Registration configuration
]]
function PickUpItems.GetRegistration()
	return {
		Name = "PickUpItems",
		Signals = { "TrackPickupItems" },
		ClientMethods = {
			{ Name = "ValidateItemPickup", Handler = "ValidateAndProcessPickup" },
		},
	}
end

-- Track spawned items per player (server-side tracking only)
-- ⭐ MULTI-TASK: Structure changed to { [player] = { [taskIndex] = { [itemId] = {...} } } }
PickUpItems.PlayerSpawnedItems = {} -- { [player] = { [taskIndex] = { [itemId] = {location, questType, questNum, taskIndex} } } }

--[[
	Constructor
]]
function PickUpItems.new()
	local self = SideQuestBase.new()
	setmetatable(self, PickUpItems)
	return self
end

--[[
	⭐ NEW: Spawn objectives for a specific task in a multi-task quest
	@param player Player
	@param questType string
	@param questNum number/string
	@param taskIndex number - Task index (1-based)
	@param taskDef table - Task definition
]]
function PickUpItems:SpawnObjectivesForTask(player, questType, questNum, taskIndex, taskDef)
	-- Get player's task progress
	local _, profileData = ProfileService:GetProfile(player)
	if not profileData then
		return
	end

	local quest = QuestProgressHandler.GetQuestData(profileData, questType, questNum)
	if not quest or not quest.Tasks or not quest.Tasks[taskIndex] then
		return
	end

	local taskData = quest.Tasks[taskIndex]

	-- Initialize player tracking if needed
	if not PickUpItems.PlayerSpawnedItems[player] then
		PickUpItems.PlayerSpawnedItems[player] = {}
	end

	-- Initialize task-specific tracking
	if not PickUpItems.PlayerSpawnedItems[player][taskIndex] then
		PickUpItems.PlayerSpawnedItems[player][taskIndex] = {}
	end

	-- Check if using Wood Crates from workspace
	local testFolder = workspace:FindFirstChild("Pickup_Item_Quest_Test")
	local useWoodCrates = testFolder ~= nil

	if useWoodCrates then
		-- Show Wood Crates (server-side visibility)
		if QuestService and QuestService.CrateVisibilityManager then
			QuestService.CrateVisibilityManager:ShowAllCrates()
		end

		-- Get Wood Crates
		local woodCrates = {}
		for _, child in ipairs(testFolder:GetChildren()) do
			if child:IsA("Model") and child.Name:match("^Wood Crate") then
				table.insert(woodCrates, child)
			end
		end

		-- Calculate items to spawn based on task progress
		local itemsToSpawn = taskDef.MaxProgress - (taskData.Progress or 0)
		itemsToSpawn = math.min(itemsToSpawn, #woodCrates)

		-- Prepare Wood Crate data for client
		local itemsData = {}
		for i = 1, itemsToSpawn do
			local crate = woodCrates[i]
			local itemId = HttpService:GenerateGUID(false)
			local cratePosition = crate:GetPivot().Position

			-- Track on server with task index
			PickUpItems.PlayerSpawnedItems[player][taskIndex][itemId] = {
				Location = cratePosition,
				QuestType = questType,
				QuestNum = questNum,
				TaskIndex = taskIndex,
				SpawnTime = os.time(),
				WoodCrate = crate,
			}

			-- Prepare data for client
			table.insert(itemsData, {
				Instance = crate,
				ItemId = itemId,
				QuestType = questType,
				QuestNum = questNum,
				TaskIndex = taskIndex,
			})
		end

		-- Get pickup config from task definition
		local pickupConfig = taskDef.PickupConfig or {
			HighlightDepthMode = Enum.HighlightDepthMode.Occluded,
		}

		-- Send to client for tracking
		if QuestService and QuestService.Client.TrackPickupItems then
			QuestService.Client.TrackPickupItems:Fire(player, {
				Items = itemsData,
				Config = pickupConfig,
				TaskIndex = taskIndex,
			})
		end
	else
		-- Use spawn locations
		local spawnLocations = self:GetSpawnLocations()
		if #spawnLocations == 0 then
			warn("No spawn locations found for PickUpItems quest!")
			return
		end

		local itemsToSpawn = taskDef.MaxProgress - (taskData.Progress or 0)

		local itemsData = {}
		for i = 1, itemsToSpawn do
			local randomLocation = spawnLocations[math.random(1, #spawnLocations)]
			local itemId = HttpService:GenerateGUID(false)

			PickUpItems.PlayerSpawnedItems[player][taskIndex][itemId] = {
				Location = randomLocation,
				QuestType = questType,
				QuestNum = questNum,
				TaskIndex = taskIndex,
				SpawnTime = os.time(),
			}

			table.insert(itemsData, {
				ItemId = itemId,
				Location = randomLocation,
				QuestType = questType,
				QuestNum = questNum,
				TaskIndex = taskIndex,
			})
		end

		if QuestService and QuestService.Client.SpawnPickupItems then
			QuestService.Client.SpawnPickupItems:Fire(player, itemsData)
		end
	end

	-- Auto-cleanup after lifetime
	local lifetime = QuestSettings.SideQuests.PickUpItems.ItemLifetime or 300
	task.delay(lifetime, function()
		self:DespawnItemsForPlayer(player, questType, questNum, taskIndex)
	end)
end

--[[
	⭐ UPDATED: Validate and process item pickup from client (multi-task support)
	@param player Player - The player attempting to pick up the item
	@param questType string - "Daily" or "Weekly"
	@param questNum number - Quest index
	@param itemId string - Unique item identifier
	@param taskIndex number - Task index (optional for backward compatibility)
	@return boolean - Success status
]]
function PickUpItems:ValidateAndProcessPickup(player, questType, questNum, itemId, taskIndex)
	-- Validate player has spawned items
	if not PickUpItems.PlayerSpawnedItems[player] then
		return false
	end

	-- Find item data (check all tasks if taskIndex not provided)
	local itemData
	local foundTaskIndex

	if taskIndex then
		-- Direct lookup if taskIndex provided
		if PickUpItems.PlayerSpawnedItems[player][taskIndex] then
			itemData = PickUpItems.PlayerSpawnedItems[player][taskIndex][itemId]
			foundTaskIndex = taskIndex
		end
	else
		-- Search all tasks (backward compatibility)
		for tIndex, taskItems in pairs(PickUpItems.PlayerSpawnedItems[player]) do
			if taskItems[itemId] then
				itemData = taskItems[itemId]
				foundTaskIndex = tIndex
				break
			end
		end
	end

	if not itemData then
		return false
	end

	-- Validate quest type and number match
	if itemData.QuestType ~= questType or itemData.QuestNum ~= questNum then
		warn("Quest mismatch for item pickup")
		return false
	end

	-- Rate limiting: Check if player is picking up too fast (anti-exploit)
	local currentTime = os.time()
	local timeSinceSpawn = currentTime - itemData.SpawnTime
	if timeSinceSpawn < 0.1 then -- Must wait at least 0.1 seconds after spawn
		warn("Player " .. player.Name .. " picked up item too fast (possible exploit)")
		return false
	end

	-- Process the pickup with task index
	local success = self:OnItemCollected(player, questType, questNum, itemId, foundTaskIndex or itemData.TaskIndex)

	if success then
		-- Remove from tracking
		if PickUpItems.PlayerSpawnedItems[player][foundTaskIndex] then
			PickUpItems.PlayerSpawnedItems[player][foundTaskIndex][itemId] = nil
		end
	end

	return success
end

--[[
	⭐ UPDATED: Handle item collection (server-side processing) with multi-task support
	@param player Player
	@param questType string
	@param questNum number
	@param itemId string - Unique item identifier
	@param taskIndex number - Task index (1-based)
	@return boolean - Success status
]]
function PickUpItems:OnItemCollected(player, questType, questNum, itemId, taskIndex)
	-- Increment task-specific progress
	local success = QuestProgressHandler.IncrementTaskProgress(player, questType, questNum, taskIndex, 1)

	if not success then
		warn("Failed to increment task progress for", player.Name, "task", taskIndex)
		return false
	end

	-- Fire ItemCollected event for passive quest tracking
	if QuestService and QuestService.ItemCollected then
		QuestService.ItemCollected:Fire(player, "Crate", 1)
	end

	-- Try to complete quest using centralized handler (respects EnableAutoCompletion setting)
	self:TryCompleteQuest(player, questType, questNum)

	return true
end

--[[
	Check quest progress (called every second)
	@param player Player
	@param questType string
	@param questNum number
]]
function PickUpItems:CheckQuestProgress(player, questType, questNum)
	-- Progress is tracked via touch events, nothing to check here
	-- This method exists to satisfy the base class interface
end

--[[
	⭐ UPDATED: Despawn items for a specific player (multi-task support)
	@param player Player
	@param questType string (optional)
	@param questNum number (optional)
	@param taskIndex number (optional) - If specified, only despawn items for this task
]]
function PickUpItems:DespawnItemsForPlayer(player, questType, questNum, taskIndex)
	if not PickUpItems.PlayerSpawnedItems[player] then
		return
	end

	-- Collect item IDs to despawn
	local itemsToDespawn = {}

	-- If taskIndex specified, only process that task
	if taskIndex then
		if PickUpItems.PlayerSpawnedItems[player][taskIndex] then
			for itemId, itemData in pairs(PickUpItems.PlayerSpawnedItems[player][taskIndex]) do
				-- If quest type/num specified, only despawn matching items
				if
					not questType
					or not questNum
					or (itemData.QuestType == questType and itemData.QuestNum == questNum)
				then
					table.insert(itemsToDespawn, itemId)
				end
			end
		end
	else
		-- Process all tasks
		for tIndex, taskItems in pairs(PickUpItems.PlayerSpawnedItems[player]) do
			for itemId, itemData in pairs(taskItems) do
				-- If quest type/num specified, only despawn matching items
				if
					not questType
					or not questNum
					or (itemData.QuestType == questType and itemData.QuestNum == questNum)
				then
					table.insert(itemsToDespawn, itemId)
				end
			end
		end
	end

	if #itemsToDespawn > 0 then
		-- Send despawn command to client
		if QuestService and QuestService.Client.DespawnPickupItems then
			QuestService.Client.DespawnPickupItems:Fire(player, itemsToDespawn)
		end

		-- Remove from server tracking
		if taskIndex then
			if PickUpItems.PlayerSpawnedItems[player][taskIndex] then
				for _, itemId in ipairs(itemsToDespawn) do
					PickUpItems.PlayerSpawnedItems[player][taskIndex][itemId] = nil
				end
			end
		else
			for _, itemId in ipairs(itemsToDespawn) do
				-- Find and remove from all tasks
				for tIndex, taskItems in pairs(PickUpItems.PlayerSpawnedItems[player]) do
					taskItems[itemId] = nil
				end
			end
		end
	end
end

--[[
	Get spawn locations for items
	@return table - Array of Vector3 positions
]]
function PickUpItems:GetSpawnLocations()
	local locations = {}

	-- Look for spawn points in workspace
	local spawnFolder = workspace:FindFirstChild("QuestItemSpawns")

	if spawnFolder then
		for _, spawnPoint in ipairs(spawnFolder:GetChildren()) do
			if spawnPoint:IsA("BasePart") or spawnPoint:IsA("Attachment") then
				table.insert(locations, spawnPoint.Position)
			end
		end
	end

	-- Fallback: Use default spawn locations if no spawn points exist
	if #locations == 0 then
		warn("No QuestItemSpawns folder found! Using default spawn locations.")
		-- Default spawn locations (you should set these up in your game)
		locations = {
			Vector3.new(0, 5, 0),
			Vector3.new(10, 5, 10),
			Vector3.new(-10, 5, 10),
			Vector3.new(10, 5, -10),
			Vector3.new(-10, 5, -10),
		}
	end

	return locations
end

--[[
	Cleanup spawned items
	@param player Player
]]
function PickUpItems:CleanUp(player)
	-- Call base cleanup
	local SideQuestBase = require(script.Parent.Parent.SideQuestBase)
	SideQuestBase.CleanUp(self, player)

	-- Despawn all items for this player
	self:DespawnItemsForPlayer(player)

	-- Hide Wood Crates (server-side visibility) if using them
	local testFolder = workspace:FindFirstChild("Pickup_Item_Quest_Test")
	if testFolder and QuestService and QuestService.CrateVisibilityManager then
		QuestService.CrateVisibilityManager:HideAllCrates()
	end

	-- Remove player from tracking
	PickUpItems.PlayerSpawnedItems[player] = nil
end

-- Initialize module
--[[
	⭐ NEW: Clean up spawned items for a specific task (for sequential mode)
	@param player Player
	@param taskIndex number
]]
function PickUpItems:CleanUpTask(player, taskIndex)
	-- Use existing DespawnItemsForPlayer method with taskIndex
	self:DespawnItemsForPlayer(player, nil, nil, taskIndex)
end

function PickUpItems.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")

	-- Load QuestProgressHandler (already initialized by QuestService)
	local ComponentsFolder = script.Parent.Parent.Parent.Parent
	QuestProgressHandler = require(ComponentsFolder.Others.Core.QuestProgressHandler)
end

-- Create singleton instance
local instance = PickUpItems.new()

return instance
