--!strict

local Players = game:GetService('Players')

local PlayerDataService = require(script.Parent.PlayerDataService)

local PartyService = {}

local nextPartyId = 0
local partiesById = {}
local playerToPartyId = {}

local function getRootPart(player)
    local character = player.Character
    return character and character:FindFirstChild('HumanoidRootPart')
end

local function getPlayerByUserId(userId: number)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == userId then
            return player
        end
    end

    return nil
end

local function destroyPartyIfEmpty(partyId)
    local party = partiesById[partyId]
    if not party then
        return
    end

    local memberCount = 0
    for _ in pairs(party.memberUserIds) do
        memberCount += 1
    end

    if memberCount == 0 then
        partiesById[partyId] = nil
    end
end

function PartyService.init()
    table.clear(partiesById)
    table.clear(playerToPartyId)
    nextPartyId = 0
end

function PartyService.start()
    Players.PlayerRemoving:Connect(function(player)
        PartyService.leaveParty(player)
    end)
end

function PartyService.getPartyId(player)
    return playerToPartyId[player.UserId]
end

function PartyService.getPartyMembers(player)
    local partyId = PartyService.getPartyId(player)
    if not partyId then
        return {}
    end

    local party = partiesById[partyId]
    if not party then
        return {}
    end

    local members = {}
    for userId in pairs(party.memberUserIds) do
        local memberPlayer = getPlayerByUserId(userId)
        if memberPlayer then
            table.insert(members, memberPlayer)
        end
    end

    table.sort(members, function(a, b)
        return a.UserId < b.UserId
    end)

    return members
end

function PartyService.getPartyStateForPlayer(player)
    local partyId = PartyService.getPartyId(player)
    if not partyId then
        return nil
    end

    local party = partiesById[partyId]
    if not party then
        return nil
    end

    local members = {}
    for _, member in ipairs(PartyService.getPartyMembers(player)) do
        local humanoid = member.Character and member.Character:FindFirstChildOfClass('Humanoid')
        local profile = PlayerDataService.getOrCreateProfile(member)
        table.insert(members, {
            userId = member.UserId,
            name = member.Name,
            isLeader = party.leaderUserId == member.UserId,
            health = humanoid and humanoid.Health or 0,
            maxHealth = humanoid and humanoid.MaxHealth or 0,
            zoneId = profile.runtime.lastZoneId,
        })
    end

    return {
        partyId = partyId,
        leaderUserId = party.leaderUserId,
        members = members,
    }
end

function PartyService.inviteNearestPlayer(player)
    local rootPart = getRootPart(player)
    if not rootPart then
        return false, 'NoCharacter'
    end

    local nearestPlayer = nil
    local nearestDistance = math.huge
    for _, candidate in ipairs(Players:GetPlayers()) do
        if candidate ~= player then
            local candidateRoot = getRootPart(candidate)
            if candidateRoot then
                local distance = (candidateRoot.Position - rootPart.Position).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestPlayer = candidate
                end
            end
        end
    end

    if not nearestPlayer or nearestDistance > 35 then
        return false, 'NoNearbyPlayer'
    end

    local inviterPartyId = PartyService.getPartyId(player)
    local targetPartyId = PartyService.getPartyId(nearestPlayer)
    if inviterPartyId and targetPartyId and inviterPartyId == targetPartyId then
        return false, 'AlreadyInSameParty'
    end
    if targetPartyId and targetPartyId ~= inviterPartyId then
        return false, 'TargetAlreadyInParty'
    end

    if not inviterPartyId then
        nextPartyId += 1
        inviterPartyId = nextPartyId
        partiesById[inviterPartyId] = {
            partyId = inviterPartyId,
            leaderUserId = player.UserId,
            memberUserIds = {
                [player.UserId] = true,
            },
        }
        playerToPartyId[player.UserId] = inviterPartyId
    end

    local party = partiesById[inviterPartyId]
    if not party then
        return false, 'MissingParty'
    end

    party.memberUserIds[nearestPlayer.UserId] = true
    playerToPartyId[nearestPlayer.UserId] = inviterPartyId
    return true, nearestPlayer.Name
end

function PartyService.leaveParty(player)
    local partyId = PartyService.getPartyId(player)
    if not partyId then
        return false, 'NotInParty'
    end

    local party = partiesById[partyId]
    if not party then
        playerToPartyId[player.UserId] = nil
        return false, 'MissingParty'
    end

    party.memberUserIds[player.UserId] = nil
    playerToPartyId[player.UserId] = nil

    if party.leaderUserId == player.UserId then
        for userId in pairs(party.memberUserIds) do
            party.leaderUserId = userId
            break
        end
    end

    destroyPartyIfEmpty(partyId)
    return true, nil
end

return PartyService
