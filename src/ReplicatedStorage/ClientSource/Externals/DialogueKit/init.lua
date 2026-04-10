-- DialogueKit/init.lua
-- Hub: loads sub-modules, wires cross-references, exports public API.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = game.Players.LocalPlayer
local playerGui = player.PlayerGui
local dialogueKitUI = playerGui:WaitForChild("DialogueKit")

-- Set default DisplayOrder if not already set
if dialogueKitUI and dialogueKitUI:IsA("ScreenGui") then
	if dialogueKitUI.DisplayOrder == 0 then
		dialogueKitUI.DisplayOrder = 10
	end
end

-- Load sub-modules
local State = require(script.State)
local SkinManager = require(script.SkinManager)
local Typewriter = require(script.Typewriter)
local InputHandler = require(script.InputHandler)
local DialogueFlow = require(script.DialogueFlow)
local NodeParser = require(script.NodeParser)

-- Initialize State with UI references
State.dialogueKitUI = dialogueKitUI
State.skins = dialogueKitUI:WaitForChild("Skins")
State.playerGui = playerGui

-- Wire cross-module references
NodeParser.CreateDialogue = DialogueFlow.CreateDialogue

Typewriter.DialogueFlow = DialogueFlow

InputHandler.DialogueFlow = DialogueFlow
InputHandler.Typewriter = Typewriter

DialogueFlow.SkinManager = SkinManager
DialogueFlow.Typewriter = Typewriter
DialogueFlow.InputHandler = InputHandler

-- Initialize skins
SkinManager.initializeSkins()

-- Export public API
local module = {}

function module.CreateDialogue(dialogueData)
	return DialogueFlow.CreateDialogue(dialogueData)
end

function module.startNodeDialogue(nodeProjectName)
	return NodeParser.startNodeDialogue(nodeProjectName)
end

return module
