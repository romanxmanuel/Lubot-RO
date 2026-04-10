--[[
	BlockParryHandler.lua
	CLIENT-SIDE component for the Parry and Block system.
	Handles F-key input, client-predicted block stance (immediate visual feedback),
	server reconciliation (rollback on rejection), and VFX/SFX for block hits,
	parry success, and stun.
	Location: CombatController/Components/Others/BlockParryHandler.lua
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local PlatformTracker = require(ReplicatedStorage.ClientSource.Utilities.Core.PlatformTracker)

local BlockParryHandler = {}

-- Preloaded sound templates (soundId → Sound instance in Assets.Effects.Combat)
local soundTemplates = {}

-- Settings
local ParryBlockSettings

-- Knit Services (server-side, accessed via Knit client bridge)
local CombatService

-- Knit Controllers
local StatusEffectController

-- State
BlockParryHandler._isBlocking = false
BlockParryHandler._onCooldown = false
BlockParryHandler._blockTrack = nil -- AnimationTrack for block idle

-- UI references (loaded in Start from PlayerGui)
local BlockInputUI -- ScreenGui
local BlockContainer -- PC "F" key prompt
local MobileBlockButton -- Mobile touch button

-- VFX templates (loaded in Init, may be nil if assets don't exist yet)
local ParryFlashTemplate
local BlockBreakTemplate

-- Default WalkSpeed
local DEFAULT_WALKSPEED = 16

-- Posture bar UI references (pre-built in BlockInputUI ScreenGui)
local PostureBarContainer -- Frame wrapping the bar
local PostureBarFill -- Inner frame showing current posture
local _postureConnection -- Attribute change listener
local _fillTween -- Active tween for smooth fill animation

-- Hotbar-based positioning state

-- ============================================================
-- HELPERS
-- ============================================================

local function getLocalCharacter()
	local player = Players.LocalPlayer
	local char = player and player.Character
	if not char then
		return nil, nil, nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return char, humanoid, hrp
end

local function playAnimation(humanoid, animId, looped)
	if not animId or animId == "" then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = humanoid:LoadAnimation(anim)
	if looped then
		track.Looped = true
	end
	track:Play(0)
	return track
end

local function stopAnimation(track)
	if track and track.IsPlaying then
		track:Stop(0.2)
	end
end

local function playSound(soundId, parent)
	if not soundId or soundId == "" then
		return
	end
	local template = soundTemplates[soundId]
	local sound
	if template then
		sound = template:Clone()
	else
		sound = Instance.new("Sound")
		sound.SoundId = soundId
	end
	sound.Parent = parent or workspace
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return sound
end

--- Resolve a VFX asset from a dot-separated path like "ReplicatedStorage.Assets.Effects.Combat.Parry"
local function resolveVfxAsset(pathStr)
	if not pathStr or pathStr == "" then
		return nil
	end
	local parts = string.split(pathStr, ".")
	local current: any = game
	for i = 1, #parts do
		current = current:FindFirstChild(parts[i])
		if not current then
			return nil
		end
	end
	return current
end

local function setWalkSpeed(humanoid, multiplier)
	local baseSpeed = humanoid:GetAttribute("BaseWalkSpeed") or DEFAULT_WALKSPEED
	humanoid.WalkSpeed = baseSpeed * multiplier
end

local function restoreWalkSpeed(humanoid)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local baseSpeed = humanoid:GetAttribute("BaseWalkSpeed") or DEFAULT_WALKSPEED
	humanoid.WalkSpeed = baseSpeed
end

-- ============================================================
-- HOTBAR POSITIONING (viewport-based prediction)
-- ============================================================

-- Roblox default hotbar constants (approximate)
local HOTBAR_SLOT_SIZE = 58 -- px per slot
local HOTBAR_SLOT_GAP = 5 -- px between slots
local HOTBAR_BOTTOM_MARGIN = 10 -- px from screen bottom
local HOTBAR_HEIGHT = 58 -- px tall

--- Returns the number of tools in the player's backpack + character (visible hotbar slots)
local function getToolCount()
	local player = Players.LocalPlayer
	if not player then return 0 end

	local count = 0

	-- Tools in Backpack
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				count += 1
			end
		end
	end

	-- Tool currently equipped (in Character)
	local char = player.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") then
				count += 1
			end
		end
	end

	return count
end

--- Predicts the hotbar's top-edge Y position and center X in BlockInputUI offset space.
--- Returns centerX, topY (pixels), or nil if backpack GUI is disabled.
local function predictHotbarPosition()
	local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	if not viewportSize or viewportSize.X == 0 then return nil, nil end

	local guiInsetY = GuiService:GetGuiInset().Y

	-- Screen height in BlockInputUI space (IgnoreGuiInset=false)
	local screenH = viewportSize.Y - guiInsetY
	local screenW = viewportSize.X

	local toolCount = math.max(getToolCount(), 1) -- At least 1 slot shown
	local hotbarWidth = toolCount * HOTBAR_SLOT_SIZE + (toolCount - 1) * HOTBAR_SLOT_GAP

	local centerX = screenW / 2
	local hotbarTopY = screenH - HOTBAR_BOTTOM_MARGIN - HOTBAR_HEIGHT


	return centerX, hotbarTopY
end

--- Checks if the default backpack CoreGui is enabled
local function isBackpackEnabled()
	local ok, enabled = pcall(function()
		return game:GetService("StarterGui"):GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
	end)
	return ok and enabled
end

--- Dynamically positions BlockContainer and PostureBarContainer above the predicted hotbar.
local function updateBlockUIPosition()
	if not BlockInputUI then return end

	local centerX, hotbarTopY = predictHotbarPosition()

	if centerX and hotbarTopY and isBackpackEnabled() then
		-- Position BlockContainer above predicted hotbar top
		if BlockContainer then
			local gap = 10
			BlockContainer.AnchorPoint = Vector2.new(0, 0)
			local blockW = BlockContainer.AbsoluteSize.X
			local blockH = BlockContainer.AbsoluteSize.Y
			local posX = centerX - blockW / 2
			local posY = hotbarTopY - gap - blockH
			BlockContainer.Position = UDim2.fromOffset(posX, posY)
		end

		-- Position PostureBarContainer above BlockContainer
		if PostureBarContainer then
			local postureGap = 6
			PostureBarContainer.AnchorPoint = Vector2.new(0, 0)
			local postureW = PostureBarContainer.AbsoluteSize.X
			local postureH = PostureBarContainer.AbsoluteSize.Y
			local aboveY
			if BlockContainer then
				local blockOffsetY = BlockContainer.Position.Y.Offset
				aboveY = blockOffsetY - postureGap - postureH
			else
				aboveY = hotbarTopY - 10 - postureH
			end
			local posX = centerX - postureW / 2
			PostureBarContainer.Position = UDim2.fromOffset(posX, aboveY)
		end
	else
		-- No hotbar (backpack disabled) — center horizontally, near bottom
		if BlockContainer then
			BlockContainer.AnchorPoint = Vector2.new(0, 0)
			BlockContainer.Position = UDim2.new(0.5, -BlockContainer.AbsoluteSize.X / 2, 0.92, -BlockContainer.AbsoluteSize.Y)
		end
		if PostureBarContainer then
			PostureBarContainer.AnchorPoint = Vector2.new(0, 0)
			PostureBarContainer.Position = UDim2.new(0.5, -PostureBarContainer.AbsoluteSize.X / 2, 0.88, -PostureBarContainer.AbsoluteSize.Y)
		end
	end
end

--- Sets up listeners to reposition block UI when viewport or tools change.
local function setupHotbarPositioning()
	updateBlockUIPosition()

	-- Reposition on screen resize
	if BlockInputUI then
		BlockInputUI:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateBlockUIPosition)
	end

	-- Reposition when camera viewport changes
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateBlockUIPosition)
	end

	-- Reposition when tools are added/removed from Backpack
	local player = Players.LocalPlayer
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(updateBlockUIPosition)
	backpack.ChildRemoved:Connect(updateBlockUIPosition)

	-- Reposition when tool is equipped/unequipped (moves to/from Character)
	player.CharacterAdded:Connect(function(char)
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				updateBlockUIPosition()
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				updateBlockUIPosition()
			end
		end)
	end)

	-- Connect for current character too
	local char = player.Character
	if char then
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				updateBlockUIPosition()
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				updateBlockUIPosition()
			end
		end)
	end
