local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MasterConfig = require(ReplicatedStorage:WaitForChild("MasterConfig"))
local comboInput = ReplicatedStorage:WaitForChild("CombatRemotes"):WaitForChild("ComboInput")

local debounce = false
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or debounce then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        debounce = true
        comboInput:FireServer()
        local clickCooldown = tonumber(MasterConfig.AttackCooldown) or 0.06
        task.delay(math.max(clickCooldown, 0), function()
            debounce = false
        end)
    end
end)
