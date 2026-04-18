-- ComboController.server.lua
-- Path: ServerScriptService/ComboController
-- SOURCE: Copied from ChatGPT design session https://chatgpt.com/c/69e31ae1-fbc8-83ea-be7f-0989d3156054

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local CombatConfig = require(ReplicatedStorage.Combat.CombatConfig)

local remotesFolder = ReplicatedStorage:FindFirstChild("CombatRemotes") or Instance.new("Folder")
remotesFolder.Name = "CombatRemotes"
remotesFolder.Parent = ReplicatedStorage

local inputRemote = remotesFolder:FindFirstChild("ComboInput") or Instance.new("RemoteEvent")
inputRemote.Name = "ComboInput"
inputRemote.Parent = remotesFolder

local impactRemote = remotesFolder:FindFirstChild("PlayImpactFX") or Instance.new("RemoteEvent")
impactRemote.Name = "PlayImpactFX"
impactRemote.Parent = remotesFolder

local states = {}

local function getNearestTarget(character, range)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local nearest, best = nil, range or 80
	for _, model in ipairs(workspace:GetChildren()) do
		if model ~= character and model:IsA("Model") then
			local hum = model:FindFirstChildOfClass("Humanoid")
			local hrp = model:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and hrp then
				local dist = (hrp.Position - root.Position).Magnitude
				if dist < best then
					best = dist
					nearest = model
				end
			end
		end
	end
	return nearest
end

local function fireImpact(player, cfg)
	impactRemote:FireClient(player, cfg)
end

local function applyKnockback(target, sourcePos, amount, upward)
	local root = target and target:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local dir = root.Position - sourcePos
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	root.AssemblyLinearVelocity = dir * amount + Vector3.new(0, upward or 0, 0)
end

local function blinkCharacter(character, destination)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(destination, destination + root.CFrame.LookVector)
	end
end

local function damageTarget(target, damage)
	local hum = target and target:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:TakeDamage(damage)
	end
end

local function playMarkerBoundImpact(player, target, cfg, damage, sourcePos)
	if not target then return end
	fireImpact(player, cfg)
	damageTarget(target, damage)
	applyKnockback(target, sourcePos, cfg.Knockback, 2)
end

inputRemote.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	local state = states[player] or {
		Step = 0,
		StartPosition = root.Position,
		Suspended = false,
		LastTarget = nil,
	}
	states[player] = state

	if state.Step == 0 then
		state.StartPosition = root.Position
	end

	local target = state.LastTarget
	if not target or not target.Parent then
		target = getNearestTarget(char, 90)
		state.LastTarget = target
	end
	if not target then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	state.Step += 1

	if state.Step == 1 then
		-- HIT 1: Blink Strike — instant, surgical opener
		local cfg = CombatConfig.Combo5.Hit1
		local behind = targetRoot.Position - targetRoot.CFrame.LookVector * 2
		blinkCharacter(char, behind)
		playMarkerBoundImpact(player, target, cfg, 18, root.Position)

	elseif state.Step == 2 then
		-- HIT 2: Pushback + Meteor — space creation, first big impact
		local pushCfg = CombatConfig.Combo5.Hit2Push
		local meteorCfg = CombatConfig.Combo5.Hit2Meteor
		fireImpact(player, pushCfg)
		damageTarget(target, 10)
		targetRoot.AssemblyLinearVelocity = targetRoot.CFrame.LookVector * pushCfg.EnemyForwardPush + Vector3.new(0, 4, 0)
		root.AssemblyLinearVelocity = -root.CFrame.LookVector * pushCfg.PlayerBackwardLaunch + Vector3.new(0, pushCfg.PlayerVerticalLift, 0)
		task.delay(0.18, function()
			if target and target.Parent then
				fireImpact(player, meteorCfg)
				damageTarget(target, 28)
				applyKnockback(target, targetRoot.Position, meteorCfg.Knockback, 8)
				state.Suspended = true
			end
		end)

	elseif state.Step == 3 then
		-- HIT 3: Air Meteor Drop — vertical dominance spike (only while airborne)
		if not state.Suspended then return end
		local cfg = CombatConfig.Combo5.Hit3
		fireImpact(player, cfg)
		damageTarget(target, 32)
		applyKnockback(target, targetRoot.Position, cfg.Knockback, 10)
		root.AssemblyLinearVelocity = Vector3.new(0, cfg.SelfLaunchUpward, 0)
		state.Suspended = true

	elseif state.Step == 4 then
		-- HIT 4: Re-engage Blink — snap return, control regained
		local cfg = CombatConfig.Combo5.Hit4
		blinkCharacter(char, targetRoot.Position + Vector3.new(0, 0, -2))
		playMarkerBoundImpact(player, target, cfg, 24, root.Position)

	elseif state.Step == 5 then
		-- HIT 5: Final Nuke — full payoff, disengage, return to start
		local cfg = CombatConfig.Combo5.Hit5
		fireImpact(player, cfg)
		damageTarget(target, 45)
		applyKnockback(target, root.Position, cfg.Knockback, 14)
		local dirBack = (state.StartPosition - root.Position)
		if dirBack.Magnitude > 0.1 then
			root.AssemblyLinearVelocity = dirBack.Unit * cfg.PlayerBackwardBlast + Vector3.new(0, 3, 0)
		end
		task.delay(cfg.ReturnDuration, function()
			if char and char.Parent then
				root.CFrame = CFrame.new(state.StartPosition, state.StartPosition + root.CFrame.LookVector)
			end
		end)
		state.Step = 0
		state.Suspended = false
		state.LastTarget = nil
	end
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)
