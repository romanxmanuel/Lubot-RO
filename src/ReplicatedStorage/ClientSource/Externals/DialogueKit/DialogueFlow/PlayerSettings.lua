-- PlayerSettings.lua
-- Apply/restore player settings (walk speed, CoreGui, camera, sound) and death handling.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local State = require(script.Parent.Parent.State)

local PlayerSettings = {}

-- Hub reference (injected by init.lua)
PlayerSettings.Flow = nil

function PlayerSettings.applyPlayerSettings(config)
	if not config then
		return
	end

	local player = game.Players.LocalPlayer
	if not player then
		return
	end

	local walkSpeedConfig = config:FindFirstChild("DialogueWalkSpeed")
	if walkSpeedConfig and walkSpeedConfig:IsA("NumberValue") then
		local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
		if humanoid then
			State.originalWalkSpeed = humanoid.WalkSpeed

			if walkSpeedConfig.Value ~= -1 then
				humanoid.WalkSpeed = walkSpeedConfig.Value
			end
		end
	end

	local coreGuiConfig = config:FindFirstChild("CoreGui")
	if coreGuiConfig and coreGuiConfig:IsA("BoolValue") and coreGuiConfig.Value then
		local StarterGui = game:GetService("StarterGui")

		local backpackEnabled = coreGuiConfig:GetAttribute("BackpackEnabled")
		if backpackEnabled ~= nil then
			State.originalCoreGuiState.Backpack = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, backpackEnabled)
		end

		local chatEnabled = coreGuiConfig:GetAttribute("ChatEnabled")
		if chatEnabled ~= nil then
			State.originalCoreGuiState.Chat = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, chatEnabled)
		end

		local leaderboardEnabled = coreGuiConfig:GetAttribute("LeaderboardEnabled")
		if leaderboardEnabled ~= nil then
			State.originalCoreGuiState.PlayerList = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
			-- Wrap in pcall to suppress GuiService selection group warning
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, leaderboardEnabled)
			end)
		end
	end

	local dialogueCameraConfig = config:FindFirstChild("DialogueCamera")
	if dialogueCameraConfig and dialogueCameraConfig:IsA("ObjectValue") and dialogueCameraConfig.Value then
		local camera = workspace.CurrentCamera
		State.originalCameraType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = dialogueCameraConfig.Value.CFrame
	end

	local backgroundSoundConfig = config:FindFirstChild("BackgroundSound")
	if backgroundSoundConfig and backgroundSoundConfig:IsA("NumberValue") then
		local dialogueSound = SoundService:FindFirstChild("DialogueKit")
		if dialogueSound and dialogueSound:FindFirstChild("BackgroundSound") then
			State.backgroundSoundInstance = dialogueSound.BackgroundSound
			State.backgroundSoundInstance.SoundId = "rbxassetid://" .. backgroundSoundConfig.Value

			local pitch = backgroundSoundConfig:GetAttribute("BackgroundSoundPitch")
			if pitch then
				State.backgroundSoundInstance.PlaybackSpeed = pitch
			end

			local originalVolume = State.backgroundSoundInstance.Volume

			State.backgroundSoundInstance.Volume = 0
			State.backgroundSoundInstance:Play()

			local volume = backgroundSoundConfig:GetAttribute("BackgroundSoundVolume") or 1
			local skin = State.skins[State.currentSkin]
			local tweenInfo = TweenInfo.new(
				skin:GetAttribute("TweenTime"),
				Enum.EasingStyle[skin:GetAttribute("EasingStyle")],
				Enum.EasingDirection[skin:GetAttribute("EasingDirection")]
			)

			TweenService
				:Create(State.backgroundSoundInstance, tweenInfo, { Volume = volume })
				:Play()
		end
	end
end

function PlayerSettings.restorePlayerSettings(config)
	if not config then
		return
	end

	local player = game.Players.LocalPlayer
	if not player then
		return
	end

	if State.originalWalkSpeed then
		local walkSpeedConfig = config:FindFirstChild("DialogueWalkSpeed")
		local defaultWalkSpeed = walkSpeedConfig and walkSpeedConfig:GetAttribute("DefaultWalkSpeed")
			or State.originalWalkSpeed

		local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = defaultWalkSpeed
		end

		State.originalWalkSpeed = nil
	end

	local coreGuiConfig = config:FindFirstChild("CoreGui")
	if coreGuiConfig and coreGuiConfig:IsA("BoolValue") and coreGuiConfig.Value then
		local StarterGui = game:GetService("StarterGui")

		if State.originalCoreGuiState.Backpack ~= nil then
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, State.originalCoreGuiState.Backpack)
		end

		if State.originalCoreGuiState.Chat ~= nil then
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, State.originalCoreGuiState.Chat)
		end

		if State.originalCoreGuiState.PlayerList ~= nil then
			-- Wrap in pcall to suppress GuiService selection group warning
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, State.originalCoreGuiState.PlayerList)
			end)
		end

		State.originalCoreGuiState = {
			Backpack = nil,
			Chat = nil,
			PlayerList = nil,
		}
	end

	if State.originalCameraType then
		local camera = workspace.CurrentCamera
		camera.CameraType = State.originalCameraType
		State.originalCameraType = nil
	end

	if State.backgroundSoundInstance then
		local skin = State.skins[State.currentSkin]
		local tweenInfo = TweenInfo.new(
			skin:GetAttribute("TweenTime"),
			Enum.EasingStyle[skin:GetAttribute("EasingStyle")],
			Enum.EasingDirection[skin:GetAttribute("EasingDirection")]
		)

		local volumeTween =
			TweenService:Create(State.backgroundSoundInstance, tweenInfo, { Volume = 0 })
		volumeTween.Completed:Connect(function()
			State.backgroundSoundInstance:Stop()
			State.backgroundSoundInstance = nil
		end)
		volumeTween:Play()
	end

	if State.healthChangedConnection then
		State.healthChangedConnection:Disconnect()
		State.healthChangedConnection = nil
	end
end

function PlayerSettings.setupPlayerDeathHandling(config)
	if not config then
		return
	end

	local playerDeadConfig = config:FindFirstChild("PlayerDead")
	if not playerDeadConfig or not playerDeadConfig:IsA("StringValue") then
		return
	end

	local stopDialogueOnDeath = playerDeadConfig:GetAttribute("StopDialogueOnDeath")
	if stopDialogueOnDeath then
		local player = game.Players.LocalPlayer
		if not player then
			return
		end

		local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
		if humanoid then
			if State.healthChangedConnection then
				State.healthChangedConnection:Disconnect()
			end

			State.healthChangedConnection = humanoid.HealthChanged:Connect(function(health)
				if health <= 0 and State.currentDialogue then
					PlayerSettings.Flow.closeDialogue()
				end
			end)
		end
	end
end

return PlayerSettings
