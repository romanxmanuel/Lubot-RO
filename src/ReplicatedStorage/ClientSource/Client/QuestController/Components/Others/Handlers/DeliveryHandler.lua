--[[
	DeliveryHandler.lua
	
	Client-side handler for Delivery quest type.
	Listens for delivery location signals from server and manages touch events.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local player = Players.LocalPlayer

---- Knit Services
local QuestService

local DeliveryHandler = {}

--[[
	Return handler config for QuestTypeManager auto-discovery
	This enables zero-touch signal subscription and cleanup management
	@return table - Handler configuration
]]
function DeliveryHandler.GetHandlerConfig()
	return {
		TypeName = "Delivery",
		SignalHandlers = {
			TrackDeliveryLocations = "OnTrackDeliveryLocations",
			ClearDeliveryLocations = "CleanupAll",
		},
		RequiresCleanup = true,
	}
end

-- Track active delivery locations
-- ⭐ MULTI-TASK: Now includes TaskIndex for multi-task quest support
DeliveryHandler.TrackedDeliveries = {} -- { [deliveryId] = { Instance, Highlight, MarkerUI, Connection, QuestType, QuestNum, TaskIndex } }

-- Reference to the UI marker template
local markerUITemplate = nil

--[[
	Initialize the delivery handler
	Called by QuestController
]]
function DeliveryHandler.Init()
	-- Wait for QuestService to be available
	QuestService = Knit.GetService("QuestService")

	-- Load the UI marker template
	local success, result = pcall(function()
		return ReplicatedStorage:WaitForChild("Assets", 5)
			:WaitForChild("UIs", 5)
			:WaitForChild("Quests", 5)
			:WaitForChild("QuestDeliveryMarkerUI", 5)
	end)

	if success and result then
		markerUITemplate = result
	else
		warn("DeliveryHandler: Failed to load QuestDeliveryMarkerUI from ReplicatedStorage.Assets.UIs.Quests")
	end

	-- NOTE: Signal subscriptions (TrackDeliveryLocations, ClearDeliveryLocations) are now
	-- handled by QuestTypeManager via GetHandlerConfig().SignalHandlers
end

--[[
	Handle TrackDeliveryLocations signal from server
	@param data table - { Locations = array, Config = table }
]]
function DeliveryHandler:OnTrackDeliveryLocations(data)
	local locations = data.Locations or {}
	local config = data.Config or {}

	for _, locationData in ipairs(locations) do
		self:TrackDeliveryLocation(locationData, config)
	end
end

--[[
	Track a single delivery location
	@param locationData table - { DeliveryId, Instance, QuestType, QuestNum, TaskIndex }
	@param config table - { HighlightColor, RequireHumanoid, HighlightDepthMode }
]]
function DeliveryHandler:TrackDeliveryLocation(locationData, config)
	local deliveryId = locationData.DeliveryId
	local instance = locationData.Instance
	local questType = locationData.QuestType
	local questNum = locationData.QuestNum
	local taskIndex = locationData.TaskIndex or 1 -- Default to 1 for backward compatibility

	-- Don't track if already exists
	if DeliveryHandler.TrackedDeliveries[deliveryId] then
		warn("[DeliveryHandler] Delivery already tracked:", deliveryId)
		return
	end

	-- Validate instance exists
	if not instance or not instance:IsDescendantOf(workspace) then
		warn("[DeliveryHandler] Invalid delivery instance:", deliveryId)
		return
	end

	-- Add Highlight visual effect
	local highlight = Instance.new("Highlight")
	highlight.FillColor = config.HighlightColor or Color3.fromRGB(0, 255, 0)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = config.HighlightDepthMode or Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = instance

	-- Add UI marker if template is available
	local markerUI = nil
	if markerUITemplate then
		markerUI = self:CreateDeliveryMarker(instance)
	end

	-- Connect to .Touched event
	local debounce = false
	local connection = instance.Touched:Connect(function(hitPart)
		if debounce then
			return
		end

		-- Check if touched by player's character
		local character = player.Character
		if not character then
			return
		end

		-- Verify the hit part belongs to player's character
		if hitPart:IsDescendantOf(character) then
			-- If RequireHumanoid is true, check for Humanoid
			if config.RequireHumanoid then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not humanoid or humanoid.Health <= 0 then
					return
				end
			end

			debounce = true

			-- Play visual feedback immediately
			self:PlayDeliveryAnimation(instance, highlight)

			-- Validate with server (include taskIndex)
			self:ValidateDeliveryWithServer(deliveryId, questType, questNum, taskIndex, function(success)
				if success then
					-- Remove delivery location after successful validation
					self:RemoveDeliveryLocation(deliveryId)
				else
					-- Reset debounce to allow retry
					debounce = false
					-- Reset visual feedback
					self:ResetHighlight(highlight, config)
				end
			end)
		end
	end)

	-- Store in tracking table
	DeliveryHandler.TrackedDeliveries[deliveryId] = {
		DeliveryId = deliveryId,
		Instance = instance,
		Highlight = highlight,
		MarkerUI = markerUI,
		Connection = connection,
		QuestType = questType,
		QuestNum = questNum,
		TaskIndex = taskIndex, -- ⭐ Store taskIndex for multi-task support
	}
end

--[[
	Create a delivery marker UI for a location
	@param instance BasePart - The delivery location
	@return BillboardGui or nil
]]
function DeliveryHandler:CreateDeliveryMarker(instance)
	if not markerUITemplate then
		return nil
	end

	-- Clone the marker UI
	local markerClone = markerUITemplate:Clone()

	-- If it's already a BillboardGui, just parent it
	if markerClone:IsA("BillboardGui") then
		markerClone.Adornee = instance
		markerClone.Parent = instance
		return markerClone
	end

	-- Otherwise, wrap it in a BillboardGui
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "DeliveryMarker"
	billboardGui.Adornee = instance
	billboardGui.Size = UDim2.new(6, 0, 6, 0) -- Adjust size as needed
	billboardGui.StudsOffset = Vector3.new(0, 3, 0) -- Hover above the location
	billboardGui.AlwaysOnTop = true
	billboardGui.Parent = instance

	-- Parent the cloned marker UI to the billboard
	markerClone.Parent = billboardGui

	return billboardGui
end

--[[
	⭐ UPDATED: Validate delivery with server (multi-task support)
	@param deliveryId string
	@param questType string
	@param questNum number/string
	@param taskIndex number - Task index (1-based)
	@param callback function - Called with success boolean
]]
function DeliveryHandler:ValidateDeliveryWithServer(deliveryId, questType, questNum, taskIndex, callback)
	if not QuestService or not QuestService.ValidateDelivery then
		warn("QuestService.ValidateDelivery not available")
		if callback then
			callback(false)
		end
		return
	end

	QuestService:ValidateDelivery(questType, questNum, deliveryId, taskIndex)
		:andThen(function(success)
			if callback then
				callback(success)
			end
		end)
		:catch(function(err)
			warn("Error validating delivery:", tostring(err))
			if callback then
				callback(false)
			end
		end)
end

--[[
	Play delivery animation (visual feedback)
	@param instance Instance
	@param highlight Highlight
]]
function DeliveryHandler:PlayDeliveryAnimation(instance, highlight)
	-- Flash the highlight brighter
	local originalFillTransparency = highlight.FillTransparency
	local originalOutlineTransparency = highlight.OutlineTransparency

	-- Create pulsing animation
	local pulseTween = TweenService:Create(
		highlight,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 2, true),
		{ FillTransparency = 0.2, OutlineTransparency = 0 }
	)

	pulseTween:Play()

	-- Play completion sound (optional - add sound if available)
	-- local sound = Instance.new("Sound")
	-- sound.SoundId = "rbxassetid://XXXXX"
	-- sound.Parent = instance
	-- sound:Play()
end

--[[
	Reset highlight to original state
	@param highlight Highlight
	@param config table
]]
function DeliveryHandler:ResetHighlight(highlight, config)
	if not highlight or not highlight.Parent then
		return
	end

	local resetTween = TweenService:Create(
		highlight,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FillTransparency = 0.5, OutlineTransparency = 0 }
	)

	resetTween:Play()