end

-- ============================================================
-- PLATFORM
-- ============================================================

--- Returns the current platform category from PlatformTracker: "PC", "Mobile", or "Console"
function BlockParryHandler:GetPlatform()
	return PlatformTracker:Get()
end

--- Returns true if the current platform is mobile (phone or tablet)
function BlockParryHandler:IsMobile()
	return PlatformTracker:Get() == "Mobile"
end

-- ============================================================
-- UI MANAGEMENT
-- ============================================================

--- Syncs MobileBlockButton size and position to the JumpButton in TouchGui.
--- Called once on setup and whenever the JumpButton's AbsoluteSize/AbsolutePosition changes.
local function syncMobileButtonToJumpButton()
	if not MobileBlockButton then
		return
	end
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if not touchGui then
		return
	end
	local controlFrame = touchGui:FindFirstChild("TouchControlFrame")
	if not controlFrame then
		return
	end
	local jumpButton = controlFrame:FindFirstChild("JumpButton")
	if not jumpButton then
		return
	end

	local absSize = jumpButton.AbsoluteSize
	local absPos = jumpButton.AbsolutePosition

	-- 1.5x smaller than JumpButton
	local btnSize = absSize.X / 1.5
	MobileBlockButton.Size = UDim2.fromOffset(btnSize, btnSize)
	-- Position right next to the JumpButton, vertically centered
	local padding = -btnSize * 0.15
	local yOffset = absPos.Y + (absSize.Y - btnSize) / 2
	MobileBlockButton.Position = UDim2.fromOffset(absPos.X - btnSize - padding, yOffset)
