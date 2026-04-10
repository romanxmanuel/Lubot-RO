--[[
	CurrencyService Get() Component
	
	Handles all currency retrieval operations on the server-side.
	Provides safe access to player currency data through ProfileService.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local module = {}

---- Knit Services
local ProfileService -- Initialized in Init() method

---- Datas
local CurrencySettings = require(ReplicatedStorage.SharedSource.Datas.CurrencySettings)
local CurrencyDefinitions = CurrencySettings.Currencies -- Cache currency definitions for performance

-- Get a player's currency amount
function module:GetCurrency(player, currencyId)
	local profile, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("Profile data not found for player: " .. (player.Name or "Unknown"))
		return 0
	end

	return profileData.Currencies[currencyId] or 0
end

-- Get all currency amounts for a player
function module:GetAllCurrencies(player)
	local profile, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("Profile data not found for player: " .. (player.Name or "Unknown"))
		return {}
	end

	local currencies = {}
	for _, currency in ipairs(CurrencyDefinitions) do
		currencies[currency.Id] = profileData.Currencies[currency.Id] or currency.DefaultValue
	end

	return currencies
end

-- Get currency definition by ID
function module:GetCurrencyDefinition(currencyId)
	for _, currency in ipairs(CurrencyDefinitions) do
		if currency.Id == currencyId then
			return currency
		end
	end
	return nil
end

-- Check if player has enough of a specific currency
function module:HasCurrency(player, currencyId, amount)
	local currentAmount = self:GetCurrency(player, currencyId)
	return currentAmount >= amount
end

function module.Start()
	-- No specific start logic needed
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
