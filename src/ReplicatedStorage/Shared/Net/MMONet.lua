--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local MMONet = {}

MMONet.RuntimeFolderName = 'MMOCoreRuntime'

MMONet.Actions = {
    BasicAttack = 'BasicAttack',
    Dash = 'Dash',
    Warp = 'Warp',
    RandomTeleport = 'RandomTeleport',
}

MMONet.Effects = {
    Dash = 'Dash',
    DekuSmash = 'DekuSmash',
    Slash = 'Slash',
    PowerSlash = 'PowerSlash',
    SkinBurst = 'SkinBurst',
    EnemyAttack = 'EnemyAttack',
    EnemyHit = 'EnemyHit',
    EnemyDeath = 'EnemyDeath',
    BossSlam = 'BossSlam',
}

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA('RemoteEvent') then
        return existing
    end

    local remote = Instance.new('RemoteEvent')
    remote.Name = name
    remote.Parent = parent
    return remote
end

local function waitForRemoteEvent(parent: Instance, name: string, timeout: number?): RemoteEvent
    local existing = parent:WaitForChild(name, timeout or 10)
    assert(existing and existing:IsA('RemoteEvent'), string.format('Missing remote event %s', name))
    return existing
end

function MMONet.ensureServerRuntime()
    local shared = ReplicatedStorage:WaitForChild('Shared')
    local folder = shared:FindFirstChild(MMONet.RuntimeFolderName)
    if not folder then
        folder = Instance.new('Folder')
        folder.Name = MMONet.RuntimeFolderName
        folder.Parent = shared
    end

    return {
        Folder = folder,
        ActionRequest = ensureRemoteEvent(folder, 'ActionRequest'),
        StatRequest = ensureRemoteEvent(folder, 'StatRequest'),
        EffectEvent = ensureRemoteEvent(folder, 'EffectEvent'),
        SystemMessage = ensureRemoteEvent(folder, 'SystemMessage'),
    }
end

function MMONet.getClientRuntime(timeout: number?)
    local shared = ReplicatedStorage:WaitForChild('Shared')
    local folder = shared:WaitForChild(MMONet.RuntimeFolderName, timeout or 10)
    assert(folder, 'MMOCoreRuntime folder was not created by the server bootstrap')

    return {
        Folder = folder,
        ActionRequest = waitForRemoteEvent(folder, 'ActionRequest', timeout),
        StatRequest = waitForRemoteEvent(folder, 'StatRequest', timeout),
        EffectEvent = waitForRemoteEvent(folder, 'EffectEvent', timeout),
        SystemMessage = waitForRemoteEvent(folder, 'SystemMessage', timeout),
    }
end

return MMONet
