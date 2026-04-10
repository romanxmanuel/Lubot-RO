--!strict
-- sword_classic.lua
-- Server-side logic for the Classic Sword tool
-- Based on the original SFOTH sword mechanics (Slash + Lunge combo)
-- Simplified to match classic sword behavior with DamageService integration

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local SwordClassic = {}

---- Knit Services
local ToolService
local DamageService

---- Damage Values
local DamageValues = {
	BaseDamage = 5,
	SlashDamage = 10,
	LungeDamage = 30,
}

---- Grip CFrames
local Grips = {
	Up = CFrame.new(0, 0, -1.70000005, 0, 0, 1, 1, 0, 0, 0, 1, 0),
	Out = CFrame.new(0, 0, -1.70000005, 0, 1, 0, 1, -0, 0, 0, 0, -1),
}

---- Player State Tracking
local _lastAttackTime = {} -- [Player] = tick()
local _currentDamage = {} -- [Player] = damage value
local _touchConnections = {} -- [Player] = connection

--[=[
	Handle sword touching something
]=]
local function Blow(player: Player, character: Model, hit: BasePart)
	if not hit or not hit.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	if not rightArm then
		return
	end

	local rightGrip = rightArm:FindFirstChild("RightGrip")
	if not rightGrip then
		return
	end

	local hitCharacter = hit.Parent
	if hitCharacter == character then
		return
	end

	local hitHumanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
	if not hitHumanoid or hitHumanoid.Health <= 0 then
		return
	end

	local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
	if hitPlayer and hitPlayer == player then
		return
	end

	local damage = _currentDamage[player] or DamageValues.BaseDamage

	if DamageService then
		DamageService:ApplyDamage(character, hitCharacter, {
			Damage = damage,
			DamageType = "melee",
			CanDamageSelf = false,
			TeamCheck = true,
			InvincibilityCheck = true,
		})
	else
		hitHumanoid:TakeDamage(damage)
	end
end

--[=[
	Perform slash attack
]=]
local function Attack(player: Player, toolInstance: Tool)
	_currentDamage[player] = DamageValues.SlashDamage

	local handle = toolInstance:FindFirstChild("Handle")
	if handle then
		local slashSound = handle:FindFirstChild("SwordSlash")
		if slashSound then
			slashSound:Play()
		end
	end
end

--[=[
	Perform lunge attack
]=]
local function Lunge(player: Player, toolInstance: Tool)
	_currentDamage[player] = DamageValues.LungeDamage

	local handle = toolInstance:FindFirstChild("Handle")
	if handle then
		local lungeSound = handle:FindFirstChild("SwordLunge")
		if lungeSound then
			lungeSound:Play()
		end
	end

	task.spawn(function()
		task.wait(0.2)
		toolInstance.Grip = Grips.Out
		task.wait(0.6)
		toolInstance.Grip = Grips.Up
		_currentDamage[player] = DamageValues.SlashDamage
	end)
end

--[=[
	Called when the tool is activated
]=]
function SwordClassic:Activate(player: Player, toolData: any, targetData: any): boolean
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local equippedTool = ToolService:GetEquippedTool(player)
	if not equippedTool or not equippedTool.toolInstance then
		return false
	end

	local toolInstance = equippedTool.toolInstance

	-- Get current tick using RunService
	local currentTick = tick()
	local lastAttack = _lastAttackTime[player] or 0

	-- Check for lunge combo (within 0.2 seconds)
	if (currentTick - lastAttack) < 0.2 then
		Lunge(player, toolInstance)
	else
		Attack(player, toolInstance)
	end

	_lastAttackTime[player] = currentTick

	-- Reset to base damage after attack window
	task.delay(1, function()
		_currentDamage[player] = DamageValues.BaseDamage
	end)

	return true
end

--[=[
	Called when the tool is equipped
]=]
function SwordClassic:OnEquip(player: Player, toolData: any)
	local character = player.Character
	if not character then
		return
	end

	local equippedTool = ToolService:GetEquippedTool(player)
	if not equippedTool or not equippedTool.toolInstance then
		return
	end

	local toolInstance = equippedTool.toolInstance
	local handle = toolInstance:FindFirstChild("Handle")

	toolInstance.Grip = Grips.Up
	_currentDamage[player] = DamageValues.BaseDamage
	_lastAttackTime[player] = 0

	if handle then
		local unsheathSound = handle:FindFirstChild("Unsheath")
		if unsheathSound then
			unsheathSound:Play()
		end

		_touchConnections[player] = handle.Touched:Connect(function(hit)
			Blow(player, character, hit)
		end)
	end
end

--[=[
	Called when the tool is unequipped
]=]
function SwordClassic:OnUnequip(player: Player, toolData: any)
	if _touchConnections[player] then
		_touchConnections[player]:Disconnect()
		_touchConnections[player] = nil
	end

	_lastAttackTime[player] = nil
	_currentDamage[player] = nil
end

function SwordClassic.Init()
	ToolService = Knit.GetService("ToolService")
	DamageService = Knit.GetService("DamageService")
	
	if not DamageService then
		warn("[sword_classic] DamageService not found! Using fallback damage.")
	end
end

return SwordClassic