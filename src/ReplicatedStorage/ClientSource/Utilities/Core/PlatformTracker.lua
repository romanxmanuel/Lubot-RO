--[[

	PlatformTracker
	Detects and provides platform-specific information such as input method, device category, and device type.

	👤 Author: Mys7o
	🕒 Last Updated: July 25, 2025

	### Device Categories ###
	🖥️ PC       - Keyboard & Mouse based devices
	🎮 Console  - Gamepad-driven interfaces
	📱 Mobile   - Touch input (Phone or Tablet)

	### API Documentation & Usage ###

	PlatformTracker.Changed
	-- BindableEvent triggered when the platform category or device type changes
	-- Example:
	-- PlatformTracker.Changed:Connect(function(category, deviceType) ... end)
	
	PlatformTracker:Get()
	-- Returns the device category: "PC", "Mobile", or "Console"
	-- Example:
	-- if PlatformTracker:Get() == "Mobile" then ...

	PlatformTracker:GetDeviceType()
	-- Returns the specific device type: "Phone", "Tablet", or "Unknown"
	-- Uses JumpButton size as primary detection, with fallback to viewport size

	PlatformTracker:GetPreferredInput()
	-- Returns the Enum.PreferredInput (KeyboardAndMouse, Touch, Gamepad)

	PlatformTracker:SetTestingMode(enabled, preferredInput)
	-- STUDIO ONLY: Locks the preferred input for testing purposes
	-- Parameters:
	--   enabled (boolean) - true to enable testing mode, false to disable
	--   preferredInput (Enum.PreferredInput) - the input type to lock to (only required if enabled = true)
	-- Example:
	--   PlatformTracker:SetTestingMode(true, Enum.PreferredInput.Touch)  -- Lock to mobile
	--   PlatformTracker:SetTestingMode(false)  -- Disable testing mode
	-- Note: This only works in Studio to avoid affecting live gameplay

	PlatformTracker:IsTestingModeEnabled()
	-- Returns true if testing mode is currently enabled

	📌 Note:
	When running in Studio's mobile emulation mode, switching from keyboard or gamepad back to touch input
	may not update PreferredInput to Touch. This is intentional behavior by Roblox to avoid rapid input switching
	on hybrid devices like touchscreen laptops. It does not affect live gameplay on actual devices.

]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PlatformTracker = {}
PlatformTracker._deviceCategory = "PC"
PlatformTracker._deviceType = "Unknown" -- "Phone", "Tablet", or "Unknown"
PlatformTracker._preferredInput = Enum.PreferredInput.KeyboardAndMouse -- default
PlatformTracker._testingMode = false -- Studio only: locks preferred input for testing
PlatformTracker._lockedInput = Enum.PreferredInput.Touch -- Studio only: the locked preferred input

local player = Players.LocalPlayer
local playerGui = player:FindFirstChild("PlayerGui", 5)

-- Event to notify platform mode changes
local changedEvent = Instance.new("BindableEvent")
PlatformTracker.Changed = changedEvent.Event

function PlatformTracker:Get()
	return PlatformTracker._deviceCategory
end

function PlatformTracker:GetDeviceType()
	return PlatformTracker._deviceType
end

function PlatformTracker:GetPreferredInput()
	return PlatformTracker._preferredInput
end

local function determineDeviceType()
	if PlatformTracker._deviceCategory ~= "Mobile" then
		return
	end

	local success, jumpButton = pcall(function()
		local touchGui = playerGui:FindFirstChild("TouchGui")
		if not touchGui then
			return nil
		end

		local controlFrame = touchGui:FindFirstChild("TouchControlFrame")
		if not controlFrame then
			return nil
		end

		return controlFrame:FindFirstChild("JumpButton")
	end)

	if success and jumpButton and jumpButton:IsA("GuiButton") then
		if jumpButton.Size == UDim2.fromOffset(120, 120) then
			PlatformTracker._deviceType = "Tablet"
		else
			PlatformTracker._deviceType = "Phone"
		end
	else
		-- Fallback using viewport size
		if workspace.CurrentCamera then
			local size = workspace.CurrentCamera.ViewportSize
			if size.Y >= 600 then
				PlatformTracker._deviceType = "Tablet"
			else
				PlatformTracker._deviceType = "Phone"
			end
		end
	end
end

local function updatePlatformCategory()
	-- If testing mode is enabled in Studio, use the locked input
	local preferredInput
	if PlatformTracker._testingMode and RunService:IsStudio() then
		preferredInput = PlatformTracker._lockedInput
		-- print("[PlatformTracker] Testing mode ACTIVE - Using locked input:", preferredInput.Name)
	else
		preferredInput = UserInputService.PreferredInput
		-- print("[PlatformTracker] Using actual PreferredInput:", preferredInput.Name)
	end

	local oldCategory = PlatformTracker._deviceCategory

	PlatformTracker._preferredInput = preferredInput

	local inputToCategory = {
		[Enum.PreferredInput.KeyboardAndMouse] = "PC",
		[Enum.PreferredInput.Gamepad] = "Console",
		[Enum.PreferredInput.Touch] = "Mobile",
	}

	-- Use simulated input category if running in Studio (e.g., Mobile Emulator)
	if RunService:IsStudio() and inputToCategory[preferredInput] then
		PlatformTracker._deviceCategory = inputToCategory[preferredInput]

		-- print("[PlatformTracker] Category updated:", oldCategory, "->", PlatformTracker._deviceCategory)

		if oldCategory ~= PlatformTracker._deviceCategory then
			-- print("[PlatformTracker] 🔔 Firing Changed event:", PlatformTracker._deviceCategory)
			changedEvent:Fire(PlatformTracker._deviceCategory, PlatformTracker._deviceType)
		end

		return
	end

	-- Fallback to actual input category
	PlatformTracker._deviceCategory = inputToCategory[preferredInput] or "PC"

	if oldCategory ~= PlatformTracker._deviceCategory then
		-- print("[PlatformTracker] 🔔 Firing Changed event:", PlatformTracker._deviceCategory)
		changedEvent:Fire(PlatformTracker._deviceCategory, PlatformTracker._deviceType)
	end
end

local function onPreferredInputChanged()
	updatePlatformCategory()
	determineDeviceType()
end

function PlatformTracker:SetTestingMode(enabled, preferredInput)
	-- Only allow testing mode in Studio
	if not RunService:IsStudio() then
		warn("PlatformTracker: Testing mode is only available in Studio")
		return
	end

	if enabled then
		if
			not preferredInput
			or typeof(preferredInput) ~= "EnumItem"
			or preferredInput.EnumType ~= Enum.PreferredInput
		then
			warn("PlatformTracker: Invalid preferredInput provided to SetTestingMode")
			return
		end

	PlatformTracker._testingMode = true
	PlatformTracker._lockedInput = preferredInput
	-- print("PlatformTracker: Testing mode ENABLED - Locked to", preferredInput.Name)

	-- Immediately update to the locked input
		PlatformTracker._preferredInput = preferredInput
		updatePlatformCategory()
		determineDeviceType()
	else
		PlatformTracker._testingMode = false
		PlatformTracker._lockedInput = nil
		-- print("PlatformTracker: Testing mode DISABLED")

		-- Update to actual current input
		onPreferredInputChanged()
	end
end

function PlatformTracker:IsTestingModeEnabled()
	return PlatformTracker._testingMode
end

-- print(
-- 	"[PlatformTracker] ⚙️ Initializing... TestingMode:",
-- 	PlatformTracker._testingMode,
-- 	"LockedInput:",
-- 	PlatformTracker._lockedInput and PlatformTracker._lockedInput.Name or "None"
-- )
onPreferredInputChanged()
-- print(
-- 	"[PlatformTracker] ✅ Initialized - Current platform:",
-- 	PlatformTracker._deviceCategory,
-- 	"PreferredInput:",
-- 	PlatformTracker._preferredInput.Name
-- )

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
	-- Ignore input changes when testing mode is enabled in Studio
	if PlatformTracker._testingMode and RunService:IsStudio() then
		-- print("[PlatformTracker] Ignoring PreferredInput change (testing mode is locked)")
		return
	end
	onPreferredInputChanged()
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(determineDeviceType)
	end
end)

return PlatformTracker
