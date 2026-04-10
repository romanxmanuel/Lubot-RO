--[[
	PickupItemsTester.lua
	
	Testing utilities for the pickup items system.
	Use in Studio command bar or server console.
	
	Usage:
	local Knit = require(game.ReplicatedStorage.Packages.Knit)
	local QuestService = Knit.GetService("QuestService")
	local tester = QuestService.PickupItemsTester
	
	-- Test spawning items for a player
	tester:TestSpawnItems(player, 5)
	
	-- Simulate item pickup
	tester:TestPickup(player, itemId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PickupItemsTester = {}

---- Knit Services (resolved in Init)
local QuestService

---- Quest Data
local SharedDatas = ReplicatedStorage:WaitForChild("SharedSource", 10).Datas
local QuestDefinitions = require(SharedDatas:WaitForChild("QuestDefinitions", 10))

--[[
	Test spawning items for a specific player
	@param player Player
	@param count number - Number of items to spawn (default 3)
]]
function PickupItemsTester:TestSpawnItems(player, count)
	count = count or 3

	print("🧪 Testing pickup items spawn for " .. player.Name)

	-- Generate test spawn data
	local itemsData = {}
	local basePosition = Vector3.new(0, 5, 0)

	for i = 1, count do
		local itemId = HttpService:GenerateGUID(false)
		local offset = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))

		table.insert(itemsData, {
			ItemId = itemId,
			Location = basePosition + offset,
			QuestType = "SideQuest",
			QuestNum = "PickupCrates", -- Quest name for SideQuest type
		})

		print(string.format("  📦 Item %d: %s at %s", i, itemId, tostring(basePosition + offset)))
	end

	-- Send to client
	if QuestService and QuestService.Client.SpawnPickupItems then
		QuestService.Client.SpawnPickupItems:Fire(player, itemsData)
		print("✅ Sent spawn command to client")
		return itemsData
	else
		warn("❌ QuestService not available")
		return nil
	end
end

--[[
	Test despawning items for a specific player
	@param player Player
	@param itemIds table - Array of item IDs to despawn
]]
function PickupItemsTester:TestDespawnItems(player, itemIds)
	print("🧪 Testing pickup items despawn for " .. player.Name)

	if QuestService and QuestService.Client.DespawnPickupItems then
		QuestService.Client.DespawnPickupItems:Fire(player, itemIds)
		print(string.format("✅ Sent despawn command for %d items", #itemIds))
	else
		warn("❌ QuestService not available")
	end
end

--[[
	Simulate a pickup validation (server-side only testing)
	@param player Player
	@param itemId string
	@param questType string (default "SideQuest")
	@param questNum string/number (default "PickupCrates" for SideQuest, 1 for Daily/Weekly)
]]
function PickupItemsTester:TestPickupValidation(player, itemId, questType, questNum)
	questType = questType or "SideQuest"
	questNum = questNum or (questType == "SideQuest" and "PickupCrates" or 1)

	print("🧪 Testing pickup validation for " .. player.Name)
	print("  Item: " .. itemId)
	print("  Quest: " .. questType .. " #" .. questNum)

	-- Get PickUpItems component
	local PickUpItems = require(script.Parent.Parent.TriggeredQuest.Types.PickUpItems)

	-- Call validation
	local success = PickUpItems:ValidateAndProcessPickup(player, questType, questNum, itemId)

	if success then
		print("✅ Pickup validated successfully")
	else
		print("❌ Pickup validation failed")
	end

	return success
end

--[[
	Create test spawn points in workspace
	@param count number - Number of spawn points to create (default 5)
]]
function PickupItemsTester:CreateTestSpawnPoints(count)
	count = count or 5

	print("🧪 Creating test spawn points")

	-- Create folder
	local spawnFolder = workspace:FindFirstChild("QuestItemSpawns")
	if not spawnFolder then
		spawnFolder = Instance.new("Folder")
		spawnFolder.Name = "QuestItemSpawns"
		spawnFolder.Parent = workspace
	end

	-- Create spawn points in a circle
	local radius = 15
	local angleStep = (2 * math.pi) / count

	for i = 1, count do
		local angle = angleStep * (i - 1)
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius

		local spawnPoint = Instance.new("Part")
		spawnPoint.Name = "SpawnPoint" .. i
		spawnPoint.Size = Vector3.new(2, 0.5, 2)
		spawnPoint.Position = Vector3.new(x, 5, z)
		spawnPoint.Anchored = true
		spawnPoint.CanCollide = false
		spawnPoint.Transparency = 0.8
		spawnPoint.Color = Color3.fromRGB(0, 255, 0)
		spawnPoint.Material = Enum.Material.Neon
		spawnPoint.Parent = spawnFolder

		-- Add text label
		local billboardGui = Instance.new("BillboardGui")
		billboardGui.Size = UDim2.new(0, 100, 0, 50)
		billboardGui.StudsOffset = Vector3.new(0, 2, 0)
		billboardGui.Parent = spawnPoint

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = "Spawn " .. i
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextScaled = true
		textLabel.Parent = billboardGui
	end

	print(string.format("✅ Created %d spawn points in circle pattern", count))
	print("  Folder: workspace.QuestItemSpawns")
end

--[[
	Remove all test spawn points
]]
function PickupItemsTester:RemoveTestSpawnPoints()
	print("🧪 Removing test spawn points")

	local spawnFolder = workspace:FindFirstChild("QuestItemSpawns")
	if spawnFolder then
		spawnFolder:Destroy()
		print("✅ Removed spawn points folder")
	else
		print("⚠️ No spawn points folder found")
	end
end

--[[
	Test using Wood Crates from Workspace.Pickup_Item_Quest_Test
	This connects the Wood Crate ProximityPrompts to the PickupItemsHandler validation system
	@param player Player
	@param count number - Number of crates to use (default: all available)
]]
function PickupItemsTester:TestWithWoodCrates(player, count)
	print("🧪 Testing with Wood Crates from Workspace")
	print(
		"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	)

	-- Find the test folder
	local testFolder = workspace:FindFirstChild("Pickup_Item_Quest_Test")
	if not testFolder then
		warn("❌ Could not find Workspace.Pickup_Item_Quest_Test")
		print("   Please create the folder and add Wood Crate objects")
		return
	end

	-- Find all Wood Crate objects (Models)
	local woodCrates = {}
	for _, child in ipairs(testFolder:GetChildren()) do
		if child:IsA("Model") and child.Name:match("^Wood Crate") then
			table.insert(woodCrates, child)
		end
	end

	if #woodCrates == 0 then
		warn("❌ No Wood Crate objects found in Pickup_Item_Quest_Test")
		return
	end

	print(string.format("✅ Found %d Wood Crate(s)", #woodCrates))

	-- Use specified count or all available
	count = count or #woodCrates
	count = math.min(count, #woodCrates)

	-- Show the crates and connect them to the pickup system
	if QuestService and QuestService.CrateVisibilityManager then
		print("👁️ Making crates visible...")
		QuestService.CrateVisibilityManager:ShowAllCrates()
	else
		warn("⚠️ CrateVisibilityManager not available")
	end

	-- ⭐ NEW SYSTEM: Just track the quest and let the system handle everything
	-- The new multi-task system automatically:
	-- 1. Clears old tracking data
	-- 2. Initializes new tracking tables with taskIndex
	-- 3. Spawns items with proper metadata
	-- 4. Sends data to client with all configuration
	if QuestService then
		print("📋 Tracking side quest in player profile (NEW SYSTEM)...")
		QuestService:TrackSideQuest(player, "SideQuest", "PickupCrates")
		print("✅ Side quest tracked: SideQuest - PickupCrates")
		print("   System automatically spawned items with proper task tracking")
		print("\n👆 Player can now interact with Wood Crates to test pickup!")
		print("   Press E and hold to pick up a crate")
		print("   🎵 Sound and animations are handled client-side for smooth experience")
	else
		warn("❌ QuestService not available")
	end

	return true -- Return success status
end

--[[
	Full integration test
	@param player Player
]]
function PickupItemsTester:RunFullTest(player)
	print("🧪 Running full pickup items integration test")
	print(
		"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	)

	-- Step 1: Create spawn points
	print("\n📍 Step 1: Creating spawn points...")
	self:CreateTestSpawnPoints(5)
	task.wait(1)

	-- Step 2: Spawn items
	print("\n📦 Step 2: Spawning items for player...")
	local itemsData = self:TestSpawnItems(player, 3)

	if not itemsData then
		print("❌ Test failed: Could not spawn items")
		return
	end

	task.wait(2)

	-- Step 3: Instructions
	print("\n👆 Step 3: Player should now see 3 items")
	print("   Go touch one of them to test pickup!")
	print("   The system will automatically validate.")

	task.wait(5)

	-- Step 4: Cleanup
	print("\n🗑️ Step 4: Despawning remaining items...")
	local itemIds = {}
	for _, item in ipairs(itemsData) do
		table.insert(itemIds, item.ItemId)
	end
	self:TestDespawnItems(player, itemIds)

	print("\n✅ Full test complete!")
	print(
		"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	)
end

--[[
	Print usage instructions
]]
function PickupItemsTester:PrintUsage()
	print([[
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📚 PickupItemsTester Usage Guide
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Access the tester:
  local Knit = require(game.ReplicatedStorage.Packages.Knit)
  local QuestService = Knit.GetService("QuestService")
  local tester = QuestService.PickupItemsTester

Commands:
  -- Test with Wood Crates from Workspace (RECOMMENDED)
  tester:TestWithWoodCrates(player)
  tester:TestWithWoodCrates(player, 3)  -- Use only 3 crates
  
  -- Run full integration test
  tester:RunFullTest(player)
  
  -- Create spawn points
  tester:CreateTestSpawnPoints(5)
  
  -- Spawn items for player
  tester:TestSpawnItems(player, 3)
  
  -- Despawn items
  tester:TestDespawnItems(player, {itemId1, itemId2})
  
  -- Remove spawn points
  tester:RemoveTestSpawnPoints()
  
  -- Print this guide
  tester:PrintUsage()

Setup for Wood Crate Test:
  1. Create a folder in Workspace named "Pickup_Item_Quest_Test"
  2. Add objects named "Wood Crate" in that folder
  3. Run tester:TestWithWoodCrates(player)

Quest Type Info:
  - Now uses "SideQuest" type (repeatable standalone quests)
  - Quest name: "PickupCrates" (defined in QuestDefinitions.SideQuest)
  - Supports repeatable quests with Repeatable flag
  - Can also test with "Daily" or "Weekly" if needed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
]])
end

-- Initialize
function PickupItemsTester.Init()
	QuestService = Knit.GetService("QuestService")
end

return PickupItemsTester
