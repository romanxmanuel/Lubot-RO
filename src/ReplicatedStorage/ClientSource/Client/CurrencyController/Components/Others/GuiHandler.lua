-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Utilities
local utilitiesFolder = ReplicatedStorage.SharedSource.Utilities
local AddCommasToNumbers = require(utilitiesFolder.Number.AddCommasToNumbers)

-- Knit Controllers
local CurrencyController

-- Player
local player = Players.LocalPlayer
local playerGui

-- UIs
local currencyGui
local currencyFrame, currencyValueTextLabel

-- Module
local GuiHandler = {}

function GuiHandler:FindGui()
	-- Try to find existing GUI in PlayerGui since it's pre-made
	currencyGui = playerGui:WaitForChild("CurrencyGui", 10)
	if not currencyGui then
		warn("[GuiHandler] CurrencyGui not found in PlayerGui")
		return false
	end

	currencyFrame = currencyGui:WaitForChild("CurrencyFrame", 10)
	if not currencyFrame then
		warn("[GuiHandler] CurrencyFrame not found in CurrencyGui")
		return false
	end

	currencyValueTextLabel = currencyFrame:WaitForChild("ValueTextLabel", 10)
	if not currencyValueTextLabel then
		warn("[GuiHandler] ValueTextLabel not found in CurrencyFrame")
		return false
	end

	return true
end

function GuiHandler:UpdateCurrencyDisplay(currencyId, amount)
	-- Example: Cash display
	if currencyId == "cash" then
		if not currencyValueTextLabel then
			if not GuiHandler:FindGui() then
				warn("[GuiHandler] Could not find currency GUI")
				return
			end
		end

		if currencyValueTextLabel then
			currencyValueTextLabel.Text = tostring(AddCommasToNumbers(amount))
		else
			warn("[GuiHandler] ValueTextLabel still not available")
		end
	end

	-- Extend here for other currencies (example: gems)
	-- if currencyId == "gems" then
	-- 	-- Update gems display
	-- end
end

function GuiHandler.Start()
	playerGui = player:WaitForChild("PlayerGui", 5)

	GuiHandler:FindGui()
end

function GuiHandler.Init()
	CurrencyController = Knit.GetController("CurrencyController")
end

return GuiHandler