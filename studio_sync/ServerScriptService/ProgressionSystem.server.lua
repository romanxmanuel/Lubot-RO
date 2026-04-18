local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local function mk(parent, name, class)
	local e = parent:FindFirstChild(name)
	if e then
		return e
	end
	e = Instance.new(class)
	e.Name = name
	e.Parent = parent
	return e
end

local HUDEvent = mk(RS, "HUDEvent", "RemoteEvent")
local KillEvent = mk(RS, "KillEvent", "BindableEvent")

local KILLS_TO_LEVEL = { 3, 5, 8, 12 }
local MAX_LEVEL = 5
local START_LEVEL = 5 -- Testing mode: spawn with all 5 combo hits unlocked
local CASH_REWARDS = { Dummy = 500, Soldier = 1000 }
local REGEN_DELAY = 0.7 -- seconds out of combat
local REGEN_RATE = 40 -- HP per second

local playerData = {}

local function getData(player)
	if not playerData[player] then
		playerData[player] = { level = START_LEVEL, kills = 0, cash = 0, lastDamageTime = -999, regenRunning = false }
	end
	return playerData[player]
end

local function getExpPct(data)
	if data.level >= MAX_LEVEL then
		return 1
	end
	return math.clamp(data.kills / KILLS_TO_LEVEL[data.level], 0, 1)
end

local function syncHUD(player, data, extra)
	extra = extra or {}
	HUDEvent:FireClient(player, {
		level = data.level,
		expPct = getExpPct(data),
		cash = data.cash,
		maxLevel = data.level >= MAX_LEVEL,
		levelUp = extra.levelUp,
		killCash = extra.killCash,
	})
end

local function startRegen(player, data)
	if data.regenRunning then
		return
	end
	data.regenRunning = true
	task.spawn(function()
		while playerData[player] == data and player.Parent do
			task.wait(0.15)
			if not player.Parent or not player.Character then
				break
			end
			local hum = player.Character:FindFirstChildWhichIsA("Humanoid")
			if not hum or not hum.Parent then
				break
			end
			local elapsed = tick() - data.lastDamageTime
			if elapsed >= REGEN_DELAY and hum.Health < hum.MaxHealth and hum.Health > 0 then
				hum.Health = math.min(hum.Health + REGEN_RATE * 0.15, hum.MaxHealth)
				HUDEvent:FireClient(player, {
					hpUpdate = true,
					hp = hum.Health,
					maxHp = hum.MaxHealth,
					regening = true,
				})
			end
		end
		data.regenRunning = false
	end)
end

KillEvent.Event:Connect(function(player, killType)
	if not player or not player.Parent then
		return
	end
	local data = getData(player)
	local cash = CASH_REWARDS[killType] or 500
	data.cash += cash

	local didLevelUp = false
	if data.level < MAX_LEVEL then
		data.kills += 1
		while data.level < MAX_LEVEL and data.kills >= KILLS_TO_LEVEL[data.level] do
			data.kills = data.kills - KILLS_TO_LEVEL[data.level]
			data.level += 1
			didLevelUp = true
		end
		player:SetAttribute("Level", data.level)
	end

	syncHUD(player, data, { levelUp = didLevelUp, killCash = cash })
end)

Players.PlayerAdded:Connect(function(player)
	getData(player)
	player:SetAttribute("Level", START_LEVEL)
	player:SetAttribute("UnlockedComboHits", 5)

	player.CharacterAdded:Connect(function(character)
		local hum = character:WaitForChild("Humanoid")
		local data = getData(player)
		data.lastDamageTime = -999

		local lastHP = hum.MaxHealth
		hum.HealthChanged:Connect(function(hp)
			if hp < lastHP then
				data.lastDamageTime = tick()
				HUDEvent:FireClient(player, {
					hpUpdate = true,
					hp = hp,
					maxHp = hum.MaxHealth,
					regening = false,
				})
			end
			lastHP = hp
		end)

		-- Initial sync
		task.wait(0.5)
		if player.Parent then
			HUDEvent:FireClient(player, { hpUpdate = true, hp = hum.Health, maxHp = hum.MaxHealth })
			syncHUD(player, data, {})
		end

		startRegen(player, data)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	getData(player)
	player:SetAttribute("Level", START_LEVEL)
	player:SetAttribute("UnlockedComboHits", 5)
	if player.Character then
		local hum = player.Character:FindFirstChildWhichIsA("Humanoid")
		if hum then
			startRegen(player, getData(player))
		end
	end
end
