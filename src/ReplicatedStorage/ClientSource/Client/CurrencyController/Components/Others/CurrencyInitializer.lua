-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Datas
local CurrencySettings = require(ReplicatedStorage.SharedSource.Datas.CurrencySettings)

-- Knit Services
local ProfileService, CurrencyService

-- Knit Controllers
local DataController, CurrencyController

-- Player & GUI references
local player = Players.LocalPlayer
local playerGui

-- Module
local CurrencyInitializer = {}

-- Initialize currency data and GUI
function CurrencyInitializer.InitializeCurrencies()
	-- Ensure profile is loaded
	DataController:WaitUntilProfileLoaded()

	local GuiHandler = CurrencyController.Components.GuiHandler

	-- Initialize the currency GUI (find pre-made GUI in StarterGui)
	if not GuiHandler:FindGui() then
		warn("[CurrencyInitializer] Failed to initialize currency GUI")
		return
	end

	local profileData = DataController.Data

	-- Set initial values in cache and GUI
	for _, currencyDefinition in ipairs(CurrencySettings.Currencies) do
		local id = currencyDefinition.Id
		local value = profileData.Currencies[id]

		CurrencyController.Currencies[id] = value
		GuiHandler:UpdateCurrencyDisplay(id, value)
	end
end

function CurrencyInitializer.Start()
	playerGui = player:WaitForChild("PlayerGui", 5)

	CurrencyInitializer.InitializeCurrencies()
end

function CurrencyInitializer.Init()
	ProfileService = Knit.GetService("ProfileService")
	CurrencyService = Knit.GetService("CurrencyService")

	DataController = Knit.GetController("DataController")
	CurrencyController = Knit.GetController("CurrencyController")
end

return CurrencyInitializer