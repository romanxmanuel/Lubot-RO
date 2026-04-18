local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = ReplicatedStorage:WaitForChild("Combat")
local CombatConfig = require(Combat:WaitForChild("CombatConfig"))
local MasterConfig = require(ReplicatedStorage:WaitForChild("MasterConfig"))
local AssetRegistry = require(Combat:WaitForChild("AssetRegistry"))
local CombatUtils = require(Combat:WaitForChild("CombatUtils"))
local StunService = require(Combat:WaitForChild("StunService"))
local TargetingService = require(Combat:WaitForChild("TargetingService"))
local VFXService = require(Combat:WaitForChild("VFXService"))
local SFXService = require(Combat:WaitForChild("SFXService"))

local remotes = ReplicatedStorage:WaitForChild("CombatRemotes")
local comboInput = remotes:WaitForChild("ComboInput")
local impactRemote = remotes:WaitForChild("PlayImpactFX")
local presentationRemote = remotes:WaitForChild("PlayPresentationFX")
local comboDamageBridge = ReplicatedStorage:WaitForChild("ComboDamageRequest")

local heartbeatFlag = ReplicatedStorage:FindFirstChild("ComboControllerAlive")
if not heartbeatFlag then
    heartbeatFlag = Instance.new("BoolValue")
    heartbeatFlag.Name = "ComboControllerAlive"
    heartbeatFlag.Parent = ReplicatedStorage
end
heartbeatFlag.Value = true

local eventCount = ReplicatedStorage:FindFirstChild("ComboInputEventCount")
if not eventCount then
    eventCount = Instance.new("IntValue")
    eventCount.Name = "ComboInputEventCount"
    eventCount.Parent = ReplicatedStorage
end

local bridgeFireCount = ReplicatedStorage:FindFirstChild("ComboBridgeFireCount")
if not bridgeFireCount then
    bridgeFireCount = Instance.new("IntValue")
    bridgeFireCount.Name = "ComboBridgeFireCount"
    bridgeFireCount.Parent = ReplicatedStorage
end

local lastTargetName = ReplicatedStorage:FindFirstChild("ComboLastTarget")
if not lastTargetName then
    lastTargetName = Instance.new("StringValue")
    lastTargetName.Name = "ComboLastTarget"
    lastTargetName.Parent = ReplicatedStorage
end

local states = {}

local function getState(player)
    local state = states[player]
    if state then
        return state
    end

    state = {
        Step = 0,
        StartPosition = nil,
        LastInputTime = 0,
        CurrentTarget = nil,
        Suspended = false,
        Busy = false,
    }
    states[player] = state
    return state
end

local function resetCombo(state)
    state.Step = 0
    state.CurrentTarget = nil
    state.Suspended = false
    state.Busy = false
end

local function shouldRetainTarget(state)
    local retain = tonumber(MasterConfig.AutolockReleaseDelay) or CombatConfig.General.AutoLockRetainTime or 0
    return retain > 0 and (os.clock() - state.LastInputTime) <= retain
end

local function ensureTarget(character, state)
    local target = state.CurrentTarget
    if target and target.Parent and CombatUtils.IsAlive(target) and shouldRetainTarget(state) then
        return target
    end

    target = TargetingService.GetNearestTarget(character, CombatConfig.General.MaxTargetRange)
    state.CurrentTarget = target
    return target
end

local function fireImpact(player, cfg)
    impactRemote:FireClient(player, cfg)
end

local function doDamage(player, hitPos, hitRadius, comboIndex, primaryModel, damage)
    bridgeFireCount.Value += 1
    comboDamageBridge:Fire(player, hitPos, hitRadius, comboIndex, primaryModel, damage)
end

local function doHit1(player, state, character, target)
    local cfg = CombatConfig.Combo5.Hit1
    local root = character.HumanoidRootPart
    local targetRoot = target.HumanoidRootPart

    local destination = CombatUtils.GetPositionBehindTarget(targetRoot, cfg.BlinkOffset or 2)
    CombatUtils.BlinkToPosition(root, destination, targetRoot.Position)

    fireImpact(player, cfg)
    doDamage(player, targetRoot.Position, 8, 1, target, cfg.Damage)
    StunService.Apply(target, cfg.Stun)
    VFXService.SpawnDrop(AssetRegistry.VFX.Hit1, CFrame.new(targetRoot.Position), 1.2)
    SFXService.PlayHit(1, root)
end

