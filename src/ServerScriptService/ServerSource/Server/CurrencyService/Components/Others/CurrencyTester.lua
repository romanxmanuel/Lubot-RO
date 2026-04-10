--[[

	CurrencyTester.lua
	
	TESTING MODULE - This is a temporary testing module for the currency system.
	It creates touchable parts in the workspace to test currency operations.
	This module can be safely removed in production builds.
	
	Features:
	- Green part: Adds +250 cash
	- Red part: Subtracts -50 cash
	- Blue part: Adds +1000 cash
	- 1-second cooldown per player per part
	- Visual feedback on touch
	
	@author Generated for testing purposes	
	@version 1.1

--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local module = {}

---- Services
local CurrencyService

---- Datas
local CurrencySettings = require(ReplicatedStorage.SharedSource.Datas.CurrencySettings)

---- Cooldown tracking
local touchCooldowns = {} -- [player] = {[partName] = lastTouchTime}

---- Part configurations
local PART_CONFIGS = {
	{
		name = "IncreasePart",
		color = Color3.fromRGB(0, 255, 0), -- Green
		position = Vector3.new(0, 5, 0),
		text = "+250 Cash",
		action = "increase",
		amount = 250,
	},
	{
		name = "DecreasePart",
		color = Color3.fromRGB(255, 0, 0), -- Red
		position = Vector3.new(10, 5, 0),
		text = "-50 Cash",
		action = "decrease",
		amount = 50,
	},
	{
		name = "BonusPart",
		color = Color3.fromRGB(0, 0, 255), -- Blue
		position = Vector3.new(20, 5, 0),
		text = "Set 1000 Cash",
		action = "set",
		amount = 1000,
	},
}

local COOLDOWN_TIME = 1 -- 1 second cooldown

---- Helper Functions
local function createPart(config)
	local part = Instance.new("Part")
	part.Name = config.name
	part.Size = Vector3.new(4, 4, 4)
	part.Position = config.position
	part.Color = config.color
	part.Material = Enum.Material.Neon
	part.Shape = Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = true

	-- Create a SurfaceGui for the text
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Top
	surfaceGui.Parent = part

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = config.text
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.SourceSansBold
	textLabel.Parent = surfaceGui

	return part
end

local function isOnCooldown(player, partName)
	if not touchCooldowns[player] then
		touchCooldowns[player] = {}
	end

	local lastTouchTime = touchCooldowns[player][partName]
	if not lastTouchTime then
		return false
	end

	return (tick() - lastTouchTime) < COOLDOWN_TIME
end

local function setCooldown(player, partName)
	if not touchCooldowns[player] then
		touchCooldowns[player] = {}
	end
	touchCooldowns[player][partName] = tick()
end

local function handlePartTouch(part, config)
	local function onTouch(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if not humanoid then
			return
		end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		-- Check cooldown
		if isOnCooldown(player, config.name) then
			return
		end

		-- Set cooldown
		setCooldown(player, config.name)

		-- Get the first currency (cash) for testing
		local currencyId = CurrencySettings.Currencies[1].Id

		-- Perform the currency action
		local success = false
		if config.action == "increase" then
			success = CurrencyService.SetComponent:IncreaseCurrency(player, currencyId, config.amount)
		elseif config.action == "decrease" then
			success = CurrencyService.SetComponent:DecreaseCurrency(player, currencyId, config.amount)
		elseif config.action == "set" then
			success = CurrencyService.SetComponent:SetCurrency(player, currencyId, config.amount)
		end

		-- Visual feedback
		if success then
			-- Create a brief flash effect
			local originalColor = part.Color
			part.Color = Color3.fromRGB(255, 255, 255)

			local tween = TweenService:Create(
				part,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = originalColor }
			)
			tween:Play()

			print(
				string.format(
					"Player %s touched %s - Action: %s %d %s",
					player.Name,
					config.name,
					config.action,
					config.amount,
					currencyId
				)
			)
		else
			-- Error feedback - red flash
			local originalColor = part.Color
			part.Color = Color3.fromRGB(255, 100, 100)

			local tween = TweenService:Create(
				part,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = originalColor }
			)
			tween:Play()

			warn(string.format("Failed to execute currency action for player %s", player.Name))
		end
	end

	part.Touched:Connect(onTouch)
end

local function cleanupPlayerCooldowns()
	-- Clean up cooldowns for players who left
	Players.PlayerRemoving:Connect(function(player)
		touchCooldowns[player] = nil
	end)
end

function module.Start()
	if true then
		return
	end

	-- Get CurrencyService reference
	CurrencyService = Knit.GetService("CurrencyService")

	-- Create the testing parts
	for _, config in ipairs(PART_CONFIGS) do
		local part = createPart(config)
		handlePartTouch(part, config)
		part.Parent = Workspace
	end

	-- Setup cleanup
	cleanupPlayerCooldowns()

	print("CurrencyTester: Created", #PART_CONFIGS, "testing parts")
end

function module.Init()
	-- Module initialization
end

return module