end

-- Connection tracking for JumpButton property watchers
local _jumpButtonConnections = {}

--- Sets up listeners to keep the mobile block button synced to the JumpButton.
local function setupJumpButtonSync()
	-- Clean up old connections
	for _, conn in ipairs(_jumpButtonConnections) do
		conn:Disconnect()
	end
	table.clear(_jumpButtonConnections)

	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	-- TouchGui may not exist yet (appears when platform switches to mobile)
	local touchGui = playerGui:FindFirstChild("TouchGui")
	if not touchGui then
		-- Watch for TouchGui to appear
		table.insert(_jumpButtonConnections, playerGui.ChildAdded:Connect(function(child)
			if child.Name == "TouchGui" then
				setupJumpButtonSync()
			end
		end))
		return
	end

	local controlFrame = touchGui:FindFirstChild("TouchControlFrame")
	if not controlFrame then
		return
	end
	local jumpButton = controlFrame:FindFirstChild("JumpButton")
	if not jumpButton then
		return
	end

	-- Initial sync
	syncMobileButtonToJumpButton()

	-- Re-sync when JumpButton size or position changes
	table.insert(_jumpButtonConnections, jumpButton:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncMobileButtonToJumpButton))
	table.insert(_jumpButtonConnections, jumpButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncMobileButtonToJumpButton))
end

--- Updates which block UI is visible based on the current platform.
local function updateUIVisibility()
	if not BlockContainer or not MobileBlockButton then
		return
	end
	local platform = PlatformTracker:Get()
	BlockContainer.Visible = (platform ~= "Mobile")
	MobileBlockButton.Visible = (platform == "Mobile")
end

--- Updates the visual state of both UI elements (idle, blocking, cooldown, stunned).
local function updateUIState()
	if not BlockContainer and not MobileBlockButton then
		return
	end

	-- Determine the visual state
	local state = "Idle"
	if StatusEffectController and (StatusEffectController:HasEffect("Stun") or StatusEffectController:HasEffect("BlockBreak")) then
		state = "Hidden"
	elseif BlockParryHandler._isBlocking then
		state = "Blocking"
	elseif BlockParryHandler._onCooldown then
		state = "Cooldown"
	end

	-- Apply to PC BlockContainer
	if BlockContainer then
		if state == "Hidden" then
			BlockContainer.Visible = false
		elseif PlatformTracker:Get() ~= "Mobile" then
			BlockContainer.Visible = true
			if state == "Blocking" then
				BlockContainer.BackgroundTransparency = 0.3
			elseif state == "Cooldown" then
				BlockContainer.BackgroundTransparency = 0.3
			else -- Idle
				BlockContainer.BackgroundTransparency = 0.5
			end
		end
	end

	-- Apply to MobileBlockButton
	if MobileBlockButton then
		if state == "Hidden" then
			MobileBlockButton.Visible = false
		elseif PlatformTracker:Get() == "Mobile" then
			MobileBlockButton.Visible = true
			if state == "Blocking" then
				MobileBlockButton.ImageTransparency = 0
			elseif state == "Cooldown" then
				MobileBlockButton.ImageTransparency = 0.7
			else -- Idle
				MobileBlockButton.ImageTransparency = 0.3
			end
		end
	end
