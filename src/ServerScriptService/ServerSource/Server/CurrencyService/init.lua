--[[
	CurrencyService.lua
	
	Server-side currency management service using the Knit framework.
	Handles all currency operations with proper validation and data persistence.
	
	Features:
	- Secure server-side currency validation
	- Integration with ProfileService for data persistence
	- Real-time currency updates
	- Comprehensive error handling
	- Support for multiple currencies
	
	Client Signals:
	- GetCurrency: Retrieve specific currency amount
	- GetAllCurrencies: Get all currency amounts for a player
	- GetCurrencyDefinition: Get currency configuration by ID
	- AddCurrency: Legacy signal (use SetComponent methods instead)
	- SetCurrency: Legacy signal (use SetComponent methods instead)
	
	@author Froredion
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Create the main CurrencyService with client communication signals
local CurrencyService = Knit.CreateService({
	Name = "CurrencyService",
	Client = {},
})

---- Datas
local sharedDatas = ReplicatedStorage:WaitForChild("SharedSource").Datas
local ProfileTemplate = require(sharedDatas.ProfileTemplate)

---- Knit Services
local ProfileService

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 5)
CurrencyService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	CurrencyService.Components[v.Name] = require(v)
end
local self_GetComponent = require(componentsFolder["Get()"])
CurrencyService.GetComponent = self_GetComponent
CurrencyService.SetComponent = require(componentsFolder["Set()"])

-- Currency settings - array of currency definitions
local CurrencySettings = require(ReplicatedStorage.SharedSource.Datas.CurrencySettings)
CurrencyService.Currencies = CurrencySettings.Currencies

--[[
	CLIENT COMMUNICATION METHODS
	These methods handle client requests and delegate to the appropriate components
--]]

-- Get specific currency amount for a player
-- @param player: Player - The player to get currency for
-- @param currencyId: string - The currency ID to retrieve
-- @return number - The currency amount (0 if not found)
function CurrencyService.Client:GetCurrency(player, currencyId)
	return CurrencyService.GetComponent:GetCurrency(player, currencyId)
end

-- Get all currency amounts for a player
-- @param player: Player - The player to get currencies for
-- @return table - Dictionary of currencyId -> amount
function CurrencyService.Client:GetAllCurrencies(player)
	return CurrencyService.GetComponent:GetAllCurrencies(player)
end

function CurrencyService:KnitStart() end

function CurrencyService:KnitInit()
	ProfileService = Knit.GetService("ProfileService")
	componentsInitializer(script)
end

return CurrencyService
