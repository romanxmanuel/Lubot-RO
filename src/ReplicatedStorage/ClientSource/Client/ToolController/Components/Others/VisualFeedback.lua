--!strict
-- VisualFeedback.lua
-- Handles visual and audio feedback for tool actions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local VisualFeedback = {}

local plr = game.Players.LocalPlayer

---- Other Components
local AnimationManager

--[=[
	Play activation feedback (animation, sound, VFX)
	@param toolData table Tool data containing feedback configuration
]=]
function VisualFeedback:PlayActivationFeedback(toolData: any)
	if not toolData then return end
	
	-- Play animation
	if AnimationManager then
		AnimationManager:PlayActivationAnimation()
	end
	
	-- Play sound
	local behaviorConfig = toolData.BehaviorConfig
	if behaviorConfig and behaviorConfig.ActivateSound then
		self:PlaySound(behaviorConfig.ActivateSound)
	end
	
	-- Play VFX
	if behaviorConfig and behaviorConfig.ActivateEffect then
		self:PlayEffect(behaviorConfig.ActivateEffect)
	end
end

--[=[
	Play a sound effect
	@param soundId string Asset ID of the sound
]=]
function VisualFeedback:PlaySound(soundId: string)
	if not soundId or soundId == "rbxassetid://0" then
		return -- No sound configured
	end
	
	local character = plr.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	-- Create and play sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = humanoidRootPart
	sound.Volume = 0.5
	sound:Play()
	
	-- Cleanup after sound finishes
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	
	print("[VisualFeedback] Playing sound:", soundId)
end

--[=[
	Play a visual effect
	@param effectId string Asset ID of the effect
]=]
function VisualFeedback:PlayEffect(effectId: string)
	if not effectId or effectId == "rbxassetid://0" then
		return -- No effect configured
	end
	
	-- TODO: Implement VFX system
	-- For now, just log
	print("[VisualFeedback] Would play effect:", effectId)
end

--[=[
	Show hit marker (for melee hits, etc.)
	@param position Vector3 Position to show marker
]=]
function VisualFeedback:ShowHitMarker(position: Vector3)
	-- TODO: Implement hit marker UI
	print("[VisualFeedback] Hit marker at:", position)
end

--[=[
	Show damage number
	@param position Vector3 Position to show number
	@param damage number Damage amount
]=]
function VisualFeedback:ShowDamageNumber(position: Vector3, damage: number)
	-- TODO: Implement damage numbers
	print("[VisualFeedback] Damage number:", damage, "at:", position)
end

function VisualFeedback.Start()
	-- Component start logic
end

function VisualFeedback.Init()
	-- Initialize references
	local ToolController = Knit.GetController("ToolController")
	AnimationManager = ToolController.Components.AnimationManager
end

return VisualFeedback
