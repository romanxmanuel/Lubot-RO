--!strict
-- AnimationManager.lua
-- Manages tool animations (equip, unequip, activation)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local AnimationManager = {}

local plr = game.Players.LocalPlayer

-- Animation state
local _loadedAnimations = {} -- [animName] = AnimationTrack
local _currentAnimator = nil

--[=[
	Load animations for a tool
	@param toolData table Tool data containing animation IDs
]=]
function AnimationManager:LoadToolAnimations(toolData: any)
	-- Cleanup previous animations
	self:CleanupAnimations()

	-- Get character animator
	local character = plr.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	_currentAnimator = humanoid:FindFirstChildOfClass("Animator")
	if not _currentAnimator then
		_currentAnimator = Instance.new("Animator")
		_currentAnimator.Parent = humanoid
	end

	-- Load activation animation if present
	local behaviorConfig = toolData.BehaviorConfig
	if behaviorConfig and behaviorConfig.ActivateAnimation then
		local animId = behaviorConfig.ActivateAnimation
		if animId and animId ~= "rbxassetid://0" then
			local success, animation = pcall(function()
				local anim = Instance.new("Animation")
				anim.AnimationId = animId
				return _currentAnimator:LoadAnimation(anim)
			end)

			if success then
				_loadedAnimations["Activate"] = animation
				print("[AnimationManager] Loaded activation animation")
			else
				warn("[AnimationManager] Failed to load activation animation:", animId)
			end
		end
	end
end

--[=[
	Play activation animation
	@return boolean True if animation played
]=]
function AnimationManager:PlayActivationAnimation(): boolean
	local activateAnim = _loadedAnimations["Activate"]
	if not activateAnim then
		return false
	end

	activateAnim:Play()
	print("[AnimationManager] Playing activation animation")
	return true
end

--[=[
	Stop all animations
]=]
function AnimationManager:StopAllAnimations()
	for animName, animTrack in pairs(_loadedAnimations) do
		if animTrack.IsPlaying then
			animTrack:Stop()
		end
	end
end

--[=[
	Cleanup animations
]=]
function AnimationManager:CleanupAnimations()
	-- Stop all animations
	self:StopAllAnimations()

	-- Destroy animation tracks
	for animName, animTrack in pairs(_loadedAnimations) do
		animTrack:Destroy()
	end

	_loadedAnimations = {}
	print("[AnimationManager] Cleaned up animations")
end

function AnimationManager.Start()
	-- Component start logic
end

function AnimationManager.Init()
	-- Initialize references
end

return AnimationManager
