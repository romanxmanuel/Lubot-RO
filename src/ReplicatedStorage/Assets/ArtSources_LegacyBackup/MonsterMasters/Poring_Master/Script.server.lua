--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--// REFERENCES
local monster = script.Parent
local humanoid = monster:WaitForChild("Humanoid")
local root = monster:WaitForChild("HumanoidRootPart")
local body = monster:WaitForChild("Body")

--// SETTINGS
local DETECTION_RANGE = 35
local ATTACK_RANGE = 4
local DAMAGE = 8
local ATTACK_COOLDOWN = 1.2
local MOVE_UPDATE_TIME = 0.12
local TURN_SPEED = 0.12
local WANDER_RADIUS = 12
local WANDER_INTERVAL = 3
local FACING_DOT_REQUIRED = 0.5

--// STARTER TUNING
humanoid.WalkSpeed = 10
humanoid.AutoRotate = false

--// STATE
local lastAttackTime = 0
local lastMoveUpdate = 0
local lastWanderTime = 0
local wanderTarget = nil
local lastHealth = humanoid.Health
local spawnPosition = root.Position

local isSquashing = false
local bodyOriginalSize = body.Size

--// FUNCTIONS

local function getNearestPlayerCharacter()
	local nearestCharacter = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
			local targetRoot = character:FindFirstChild("HumanoidRootPart")

			if targetHumanoid and targetRoot and targetHumanoid.Health > 0 then
				local distance = (targetRoot.Position - root.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestCharacter = character
				end
			end
		end
	end

	return nearestCharacter, nearestDistance
end

local function flatDirection(fromPos, toPos)
	local dir = toPos - fromPos
	dir = Vector3.new(dir.X, 0, dir.Z)

	if dir.Magnitude < 0.001 then
		return nil
	end

	return dir.Unit
end

local function smoothFaceTarget(targetPos)
	local dir = flatDirection(root.Position, targetPos)
	if not dir then return end

	local targetCFrame = CFrame.new(root.Position, root.Position + dir)
	root.CFrame = root.CFrame:Lerp(targetCFrame, TURN_SPEED)
end

local function isFacingTarget(targetRoot)
	local dir = flatDirection(root.Position, targetRoot.Position)
	if not dir then return false end

	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.001 then
		return false
	end

	forward = forward.Unit
	local dot = forward:Dot(dir)

	return dot >= FACING_DOT_REQUIRED
end

local function playJellyAttack()
	if isSquashing then return end
	isSquashing = true

	local squashSize = Vector3.new(
		bodyOriginalSize.X * 1.18,
		bodyOriginalSize.Y * 0.72,
		bodyOriginalSize.Z * 1.18
	)

	local stretchSize = Vector3.new(
		bodyOriginalSize.X * 0.92,
		bodyOriginalSize.Y * 1.12,
		bodyOriginalSize.Z * 0.92
	)

	local squashTween = TweenService:Create(
		body,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = squashSize}
	)

	local stretchTween = TweenService:Create(
		body,
		TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = stretchSize}
	)

	local returnTween = TweenService:Create(
		body,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = bodyOriginalSize}
	)

	squashTween:Play()
	squashTween.Completed:Wait()

	stretchTween:Play()
	stretchTween.Completed:Wait()

	returnTween:Play()
	returnTween.Completed:Wait()

	isSquashing = false
end

local function attackTarget(character)
	local targetHumanoid = character:FindFirstChildOfClass("Humanoid")
	if not targetHumanoid or targetHumanoid.Health <= 0 then
		return
	end

	local now = time()
	if now - lastAttackTime >= ATTACK_COOLDOWN then
		lastAttackTime = now

		task.spawn(playJellyAttack)

		targetHumanoid:TakeDamage(DAMAGE)
	end
end

local function getRandomWanderPoint()
	local offset = Vector3.new(
		math.random(-WANDER_RADIUS, WANDER_RADIUS),
		0,
		math.random(-WANDER_RADIUS, WANDER_RADIUS)
	)

	return spawnPosition + offset
end

local function playHitEffect()
	for _, obj in ipairs(monster:GetDescendants()) do
		if obj:IsA("BasePart") and obj ~= root then
			local originalColor = obj.Color
			obj.Color = Color3.fromRGB(255, 80, 80)

			task.delay(0.12, function()
				if obj and obj.Parent then
					obj.Color = originalColor
				end
			end)
		end
	end
end

local function applyKnockback(fromPosition)
	local dir = flatDirection(fromPosition, root.Position)
	if not dir then return end

	root:ApplyImpulse(dir * root.AssemblyMass * 18 + Vector3.new(0, root.AssemblyMass * 6, 0))
end

-- Example for later when the player damages the monster:
-- applyKnockback(player.Character.HumanoidRootPart.Position)

humanoid.HealthChanged:Connect(function(newHealth)
	if newHealth < lastHealth then
		playHitEffect()
	end
	lastHealth = newHealth
end)

--// MAIN LOOP
RunService.Heartbeat:Connect(function()
	if humanoid.Health <= 0 then
		return
	end

	local targetCharacter, distance = getNearestPlayerCharacter()

	if targetCharacter and distance <= DETECTION_RANGE then
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
		if not targetRoot then
			return
		end

		smoothFaceTarget(targetRoot.Position)

		if distance > ATTACK_RANGE then
			local now = time()
			if now - lastMoveUpdate >= MOVE_UPDATE_TIME then
				lastMoveUpdate = now
				humanoid:MoveTo(targetRoot.Position)
			end
		else
			humanoid:MoveTo(root.Position)

			if isFacingTarget(targetRoot) then
				attackTarget(targetCharacter)
			end
		end
	else
		local now = time()

		if (not wanderTarget) or ((root.Position - wanderTarget).Magnitude < 2) then
			if now - lastWanderTime >= WANDER_INTERVAL then
				wanderTarget = getRandomWanderPoint()
				lastWanderTime = now
			end
		end

		if wanderTarget then
			smoothFaceTarget(wanderTarget)

			if now - lastMoveUpdate >= MOVE_UPDATE_TIME then
				lastMoveUpdate = now
				humanoid:MoveTo(wanderTarget)
			end
		end
	end
end)