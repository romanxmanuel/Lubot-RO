--[[

	NotifierService.lua
	Server-side service for sending notifications to specific players or all players.

	✨ Features:
	- NotifyPlayer(): Sends a notification to a single player.
	- NotifyAll(): Broadcasts a notification to all players.
	- Supports multiple notification types (Normal, Image, Level).
	- Flexible info table for customizing text, color, sound, and duration.
	- Integrated EasyVisuals support for animated text and gradient effects on notifications.
	  (EasyVisuals by Arxk — https://devforum.roblox.com/t/ezvisualz-uigradient-and-uistroke-effects-made-easy/2470313)

	Usage Example:
		local NotifierService = Knit.GetService("NotifierService")

		-- Notify a single player
		NotifierService:NotifyPlayer(player, {
			MessageType = "Level Notification",
			Message = "Level Up! You reached Level 10!",
			TextColor = Color3.fromRGB(120, 255, 120),
			Sound = "rbxassetid://91237802491822",
			Duration = 3,
		})

		-- Notify all players
		NotifierService:NotifyAll({
			MessageType = "Normal Notification",
			Message = "Server maintenance will start soon.",
			TextColor = Color3.fromRGB(255, 180, 80),
			Sound = "rbxassetid://93096261667476",
			Duration = 5,
		})

	⚙️ Info Table Parameters:
	| Field              | Type              | Description |
	|--------------------|-------------------|-------------|
	| `MessageType`      | string            | Type/category of message (`"Normal Notification"`, `"Image Notification"`, `"Level Notification"`) |
	| `Message`          | string            | The main text displayed in the notification |
	| `TextColor`        | Color3?           | Optional color for text |
	| `Sound`            | string | Sound    | Optional sound (SoundId string or Sound instance) |
	| `ImageId`          | string?           | **Only used for "Image Notification"** — displays an icon (e.g. reward item, badge) |
	| `Duration`         | number?           | Duration of the notification in seconds (default: 3) |
	| `Persistent`       | boolean?          | If true, stays until manually removed |
	| `ShowCountdown`    | boolean?          | If true, appends countdown text (e.g. sabotage timers) |
	| `VisualEffect`     | table?            | Optional EasyVisuals parameters: `{ Preset = "RainbowStroke", Speed = 0.35, Size = 3 }` |

	⚠️ Note:
	This service only handles signal dispatching.
	The client (NotifierController) is responsible for rendering UI, playing sounds,
	and applying EasyVisuals effects to the notification text.

	@author Mys7o

]]

-- Roblox Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

local NotifierService = Knit.CreateService({
	Name = "NotifierService",
	Client = {
		Notify = Knit.CreateSignal(),
	},

	Instance = script, -- Automatically initializes components
})

-- Knit Services

function NotifierService:NotifyPlayer(player: Player, info: table)
	if typeof(player) ~= "Instance" or player.ClassName ~= "Player" then
		warn("NotifierService: Invalid player passed.")
		return
	end

	if typeof(info) ~= "table" then
		warn("NotifierService: Info must be a table.")
		return
	end

	NotifierService.Client.Notify:Fire(player, info)
end

function NotifierService:NotifyAll(info: table)
	if typeof(info) ~= "table" then
		warn("NotifierService: Info must be a table.")
		return
	end

	NotifierService.Client.Notify:FireAll(info)
end

function NotifierService:KnitStart()

end

function NotifierService:KnitInit()
	
end

return NotifierService