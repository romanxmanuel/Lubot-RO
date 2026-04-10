--!strict

local StarterGui = game:GetService('StarterGui')
local TextChatService = game:GetService('TextChatService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local ChatController = {
    Name = 'ChatController',
}

local dependencies = nil
local commandRegistered = false

local function displaySystemMessage(message: string)
    local textChannels = TextChatService:FindFirstChild('TextChannels') or TextChatService:WaitForChild('TextChannels', 8)
    if textChannels then
        local general = textChannels:FindFirstChild('RBXGeneral') or textChannels:FindFirstChild('RBXSystem')
        if general and general:IsA('TextChannel') then
            general:DisplaySystemMessage(message)
            return
        end
    end

    pcall(function()
        StarterGui:SetCore('ChatMakeSystemMessage', {
            Text = message,
            Color = Color3.fromRGB(151, 225, 255),
        })
    end)
end

local function registerWarpCommand()
    if commandRegistered then
        return
    end
    commandRegistered = true

    local goCommand = Instance.new('TextChatCommand')
    goCommand.Name = 'MMOWarpCommand'
    goCommand.PrimaryAlias = '/go'
    goCommand.SecondaryAlias = '/warp'
    goCommand.AutocompleteVisible = false
    goCommand.Enabled = true
    goCommand.Parent = TextChatService

    goCommand.Triggered:Connect(function(_, rawText: string)
        local query = rawText:match('^/%w+%s+(.+)$')
        if not query then
            displaySystemMessage('Usage: /go <map>')
            return
        end

        dependencies.Runtime.ActionRequest:FireServer({
            action = MMONet.Actions.Warp,
            query = string.lower(query),
        })
    end)
end

function ChatController.init(deps)
    dependencies = deps
end

function ChatController.start()
    registerWarpCommand()
    dependencies.Runtime.SystemMessage.OnClientEvent:Connect(function(message: string)
        displaySystemMessage(message)
    end)
end

return ChatController
