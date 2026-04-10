--[[
	PickupItemsHandler.lua
	
	Client-side handler for pickup quest items.
	Adds visual effects (Highlight + Particles) to world objects and handles pickup validation.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PickupItemsHandler = {}

--[[
	Return handler config for QuestTypeManager auto-discovery
	This enables zero-touch signal subscription and cleanup management
	@return table - Handler configuration
]]
function PickupItemsHandler.GetHandlerConfig()
	return {
		TypeName = "PickUpItems",
		SignalHandlers = {
			TrackPickupItems = "TrackPickupItems",
		},
		RequiresCleanup = true,
	}
end

---- Knit Services
local QuestService

---- Player Reference
local player = Players.LocalPlayer
local character

---- Item Tracking
-- { [itemId] = { ItemId = string, TaskIndex = number, Instance = Instance, Connection = RBXScriptConnection, ProximityPrompt = ProximityPrompt, QuestType = string, QuestNum = number, ItemType = string, Highlight = Highlight, Particles = ParticleEmitter } }
PickupItemsHandler.TrackedItems = {}

-- Container folder (for any client-side temporary items if needed)
local itemsFolder

-- Cached sound instance (for preloading audio asset)
local cachedPickupSound

--[[
	Initialize the items container
]]
function PickupItemsHandler:InitializeContainer()
	-- Create a folder in workspace to hold client-side items
	if not workspace:FindFirstChild("ClientQuestItems_" .. player.UserId) then
		itemsFolder = Instance.new("Folder")
		itemsFolder.Name = "ClientQuestItems_" .. player.UserId
		itemsFolder.Parent = workspace
	else
		itemsFolder = workspace:FindFirstChild("ClientQuestItems_" .. player.UserId)
	end
end

--[[
	Validate pickup with server (unified handler for all items)
	@param itemId string
	@param questType string
	@param questNum number
	@param taskIndex number (optional) - Task index for multi-task quests
	@param onSuccess function - Callback on successful validation (optional)
	@param onFailure function - Callback on failed validation (optional)
]]
local function validatePickupWithServer(itemId, questType, questNum, taskIndex, onSuccess, onFailure)
	if not QuestService or not QuestService.ValidateItemPickup then
		if onFailure then
			onFailure()
		end
		return
	end

	QuestService:ValidateItemPickup(questType, questNum, itemId, taskIndex)
		:andThen(function(success)
			if success then
				if onSuccess then
					onSuccess()
				end
			else
				if onFailure then
					onFailure()
				end
			end
		end)
		:catch(function(err)
			warn("Error validating pickup: " .. tostring(err))
			if onFailure then
				onFailure()
			end
		end)
end

--[[
	Function to track a pickup item (world object)
	@param itemConfig table - { ItemId, Instance, ProximityPrompt, QuestType, QuestNum, TaskIndex, ItemType, Highlight, Particles }
]]
function PickupItemsHandler:TrackPickupItem(itemConfig)
	local itemId = itemConfig.ItemId
	local instance = itemConfig.Instance
	local prompt = itemConfig.ProximityPrompt
	local questType = itemConfig.QuestType
	local questNum = itemConfig.QuestNum
	local taskIndex = itemConfig.TaskIndex
	local itemType = itemConfig.ItemType

	-- Check if this INSTANCE is already tracked under a different itemId (prevents duplicate connections)
	for existingItemId, existingData in pairs(PickupItemsHandler.TrackedItems) do
		if existingData.Instance == instance then
			-- Disconnect old connection to prevent duplicate triggers
			if existingData.Connection then
				existingData.Connection:Disconnect()
			end

			-- Remove old visual effects
			if existingData.Highlight and existingData.Highlight.Parent then
				existingData.Highlight:Destroy()
			end
			if existingData.Particles and existingData.Particles.Parent then
				existingData.Particles:Destroy()
			end

			-- Remove from tracking
			PickupItemsHandler.TrackedItems[existingItemId] = nil
			break
		end
	end

	-- If already tracked with the same itemId, skip
	if PickupItemsHandler.TrackedItems[itemId] then
		return
	end

	-- Connect to ProximityPrompt trigger (CLIENT-SIDE)
	local pickedUp = false
	local connection = prompt.Triggered:Connect(function(triggeredPlayer)
		if triggeredPlayer ~= player or pickedUp then
			return
		end

		pickedUp = true

		-- Immediately disable prompt for smooth UX
		prompt.Enabled = false

		-- Play pickup animation and sound (CLIENT-SIDE)
		self:PlayPickupAnimation(instance, itemType)

		-- Validate with server
		validatePickupWithServer(itemId, questType, questNum, taskIndex, function() -- onSuccess
			self:RemovePickupItem(itemId)
		end, function() -- onFailure
			self:ResetPickupItem(itemId)
		end)
	end)

	-- Store in tracking table
	PickupItemsHandler.TrackedItems[itemId] = {
		ItemId = itemId,
		TaskIndex = taskIndex,
		Instance = instance,
		Connection = connection,
		ProximityPrompt = prompt,
		QuestType = questType,
		QuestNum = questNum,
		ItemType = itemType,
		Highlight = itemConfig.Highlight,
		Particles = itemConfig.Particles,
	}
end

--[[
	Play pickup sound at a position (dedicated sound part that won't be destroyed)
	@param position Vector3 - Position to play sound at
]]
local function playPickupSound(position)
	-- Create dedicated sound part (won't be destroyed with item)
	local soundPart = Instance.new("Part")
	soundPart.Name = "PickupSoundPart"
	soundPart.Transparency = 1
	soundPart.CanCollide = false
	soundPart.Anchored = true
	soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
	soundPart.Position = position
	soundPart.Parent = workspace

	-- Play satisfying sound effect on dedicated part
	local pickupSound = Instance.new("Sound")
	pickupSound.SoundId = "rbxassetid://4056786383"
	pickupSound.Volume = 0.5
	pickupSound.PlaybackSpeed = 1
	pickupSound.TimePosition = 0.2 -- Start at 0.2 seconds
	pickupSound.Parent = soundPart
	pickupSound:Play()

	-- Cleanup sound and part after playing
	task.delay(2, function()
		if soundPart and soundPart.Parent then
			soundPart:Destroy()
		end
	end)
end

--[[
	Animate and fade out parts (for both quest items and crates)
	@param parts table - Array of BaseParts to animate
	@param duration number - Animation duration (optional, default 0.5)
]]
local function animatePartsUpAndFade(parts, duration)
	duration = duration or 0.5

	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			-- Disable collision
			part.CanCollide = false

			-- Tween up and fade out
			local originalPos = part.Position
			TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = originalPos + Vector3.new(0, 3, 0),
				Transparency = 1,
			}):Play()
		end
	end
end

--[[
	Play pickup animation for world objects
	@param instance Instance - The world object to animate
	@param itemType string - Always "crate" (world object type)
]]
function PickupItemsHandler:PlayPickupAnimation(instance, itemType)
	-- Get position for sound
	local position = instance:GetPivot().Position

	-- Play sound at position
	playPickupSound(position)

	-- Disable Highlight
	local highlight = instance:FindFirstChild("QuestHighlight")
	if highlight then
		highlight.Enabled = false
	end

	-- Disable Particles
	local particles = instance.PrimaryPart and instance.PrimaryPart:FindFirstChild("QuestParticles")
	if particles then
		particles.Enabled = false
	end

	-- Clone the object for animation (BEFORE hiding original!)
	local objectClone = instance:Clone()
	objectClone.Parent = workspace

	-- Remove ProximityPrompt and visual effects from clone
	local cloneCenter = objectClone:FindFirstChild("Center") or objectClone.PrimaryPart
	if cloneCenter then
		local clonePrompt = cloneCenter:FindFirstChild("ProximityPrompt")
		if clonePrompt then
			clonePrompt:Destroy()
		end
	end

	-- Remove Highlight and Particles from clone
	local cloneHighlight = objectClone:FindFirstChild("QuestHighlight")
	if cloneHighlight then
		cloneHighlight:Destroy()
	end
	local cloneParticles = objectClone.PrimaryPart and objectClone.PrimaryPart:FindFirstChild("QuestParticles")
	if cloneParticles then
		cloneParticles:Destroy()
	end

	-- NOW hide the original object (for quest resets)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		end
	end

	-- Disable the ProximityPrompt on original
	local centerPart = instance:FindFirstChild("Center") or instance.PrimaryPart
	if centerPart then
		local prompt = centerPart:FindFirstChild("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
	end

	-- Collect clone parts for animation
	local cloneParts = {}
	for _, descendant in ipairs(objectClone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(cloneParts, descendant)
		end
	end

	-- Animate the clone (visible pickup animation!)
	animatePartsUpAndFade(cloneParts, 0.5)

	-- Destroy the clone after animation completes (original stays hidden)
	task.delay(0.6, function()
		if objectClone and objectClone.Parent then
			objectClone:Destroy()
		end
	end)
end

--[[
	Reset pickup item state if server rejected
	@param itemId string
]]
function PickupItemsHandler:ResetPickupItem(itemId)
	local itemData = PickupItemsHandler.TrackedItems[itemId]
	if not itemData then
		return
	end

	local item = itemData.Instance
	if item and item.Parent then
		-- Re-enable proximity prompt
		if itemData.ProximityPrompt then
			itemData.ProximityPrompt.Enabled = true
		end

		-- Restore visibility (unhide original)
		for _, descendant in ipairs(item:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Transparency = 0
				descendant.CanCollide = true
			end
		end

		-- Re-enable visual effects
		local highlight = item:FindFirstChild("QuestHighlight")
		if highlight then
			highlight.Enabled = true
		end

		local particles = item.PrimaryPart and item.PrimaryPart:FindFirstChild("QuestParticles")
		if particles then
			particles.Enabled = true
		end
	end
end

--[[
	Remove pickup item from client
	@param itemId string
]]
function PickupItemsHandler:RemovePickupItem(itemId)
	local itemData = PickupItemsHandler.TrackedItems[itemId]
	if not itemData then
		return
	end

	-- Disconnect proximity prompt event
	if itemData.Connection then
		itemData.Connection:Disconnect()
		itemData.Connection = nil
	end

	-- Remove visual effects and keep hidden
	-- Original object stays in workspace for future quest attempts

	-- Remove Highlight
	if itemData.Highlight and itemData.Highlight.Parent then
		itemData.Highlight:Destroy()
		itemData.Highlight = nil
	end

	-- Remove Particles
	if itemData.Particles and itemData.Particles.Parent then
		itemData.Particles:Destroy()
		itemData.Particles = nil
	end

	-- Mark as collected but KEEP in tracking for cleanup restoration
	itemData.Collected = true
end

--[[
	Despawn multiple items
	@param itemIds table - Array of item IDs to remove
]]
function PickupItemsHandler:DespawnItems(itemIds)
	for _, itemId in ipairs(itemIds) do
		self:RemovePickupItem(itemId)
	end
end

--[[
	Add visual effects to a world object (Highlight + Particle Emitter)
	@param instance Model - The world object/model to highlight
	@param config table - Optional configuration { HighlightDepthMode = Enum.HighlightDepthMode }
	@return Highlight, ParticleEmitter - The created visual effects
]]
function PickupItemsHandler:AddPickupVisualEffects(instance, config)
	config = config or {}

	-- Add Highlight instance (yellow/gold color)
	local highlight = Instance.new("Highlight")
	highlight.Name = "QuestHighlight"
	highlight.FillColor = Color3.fromRGB(255, 255, 0) -- Yellow
	highlight.OutlineColor = Color3.fromRGB(255, 200, 0) -- Gold outline
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = config.HighlightDepthMode or Enum.HighlightDepthMode.Occluded -- Default: not visible through walls
	highlight.Enabled = true -- Explicitly enable
	highlight.Adornee = instance
	highlight.Parent = instance

	-- Add particle effect to PrimaryPart
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "QuestParticles"
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(0.3)
	particles.Transparency = NumberSequence.new(0.5)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 20
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(30, 30)
	particles.Enabled = true -- Explicitly enable
	particles.Parent = instance.PrimaryPart

	return highlight, particles
end

--[[
	Find the biggest part in a model by volume
	@param model Model - The model to search
	@return BasePart | nil - The biggest part found, or nil if none found
]]
local function findBiggestPart(model)
	local biggestPart = nil
	local biggestVolume = 0

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			local size = child.Size
			local volume = size.X * size.Y * size.Z

			if volume > biggestVolume then
				biggestVolume = volume
				biggestPart = child
			end
		end
	end

	return biggestPart
end

--[[
	Track world objects for pickup quests
	@param pickupData table - { Items = array, Config = table }
		Items: Array of { Instance = Model, ItemId = string, QuestType = string, QuestNum = string/number }
		Config: { HighlightDepthMode = Enum.HighlightDepthMode }
]]
function PickupItemsHandler:TrackPickupItems(pickupData)
	local items = pickupData.Items or {}
	local config = pickupData.Config or {}

	for _, itemData in ipairs(items) do
		local worldObject = itemData.Instance
		local itemId = itemData.ItemId
		local questType = itemData.QuestType
		local questNum = itemData.QuestNum
		local taskIndex = itemData.TaskIndex

		-- Ensure object has a PrimaryPart, if not, find and set the biggest part
		if not worldObject.PrimaryPart then
			local biggestPart = findBiggestPart(worldObject)
			if biggestPart then
				worldObject.PrimaryPart = biggestPart
				warn(
					"[PickupItemsHandler] World object had no PrimaryPart, set biggest part as PrimaryPart:",
					worldObject.Name
				)
			else
				warn("[PickupItemsHandler] World object has no valid parts to set as PrimaryPart:", worldObject.Name)
				continue
			end
		end

		-- Find the ProximityPrompt
		local centerPart = worldObject:FindFirstChild("Center") or worldObject.PrimaryPart
		if not centerPart then
			warn("[PickupItemsHandler] No center part found on object:", worldObject.Name)
			continue
		end

		local prompt = centerPart:FindFirstChild("ProximityPrompt")
		if not prompt then
			warn("[PickupItemsHandler] No ProximityPrompt found on object:", worldObject.Name)
			continue
		end

		-- Add visual effects to the world object with config
		local highlight, particles = self:AddPickupVisualEffects(worldObject, config)

		-- Track this world object
		self:TrackPickupItem({
			ItemId = itemId,
			Instance = worldObject,
			ProximityPrompt = prompt,
			QuestType = questType,
			QuestNum = questNum,
			TaskIndex = taskIndex,
			ItemType = "crate",
			Highlight = highlight,
			Particles = particles,
		})
	end
end

--[[
	Cleanup all items (called on player leaving or quest reset)
]]
function PickupItemsHandler:CleanupAll()
	-- Cleanup all tracked items
	for itemId, itemData in pairs(PickupItemsHandler.TrackedItems) do
		-- Disconnect connections
		if itemData.Connection then
			itemData.Connection:Disconnect()
		end

		-- Remove visual effects from world objects
		-- Note: Visibility is controlled server-side, client only handles visual effects
		local worldObject = itemData.Instance
		if worldObject and worldObject.Parent then
			-- Remove Highlight
			if itemData.Highlight and itemData.Highlight.Parent then
				itemData.Highlight:Destroy()
			end

			-- Remove Particles
			if itemData.Particles and itemData.Particles.Parent then
				itemData.Particles:Destroy()
			end
		end
	end

	if itemsFolder and itemsFolder.Parent then
		itemsFolder:Destroy()
	end

	PickupItemsHandler.TrackedItems = {}
end

function PickupItemsHandler.Start()
	-- Initialize container
	PickupItemsHandler:InitializeContainer()

	-- Create cached sound instance for preloading (Roblox auto-caches parented sounds)
	cachedPickupSound = Instance.new("Sound")
	cachedPickupSound.Name = "CachedPickupSound"
	cachedPickupSound.SoundId = "rbxassetid://4056786383"
	cachedPickupSound.Volume = 0 -- Silent, just for caching
	cachedPickupSound.Parent = workspace -- Parent it to cache the asset

	-- NOTE: Signal subscription (TrackPickupItems) is now handled by QuestTypeManager
	-- via GetHandlerConfig().SignalHandlers

	-- Cleanup on character respawn
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
	end)
end

function PickupItemsHandler.Init()
	---- Knit Services
	QuestService = Knit.GetService("QuestService")
end

return PickupItemsHandler
