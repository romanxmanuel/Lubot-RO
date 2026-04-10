--!strict

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)

local localPlayer = Players.LocalPlayer

local CombatModuleRegistry = require(script.Parent.CombatModuleRegistry)
local CombatModulesFolder = script.Parent:WaitForChild('CombatModules')

local CombatHandler = {
    Name = 'CombatHandler',
}

local dependencies = nil
local moduleCache = {}
local activeTool: Tool? = nil
local activeModuleName = CombatModuleRegistry.DEFAULT_MODULE
local activeModule = nil
local characterConnections: { RBXScriptConnection } = {}

local function disconnectAll(connections: { RBXScriptConnection })
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
end

local function getEquippedTool(): Tool?
    local character = localPlayer.Character
    if not character then
        return nil
    end

    for _, child in ipairs(character:GetChildren()) do
        if child:IsA('Tool') then
            return child
        end
    end

    return nil
end

local function hasUsableEquippedTool(): boolean
    local equippedTool = getEquippedTool()
    if not equippedTool then
        return false
    end

    if equippedTool:GetAttribute('AllowsCombatStyleOnly') == true then
        return false
    end

    return true
end

local function toolOwnsActionInput(keyCode: Enum.KeyCode): boolean
    local equippedTool = getEquippedTool()
    if not equippedTool then
        return false
    end

    if equippedTool:GetAttribute('ImportedAssetId') == nil then
        return false
    end

    if keyCode == Enum.KeyCode.Q or keyCode == Enum.KeyCode.E or keyCode == Enum.KeyCode.R then
        return true
    end

    return false
end

local function getActionContext()
    return {
        dependencies = dependencies,
        runtime = dependencies.Runtime,
        localPlayer = localPlayer,
        gameConfig = GameConfig,
        net = MMONet,
        activeTool = activeTool,
        hasUsableEquippedTool = hasUsableEquippedTool,
        toolOwnsActionInput = toolOwnsActionInput,
    }
end

local function loadModuleByName(moduleName: string)
    if moduleCache[moduleName] then
        return moduleCache[moduleName]
    end

    local moduleScript = CombatModulesFolder:FindFirstChild(moduleName)
    if not moduleScript or not moduleScript:IsA('ModuleScript') then
        warn(string.format('[CombatHandler] Combat module "%s" not found. Falling back to %s.', moduleName, CombatModuleRegistry.DEFAULT_MODULE))
        moduleScript = CombatModulesFolder:FindFirstChild(CombatModuleRegistry.DEFAULT_MODULE)
        if not moduleScript or not moduleScript:IsA('ModuleScript') then
            return nil
        end
        moduleName = CombatModuleRegistry.DEFAULT_MODULE
    end

    local ok, result = pcall(require, moduleScript)
    if not ok then
        warn(string.format('[CombatHandler] Failed to require combat module "%s": %s', moduleName, tostring(result)))
        return nil
    end

    moduleCache[moduleName] = result
    return result
end

local function callModuleHook(moduleRef, hookName: string, context)
    if not moduleRef then
        return
    end
    local hook = moduleRef[hookName]
    if type(hook) ~= 'function' then
        return
    end
    local ok, err = pcall(function()
        hook(moduleRef, context)
    end)
    if not ok then
        warn(string.format('[CombatHandler] %s failed in module %s: %s', hookName, activeModuleName, tostring(err)))
    end
end

local function refreshActiveModule()
    local nextTool = getEquippedTool()
    if nextTool == activeTool then
        return
    end

    if activeModule then
        callModuleHook(activeModule, 'OnUnequip', getActionContext())
    end

    activeTool = nextTool
    activeModuleName = CombatModuleRegistry.resolveModuleName(activeTool)
    activeModule = loadModuleByName(activeModuleName)

    if activeModule then
        callModuleHook(activeModule, 'OnEquip', getActionContext())
    end
end

local function bindCharacter(character: Model)
    disconnectAll(characterConnections)
    table.insert(characterConnections, character.ChildAdded:Connect(function(child)
        if child:IsA('Tool') then
            refreshActiveModule()
        end
    end))
    table.insert(characterConnections, character.ChildRemoved:Connect(function(child)
        if child:IsA('Tool') then
            refreshActiveModule()
        end
    end))
    refreshActiveModule()
end

local function routeAction(actionName: 'Attack' | 'Block' | 'Dash')
    refreshActiveModule()
    if not activeModule then
        return false
    end

    local actionFn = activeModule[actionName]
    if type(actionFn) ~= 'function' then
        return false
    end

    local ok, result = pcall(function()
        return actionFn(activeModule, getActionContext())
    end)
    if not ok then
        warn(string.format('[CombatHandler] %s failed in module %s: %s', actionName, activeModuleName, tostring(result)))
        return false
    end

    return result == true
end

function CombatHandler.init(deps)
    dependencies = deps
end

function CombatHandler.start()
    if localPlayer.Character then
        bindCharacter(localPlayer.Character)
    end

    localPlayer.CharacterAdded:Connect(function(character)
        bindCharacter(character)
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end

        if UserInputService:GetFocusedTextBox() then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            routeAction('Attack')
            return
        end

        if input.KeyCode == Enum.KeyCode.Q then
            routeAction('Dash')
            return
        end

        if input.KeyCode == Enum.KeyCode.E then
            routeAction('Block')
        end
    end)
end

return CombatHandler
