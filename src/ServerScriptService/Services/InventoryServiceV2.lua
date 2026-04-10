--!strict

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local ItemData = require(ReplicatedStorage.GameData.Items.ItemData)
local SkillData = require(ReplicatedStorage.GameData.Skills.SkillData)
local ToolFactory = require(script.Parent.Parent.Systems.Tools.ToolFactory)

local InventoryServiceV2 = {
    Name = 'InventoryService',
}

local dependencies = nil

local function getInventoryEntry(profile, itemId: string)
    for _, entry in ipairs(profile.inventory) do
        if entry.itemId == itemId then
            return entry
        end
    end
    return nil
end

local function destroyTools(container: Instance?)
    if not container then
        return
    end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA('Tool') then
            child:Destroy()
        end
    end
end

function InventoryServiceV2.init(deps)
    dependencies = deps
end

function InventoryServiceV2.start()
    local function bindPlayer(player: Player)
        local profile = dependencies.PersistenceService.waitForProfile(player, 10)
        if not profile then
            return
        end

        InventoryServiceV2.ensureStarterLoadout(player)

        local function rebuild()
            InventoryServiceV2.rebuildPlayerTools(player)
        end

        player.CharacterAdded:Connect(function()
            task.defer(rebuild)
        end)

        task.defer(rebuild)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        bindPlayer(player)
    end
    Players.PlayerAdded:Connect(bindPlayer)
end

function InventoryServiceV2.ensureStarterLoadout(player: Player)
    dependencies.PersistenceService.updateProfile(player, function(profile)
        profile.equippedWeaponId = ''

        if #profile.unlockedSkills == 0 then
            table.insert(profile.unlockedSkills, 'power_slash')
        end
        if #profile.skillLoadout == 0 then
            table.insert(profile.skillLoadout, 'power_slash')
        end

        local potionEntry = getInventoryEntry(profile, 'minor_healing_potion')
        if not potionEntry then
            table.insert(profile.inventory, {
                itemId = 'minor_healing_potion',
                amount = 3,
            })
        end

        for index = #profile.inventory, 1, -1 do
            local itemId = profile.inventory[index].itemId
            if itemId == 'r6_combat_emblem' or itemId == 'gojo_skin' then
                table.remove(profile.inventory, index)
            end
        end

        local styleEntry = getInventoryEntry(profile, 'deku_combat_emblem')
        if not styleEntry then
            table.insert(profile.inventory, {
                itemId = 'deku_combat_emblem',
                amount = 1,
            })
        end

        local dekuSkinEntry = getInventoryEntry(profile, 'deku_skin')
        if not dekuSkinEntry then
            table.insert(profile.inventory, {
                itemId = 'deku_skin',
                amount = 1,
            })
        end

    end)
end

function InventoryServiceV2.rebuildPlayerTools(player: Player)
    local profile = dependencies.PersistenceService.getProfile(player)
    if not profile then
        return
    end

    local backpack = player:FindFirstChildOfClass('Backpack') or player:WaitForChild('Backpack', 5)
    if not backpack then
        return
    end

    destroyTools(backpack)
    if player.Character then
        destroyTools(player.Character)
    end

    for _, skillId in ipairs(profile.skillLoadout) do
        local skillDef = SkillData[skillId]
        if skillDef then
            local skillTool = ToolFactory.createSkillTool(skillId, skillDef, function()
                dependencies.SkillService.useSkill(player, skillId)
            end)
            skillTool.Parent = backpack
        end
    end

    for _, entry in ipairs(profile.inventory) do
        local itemDef = ItemData[entry.itemId]
        if itemDef and entry.amount > 0 then
            if itemDef.toolKind == 'consumable' then
                local consumableTool = ToolFactory.createConsumableTool(entry.itemId, itemDef, entry.amount, function()
                    InventoryServiceV2.consumeItem(player, entry.itemId, 1)
                end)
                consumableTool.Parent = backpack
            elseif itemDef.toolKind == 'skin' then
                local skinTool = ToolFactory.createSkinTool(entry.itemId, itemDef, function()
                    dependencies.CharacterSkinService.applySkin(player, itemDef.skinTemplateId)
                end)
                skinTool.Parent = backpack
            else
                local itemTool = ToolFactory.createInventoryItemTool(entry.itemId, itemDef, entry.amount)
                itemTool.Parent = backpack
            end
        end
    end
end

function InventoryServiceV2.consumeItem(player: Player, itemId: string, amount: number)
    local itemDef = ItemData[itemId]
    if not itemDef then
        return false
    end

    local consumed = false
    dependencies.PersistenceService.updateProfile(player, function(profile)
        local entry = getInventoryEntry(profile, itemId)
        if not entry or entry.amount < amount then
            return
        end
        entry.amount -= amount
        consumed = true
    end)

    if not consumed then
        return false
    end

    if itemDef.healAmount then
        dependencies.CharacterService.healPlayer(player, itemDef.healAmount)
    end

    InventoryServiceV2.rebuildPlayerTools(player)
    dependencies.Runtime.SystemMessage:FireClient(player, string.format('Used %s.', itemDef.displayName))
    return true
end

function InventoryServiceV2.addItem(player: Player, itemId: string, amount: number)
    dependencies.PersistenceService.updateProfile(player, function(profile)
        local entry = getInventoryEntry(profile, itemId)
        if entry then
            entry.amount += amount
        else
            table.insert(profile.inventory, {
                itemId = itemId,
                amount = amount,
            })
        end
    end)

    InventoryServiceV2.rebuildPlayerTools(player)
end

return InventoryServiceV2