end

-- ============================================================
-- BLOCK STATE (client-predicted)
-- ============================================================

--- Immediately enters block stance on the client (no server wait).
function BlockParryHandler:EnterBlockStance()
	if self._isBlocking or self._onCooldown or (StatusEffectController and (StatusEffectController:HasEffect("Stun") or StatusEffectController:HasEffect("BlockBreak"))) then
		return
	end

	local char, humanoid, _hrp = getLocalCharacter()
	if not char or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Post-attack delay: don't enter block too soon after attacking
	local lastAttack = char:GetAttribute("LastAttackTime") or 0
	local postDelay = ParryBlockSettings.Block.PostAttackBlockDelay or 0.3
	if (workspace:GetServerTimeNow() - lastAttack) < postDelay then
		return
	end

	self._isBlocking = true

	-- Play block idle animation — use bare-handed anim when no tool equipped
	local holdingTool = char:FindFirstChildWhichIsA("Tool") ~= nil
	local blockAnim
	if holdingTool then
		blockAnim = ParryBlockSettings.Animations.BlockIdle
	else
		blockAnim = ParryBlockSettings.Animations.BlockIdleBareHanded
	end

	local track = playAnimation(humanoid, blockAnim, false)
	self._blockTrack = track

	-- Pause at "PauseBlock" marker event, or at 0.2s as fallback
	if track then
		local paused = false
		local markerConn
		markerConn = track:GetMarkerReachedSignal("PauseBlock"):Connect(function()
			if not paused then
				paused = true
				track:AdjustSpeed(0)
			end
			if markerConn then
				markerConn:Disconnect()
				markerConn = nil
			end
		end)

	end

	-- Apply movement slow (client prediction)
	setWalkSpeed(humanoid, ParryBlockSettings.Block.MovementSpeedMultiplier)

	-- Play block start sound
	playSound(ParryBlockSettings.Sounds.BlockStart, char)

	-- Set client-side attribute so other systems can read combat state
	char:SetAttribute("CombatState", "Blocking")

	-- Update UI to blocking state
	updateUIState()
end

--- Immediately exits block stance on the client.
function BlockParryHandler:ExitBlockStance()
	if not self._isBlocking then
		return
	end

	local char, humanoid = getLocalCharacter()
	self._isBlocking = false

	stopAnimation(self._blockTrack)
	self._blockTrack = nil

	if humanoid and humanoid.Health > 0 then
		restoreWalkSpeed(humanoid)
	end

	if char then
		char:SetAttribute("CombatState", "Idle")
	end

	-- Brief cooldown visual on UI
	self._onCooldown = true
	updateUIState()
	task.delay(ParryBlockSettings.Block.BlockCooldown, function()
		BlockParryHandler._onCooldown = false
		updateUIState()
	end)
end

--- Public method: Start blocking (called by F key or mobile button).
--- Enters block stance immediately and sends validation request to server.
function BlockParryHandler:StartBlock()
	if self._isBlocking or self._onCooldown or (StatusEffectController and (StatusEffectController:HasEffect("Stun") or StatusEffectController:HasEffect("BlockBreak"))) then
		return
	end

	self:EnterBlockStance()

	local blockStartTime = workspace:GetServerTimeNow()

	CombatService:RequestBlock(true, blockStartTime):catch(function(err)
		warn("[BlockParryHandler] RequestBlock failed:", err)
		self:ExitBlockStance()
	end)
end

--- Public method: Stop blocking (called by F key release or mobile button release).
function BlockParryHandler:StopBlock()
	if not self._isBlocking then
		return
	end

	self:ExitBlockStance()

	CombatService:RequestBlock(false):catch(function() end)
end

