-- State.lua
-- All shared mutable state for DialogueKit.
-- Leaf module: no requires to other DialogueKit sub-modules.

local State = {}

-- UI references (set by init.lua)
State.dialogueKitUI = nil
State.skins = nil
State.playerGui = nil

-- Transparency cache
State.defaultTransparencyValues = {}

-- Current dialogue state
State.currentDialogue = nil
State.currentLayer = nil
State.currentContentIndex = nil
State.currentSkin = nil

-- Connection tracking
State.contentClickConnection = nil
State.continueConnection = nil
State.typewriterThread = nil
State.isTyping = false
State.replyConnections = {}
State.isShowingReplies = false
State.cinematicBars = {}

-- Input connections
State.inputBeganConnection = nil
State.mouseClickConnection = nil

-- Player state backup
State.originalWalkSpeed = nil
State.originalCoreGuiState = { Backpack = nil, Chat = nil, PlayerList = nil }
State.originalCameraType = nil
State.backgroundSoundInstance = nil
State.healthChangedConnection = nil
State.activeDialogueSound = nil

return State
