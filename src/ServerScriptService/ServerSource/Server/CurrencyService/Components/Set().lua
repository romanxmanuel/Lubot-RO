--[[
	CurrencyService Set() Component
	
	Handles all currency modification operations on the server-side.
	Provides secure currency updates with validation and ProfileService integration.
	
	Methods:
	- IncreaseCurrency: Add to current amount
	- DecreaseCurrency: Subtract from current amount (minimum 0)
	- SetCurrency: Set exact amount
	- ValidateCurrencyId: Validate currency exists
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local module = {}

---- Knit Services
local ProfileService -- Initialized in Init() method

---- Datas
local CurrencySettings = require(ReplicatedStorage.SharedSource.Datas.CurrencySettings)
local CurrencyDefinitions = CurrencySettings.Currencies -- Cache currency definitions for performance

-- Increase currency for a player (increments the current amount)
function module:IncreaseCurrency(player, currencyId, amount)
	local profile, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("Profile data not found for player: " .. (player.Name or "Unknown"))
		return false
	end

	local currencyDef = self:ValidateCurrencyId(currencyId)
	if not currencyDef then
		warn("Currency definition not found for: " .. tostring(currencyId))
		return false
	end

	-- Ensure amount is positive for increment operation
	if amount <= 0 then
		warn("Amount must be positive for IncreaseCurrency: " .. tostring(amount))
		return false
	end

	-- Use ProfileService:ChangeData() to properly update the currency
	local currentAmount = profileData.Currencies[currencyId] or 0
	local newAmount = currentAmount + amount
	ProfileService:ChangeData(player, { "Currencies", currencyId }, newAmount)
	return true
end

-- Decrease currency for a player (decrements the current amount)
function module:DecreaseCurrency(player, currencyId, amount)
	local profile, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("Profile data not found for player: " .. (player.Name or "Unknown"))
		return false
	end

	local currencyDef = self:ValidateCurrencyId(currencyId)
	if not currencyDef then
		warn("Currency definition not found for: " .. tostring(currencyId))
		return false
	end

	-- Ensure amount is positive for decrement operation
	if amount <= 0 then
		warn("Amount must be positive for DecreaseCurrency: " .. tostring(amount))
		return false
	end

	-- Use ProfileService:ChangeData() to properly update the currency
	local currentAmount = profileData.Currencies[currencyId] or 0
	local newAmount = currentAmount - amount
	ProfileService:ChangeData(player, { "Currencies", currencyId }, newAmount)
	return true
end

-- Set currency amount for a player
function module:SetCurrency(player, currencyId, amount)
	local profile, profileData = ProfileService:GetProfile(player)
	if not profileData then
		warn("Profile data not found for player: " .. (player.Name or "Unknown"))
		return false
	end

	local currencyDef = self:ValidateCurrencyId(currencyId)
	if not currencyDef then
		warn("Currency definition not found for: " .. tostring(currencyId))
		return false
	end

	-- Use ProfileService:ChangeData() to properly update the currency
	local newAmount = amount
	ProfileService:ChangeData(player, { "Currencies", currencyId }, newAmount)
	return true
end

-- Validate currency ID and return its definition if valid
function module:ValidateCurrencyId(currencyId)
	for _, currency in ipairs(CurrencyDefinitions) do
		if currency.Id == currencyId then
			return currency
		end
	end
	return nil
end

function module.Start()
	-- No specific start logic needed
end

function module.Init()
	ProfileService = Knit.GetService("ProfileService")
end

return module
