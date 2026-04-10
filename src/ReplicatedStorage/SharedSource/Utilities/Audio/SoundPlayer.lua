--[[

	SoundPlayer.lua
	Utility module for creating, playing, and managing sound instances safely.

	✨ Features:
	- Play(): Creates a temporary sound (SoundId or Sound object), plays it, and auto-cleans with Debris.
	- PlayMusic(): Plays background music using an existing Sound instance with smooth fade-in / fade-out transitions.
	- ToggleMusicVolume(): Smoothly mutes or unmutes currently playing music.
	- Remove(): Removes a sound from a parent by name.
	- Supports custom sound properties and attributes.
	- Automatically waits for sounds to load before playing them.

	📌 Play() Usage Example (SFX):
		local SoundPlayer = require(ReplicatedStorage.SharedSource.Utilities.SoundPlayer)

		-- Play directly from SoundId
		SoundPlayer.Play("rbxassetid://1234567890", { Volume = 1 }, workspace)

		-- Play from an existing Sound instance (clones it)
		local sfx = ReplicatedStorage.Assets.Sounds.Click
		SoundPlayer.Play(sfx, { Volume = 0.5 }, script.Parent)

	📌 PlayMusic() Usage Example (Background Music):
		local music = SoundService.BackgroundMusic.Track1
		currentMusicSound = SoundPlayer.PlayMusic(music, 0.35, 2, currentMusicSound)

	⚠️ Notes:
	- Play() is intended for short, temporary SFX. These sounds are automatically removed.
	- PlayMusic() is intended for persistent background music and does NOT auto-delete or clone.
	- For advanced music logic (queues, playlists, looping rules), consider using a dedicated MusicManager.

	@author Mys7o
	@version 1.0.1

]]

-- Roblox Services
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

-- Module
local SoundPlayer = {}

-- Create and play a sound instance
function SoundPlayer.Play(
	soundOrSoundId: string | Sound,
	properties: table?,
	parent: Instance,
	delayBeforeDeleting: number?,
	attributes: table?
): Sound?

	if not parent then
		warn("SoundPlayer.Play: Missing parent argument.")
		return nil
	end

	local sound
	if typeof(soundOrSoundId) == "string" then
		sound = Instance.new("Sound")
		sound.SoundId = soundOrSoundId

		if typeof(properties) == "table" then
			for propertyName, propertyValue in pairs(properties) do
				pcall(function()
					sound[propertyName] = propertyValue
				end)
			end
		end

	elseif typeof(soundOrSoundId) == "Instance" and soundOrSoundId:IsA("Sound") then
		sound = soundOrSoundId:Clone()
	else
		warn("SoundPlayer.Play: Invalid soundOrSoundId provided.")
		return nil
	end

	sound.Parent = parent

	if typeof(attributes) == "table" then
		for name, value in pairs(attributes) do
			sound:SetAttribute(name, value)
		end
	end

	-- Optional non-blocking load
	if not sound.IsLoaded then
		task.spawn(function()
			pcall(function()
				sound.Loaded:Wait()
			end)

			if sound and sound.Parent then
				sound:Play()
			end
		end)
	else
		sound:Play()
	end

	if not delayBeforeDeleting then
		delayBeforeDeleting = (sound.TimeLength > 0 and sound.TimeLength + 0.1) or 2
	end

	Debris:AddItem(sound, delayBeforeDeleting)

	return sound
end

-- Remove an existing sound from a part or parent
function SoundPlayer.Remove(parent: Instance, soundName: string)
	if not parent or not soundName then
		warn("SoundPlayer.Remove: Missing parent or soundName argument.")
		return
	end

	local sound = parent:FindFirstChild(soundName)
	if sound then
		sound:Destroy()
	end
end

-- Plays background music with fade-in / fade-out transitions
function SoundPlayer.PlayMusic(
	sound: Sound,
	targetVolume: number,
	fadeTime: number,
	previousSound: Sound?
): Sound?

	if not sound or not sound:IsA("Sound") then
		warn("SoundPlayer.PlayMusic: Invalid Sound provided.")
		return nil
	end

	-- If a previous track is playing, fade it out fully first
	if previousSound and previousSound.IsPlaying then
		local finished = false

		local fadeOutTween = TweenService:Create(
			previousSound,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Volume = 0 }
		)

		fadeOutTween.Completed:Connect(function()
			if previousSound and previousSound.IsPlaying then
				previousSound:Stop()
			end
			finished = true
		end)

		fadeOutTween:Play()

		-- Non-blocking wait (polling loop that doesn't freeze Knit threads)
		while not finished do
			task.wait()
		end
	end

	-- Prepare and start new track
	sound.Volume = 0
	sound.TimePosition = 0
	sound:Play()

	-- Fade-in
	local fadeInTween = TweenService:Create(
		sound,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = targetVolume }
	)
	fadeInTween:Play()

	return sound
end

-- Smoothly toggles volume between muted/unmuted for an active sound
function SoundPlayer.ToggleMusicVolume(
	sound: Sound,
	targetVolume: number,
	fadeTime: number
)
	if not sound or not sound:IsA("Sound") then
		warn("[SoundPlayer] ToggleMusicVolume: Invalid Sound provided.")
		return
	end

	if not sound.IsPlaying then
		warn("[SoundPlayer] ToggleMusicVolume: Sound is not currently playing.")
		return
	end

	local isMuted = sound.Volume > 0
	local newVolume = isMuted and 0 or targetVolume

	local tween = TweenService:Create(
		sound,
		TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = newVolume }
	)

	tween:Play()

	return not isMuted -- returns true if now unmuted, false if muted
end

return SoundPlayer