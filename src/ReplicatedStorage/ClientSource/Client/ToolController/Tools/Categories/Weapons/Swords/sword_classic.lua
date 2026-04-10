--!strict
-- sword_classic.lua
-- Client-side visual feedback for the Classic Sword tool
-- Based on the original SFOTH sword mechanics (Slash + Lunge combo)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SwordClassic = {}

---- Knit Controllers
local ToolController

---- Local Player
local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

---- Cursor Icons
local MouseIcon = "rbxasset://textures/GunCursor.png"
local ReloadingIcon = "rbxasset://textures/GunWaitCursor.png"

---- Animation IDs (R15)
local Animations = {
	R15Slash = "rbxassetid://522635514",
	R15Lunge = "rbxassetid://522638767",
}

---- State Tracking
local _lastAttackTime = 0
local _loadedAnimations = {} -- [animName] = AnimationTrack
local _isEquipped = false

--[=[
	Load animations for R15 avatars
]=]
local function LoadAnimations(humanoid: Humanoid)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Load Slash animation
	local slashAnim = Instance.new("Animation")
	slashAnim.AnimationId = Animations.R15Slash
	local slashTrack = animator:LoadAnimation(slashAnim)
	_loadedAnimations["Slash"] = slashTrack

	-- Load Lunge animation
	local lungeAnim = Instance.new("Animation")
	lungeAnim.AnimationId = Animations.R15Lunge
	local lungeTrack = animator:LoadAnimation(lungeAnim)
	_loadedAnimations["Lunge"] = lungeTrack

	print("[sword_classic] Client: Loaded R15 animations")
end

--[=[
	Cleanup loaded animations
]=]
local function CleanupAnimations()
	for name, track in pairs(_loadedAnimations) do
		track:Stop()
		track:Destroy()
	end
	_loadedAnimations = {}
end

--[=[
	Play slash animation
]=]
local function PlaySlashAnimation(humanoid: Humanoid, toolInstance: Tool)
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		-- R6: Use toolanim StringValue
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = toolInstance
	elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
		-- R15: Use loaded animation track
		local slashTrack = _loadedAnimations["Slash"]
		if slashTrack then
			slashTrack:Play(0)
		end
	end
end

--[=[
	Play lunge animation
]=]
local function PlayLungeAnimation(humanoid: Humanoid, toolInstance: Tool)
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		-- R6: Use toolanim StringValue
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Lunge"
		anim.Parent = toolInstance
	elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
		-- R15: Use loaded animation track
		local lungeTrack = _loadedAnimations["Lunge"]
		if lungeTrack then
			lungeTrack:Play(0)
		end
	end
end

--[=[
	Update mouse cursor icon
]=]
local function UpdateCursor(enabled: boolean)
	if _isEquipped then
		Mouse.Icon = enabled and MouseIcon or ReloadingIcon
	end
end

--[=[
	Called when the tool is activated - plays visual feedback
	@param toolData table - Tool definition from ToolRegistry
	@param targetData table - { Target: Instance?, Position: Vector3?, Direction: Vector3? }
]=]
function SwordClassic:OnActivate(toolData: any, targetData: any)
	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Get tool instance
	local currentTool = ToolController:GetEquippedTool()
	if not currentTool or not currentTool.toolInstance then return end

	local toolInstance = currentTool.toolInstance

	-- Check for combo timing (lunge if activated within 0.2 seconds)
	local currentTime = tick()
	local isLunge = (currentTime - _lastAttackTime) < 0.2

	if isLunge then
		-- Lunge animation
		PlayLungeAnimation(humanoid, toolInstance)
		print("[sword_classic] Client: Playing lunge animation")
	else
		-- Slash animation
		PlaySlashAnimation(humanoid, toolInstance)
		print("[sword_classic] Client: Playing slash animation")
	end

	_lastAttackTime = currentTime

	-- Update cursor to show cooldown
	UpdateCursor(false)
	task.delay(toolData.Stats.Cooldown or 0.5, function()
		UpdateCursor(true)
	end)
end

--[=[
	Called when the tool is equipped
	@param toolData table
]=]
function SwordClassic:OnEquip(toolData: any)
	_isEquipped = true
	_lastAttackTime = 0

	local character = Player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		LoadAnimations(humanoid)
	end

	-- Set cursor
	Mouse.Icon = MouseIcon

	print("[sword_classic] Client: Equipped")
end

--[=[
	Called when the tool is unequipped
	@param toolData table
]=]
function SwordClassic:OnUnequip(toolData: any)
	_isEquipped = false

	-- Cleanup animations
	CleanupAnimations()

	-- Reset cursor
	Mouse.Icon = ""

	print("[sword_classic] Client: Unequipped")
end

--[=[
	Called when tool state changes (optional)
	@param newState any
]=]
function SwordClassic:OnStateChanged(newState: any)
	-- Handle state changes if needed (e.g., combo state from server)
end

function SwordClassic.Init()
	ToolController = Knit.GetController("ToolController")
end

return SwordClassic
