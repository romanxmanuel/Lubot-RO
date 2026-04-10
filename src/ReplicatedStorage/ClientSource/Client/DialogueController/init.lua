local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local DialogueController = Knit.CreateController({
	Name = "DialogueController",
})

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 10)
DialogueController.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	DialogueController.Components[v.Name] = require(v)
end
DialogueController.GetComponent = require(componentsFolder["Get()"])
DialogueController.SetComponent = require(componentsFolder["Set()"])

--- Knit Services (none required for client-only wrapper)

--- Knit Controllers (none required)

-- Locals
local DialogueKit -- set in :KnitInit()

-- External dependencies
local ClientSource = ReplicatedStorage:WaitForChild("ClientSource", 10)
local Externals = ClientSource:WaitForChild("Externals", 10)
local DialogueKitModule = Externals:WaitForChild("DialogueKit", 10)

-- Public API
-- Open a dialogue using a data table (InitialLayer, SkinName, Layers required)
function DialogueController:Open(dialogueData: table, skinName: string?)
	if typeof(dialogueData) ~= "table" then
		warn("[DialogueController] :Open expected table dialogueData")
		return false
	end

	if not skinName then
		skinName = dialogueData.SkinName
	end

	-- Available skins: DefaultLight, DefaultDark, RPG, Cinematic, Hotline, Classic, Goofy, Interactive, Custom
	dialogueData = DialogueController.Components.SkinInstaller:InstallSkinIfNotInstalled(dialogueData, skinName)

	-- Use SkinInstaller for enhanced functionality with config support
	return DialogueKit.CreateDialogue(dialogueData)
end

-- Start a dialogue defined by a Dialogue_node project name
function DialogueController:StartNode(nodeProjectName: string)
	if typeof(nodeProjectName) ~= "string" or nodeProjectName == "" then
		warn("[DialogueController] :StartNode expected non-empty string nodeProjectName")
		return false
	end

	-- Ensure skins are installed
	DialogueController.Components.SkinInstaller:InstallDialogueSkins()

	local ok, err = pcall(function()
		DialogueKit.startNodeDialogue(nodeProjectName)
	end)
	if not ok then
		warn("[DialogueController] StartNode failed:", err)
		return false
	end
	return true
end

-- Get list of available dialogue skins
function DialogueController:GetAvailableSkins()
	return DialogueController.Components.SkinInstaller:GetAvailableSkins()
end

-- Get list of available configurations for a specific skin
function DialogueController:GetConfig(skinName: string)
	if typeof(skinName) ~= "string" or skinName == "" then
		warn("[DialogueController] :GetAvailableConfigs expected non-empty string skinName")
		return {}
	end
	return DialogueController.Components.SkinInstaller:GetSkinConfig(skinName)
end

function DialogueController:KnitStart()
	-- No-op for now
end

function DialogueController:KnitInit()
	componentsInitializer(script)

	DialogueKit = require(Externals:WaitForChild("DialogueKit", 10))
end

return DialogueController
