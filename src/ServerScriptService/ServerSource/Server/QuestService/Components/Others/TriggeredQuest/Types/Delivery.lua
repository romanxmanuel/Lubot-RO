--[[
	Delivery.lua
	
	Side quest type: Deliver packages to marked locations.
	Players must touch specific parts in the workspace to complete deliveries.
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

local Delivery = {}
Delivery.__index = Delivery

-- Set up inheritance from SideQuestBase
setmetatable(Delivery, { __index = SideQuestBase })

--[[
	Return registration config for QuestTypeManager auto-discovery
	This enables zero-touch signal/method registration in QuestService
	@return table - Registration configuration
]]
function Delivery.GetRegistration()
	return {
		Name = "Delivery",
		Signals = { "TrackDeliveryLocations", "ClearDeliveryLocations" },
		ClientMethods = {
			{ Name = "ValidateDelivery", Handler = "ValidateDelivery" },
		},
	}
end

-- Track delivery locations per player (server-side tracking only)
-- ⭐ MULTI-TASK: Structure changed to { [player] = { [taskIndex] = { [deliveryId] = {...} } } }
Delivery.PlayerDeliveryLocations = {} -- { [player] = { [taskIndex] = { [deliveryId] = {Instance, questType, questNum, taskIndex} } } }

--[[
	Constructor
]]
function Delivery.new()
	local self = SideQuestBase.new()
	setmetatable(self, Delivery)
	return self
end

--[[
	⭐ NEW: Spawn delivery objectives for a specific task in a multi-task quest
	@param player Player
	@param questType string
	@param questNum number/string
	@param taskIndex number - Task index (1-based)
	@param taskDef table - Task definition
]]
function Delivery:SpawnObjectivesForTask(player, questType, questNum, taskIndex, taskDef)
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
	if not Delivery.PlayerDeliveryLocations[player] then
		Delivery.PlayerDeliveryLocations[player] = {}
	end

	-- Initialize task-specific tracking
	if not Delivery.PlayerDeliveryLocations[player][taskIndex] then
		Delivery.PlayerDeliveryLocations[player][taskIndex] = {}
	end

	-- Get delivery config from task definition
	local deliveryConfig = taskDef.DeliveryConfig or {}

	-- Get delivery locations from workspace
	local deliveryLocations = self:GetDeliveryLocations(deliveryConfig)
	if #deliveryLocations == 0 then
		warn("Delivery: No delivery locations found for task", taskIndex)
		return
	end

	-- Calculate deliveries needed based on task progress
	local deliveriesNeeded = taskDef.MaxProgress - (taskData.Progress or 0)

	-- Prepare delivery data for client
	local locationsData = {}
	for i = 1, math.min(deliveriesNeeded, #deliveryLocations) do
		local deliveryPart = deliveryLocations[i]
		local deliveryId = HttpService:GenerateGUID(false)

		-- Track on server with task index
		Delivery.PlayerDeliveryLocations[player][taskIndex][deliveryId] = {
			Instance = deliveryPart,
			QuestType = questType,
			QuestNum = questNum,
			TaskIndex = taskIndex,
			SpawnTime = os.time(),
		}

		-- Prepare data for client
		table.insert(locationsData, {
			DeliveryId = deliveryId,
			Instance = deliveryPart,
			QuestType = questType,
			QuestNum = questNum,
			TaskIndex = taskIndex,
		})
	end

	-- Ensure default values for delivery config
	deliveryConfig.HighlightColor = deliveryConfig.HighlightColor or Color3.fromRGB(0, 255, 0)
	deliveryConfig.RequireHumanoid = deliveryConfig.RequireHumanoid ~= false
	deliveryConfig.HighlightDepthMode = deliveryConfig.HighlightDepthMode or Enum.HighlightDepthMode.AlwaysOnTop

	-- Send delivery locations to client
	if QuestService and QuestService.Client.TrackDeliveryLocations then
		QuestService.Client.TrackDeliveryLocations:Fire(player, {
			Locations = locationsData,
			Config = deliveryConfig,
			TaskIndex = taskIndex,
		})
	end
end


--[[
	⭐ UPDATED: Validate and process delivery from client (multi-task support)
	@param player Player - The player attempting delivery
	@param questType string - "Daily", "Weekly", or "SideQuest"
	@param questNum number/string - Quest index or name
	@param deliveryId string - Unique delivery identifier
	@param taskIndex number - Task index (optional for backward compatibility)
	@return boolean - Success status
]]
function Delivery:ValidateDelivery(player, questType, questNum, deliveryId, taskIndex)
	-- Validate player has active deliveries
	if not Delivery.PlayerDeliveryLocations[player] then
		warn("Delivery: Player " .. player.Name .. " has no active deliveries")
		return false
	end

	-- Find delivery data (check all tasks if taskIndex not provided)
	local deliveryData
	local foundTaskIndex

	if taskIndex then
		-- Direct lookup if taskIndex provided
		if Delivery.PlayerDeliveryLocations[player][taskIndex] then
			deliveryData = Delivery.PlayerDeliveryLocations[player][taskIndex][deliveryId]
			foundTaskIndex = taskIndex
		end
	else
		-- Search all tasks (backward compatibility)
		for tIndex, taskDeliveries in pairs(Delivery.PlayerDeliveryLocations[player]) do
			if taskDeliveries[deliveryId] then
				deliveryData = taskDeliveries[deliveryId]
				foundTaskIndex = tIndex
				break
			end
		end
	end

	if not deliveryData then
		warn("Delivery: Invalid deliveryId: " .. tostring(deliveryId) .. " for player " .. player.Name)
		return false
	end

	-- Validate quest type and number match
	if deliveryData.QuestType ~= questType or deliveryData.QuestNum ~= questNum then
		warn("Delivery: Quest mismatch for delivery")
		return false
	end

	-- Rate limiting: Check if player is delivering too fast (anti-exploit)
	local currentTime = os.time()
	local timeSinceSpawn = currentTime - deliveryData.SpawnTime
	if timeSinceSpawn < 0.1 then -- Must wait at least 0.1 seconds after spawn
		warn("Delivery: Player " .. player.Name .. " delivered too fast (possible exploit)")
		return false
	end

	-- Additional validation: Check if player is actually near the delivery location
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local playerPosition = character.HumanoidRootPart.Position
		local deliveryPosition = deliveryData.Instance.Position
		local distance = (playerPosition - deliveryPosition).Magnitude

		-- Allow up to 50 studs distance (adjust as needed)
		if distance > 50 then
			warn("Delivery: Player " .. player.Name .. " too far from delivery location")
			return false
		end
	end

	-- Process the delivery with task index
	local success = self:OnDeliveryCompleted(player, questType, questNum, deliveryId, foundTaskIndex or deliveryData.TaskIndex)

	if success then
		-- Remove from tracking
		if Delivery.PlayerDeliveryLocations[player][foundTaskIndex] then
			Delivery.PlayerDeliveryLocations[player][foundTaskIndex][deliveryId] = nil
		end
	end

	return success
end

--[[
	⭐ UPDATED: Handle delivery completion (server-side processing) with multi-task support
	@param player Player
	@param questType string
	@param questNum number/string
	@param deliveryId string - Unique delivery identifier
	@param taskIndex number - Task index (1-based)
	@return boolean - Success status
]]
function Delivery:OnDeliveryCompleted(player, questType, questNum, deliveryId, taskIndex)
	-- Increment task-specific progress
	local success = QuestProgressHandler.IncrementTaskProgress(player, questType, questNum, taskIndex, 1)

	if not success then
		warn("Delivery: Failed to increment quest progress for", player.Name)
		return false
	end

	-- Fire ItemCollected event for passive quest tracking
	if QuestService and QuestService.ItemCollected then
		QuestService.ItemCollected:Fire(player, "Package", 1)
	end

	-- Try to complete quest using centralized handler (respects EnableAutoCompletion setting)
	self:TryCompleteQuest(player, questType, questNum)

	return true
end

--[[
	Check quest progress (called every second if auto-completion enabled)
	@param player Player
	@param questType string
	@param questNum number/string
]]
function Delivery:CheckQuestProgress(player, questType, questNum)
	-- Progress is tracked via touch events, nothing to check here
	-- This method exists to satisfy the base class interface
end

--[[
	Get delivery locations from workspace
	@param config table - Delivery configuration containing TargetFolder
	@return table - Array of BasePart instances to use as delivery targets
]]
function Delivery:GetDeliveryLocations(config)
	local locations = {}

	-- Get target folder path from config (default to "Deliver_Test" for backwards compatibility)
	local targetFolderPath = config and config.TargetFolder or "Deliver_Test"

	-- Navigate to the target folder using dot-separated path
	-- Examples: "Deliver_Test", "Others.DeliveryPoints", "Quests.Deliveries"
	local deliveryFolder = workspace
	local pathParts = string.split(targetFolderPath, ".")
	
	for _, partName in ipairs(pathParts) do
		deliveryFolder = deliveryFolder:FindFirstChild(partName)
		if not deliveryFolder then
			warn(
				string.format(
					"Delivery: Path 'workspace.%s' not found! Failed at '%s'",
					targetFolderPath,
					partName
				)
			)
			return {}
		end
	end

	-- Recursively get all BaseParts from folder and subfolders
	local function getPartsFromFolder(folder)
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(locations, child)
			elseif child:IsA("Folder") or child:IsA("Model") then
				-- Recursively search subfolders/models
				getPartsFromFolder(child)
			end
		end
	end

	getPartsFromFolder(deliveryFolder)

	-- Fallback warning if no locations found
	if #locations == 0 then
		warn(
			string.format(
				"Delivery: No delivery locations found! Create BasePart children in 'workspace.%s'.",
				targetFolderPath
			)
		)
	end

	return locations
end

--[[
	⭐ NEW: Clean up delivery locations for a specific task (for sequential mode)
	@param player Player
	@param taskIndex number
]]
function Delivery:CleanUpTask(player, taskIndex)
	print(string.format("[DELIVERY_DEBUG] CleanUpTask called: Player=%s, TaskIndex=%s", player.Name, tostring(taskIndex)))
	
	if not Delivery.PlayerDeliveryLocations[player] then
		return
	end
	
	-- Collect delivery IDs to clear for this task
	local deliveryIdsToClear = {}
	if Delivery.PlayerDeliveryLocations[player][taskIndex] then
		for deliveryId in pairs(Delivery.PlayerDeliveryLocations[player][taskIndex]) do
			table.insert(deliveryIdsToClear, deliveryId)
		end
		
		-- Clear the task's tracking data
		Delivery.PlayerDeliveryLocations[player][taskIndex] = nil
	end
	
	-- Clear client-side delivery highlights for this task
	if #deliveryIdsToClear > 0 and QuestService and QuestService.Client.ClearDeliveryLocations then
		QuestService.Client.ClearDeliveryLocations:Fire(player, deliveryIdsToClear)
	end
end

--[[
	Cleanup delivery data when quest ends
	@param player Player
]]
function Delivery:CleanUp(player)
	-- Call base cleanup
	local SideQuestBase = require(script.Parent.Parent.SideQuestBase)
	SideQuestBase.CleanUp(self, player)

	-- Clear client-side delivery highlights via signal
	if QuestService and QuestService.Client.ClearDeliveryLocations then
		QuestService.Client.ClearDeliveryLocations:Fire(player)
	end

	-- Remove player from tracking
	Delivery.PlayerDeliveryLocations[player] = nil
end

-- Initialize module
function Delivery.Init()
	ProfileService = Knit.GetService("ProfileService")
	QuestService = Knit.GetService("QuestService")

	-- Load QuestProgressHandler (already initialized by QuestService)
	local ComponentsFolder = script.Parent.Parent.Parent.Parent
	QuestProgressHandler = require(ComponentsFolder.Others.Core.QuestProgressHandler)
end

-- Create singleton instance
local instance = Delivery.new()

return instance
