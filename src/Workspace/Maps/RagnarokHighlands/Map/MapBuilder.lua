-- Ragnarok Highlands Map Builder
-- This module builds the map terrain and positions assets

local MapBuilder = {}

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

-- Map center position
local MAP_CENTER = Vector3.new(2000, 50, -2000)
local MAP_SIZE = Vector3.new(800, 100, 800)

-- Zone definitions for the map
local ZONES = {
	{
		name = "CentralTown",
		center = MAP_CENTER + Vector3.new(0, 0, 0),
		size = Vector3.new(200, 10, 200),
		color = Color3.fromRGB(155, 164, 171),
		material = Enum.Material.Slate,
		description = "Medieval town center with buildings and plaza"
	},
	{
		name = "EnchantedForest",
		center = MAP_CENTER + Vector3.new(-250, 0, -250),
		size = Vector3.new(300, 20, 300),
		color = Color3.fromRGB(86, 166, 78),
		material = Enum.Material.Grass,
		description = "Dense magical forest with glowing flora"
	},
	{
		name = "MistyHills",
		center = MAP_CENTER + Vector3.new(250, 10, -200),
		size = Vector3.new(250, 30, 250),
		color = Color3.fromRGB(126, 146, 118),
		material = Enum.Material.Ground,
		description = "Rolling hills with mist and fog"
	},
	{
		name = "AncientRuins",
		center = MAP_CENTER + Vector3.new(-200, 5, 250),
		size = Vector3.new(200, 15, 200),
		color = Color3.fromRGB(146, 136, 126),
		material = Enum.Material.Sandstone,
		description = "Ancient crumbling structures"
	},
	{
		name = "SereneLake",
		center = MAP_CENTER + Vector3.new(200, 48, 250),
		size = Vector3.new(150, 5, 150),
		color = Color3.fromRGB(31, 43, 59),
		material = Enum.Material.Slate,
		description = "Calm reflective lake"
	}
}

-- Spawn point definitions
local SPAWN_POINTS = {
	{name = "TownSpawn", position = MAP_CENTER + Vector3.new(0, 52, -80), color = Color3.fromRGB(255, 235, 160)},
	{name = "ForestSpawn", position = MAP_CENTER + Vector3.new(-200, 53, -200), color = Color3.fromRGB(160, 255, 180)},
	{name = "HillsSpawn", position = MAP_CENTER + Vector3.new(200, 62, -180), color = Color3.fromRGB(255, 240, 200)},
	{name = "RuinsSpawn", position = MAP_CENTER + Vector3.new(-180, 56, 200), color = Color3.fromRGB(200, 200, 220)},
	{name = "LakeSpawn", position = MAP_CENTER + Vector3.new(180, 52, 180), color = Color3.fromRGB(160, 220, 255)}
}

-- Warp point definitions (for random teleportation)
local WARP_POINTS = {
	{name = "TownPlaza", position = MAP_CENTER + Vector3.new(0, 52, 0)},
	{name = "ForestClearing", position = MAP_CENTER + Vector3.new(-220, 53, -220)},
	{name = "Hilltop", position = MAP_CENTER + Vector3.new(220, 72, -190)},
	{name = "RuinsCenter", position = MAP_CENTER + Vector3.new(-190, 57, 210)},
	{name = "Lakeside", position = MAP_CENTER + Vector3.new(170, 52, 220)},
	{name = "HiddenGlade", position = MAP_CENTER + Vector3.new(-100, 54, -100)},
	{name = "MountainPass", position = MAP_CENTER + Vector3.new(100, 65, 100)},
	{name = "WaterfallEdge", position = MAP_CENTER + Vector3.new(0, 55, 100)}
}

-- Monster spawn area definitions
local MONSTER_AREAS = {
	{name = "ForestCreatures", center = MAP_CENTER + Vector3.new(-250, 53, -250), size = Vector3.new(120, 10, 120)},
	{name = "HillBeasts", center = MAP_CENTER + Vector3.new(250, 62, -200), size = Vector3.new(100, 15, 100)},
	{name = "RuinsSpirits", center = MAP_CENTER + Vector3.new(-200, 56, 250), size = Vector3.new(110, 12, 110)},
	{name = "LakeDenizens", center = MAP_CENTER + Vector3.new(200, 52, 250), size = Vector3.new(80, 8, 80)},
	{name = "PlazaGuards", center = MAP_CENTER + Vector3.new(0, 52, 0), size = Vector3.new(60, 10, 60)}
}

local function shouldBuild()
	if not IS_SERVER then
		print("⚠️ MapBuilder: Skipping build on client")
		return false
	end
	return true
end

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder
end

