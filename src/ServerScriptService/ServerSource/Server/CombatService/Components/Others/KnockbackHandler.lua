--[[
	KnockbackHandler.lua
	
	Handles knockback application using LinearVelocity.
	Manages network ownership for NPCs and delegates knockback to players for their own characters.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local KnockbackHandler = {}

-- Configuration
KnockbackHandler._config = nil
KnockbackHandler._networkOwnerManager = nil

--[[
	Applies knockback to a target character.
	
	@param target Model - The character model to knockback
	@param attackerPosition Vector3 - Position of the attacker
	@param attacker Player? - The attacking player (for NPC ownership)
]]
function KnockbackHandler:ApplyKnockback(target: Model, attackerPosition: Vector3, attacker: Player?)
	if not target or not target:IsA("Model") then
		warn("[KnockbackHandler] Invalid target")
		return
	end
	
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local rootPart = target:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return
	end
	
	-- Determine if target is a player or NPC
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	local isNPC = targetPlayer == nil

	-- Skip NPC→player knockback if disabled (attacker == nil means NPC attacker)
	if not isNPC and attacker == nil and not self._config.Knockback.NPCKnockbackPlayers then
		return
	end

	-- Calculate knockback direction (away from attacker)
	local direction = (rootPart.Position - attackerPosition).Unit
	local knockbackVelocity = direction * self._config.Knockback.BasePower

	if isNPC then
		-- NPC: Set network owner to attacker for physics optimization
		if attacker then
			self._networkOwnerManager.SetTemporaryOwner(
				target,
				attacker,
				self._config.Knockback.NPC.OwnershipDuration
			)
		end
		
		-- Apply knockback on server
		self:_applyKnockbackForce(rootPart, knockbackVelocity)
	else
		-- Player: Delegate knockback to that player's client
		local CombatService = Knit.GetService("CombatService")
		CombatService.Client.ApplyKnockback:Fire(targetPlayer, knockbackVelocity)
	end
end

--[[
	Applies the actual knockback force using LinearVelocity.
	This is called for NPCs on the server, or for players on their own client.
	
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
	Applies knockback to multiple targets at once.
	
	@param targets { Model } - Array of character models
	@param attackerPosition Vector3 - Position of the attacker
	@param attacker Player? - The attacking player
]]
function KnockbackHandler:ApplyKnockbackToTargets(targets: { Model }, attackerPosition: Vector3, attacker: Player?)
	for _, target in ipairs(targets) do
		self:ApplyKnockback(target, attackerPosition, attacker)
	end
end

function KnockbackHandler.Start()
	-- Nothing needed here
end

function KnockbackHandler.Init()
	-- Load configuration
	local datas = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Datas", 10)
	KnockbackHandler._config = require(datas:WaitForChild("Combat"):WaitForChild("CombatConfig", 10))
	
	-- Load NetworkOwnerManager utility
	local utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
	KnockbackHandler._networkOwnerManager = require(utilities:WaitForChild("NetworkOwnerManager", 10))
end

return KnockbackHandler
