-- AbilityClient.client.lua
-- Path: StarterPlayerScripts/AbilityClient
-- SOURCE: Copied from ChatGPT design session https://chatgpt.com/c/69e31ae1-fbc8-83ea-be7f-0989d3156054

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local comboInput = ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("ComboInput")

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		comboInput:FireServer()
	end
end)
