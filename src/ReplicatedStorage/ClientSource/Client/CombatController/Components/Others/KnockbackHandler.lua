--[[
	KnockbackHandler.lua (Client)
	
	Handles client-side knockback application for the local player.
	When the server signals knockback, this applies the LinearVelocity force locally.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local KnockbackHandler = {}

-- Configuration
KnockbackHandler._config = nil
KnockbackHandler._combatService = nil

--[[
	Applies knockback force to the local player's character.
	
	@param velocity Vector3 - The knockback velocity vector
]]
function KnockbackHandler:ApplyKnockback(velocity: Vector3)
	local player = Players.LocalPlayer
	local character = player.Character
	
	if not character then
		return
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if not rootPart or not humanoid or humanoid.Health <= 0 then
		return
	end
	
	-- Apply the knockback force using LinearVelocity
	self:_applyKnockbackForce(rootPart, velocity)
end

--[[
	Applies the actual knockback force using LinearVelocity.
	
	@param rootPart BasePart - The HumanoidRootPart to apply force
	@param velocity Vector3 - The knockback velocity vector
]]
function KnockbackHandler:_applyKnockbackForce(rootPart: BasePart, velocity: Vector3)
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end
	
	local duration = self._config.Knockback.Duration
	
	-- Create attachment for LinearVelocity
	local attachment = Instance.new("Attachment")
	attachment.Name = "KnockbackAttachment"
	attachment.Parent = rootPart
	
	-- Create LinearVelocity constraint
	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "KnockbackVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = self._config.Knockback.LinearVelocity.MaxForce
	linearVelocity.VectorVelocity = velocity
	linearVelocity.RelativeTo = self._config.Knockback.LinearVelocity.RelativeTo
	linearVelocity.VelocityConstraintMode = self._config.Knockback.LinearVelocity.VelocityConstraintMode
	linearVelocity.Parent = attachment
	
	-- Clean up after duration
	task.delay(duration, function()
		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end)
end

--[[
	Connects to server signals for knockback events.
]]
function KnockbackHandler:_connectSignals()
	-- Listen for server knockback events
	self._combatService.ApplyKnockback:Connect(function(velocity: Vector3)
		self:ApplyKnockback(velocity)
	end)
end

function KnockbackHandler.Start()
	KnockbackHandler:_connectSignals()
end

function KnockbackHandler.Init()
	-- Load configuration
	local datas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
	KnockbackHandler._config = require(datas:WaitForChild("Combat"):WaitForChild("CombatConfig", 10))
	
	-- Get CombatService for signals
	KnockbackHandler._combatService = Knit.GetService("CombatService")
end

return KnockbackHandler
