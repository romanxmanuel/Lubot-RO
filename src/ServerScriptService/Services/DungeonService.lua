--!strict

local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)

local DungeonService = {}

function DungeonService.init() end
function DungeonService.start() end

function DungeonService.createRun(dungeonId: string, players)
    return {
        dungeonId = dungeonId,
        players = players,
        createdAt = os.time(),
    }
end

function DungeonService.warpPlayerToZone(player, zoneId: string)
    local character = player.Character
    local rootPart = character and character:FindFirstChild('HumanoidRootPart')
    if not rootPart then
        return false, 'NoCharacter'
    end

    rootPart.CFrame = WorldService.getSpawnCFrameForZoneId(zoneId)
    PlayerDataService.getOrCreateProfile(player).runtime.lastZoneId = zoneId
    return true, nil
end

function DungeonService.warpPlayerToDungeon(player, dungeonId: string)
    return DungeonService.warpPlayerToZone(player, dungeonId)
end

function DungeonService.warpPlayerToField(player)
    return DungeonService.warpPlayerToZone(player, 'prontera_field')
end

function DungeonService.warpPlayerToTowerOfAscension(player)
    return DungeonService.warpPlayerToZone(player, 'tower_of_ascension')
end

function DungeonService.warpPlayerToNiffheim(player)
    return DungeonService.warpPlayerToZone(player, 'niffheim')
end

return DungeonService
