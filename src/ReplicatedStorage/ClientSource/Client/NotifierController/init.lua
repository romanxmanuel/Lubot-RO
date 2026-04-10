-- Roblox Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Utilities
local UIAnimator = require(ReplicatedStorage.SharedSource.Utilities.UI.UIAnimator)
local EasyVisuals = require(ReplicatedStorage.SharedSource.Utilities.UI.EasyVisuals)
local SoundPlayer = require(ReplicatedStorage.SharedSource.Utilities.Audio.SoundPlayer)

local NotifierController = Knit.CreateController({
	Name = "NotifierController",
	Instance = script, -- Automatically initializes components
})

-- Assets (safely loaded with pcall)
local assetsFolder, uisFolder, normalNotificationTemplate, imageNotificationTemplate, levelNotificationCanvasGroup
local success, result = pcall(function()
    assetsFolder = ReplicatedStorage:WaitForChild("Assets", 10)
    if assetsFolder then
        uisFolder = assetsFolder:WaitForChild("UIs", 10)
        if uisFolder then
            normalNotificationTemplate = uisFolder:WaitForChild("NormalNotificationCanvasGroup", 10)
            imageNotificationTemplate = uisFolder:WaitForChild("ImageNotificationCanvasGroup", 10)
            levelNotificationCanvasGroup = uisFolder:WaitForChild("LevelNotificationCanvasGroup", 10)
        end
    end
end)
if not success then
    warn("[NotifierController] Failed to load assets:", result)
    assetsFolder = nil
    uisFolder = nil
    normalNotificationTemplate = nil
    imageNotificationTemplate = nil
    levelNotificationCanvasGroup = nil
end

-- Knit Services
local NotifierService

-- Knit Controllers

-- Player & Gui references
local player
local playerGui

local notifierGui
local notifierFrame

local function displayNotification(
	template: CanvasGroup,
	messageType: string,
	message: string,
	textColor: Color3?,
	duration: number?,
	soundOrSoundId: any?,
	imageId: string?,
	persistent: boolean?,
	showCountdown: boolean?,
	visualEffect: table?
)
	duration = duration or 3

	local notification = template:Clone()
	local textLabel = notification:FindFirstChild("TextLabel")

	if not textLabel then
		warn("[NotifierController] Missing TextLabel inside notification template: " .. template.Name)
		return
	end

	textLabel.Text = message

	if messageType ~= "Level Notification" then
		textLabel.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	end

	-- Optional image display
	if messageType == "Image Notification" and imageId then
		local imageContainerFrame = notification:FindFirstChild("ImageContainerFrame")
		local imageLabel = imageContainerFrame and imageContainerFrame:FindFirstChild("ImageLabel")

		if imageLabel then
			imageLabel.Image = imageId
			imageLabel.Visible = true
		else
			warn("[NotifierController] Missing ImageContainerFrame.ImageLabel inside template:", template.Name)
		end
	end

	if not notifierFrame then
		warn("[NotifierController] NotifierFrame missing from NotifierGui.")
		return
	end

	-- Setup and parent
	notification.GroupTransparency = 1
	notification.Parent = notifierFrame

		-- Apply EasyVisuals if requested
		if visualEffect then
			local preset = visualEffect.Preset or "RainbowStroke"
			local speed = visualEffect.Speed or 0.35
			local size = visualEffect.Size or 3
			local color = visualEffect.Color
			local transparency = visualEffect.Transparency

			EasyVisuals.new(
				textLabel,
				preset,
				speed,
				size,
				false,
				color,
				transparency
			)
		end

	-- Optional sound
	if soundOrSoundId then
		SoundPlayer.Play(soundOrSoundId, {}, notification)
	end

	-- Fade In (using UIAnimator)
	UIAnimator.Play(
		notification,
		{ GroupTransparency = 0 },
		0.35,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	-- Countdown updater
	if showCountdown and duration > 0 then
		task.spawn(function()
			for remaining = duration, 1, -1 do
				if not notification.Parent or not textLabel then break end
				textLabel.Text = string.format("%s [%ds]", message, remaining)
				task.wait(1)
			end
		end)
	end

	-- Persistent notifications stay until manually removed
	if persistent then
		return notification
	end

	-- Auto remove after duration
	task.delay(duration, function()
		if not notification or not notification.Parent then return end

		UIAnimator.Play(
			notification,
			{ GroupTransparency = 1 },
			0.5,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			function()
				if notification then
					notification:Destroy()
				end
			end
		)
	end)

	return notification
end

function NotifierController:CreateNotification(info: table): CanvasGroup?
	local messageType = info.MessageType       -- string | "Normal Notification", "Image Notification", or "Level Notification"
	local message = info.Message               -- string | Main text displayed in the notification
	local textColor = info.TextColor           -- Color3? | Optional text color (ignored for Level Notification)
	local soundOrSoundId = info.Sound          -- string | Sound | Optional sound ID or Sound instance
	local imageId = info.ImageId               -- string? | Optional image asset ID (only for Image Notification)
	local duration = info.Duration             -- number? | Duration in seconds before fading out (default: 3)
	local persistent = info.Persistent         -- boolean?| If true, stays visible until manually removed
	local showCountdown = info.ShowCountdown   -- boolean?| If true, shows countdown text beside the message
	local visualEffect = info.VisualEffect     -- table? | Optional EasyVisuals configuration `{ Preset, Speed, Size, Color, Transparency }`

	local templateMap = {
		["Normal Notification"] = normalNotificationTemplate,
		["Image Notification"] = imageNotificationTemplate,
		["Level Notification"] = levelNotificationCanvasGroup,
	}

	local template = templateMap[messageType]
	if not template then
		warn("[NotifierController] Invalid template for messageType:", messageType)
		return
	end

	return displayNotification(
		template,
		messageType,
		message,
		textColor,
		duration,
		soundOrSoundId,
		imageId,
		persistent,
		showCountdown,
		visualEffect
	)
end

function NotifierController:KnitStart()
	playerGui = player:WaitForChild("PlayerGui", 10)
	notifierGui = playerGui:WaitForChild("NotifierGui", 10)
	notifierFrame = notifierGui:WaitForChild("NotifierFrame", 10)

	NotifierService.Notify:Connect(function(info)
		NotifierController:CreateNotification(info)
	end)
end

function NotifierController:KnitInit()
	player = Players.LocalPlayer
	NotifierService = Knit.GetService("NotifierService")
end

return NotifierController