-- ============================================================
-- VFX
-- ============================================================

--- Play parry flash particle effect 2 studs in front of a character.
--- Clones the Parry part, welds it to HumanoidRootPart offset 2 studs forward.
function BlockParryHandler:PlayParryFlashVFX(targetChar)
	if not ParryFlashTemplate then
		return
	end
	local hrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local clone = ParryFlashTemplate:Clone()
	clone.Anchored = false
	clone.CanCollide = false
	clone.CFrame = hrp.CFrame * CFrame.new(0, 0, -2)

	-- Weld to HRP so it stays relative to the character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = clone
	weld.Parent = clone

	clone.Parent = workspace

	-- Emit all particles
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			local emitCount = desc:GetAttribute("EmitCount") or 15
			desc:Emit(emitCount)
		end
	end

	-- Cleanup after particles finish
	task.delay(2, function()
		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
end

--- Play block break VFX on a character's HumanoidRootPart.
--- Clones the "Block Break" part, positions at HRP, emits particles.
function BlockParryHandler:PlayBlockBreakVFX(targetChar)
	if not BlockBreakTemplate then
		return
	end
	local hrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local clone = BlockBreakTemplate:Clone()
	clone.Anchored = false
	clone.CanCollide = false
	clone.CFrame = hrp.CFrame

	-- Weld to HRP
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = clone
	weld.Parent = clone

	clone.Parent = workspace

	-- Emit all particles
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			local emitCount = desc:GetAttribute("EmitCount") or 20
			desc:Emit(emitCount)
		end
	end

	-- Cleanup after particles finish
	task.delay(2, function()
		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
end

-- ============================================================
-- POSTURE BAR UI
-- ============================================================

--- Finds the pre-built posture bar elements inside BlockInputUI.
local function findPostureBar()
	if not BlockInputUI then
		return
	end

	PostureBarContainer = BlockInputUI:FindFirstChild("PostureBarContainer")
	if PostureBarContainer then
		PostureBarFill = PostureBarContainer:FindFirstChild("Fill")
	end

	if not PostureBarContainer or not PostureBarFill then
		warn("[BlockParryHandler] PostureBarContainer or Fill not found in BlockInputUI")
	end
end

-- Posture color thresholds: yellow → orange → red as posture depletes
local POSTURE_COLOR_HIGH = Color3.fromRGB(255, 200, 50) -- > 50%
local POSTURE_COLOR_MID = Color3.fromRGB(255, 140, 30)  -- 25-50%
local POSTURE_COLOR_LOW = Color3.fromRGB(255, 60, 30)   -- < 25%
local FILL_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local COLOR_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

--- Updates the posture bar fill and visibility based on current Posture attribute.
--- Uses TweenService for smooth size and color transitions.
local function updatePostureBar()
	if not PostureBarContainer or not PostureBarFill then
		return
	end

	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	if not char then
		PostureBarContainer.Visible = false
		return
	end

	local posture = char:GetAttribute("Posture")
	local maxPosture = char:GetAttribute("MaxPosture")
	if not posture or not maxPosture or maxPosture <= 0 then
		PostureBarContainer.Visible = false
		return
	end

	local ratio = math.clamp(posture / maxPosture, 0, 1)

	-- Show bar when posture is not full
	PostureBarContainer.Visible = (ratio < 1)

	-- Determine target color
	local targetColor
	if ratio > 0.5 then
		targetColor = POSTURE_COLOR_HIGH
	elseif ratio > 0.25 then
		targetColor = POSTURE_COLOR_MID
	else
		targetColor = POSTURE_COLOR_LOW
	end

	-- Cancel previous fill tween
	if _fillTween then
		_fillTween:Cancel()
	end

	-- Tween fill size and color smoothly
	_fillTween = TweenService:Create(PostureBarFill, FILL_TWEEN_INFO, {
		Size = UDim2.new(ratio, 0, 1, 0),
	})
	_fillTween:Play()

	-- Tween color separately for a smooth blend
	TweenService:Create(PostureBarFill, COLOR_TWEEN_INFO, {
		BackgroundColor3 = targetColor,
	}):Play()
end

--- Connects the posture attribute listener to the local character.
local function connectPostureListener()
	if _postureConnection then
		_postureConnection:Disconnect()
		_postureConnection = nil
	end

	local char = Players.LocalPlayer and Players.LocalPlayer.Character
	if not char then
		return
	end

	_postureConnection = char:GetAttributeChangedSignal("Posture"):Connect(updatePostureBar)
	updatePostureBar()
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

function BlockParryHandler.Start()
	-- Get StatusEffectController for stun state queries (must be in Start, not Init, so its components are ready)
	StatusEffectController = Knit.GetController("StatusEffectController")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- === BLOCK INPUT UI SETUP ===
	BlockInputUI = playerGui:WaitForChild("BlockInputUI", 10)
	if BlockInputUI then
		BlockContainer = BlockInputUI:FindFirstChild("BlockContainer")
		MobileBlockButton = BlockInputUI:FindFirstChild("MobileBlockButton")
	else
		warn("[BlockParryHandler] BlockInputUI not found in PlayerGui")
	end

	-- Set initial UI visibility based on current platform
	updateUIVisibility()
	updateUIState()

	-- Sync mobile block button size/position to JumpButton
	setupJumpButtonSync()

	-- Switch visible UI when platform changes (e.g., player plugs in keyboard on tablet)
	PlatformTracker.Changed:Connect(function(_category, _deviceType)
		updateUIVisibility()
		updateUIState()
		-- Re-sync mobile button layout (TouchGui may have appeared/changed)
		setupJumpButtonSync()
		-- Cancel block if platform switches mid-block to avoid stuck state
		if BlockParryHandler._isBlocking then
			BlockParryHandler:StopBlock()
		end
	end)

	-- === MOBILE BUTTON INPUT ===
	-- Uses InputBegan on the button to capture the touch, then tracks that specific
	-- input globally via UserInputService.InputEnded so release is detected even if
	-- the finger drags off the button before lifting.
	if MobileBlockButton then
		local activeTouchInput = nil

		MobileBlockButton.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			if PlatformTracker:Get() ~= "Mobile" then
				return
			end
		if StatusEffectController and (StatusEffectController:HasEffect("Stun") or StatusEffectController:HasEffect("BlockBreak")) then
			return
		end
			activeTouchInput = input
			BlockParryHandler:StartBlock()
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input == activeTouchInput then
				activeTouchInput = nil
				BlockParryHandler:StopBlock()
			end
		end)
	end

	-- === INPUT HANDLING (F key — PC/Console only) ===
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
	if StatusEffectController and (StatusEffectController:HasEffect("Stun") or StatusEffectController:HasEffect("BlockBreak")) then
		return
	end
		-- Only process keyboard input on PC/Console; mobile uses the touch button
		local platform = PlatformTracker:Get()
		if platform == "Mobile" then
			return
		end

		if input.KeyCode == ParryBlockSettings.Input.PCKey then
			BlockParryHandler:StartBlock()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		local platform = PlatformTracker:Get()
		if platform == "Mobile" then
			return
		end
		if input.KeyCode == ParryBlockSettings.Input.PCKey then
			BlockParryHandler:StopBlock()
		end
	end)

	-- === SERVER RECONCILIATION ===
	CombatService.BlockConfirmed:Connect(function()
		-- Server accepted — client is already in block stance, no action needed
	end)

	CombatService.BlockRejected:Connect(function(_reason)
		-- Server rejected — roll back to Idle
		BlockParryHandler:ExitBlockStance()
	end)

	-- === COMBAT FEEDBACK SIGNALS ===
	CombatService.BlockHit:Connect(function(_attackerChar)
		local char = player.Character
		if not char then
			return
		end
		playSound(ParryBlockSettings.Sounds.BlockHit, char)
	end)

	CombatService.ParrySuccess:Connect(function(_otherChar)
		local char = player.Character
		if not char then
			return
		end

		-- Parry success animation
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			-- Stop block idle so parry anim isn't fighting it
			stopAnimation(BlockParryHandler._blockTrack)
			playAnimation(humanoid, ParryBlockSettings.Animations.ParrySuccess, false)
		end

		-- Parry success sound
		playSound(ParryBlockSettings.Sounds.ParrySuccess, char)

		-- Parry flash VFX on our character
		BlockParryHandler:PlayParryFlashVFX(char)

		-- Camera shake for impact feel
		local camera = workspace.CurrentCamera
		if camera then
			task.spawn(function()
				for _ = 1, 4 do
					local offset = Vector3.new(
						(math.random() - 0.5) * 0.3,
						(math.random() - 0.5) * 0.3,
						0
					)
					camera.CFrame = camera.CFrame * CFrame.new(offset)
					task.wait(0.03)
				end
			end)
		end
	end)

	-- === BLOCK BREAK SIGNAL ===
	CombatService.BlockBreak:Connect(function(_attackerChar)
		local char = player.Character
		if not char then
			return
		end

		-- Force exit block stance on client
		if BlockParryHandler._isBlocking then
			BlockParryHandler._isBlocking = false
			stopAnimation(BlockParryHandler._blockTrack)
			BlockParryHandler._blockTrack = nil
		end

		-- Play block break sound + VFX
		local breakSound = playSound(ParryBlockSettings.Sounds.BlockBreak, char:FindFirstChild("HumanoidRootPart"))
		if breakSound then
			breakSound.Volume = 0.25
		end
		BlockParryHandler:PlayBlockBreakVFX(char)

		-- Camera shake (stronger than parry)
		local camera = workspace.CurrentCamera
		if camera then
			task.spawn(function()
				for _ = 1, 6 do
					local offset = Vector3.new(
						(math.random() - 0.5) * 0.5,
						(math.random() - 0.5) * 0.5,
						0
					)
					camera.CFrame = camera.CFrame * CFrame.new(offset)
					task.wait(0.03)
				end
			end)
		end

		updateUIState()
	end)

	-- === POSTURE BAR SETUP ===
	findPostureBar()
	connectPostureListener()

	-- === HOTBAR-BASED POSITIONING ===
	setupHotbarPositioning()

	-- === CHARACTER RESPAWN CLEANUP ===
	player.CharacterAdded:Connect(function(_char)
		BlockParryHandler._isBlocking = false
		BlockParryHandler._onCooldown = false
		stopAnimation(BlockParryHandler._blockTrack)
		BlockParryHandler._blockTrack = nil
		updateUIVisibility()
		updateUIState()
		connectPostureListener()
		updateBlockUIPosition()
	end)