end

--[[
	Remove a delivery location from tracking
	@param deliveryId string
]]
function DeliveryHandler:RemoveDeliveryLocation(deliveryId)
	local deliveryData = DeliveryHandler.TrackedDeliveries[deliveryId]
	if not deliveryData then
		return
	end

	-- Disconnect touch event
	if deliveryData.Connection then
		deliveryData.Connection:Disconnect()
	end

	-- Remove highlight
	if deliveryData.Highlight and deliveryData.Highlight.Parent then
		deliveryData.Highlight:Destroy()
	end

	-- Remove marker UI
	if deliveryData.MarkerUI and deliveryData.MarkerUI.Parent then
		deliveryData.MarkerUI:Destroy()
	end

	-- Remove from tracking
	DeliveryHandler.TrackedDeliveries[deliveryId] = nil
end

--[[
	Cleanup all tracked deliveries
	Called when quest ends or player leaves
]]
function DeliveryHandler:CleanupAll()
	for deliveryId, _ in pairs(DeliveryHandler.TrackedDeliveries) do
		self:RemoveDeliveryLocation(deliveryId)
	end
end

-- Handle player respawn/character changes
function DeliveryHandler.Start()
	if player then
		player.CharacterAdded:Connect(function()
			-- Cleanup deliveries on respawn (server will resend if needed)
			DeliveryHandler:CleanupAll()
		end)
	end
end

return DeliveryHandler
