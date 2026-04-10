--!strict

local AdminConfig = {}

local DEFAULT_AUTHORIZED_USERNAMES = {
    romanxmanuel = true,
    anthonymlg21 = true,
    tonybalony21 = true,
    romansnowman67 = true,
}

local sessionGrantedUsernames = {}
local sessionRevokedUsernames = {}

local function normalizeUsername(username: string): string
    return string.lower(string.gsub(username or '', '^%s*(.-)%s*$', '%1'))
end

function AdminConfig.isPlayerAuthorized(player): boolean
    local normalizedName = normalizeUsername(player.Name)
    if normalizedName == '' then
        return false
    end
    if sessionRevokedUsernames[normalizedName] == true then
        return false
    end
    return sessionGrantedUsernames[normalizedName] == true or DEFAULT_AUTHORIZED_USERNAMES[normalizedName] == true
end

function AdminConfig.grantUsername(username: string, grantedBy): (boolean, string?)
    if grantedBy == nil or not AdminConfig.isPlayerAuthorized(grantedBy) then
        return false, 'Unauthorized'
    end

    local normalizedName = normalizeUsername(username)
    if normalizedName == '' then
        return false, 'InvalidUsername'
    end

    sessionRevokedUsernames[normalizedName] = nil
    sessionGrantedUsernames[normalizedName] = true
    return true, normalizedName
end

function AdminConfig.revokeUsername(username: string, revokedBy): (boolean, string?)
    if revokedBy == nil or not AdminConfig.isPlayerAuthorized(revokedBy) then
        return false, 'Unauthorized'
    end

    local normalizedName = normalizeUsername(username)
    if normalizedName == '' then
        return false, 'InvalidUsername'
    end

    sessionGrantedUsernames[normalizedName] = nil
    sessionRevokedUsernames[normalizedName] = true
    return true, normalizedName
end

function AdminConfig.getAuthorizedUsernames()
    local merged = {}
    for username in pairs(DEFAULT_AUTHORIZED_USERNAMES) do
        if sessionRevokedUsernames[username] ~= true then
            merged[username] = true
        end
    end
    for username in pairs(sessionGrantedUsernames) do
        merged[username] = true
    end

    local usernames = {}
    for username in pairs(merged) do
        table.insert(usernames, username)
    end
    table.sort(usernames)
    return usernames
end

return AdminConfig
