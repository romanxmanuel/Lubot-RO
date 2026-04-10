--[[
	DeliveryTester.lua
	
	Testing utilities for the Delivery quest system.
	Provides commands to test delivery quest functionality in Studio.
	
	Usage (Server command bar):
	```lua
	local Knit = require(game.ReplicatedStorage.Packages.Knit)
	local QuestService = Knit.GetService("QuestService")
	local tester = QuestService.DeliveryTester
	
	-- Start delivery quest for a player
	tester:TestDeliveryQuest(game.Players.YourUsername)
	
	-- Print all available commands
	tester:PrintUsage()
	```
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local DeliveryTester = {}

---- Knit Services
local QuestService

--[[
	Print usage guide
]]
function DeliveryTester:PrintUsage()
	print(
		"\n═══════════════════════════════════════════════════════════"
	)
	print("📦 DELIVERY QUEST TESTER - COMMAND GUIDE")
	print(
		"═══════════════════════════════════════════════════════════"
	)
	print("\n🔧 Setup Commands:")
	print("  • tester:CreateDeliveryTargets(count, position)")
	print("    - Creates delivery target parts in workspace")
	print("    - count: Number of targets to create (default: 1)")
	print("    - position: Center position (default: Vector3.new(0, 5, 0))")
	print("")
	print("  • tester:RemoveDeliveryTargets()")
	print("    - Removes all test delivery targets from workspace")
	print("")
	print("\n🎮 Testing Commands:")
	print("  • tester:TestDeliveryQuest(player)")
	print("    - Starts a delivery quest for the specified player")
	print("    - Example: tester:TestDeliveryQuest(game.Players.Player1)")
	print("")
	print("  • tester:ValidateDelivery(player, deliveryId)")
	print("    - Manually test delivery validation (advanced)")
	print("")
	print("\n📝 Example Workflow:")
	print("  1. tester:CreateDeliveryTargets(1)")
	print("  2. tester:TestDeliveryQuest(game.Players.LocalPlayer)")
	print("  3. Walk to the green highlighted area")
	print("  4. Quest should complete automatically")
	print("")
	print(
		"═══════════════════════════════════════════════════════════\n"
	)
end

--[[
	Create delivery target parts in workspace for testing
	@param count number - Number of targets to create (default: 1)
	@param centerPosition Vector3 - Center position for targets (default: 0, 5, 0)
]]
function DeliveryTester:CreateDeliveryTargets(count, centerPosition)
	count = count or 1
	centerPosition = centerPosition or Vector3.new(0, 5, 0)

	-- Create or get Deliver_Test folder
	local deliverFolder = workspace:FindFirstChild("Deliver_Test")
	if not deliverFolder then
		deliverFolder = Instance.new("Folder")
		deliverFolder.Name = "Deliver_Test"
		deliverFolder.Parent = workspace
	end

	-- Clear existing targets
	for _, child in ipairs(deliverFolder:GetChildren()) do
		if child:IsA("BasePart") then
			child:Destroy()
		end
	end

	-- Create new targets
	for i = 1, count do
		local targetPart = Instance.new("Part")
		targetPart.Name = "DeliveryTarget_" .. i
		targetPart.Size = Vector3.new(10, 1, 10)
		targetPart.Anchored = true
		targetPart.CanCollide = false
		targetPart.Transparency = 0.5 -- Semi-transparent for testing (set to 1 for production)
		targetPart.Color = Color3.fromRGB(0, 255, 0)
		targetPart.Material = Enum.Material.Neon

		-- Position targets in a line or circle
		if count == 1 then
			targetPart.Position = centerPosition
		else
			local angle = (i - 1) * (math.pi * 2 / count)
			local radius = 20
			local x = centerPosition.X + math.cos(angle) * radius
			local z = centerPosition.Z + math.sin(angle) * radius
			targetPart.Position = Vector3.new(x, centerPosition.Y, z)
		end

		targetPart.Parent = deliverFolder
	end

	return deliverFolder
end

--[[
	Remove all delivery targets from workspace
]]
function DeliveryTester:RemoveDeliveryTargets()
	local deliverFolder = workspace:FindFirstChild("Deliver_Test")
	if deliverFolder then
		deliverFolder:Destroy()
	end
end

--[[
	Test delivery quest for a player
	@param player Player
]]
function DeliveryTester:TestDeliveryQuest(player)
	if not player or not player:IsA("Player") then
		warn("Invalid player")
		return false
	end

	-- Ensure delivery targets exist
	local deliverFolder = workspace:FindFirstChild("Deliver_Test")
	if not deliverFolder or #deliverFolder:GetChildren() == 0 then
		self:CreateDeliveryTargets(1)
	end

	-- Start the delivery quest
	local success, result = pcall(function()
		return QuestService:TrackSideQuest(player, "SideQuest", "DeliverPackage")
	end)

	if not success then
		warn("Failed to start delivery quest:", result)
		return false
	end

	return true
end

--[[
	⭐ UPDATED: Manually validate a delivery (for advanced testing) with multi-task support
	@param player Player
	@param deliveryId string
	@param taskIndex number - Optional task index (defaults to 1)
]]
function DeliveryTester:ValidateDelivery(player, deliveryId, taskIndex)
	if not player or not player:IsA("Player") then
		warn("Invalid player")
		return false
	end

	if not deliveryId then
		warn("deliveryId required")
		return false
	end

	-- Get Delivery component
	local Delivery = require(script.Parent.Parent.TriggeredQuest.Types.Delivery)

	-- Call validation with taskIndex (defaults to 1 for backward compatibility)
	local success = Delivery:ValidateDelivery(player, "SideQuest", "DeliverPackage", deliveryId, taskIndex or 1)

	return success
end

--[[
	Get delivery statistics for a player
	@param player Player
]]
function DeliveryTester:GetDeliveryStats(player)
	if not player or not player:IsA("Player") then
		warn("Invalid player")
		return nil
	end

	local Delivery = require(script.Parent.Parent.TriggeredQuest.Types.Delivery)
	local deliveries = Delivery.PlayerDeliveryLocations[player]

	return deliveries
end

--[[
	Initialize the tester
]]
function DeliveryTester.Init()
	QuestService = Knit.GetService("QuestService")
end

return DeliveryTester