local function createPart(parent, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createSpawnLocation(parent, name, position, color)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = position
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Material = Enum.Material.Neon
	spawn.Color = color
	spawn.Parent = parent
	return spawn
end

local function createWarpMarker(parent, name, position)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(6, 12, 6)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.7
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(156, 126, 232)
	part.Parent = parent
	
	-- Add a billboard for visibility
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WarpBillboard"
	billboard.Size = UDim2.fromOffset(100, 30)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = part
	
	local label = Instance.new("TextLabel")
	label.Name = "WarpLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Text = name
	label.Parent = billboard
	
	return part
end

local function createMonsterZone(parent, name, center, size)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = center
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.8
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(255, 100, 100)
	part.Parent = parent
	
	-- Set attributes for monster spawning
	part:SetAttribute("MonsterZone", true)
	part:SetAttribute("ZoneName", name)
	
	return part
end

function MapBuilder.buildBaseTerrain()
	if not shouldBuild() then return false end
	print("🏗️ Building Ragnarok Highlands terrain...")
	
	-- Get or create map folder
	local maps = Workspace:FindFirstChild("Maps")
	if not maps then
		maps = Instance.new("Folder")
		maps.Name = "Maps"
		maps.Parent = Workspace
	end
	
	local mapFolder = maps:FindFirstChild("RagnarokHighlands")
	if not mapFolder then
		warn("RagnarokHighlands map folder not found!")
		return false
	end
	
	local mapRegionFolder = mapFolder.Map:FindFirstChild("RagnarokHighlandsRegion")
	if not mapRegionFolder then
		mapRegionFolder = ensureFolder(mapFolder.Map, "RagnarokHighlandsRegion")
	end
	
	-- Create base grass terrain covering entire map
	local _baseGrass = createPart(
		mapRegionFolder,
		"HighlandsGrass",
		Vector3.new(MAP_SIZE.X - 20, 2, MAP_SIZE.Z - 20),
		CFrame.new(MAP_CENTER + Vector3.new(0, 49, 0)),
		Color3.fromRGB(86, 166, 78),
		Enum.Material.Grass
	)
	
	-- Create zone terrain pieces
	for _, zone in ipairs(ZONES) do
		local zonePart = createPart(
			mapRegionFolder,
			zone.name,
			zone.size,
			CFrame.new(zone.center + Vector3.new(0, zone.size.Y/2 - 1, 0)),
			zone.color,
			zone.material
		)
		
		-- Add decorative zone label
		zonePart:SetAttribute("ZoneName", zone.description)
	end
	
	-- Special terrain: Lake (transparent water)
	local lakePart = mapRegionFolder:FindFirstChild("SereneLake")
	if lakePart then
		lakePart.Transparency = 0.3
		lakePart.CanCollide = false
		lakePart.Material = Enum.Material.Water
	end
	
	-- Special terrain: Hills (make them actually hilly)
	local hillsPart = mapRegionFolder:FindFirstChild("MistyHills")
	if hillsPart then
		-- Create additional hill parts for more verticality
		for i = 1, 3 do
			local _hill = createPart(
				mapRegionFolder,
				"Hill" .. i,
				Vector3.new(60, 15 + i * 5, 60),
				CFrame.new(MAP_CENTER + Vector3.new(250 + (i-2)*40, 62 + i*3, -200)),
				Color3.fromRGB(136, 156, 128),
				Enum.Material.Ground
			)
		end
	end
	
	print("✅ Base terrain built")
	return true
end

function MapBuilder.createSpawnPoints()
	if not shouldBuild() then return false end
	print("📍 Creating spawn points...")
	
	local mapFolder = Workspace.Maps:FindFirstChild("RagnarokHighlands")
	if not mapFolder then return false end
	
	local spawnFolder = ensureFolder(mapFolder, "Spawn")
	
	-- Clear existing spawn points
	for _, child in ipairs(spawnFolder:GetChildren()) do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end
	
	-- Create spawn points
	for _, spawnDef in ipairs(SPAWN_POINTS) do
		createSpawnLocation(spawnFolder, spawnDef.name, spawnDef.position, spawnDef.color)
	end
	
	print("✅ Created " .. #SPAWN_POINTS .. " spawn points")
	return true
end

function MapBuilder.createWarpPoints()
	if not shouldBuild() then return false end
	print("🌀 Creating warp points...")
	
	local mapFolder = Workspace.Maps:FindFirstChild("RagnarokHighlands")
	if not mapFolder then return false end
	
	local warpFolder = ensureFolder(mapFolder, "WarpPoints")
	
	-- Clear existing warp points
	for _, child in ipairs(warpFolder:GetChildren()) do
		if child:IsA("Part") then
			child:Destroy()
		end
	end
	
	-- Create MainWarp (primary spawn warp)
	local mainWarp = createWarpMarker(warpFolder, "MainWarp", MAP_CENTER + Vector3.new(0, 52, -80))
	mainWarp.Color = Color3.fromRGB(255, 235, 160)
	mainWarp.Size = Vector3.new(10, 16, 10)
	
	-- Create additional warp points
	for _, warpDef in ipairs(WARP_POINTS) do
		createWarpMarker(warpFolder, warpDef.name, warpDef.position)
	end
	
	print("✅ Created " .. (#WARP_POINTS + 1) .. " warp points")
	return true
end

function MapBuilder.createMonsterZones()
	if not shouldBuild() then return false end
	print("👹 Creating monster zones...")
	
	local mapFolder = Workspace.Maps:FindFirstChild("RagnarokHighlands")
	if not mapFolder then return false end
	
	local monsterFolder = ensureFolder(mapFolder, "MonsterSpawnPoints")
	
	-- Clear existing monster zones
	for _, child in ipairs(monsterFolder:GetChildren()) do
		child:Destroy()
	end
	
	-- Create monster zones
	for _, zoneDef in ipairs(MONSTER_AREAS) do
		createMonsterZone(monsterFolder, zoneDef.name, zoneDef.center, zoneDef.size)
	end
	
	print("✅ Created " .. #MONSTER_AREAS .. " monster zones")
	return true
end

function MapBuilder.createWarpRegistration()
	if not shouldBuild() then return false end
	print("📋 Creating warp registration...")
	
	local gameData = ReplicatedStorage:FindFirstChild("GameData")
	if not gameData then
		gameData = Instance.new("Folder")
		gameData.Name = "GameData"
		gameData.Parent = ReplicatedStorage
	end
	
	local warps = gameData:FindFirstChild("Warps")
	if not warps then
		warps = Instance.new("Folder")
		warps.Name = "Warps"
		warps.Parent = gameData
	end
	
	-- Check if already exists
	local existing = warps:FindFirstChild("RagnarokHighlands")
	if existing then
		print("✅ Warp registration already exists")
		return true
	end
	
	-- Create warp registration folder
	local warpFolder = Instance.new("Folder")
	warpFolder.Name = "RagnarokHighlands"
	warpFolder.Parent = warps
	
	-- Create StringValue for MapName
	local mapNameValue = Instance.new("StringValue")
	mapNameValue.Name = "MapName"
	mapNameValue.Value = "RagnarokHighlands"
	mapNameValue.Parent = warpFolder
	
	-- Create StringValue for DisplayName
	local displayNameValue = Instance.new("StringValue")
	displayNameValue.Name = "DisplayName"
	displayNameValue.Value = "Ragnarok Highlands"
	displayNameValue.Parent = warpFolder
	
	-- Create StringValue for ZoneId
	local zoneIdValue = Instance.new("StringValue")
	zoneIdValue.Name = "ZoneId"
	zoneIdValue.Value = "ragnarok_highlands"
	zoneIdValue.Parent = warpFolder
	
	-- Create IntValue for WarpNumber (use 10 as next available)
	local warpNumberValue = Instance.new("IntValue")
	warpNumberValue.Name = "WarpNumber"
	warpNumberValue.Value = 10
	warpNumberValue.Parent = warpFolder
	
	-- Create StringValue for PrimaryAlias
	local primaryAliasValue = Instance.new("StringValue")
	primaryAliasValue.Name = "PrimaryAlias"
	primaryAliasValue.Value = "highlands"
	primaryAliasValue.Parent = warpFolder
	
	-- Create StringValue for Aliases (comma-separated)
	local aliasesValue = Instance.new("StringValue")
	aliasesValue.Name = "Aliases"
	aliasesValue.Value = "ragnarok,rh,ragnarokhighlands,highland,rag,high"
	aliasesValue.Parent = warpFolder
	
	-- Create Vector3Value for SpawnPosition
	local spawnPositionValue = Instance.new("Vector3Value")
	spawnPositionValue.Name = "SpawnPosition"
	spawnPositionValue.Value = MAP_CENTER + Vector3.new(0, 52, -80)
	spawnPositionValue.Parent = warpFolder
	
	-- Create Vector3Value for FacingDirection (looking north)
	local facingDirectionValue = Instance.new("Vector3Value")
	facingDirectionValue.Name = "FacingDirection"
	facingDirectionValue.Value = Vector3.new(0, 0, -1)
	facingDirectionValue.Parent = warpFolder
	
	-- Create Vector3Value for ZoneCenter
	local zoneCenterValue = Instance.new("Vector3Value")
	zoneCenterValue.Name = "ZoneCenter"
	zoneCenterValue.Value = MAP_CENTER
	zoneCenterValue.Parent = warpFolder
	
	-- Create Vector3Value for ZoneSize
	local zoneSizeValue = Instance.new("Vector3Value")
	zoneSizeValue.Name = "ZoneSize"
	zoneSizeValue.Value = MAP_SIZE
	zoneSizeValue.Parent = warpFolder
	
	print("✅ Created warp registration")
	print("   WarpNumber: 10")
	print("   Aliases: ragnarok, rh, ragnarokhighlands, highland, rag, high")
	return true
end

function MapBuilder.positionImportedAssets()
	if not shouldBuild() then return false end
	print("🏰 Positioning imported assets...")
	
	-- Find imported asset packs
	local medievalPack = Workspace:FindFirstChild("Medieval_Build_Pack_1")
	local treePack = Workspace:FindFirstChild("TreeFoliagePack_593B82D4")
	
	if not medievalPack and not treePack then
		warn("No imported assets found for map decoration")
		return false
	end
	
	local mapFolder = Workspace.Maps:FindFirstChild("RagnarokHighlands")
	if not mapFolder then return false end
	
	local decorFolder = ensureFolder(mapFolder, "Decor")
	
	-- Position medieval buildings in town area
	if medievalPack then
		local buildingsFolder = medievalPack:FindFirstChild("Buildings")
		local castleWallsFolder = medievalPack:FindFirstChild("CastleWalls")
		
		if buildingsFolder then
			-- Position some buildings around town center
			local buildingPositions = {
				Vector3.new(-60, 52, -40),
				Vector3.new(60, 52, -40),
				Vector3.new(-40, 52, 40),
				Vector3.new(40, 52, 40),
				Vector3.new(0, 52, -120)
			}
			
			local buildingIndex = 1
			for _, building in ipairs(buildingsFolder:GetChildren()) do
				if building:IsA("Model") and buildingIndex <= #buildingPositions then
					-- Clone and position building
					local clone = building:Clone()
					clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
					if clone.PrimaryPart then
						clone:SetPrimaryPartCFrame(CFrame.new(buildingPositions[buildingIndex]))
						clone.Parent = decorFolder
						buildingIndex = buildingIndex + 1
					end
				end
			end
		end
		
		if castleWallsFolder then
			-- Position castle walls around perimeter
			local wall = castleWallsFolder:FindFirstChild("Wall")
			if wall and wall:IsA("Model") then
				local clone = wall:Clone()
				clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
				if clone.PrimaryPart then
					-- Position wall segment
					clone:SetPrimaryPartCFrame(CFrame.new(MAP_CENTER + Vector3.new(-120, 52, 0)))
					clone.Parent = decorFolder
				end
			end
		end
	end
	
	-- Position trees in forest area
	if treePack then
		local forestCenter = MAP_CENTER + Vector3.new(-250, 53, -250)
		
		-- Create a grid of trees in forest area
		for x = -4, 4 do
			for z = -4, 4 do
				if math.random(1, 3) > 1 then -- 66% density
					-- Clone a random tree type
					local treeTypes = {"NormalTree1", "NormalTree2", "PineTree2"}
					local treeType = treeTypes[math.random(1, #treeTypes)]
					local tree = treePack:FindFirstChild(treeType)
					
					if tree and tree:IsA("Model") then
						local clone = tree:Clone()
						clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
						if clone.PrimaryPart then
							local position = forestCenter + Vector3.new(x * 25, 0, z * 25)
							position = position + Vector3.new(
								math.random(-5, 5),
								0,
								math.random(-5, 5)
							)
							clone:SetPrimaryPartCFrame(CFrame.new(position))
							clone.Parent = decorFolder
						end
					end
				end
			end
		end
	end
	
	print("✅ Positioned imported assets")
	return true
end

function MapBuilder.buildCompleteMap()
	print("🎮 Building complete Ragnarok Highlands map...")
	
	-- Run all build steps
	local success = true
	
	success = success and MapBuilder.buildBaseTerrain()
	success = success and MapBuilder.createSpawnPoints()
	success = success and MapBuilder.createWarpPoints()
	success = success and MapBuilder.createMonsterZones()
	success = success and MapBuilder.positionImportedAssets()
	success = success and MapBuilder.createWarpRegistration()
	
	if success then
		print("✅ Ragnarok Highlands map built successfully!")
		print("📍 Location: 2000, 50, -2000")
		print("📏 Size: 800x100x800")
		print("🎯 ZoneId: ragnarok_highlands")
		print("🏰 Contains: Town, Forest, Hills, Ruins, Lake")
		print("👹 Monster zones: " .. #MONSTER_AREAS)
		print("🌀 Warp points: " .. (#WARP_POINTS + 1))
		print("📍 Spawn points: " .. #SPAWN_POINTS)
		print("📋 Warp registration created with number 10")
	else
		warn("⚠️ Some map components failed to build")
	end
	
	return success
end

return MapBuilder