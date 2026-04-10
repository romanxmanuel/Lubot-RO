--!strict

local Players = game:GetService('Players')
local StarterGui = game:GetService('StarterGui')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local BackpackBridgeController = {
    Name = 'BackpackBridgeController',
}

local localPlayer = Players.LocalPlayer

local function setCoreGuiEnabled(coreGuiType: Enum.CoreGuiType, enabled: boolean)
    task.spawn(function()
        for _ = 1, 10 do
            local ok = pcall(function()
                StarterGui:SetCoreGuiEnabled(coreGuiType, enabled)
            end)
            if ok then
                return
            end
            task.wait(0.5)
        end
    end)
end

local function disableLegacyPlayerGuis()
    local playerGui = localPlayer:WaitForChild('PlayerGui')

    local function handleGui(gui: Instance)
        if gui:IsA('ScreenGui') and gui.Name ~= 'MMOHud' then
            gui.Enabled = false
        end
    end

    for _, gui in ipairs(playerGui:GetChildren()) do
        handleGui(gui)
    end

    playerGui.ChildAdded:Connect(handleGui)
end

function BackpackBridgeController.init()
    return nil
end

function BackpackBridgeController.start()
    setCoreGuiEnabled(Enum.CoreGuiType.Backpack, GameConfig.NativeBackpackEnabled)
    setCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
    disableLegacyPlayerGuis()
end

return BackpackBridgeController