local function doHit2(player, state, character, target)
    local pushCfg = CombatConfig.Combo5.Hit2Push
    local meteorCfg = CombatConfig.Combo5.Hit2Meteor

    local root = character.HumanoidRootPart
    local targetRoot = target.HumanoidRootPart

    fireImpact(player, pushCfg)
    doDamage(player, targetRoot.Position, 20, 2, target, pushCfg.Damage)

    targetRoot.AssemblyLinearVelocity = targetRoot.CFrame.LookVector * pushCfg.EnemyForwardPush + Vector3.new(0, 4, 0)
    root.AssemblyLinearVelocity = -root.CFrame.LookVector * pushCfg.PlayerBackwardLaunch + Vector3.new(0, pushCfg.PlayerVerticalLift, 0)

    VFXService.SpawnDrop(AssetRegistry.VFX.Hit2, CFrame.new(targetRoot.Position), 1.5)
    SFXService.PlayHit(2, root)

    task.delay(pushCfg.LaunchDuration, function()
        if target and target.Parent and CombatUtils.IsAlive(target) then
            fireImpact(player, meteorCfg)
            doDamage(player, targetRoot.Position, 24, 3, target, meteorCfg.Damage)
            StunService.Apply(target, meteorCfg.Stun)
            VFXService.SpawnDrop(AssetRegistry.VFX.Hit3, CFrame.new(targetRoot.Position), 1.5)
            SFXService.PlayHit(3, root)
            state.Suspended = true
        end
    end)
end

local function doHit3(player, state, character, target)
    local cfg = CombatConfig.Combo5.Hit3
    local root = character.HumanoidRootPart
    local targetRoot = target.HumanoidRootPart

    fireImpact(player, cfg)
    doDamage(player, targetRoot.Position, 26, 3, target, cfg.Damage)
    StunService.Apply(target, cfg.Stun)

    root.AssemblyLinearVelocity = Vector3.new(0, cfg.SelfLaunchUpward, 0)
    VFXService.SpawnDrop(AssetRegistry.VFX.Hit3, CFrame.new(targetRoot.Position), 1.6)
    SFXService.PlayHit(3, root)
end

local function doHit4(player, state, character, target)
    local cfg = CombatConfig.Combo5.Hit4
    local root = character.HumanoidRootPart
    local targetRoot = target.HumanoidRootPart

    local destination = CombatUtils.GetPositionBehindTarget(targetRoot, cfg.BlinkOffset or 2)
    CombatUtils.BlinkToPosition(root, destination, targetRoot.Position)

    fireImpact(player, cfg)
    doDamage(player, targetRoot.Position, 13, 4, target, cfg.Damage)
    StunService.Apply(target, cfg.Stun)

    VFXService.SpawnDrop(AssetRegistry.VFX.Hit4, CFrame.new(targetRoot.Position), 1.2)
    SFXService.PlayHit(4, root)
end

local function doHit5(player, state, character, target)
    local cfg = CombatConfig.Combo5.Hit5Blast
    local root = character.HumanoidRootPart
    local targetRoot = target.HumanoidRootPart

    fireImpact(player, cfg)
    presentationRemote:FireClient(player, { Kind = "CastFlash" })

    doDamage(player, targetRoot.Position, 32, 5, target, cfg.Damage)
    StunService.Apply(target, cfg.Stun)
    CombatUtils.ApplyKnockback(target, root.Position, cfg.Knockback, 14)

    VFXService.SpawnDrop(AssetRegistry.VFX.Hit5, CFrame.lookAt(root.Position, targetRoot.Position), 2)
    SFXService.PlayHit(5, root)

    local dirBack = state.StartPosition and (state.StartPosition - root.Position) or Vector3.zero
    if dirBack.Magnitude > 0.1 then
        root.AssemblyLinearVelocity = dirBack.Unit * cfg.PlayerBackwardBlast + Vector3.new(0, 3, 0)
    end

    task.delay(cfg.ReturnDuration, function()
        if character and character.Parent and state.StartPosition then
            root.CFrame = CFrame.new(state.StartPosition, state.StartPosition + root.CFrame.LookVector)
        end
    end)

    resetCombo(state)
end

comboInput.OnServerEvent:Connect(function(player)
    eventCount.Value += 1

    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end

    local state = getState(player)
    local now = os.clock()

    if state.Busy then
        return
    end

    local attackCooldown = tonumber(MasterConfig.AttackCooldown) or CombatConfig.General.InputDebounce or 0.08
    if now - state.LastInputTime < attackCooldown then
        return
    end

    local chainWindow = tonumber(MasterConfig.AttackChainWindow) or CombatConfig.General.ComboResetWindow or 1.25
    if state.Step > 0 and (now - state.LastInputTime) > chainWindow then
        resetCombo(state)
    end

    state.LastInputTime = now

    if state.Step == 0 then
        state.StartPosition = character.HumanoidRootPart.Position
    end

    local target = ensureTarget(character, state)
    if not target then
        lastTargetName.Value = "NONE"
        resetCombo(state)
        return
    end

    lastTargetName.Value = target.Name
    state.Step += 1

    local unlockedHits = math.clamp(tonumber(player:GetAttribute("UnlockedComboHits")) or 5, 1, 5)
    if state.Step > unlockedHits then
        state.Step = 1
    end

    if state.Step == 1 then
        doHit1(player, state, character, target)
    elseif state.Step == 2 then
        doHit2(player, state, character, target)
    elseif state.Step == 3 then
        if not state.Suspended then
            state.Step = 2
            return
        end
        doHit3(player, state, character, target)
    elseif state.Step == 4 then
        doHit4(player, state, character, target)
    elseif state.Step == 5 then
        doHit5(player, state, character, target)
    else
        resetCombo(state)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    states[player] = nil
end)