end

function BlockParryHandler.Init()
	-- Get CombatService (server bridge)
	CombatService = Knit.GetService("CombatService")

	-- Load settings
	local datas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
	ParryBlockSettings = require(datas:WaitForChild("Combat"):WaitForChild("ParryBlockSettings", 10))

	-- Preload combat sounds into Assets.Effects.Combat
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end
	local effectsFolder = assets:FindFirstChild("Effects")
	if not effectsFolder then
		effectsFolder = Instance.new("Folder")
		effectsFolder.Name = "Effects"
		effectsFolder.Parent = assets
	end
	local combatFolder = effectsFolder:FindFirstChild("Combat")
	if not combatFolder then
		combatFolder = Instance.new("Folder")
		combatFolder.Name = "Combat"
		combatFolder.Parent = effectsFolder
	end

	local function preloadSound(soundId, name)
		if not soundId or soundId == "" or soundTemplates[soundId] then
			return
		end
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = soundId
		s.Parent = combatFolder
		soundTemplates[soundId] = s
	end

	preloadSound(ParryBlockSettings.Sounds.BlockStart, "BlockStart")
	preloadSound(ParryBlockSettings.Sounds.BlockHit, "BlockHit")
	preloadSound(ParryBlockSettings.Sounds.ParrySuccess, "ParrySuccess")
	preloadSound(ParryBlockSettings.Sounds.BlockBreak, "BlockBreak")

	-- Load VFX templates (graceful if assets not yet created)
	ParryFlashTemplate = resolveVfxAsset(ParryBlockSettings.VFX.ParryFlash)
	BlockBreakTemplate = resolveVfxAsset(ParryBlockSettings.VFX.BlockBreak)

	if not ParryFlashTemplate then
		warn("[BlockParryHandler] ParryFlash VFX not found at:", ParryBlockSettings.VFX.ParryFlash)
	end
	if not BlockBreakTemplate then
		warn("[BlockParryHandler] BlockBreak VFX not found at:", ParryBlockSettings.VFX.BlockBreak)
	end
end

return BlockParryHandler
