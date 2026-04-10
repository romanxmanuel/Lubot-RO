--[[

	CurrencyController.lua
	Handles client-side currency management and UI updates.
	
	Responsibilities:
	- Maintains a local cache of all player currencies (synced via ProfileService)
	- Listens for real-time currency updates from the server
	- Updates GUI through GuiHandler components
	- Exposes helper methods to retrieve current currency values
	
	Signals:
	- CurrencyUpdated(currencyId: string, newValue: number)
	  → Fired whenever a currency value changes
	
	Dependencies:
	- ProfileService (listens to UpdateSpecificData for Currencies)
	- CurrencyService (backend validation and persistence)
	- DataController (ensures profile is loaded before initialization)
	- Components.GuiHandler (handles in-game currency display)
	
	@author Froredion
	@maintained by Mys7o
	
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

-- Datas
local CurrencySettings = require(ReplicatedStorage.SharedSource.Datas.CurrencySettings)

-- Controller
local CurrencyController = Knit.CreateController({
	Name = "CurrencyController",
	
	Currencies = {}, -- Local cache
	CurrencyUpdated = Signal.new(), -- Fires when a currency changes
})

-- Knit Services
local ProfileService, CurrencyService

-- Knit Controllers
local DataController

-- Components
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
local componentsFolder = script:WaitForChild("Components", 5)
local otherComponentsFolder = componentsFolder:WaitForChild("Others", 10)

CurrencyController.Components = {}
for _, v in pairs(otherComponentsFolder:GetChildren()) do
	CurrencyController.Components[v.Name] = require(v)
end

CurrencyController.GetComponent = require(componentsFolder["Get()"])
CurrencyController.SetComponent = require(componentsFolder["Set()"])

-- Player
local player = Players.LocalPlayer

function CurrencyController:GetCurrency(currencyId: string): number
	return CurrencyController.Currencies[currencyId] or 0
end

function CurrencyController:GetAllCurrencies(): table
	return CurrencyController.Currencies
end

local function updateCurrency(currencyId, newValue)
	CurrencyController.Currencies[currencyId] = newValue
	CurrencyController.CurrencyUpdated:Fire(currencyId, newValue)

	-- Update GUI if component exists
	local GuiHandler = CurrencyController.Components.GuiHandler
	if GuiHandler then
		GuiHandler:UpdateCurrencyDisplay(currencyId, newValue)
	end
end

function CurrencyController:KnitStart()
	-- Listen for profile updates from server
	ProfileService.UpdateSpecificData:Connect(function(redirectories, newValue)
		if #redirectories == 2 and redirectories[1] == "Currencies" then
			local currencyId = redirectories[2]
			updateCurrency(currencyId, newValue)
		end
	end)
end

function CurrencyController:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
	CurrencyService = Knit.GetService("CurrencyService")

	DataController = Knit.GetController("DataController")

	componentsInitializer(script)
end

return CurrencyController