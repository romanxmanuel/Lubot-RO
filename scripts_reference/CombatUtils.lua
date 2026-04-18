-- CombatUtils.lua
-- Path: ReplicatedStorage/Combat/CombatUtils
-- SOURCE: Copied from ChatGPT design session https://chatgpt.com/c/69e31ae1-fbc8-83ea-be7f-0989d3156054

local CombatUtils = {}

function CombatUtils.GetCharacterParts(character)
	if not character then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart"), character:FindFirstChildOfClass("Humanoid")
end

function CombatUtils.IsAlive(model)
	local _, hum = CombatUtils.GetCharacterParts(model)
	return hum and hum.Health > 0
end

function CombatUtils.ApplyDamage(target, amount)
	local _, hum = CombatUtils.GetCharacterParts(target)
	if hum and hum.Health > 0 then
		hum:TakeDamage(amount)
	end
end

function CombatUtils.ApplyKnockback(target, sourcePosition, amount, upward)
	local root = target and target:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local dir = root.Position - sourcePosition
	if dir.Magnitude < 0.001 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	root.AssemblyLinearVelocity = dir * amount + Vector3.new(0, upward or 0, 0)
end

function CombatUtils.PushAlongLook(root, studs, y)
	if not root then return end
	root.AssemblyLinearVelocity = root.CFrame.LookVector * studs + Vector3.new(0, y or 0, 0)
end

function CombatUtils.BlinkToPosition(root, destination, faceTarget)
	if not root then return end
	if faceTarget then
		root.CFrame = CFrame.lookAt(destination, faceTarget)
	else
		root.CFrame = CFrame.new(destination)
	end
end

function CombatUtils.GetPositionBehindTarget(targetRoot, offset)
	if not targetRoot then return nil end
	return targetRoot.Position - targetRoot.CFrame.LookVector * (offset or 2)
end

function CombatUtils.SafeDisconnect(connection)
	if connection then
		connection:Disconnect()
	end
end

return CombatUtils
