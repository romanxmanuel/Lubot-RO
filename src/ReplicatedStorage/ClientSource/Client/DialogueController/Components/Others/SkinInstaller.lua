local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

---- Assets
-- Safely get Assets folder with pcall
local Assets, DialogueAssets, DialogueSkinsAssets
local success, result = pcall(function()
    Assets = ReplicatedStorage:WaitForChild("Assets", 10)
    if Assets then
        DialogueAssets = Assets:WaitForChild("Dialogue", 10)
        if DialogueAssets then
            DialogueSkinsAssets = DialogueAssets:WaitForChild("Skins", 10)
        end
    end
end)
if not success then
    warn("[SkinInstaller] Failed to load assets:", result)
    Assets = nil
    DialogueAssets = nil
    DialogueSkinsAssets = nil
end

---- Locals
local player = Players.LocalPlayer

-- Install dialogue skins to PlayerGui if not already installed
function module:InstallDialogueSkin(skinName)
	if not DialogueSkinsAssets then
		warn("[SkinInstaller] Dialogue skins assets not found, cannot install skin:", skinName)
		return nil, nil
	end
	local playerGui = player.PlayerGui
	local dialogueKit = playerGui:WaitForChild("DialogueKit", 10)
	if not dialogueKit then
		warn("[SkinInstaller] DialogueKit not found in PlayerGui")
		return nil, nil
	end

	-- Set default DisplayOrder if not already set
	if dialogueKit:IsA("ScreenGui") then
		if dialogueKit.DisplayOrder == 0 then
			dialogueKit.DisplayOrder = 10
		end
	end

	local skinsFolder = dialogueKit:WaitForChild("Skins", 10)
	if not skinsFolder then
		warn("[SkinInstaller] Skins folder not found in DialogueKit")
		return nil, nil
	end

	-- Check if the skin is already installed
	local existingSkin = skinsFolder:FindFirstChild(skinName)
	if existingSkin then
		return dialogueKit, skinsFolder
	end

	-- Copy skin Frame from ReplicatedStorage to PlayerGui
	local skinFolder = DialogueSkinsAssets:WaitForChild(skinName, 10)
	if not skinFolder then
		warn("[SkinInstaller] Skin folder not found:", skinName)
		return nil, nil
	end
	local frame = skinFolder:FindFirstChildOfClass("Frame")
	if not frame then
		warn("[SkinInstaller] No Frame found in skin folder:", skinName)
		return nil, nil
	end
	local clonedSkin = frame:Clone()
	clonedSkin.Parent = skinsFolder

	return dialogueKit, skinsFolder
end

-- Get available skin configurations for a skin
function module:GetSkinConfig(skinName)
	if not DialogueSkinsAssets then
		warn("[SkinInstaller] Dialogue skins assets not found")
		return nil
	end
	local skinFolder = DialogueSkinsAssets:FindFirstChild(skinName)
	if not skinFolder then
		return nil
	end
	return skinFolder:FindFirstChildOfClass("Configuration")
end

-- Apply configuration to dialogue data
function module:ApplyConfig(dialogueData, skinName)
	if not DialogueSkinsAssets then
		warn("[SkinInstaller] Dialogue skins assets not found")
		return dialogueData
	end
	local skinFolder = DialogueSkinsAssets:FindFirstChild(skinName or dialogueData.SkinName)
	if not skinFolder then
		warn("[DialogueController] Skin folder not found for config application")
		return dialogueData
	end

	local configObject = module:GetSkinConfig(skinName)
	if not configObject or not configObject:IsA("Configuration") then
		warn("[DialogueController] Config not found in skin:", skinName)
		return dialogueData
	end

	dialogueData.Config = configObject

	return dialogueData
end

-- Enhanced dialogue opening with config support
function module:InstallSkinIfNotInstalled(dialogueData, skinName)
	-- Apply configuration if specified
	if skinName then
		dialogueData = self:ApplyConfig(dialogueData, skinName)
	end

	module:InstallDialogueSkin(skinName)

	return dialogueData
end

-- Get list of available skins
function module:GetAvailableSkins()
	if not DialogueSkinsAssets then
		warn("[SkinInstaller] Dialogue skins assets not found")
		return {}
	end
	local skins = {}
	for _, skinFolder in pairs(DialogueSkinsAssets:GetChildren()) do
		if skinFolder:IsA("Folder") then
			table.insert(skins, skinFolder.Name)
		end
	end
	return skins
end

function module.Start()
	-- Component start logic
end

function module.Init()
	-- Component initialization logic
end

return module
