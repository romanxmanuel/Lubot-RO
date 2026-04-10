--!strict

local Players = game:GetService('Players')

local PartyService = require(script.Parent.PartyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ChatService = {}

local LOCAL_CHAT_RADIUS = 120
local MAX_CHAT_LENGTH = 120

local function getRootPart(player)
    local character = player.Character
    return character and character:FindFirstChild('HumanoidRootPart')
end

local function sanitizeText(text)
    if type(text) ~= 'string' then
        return nil
    end

    local trimmed = text:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if trimmed == '' then
        return nil
    end

    return string.sub(trimmed, 1, MAX_CHAT_LENGTH)
end

function ChatService.init() end
function ChatService.start() end

function ChatService.buildMessagePayload(channel: string, sender, text: string)
    return {
        channel = channel,
        senderUserId = sender.UserId,
        senderName = sender.Name,
        text = text,
        sentAt = os.time(),
    }
end

function ChatService.getLocalRecipients(sender)
    local senderRoot = getRootPart(sender)
    local senderProfile = PlayerDataService.getOrCreateProfile(sender)
    if not senderRoot then
        return { sender }
    end

    local recipients = {}
    for _, candidate in ipairs(Players:GetPlayers()) do
        local candidateRoot = getRootPart(candidate)
        local candidateProfile = PlayerDataService.getOrCreateProfile(candidate)
        if candidateRoot and candidateProfile.runtime.lastZoneId == senderProfile.runtime.lastZoneId then
            if (candidateRoot.Position - senderRoot.Position).Magnitude <= LOCAL_CHAT_RADIUS then
                table.insert(recipients, candidate)
            end
        end
    end

    if #recipients == 0 then
        table.insert(recipients, sender)
    end

    return recipients
end

function ChatService.getPartyRecipients(sender)
    local members = PartyService.getPartyMembers(sender)
    if #members == 0 then
        return { sender }
    end

    return members
end

function ChatService.sendMessage(sender, channel: string, rawText: string)
    local text = sanitizeText(rawText)
    if not text then
        return false, 'EmptyMessage', nil, nil
    end

    local normalizedChannel = string.lower(channel or 'local')
    if normalizedChannel == 'party' then
        local recipients = ChatService.getPartyRecipients(sender)
        local payload = ChatService.buildMessagePayload('Party', sender, text)
        return true, nil, recipients, payload
    end

    local recipients = ChatService.getLocalRecipients(sender)
    local payload = ChatService.buildMessagePayload('Local', sender, text)
    return true, nil, recipients, payload
end

return ChatService
