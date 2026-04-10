-- DialogueFlow/init.lua
-- Hub: loads sub-modules, builds public API, wires cross-references.

local ExecHandler = require(script.ExecHandler)
local ContinueButton = require(script.ContinueButton)
local ReplyManager = require(script.ReplyManager)
local ContentDisplay = require(script.ContentDisplay)
local PlayerSettings = require(script.PlayerSettings)
local CinematicBars = require(script.CinematicBars)
local Lifecycle = require(script.Lifecycle)

local DialogueFlow = {}

-- External refs (set by parent DialogueKit/init.lua)
DialogueFlow.SkinManager = nil
DialogueFlow.Typewriter = nil
DialogueFlow.InputHandler = nil

-- Exec
DialogueFlow.executeLayerFunction = ExecHandler.executeLayerFunction
DialogueFlow.findExecForContent = ExecHandler.findExecForContent
DialogueFlow.findExecForContinue = ExecHandler.findExecForContinue
DialogueFlow.findExecForReply = ExecHandler.findExecForReply

-- Continue button
DialogueFlow.showContinueButton = ContinueButton.showContinueButton
DialogueFlow.hideContinueButton = ContinueButton.hideContinueButton

-- Replies
DialogueFlow.clearReplyConnections = ReplyManager.clearReplyConnections
DialogueFlow.showReplies = ReplyManager.showReplies
DialogueFlow.onReplyButtonClicked = ReplyManager.onReplyButtonClicked
DialogueFlow.onRepliesTweenComplete = ReplyManager.onRepliesTweenComplete

-- Content
DialogueFlow.displayContent = ContentDisplay.displayContent

-- Player settings
DialogueFlow.applyPlayerSettings = PlayerSettings.applyPlayerSettings
DialogueFlow.restorePlayerSettings = PlayerSettings.restorePlayerSettings
DialogueFlow.setupPlayerDeathHandling = PlayerSettings.setupPlayerDeathHandling

-- Cinematic bars
DialogueFlow.createCinematicBars = CinematicBars.createCinematicBars

-- Lifecycle
DialogueFlow.closeDialogue = Lifecycle.closeDialogue
DialogueFlow.onContinueButtonClicked = Lifecycle.onContinueButtonClicked
DialogueFlow.CreateDialogue = Lifecycle.CreateDialogue

-- Inject hub reference into sub-modules that need cross-module access
ContinueButton.Flow = DialogueFlow
ReplyManager.Flow = DialogueFlow
ContentDisplay.Flow = DialogueFlow
PlayerSettings.Flow = DialogueFlow
Lifecycle.Flow = DialogueFlow

return DialogueFlow
