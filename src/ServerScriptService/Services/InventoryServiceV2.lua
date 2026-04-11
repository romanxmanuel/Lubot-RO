--!strict

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local ItemData = require(ReplicatedStorage.GameData.Items.ItemData)
local SkillData = require(ReplicatedStorage.GameData.Skills.SkillData)
local MMONet = require(ReplicatedStorage.Shared.Net.MMONet)
local ToolFactory = require(script.Parent.Parent.Systems.Tools.ToolFactory)

local InventoryServiceV2 = {
    Name = 'InventoryService',
}

local dependencies = nil
local STARTER_SKILL_IDS = {
    'power_slash',
    'arc_flare',
    'nova_strike',
    'vortex_spin',
    'comet_drop',
    'razor_orbit',
}

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

local function shouldMaterializeInventoryTool(itemDef): boolean
    local toolKind = itemDef.toolKind
    return toolKind == 'consumable'
        or toolKind == 'skin'
        or toolKind == 'imported_tool'
        or toolKind == 'weapon'
        or toolKind == 'style'
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

    dependencies.Runtime.ActionRequest.OnServerEvent:Connect(function(player, payload)
        if type(payload) ~= 'table' then
            return
        end

        if payload.action == MMONet.Actions.ToggleInventoryToolStash then
            InventoryServiceV2.toggleInventoryToolStash(player)
        elseif payload.action == MMONet.Actions.StashInventoryTools then
            InventoryServiceV2.stashInventoryTools(player)
        end
    end)
end

function InventoryServiceV2.ensureStarterLoadout(player: Player)
    dependencies.PersistenceService.updateProfile(player, function(profile)
        local function ensureSkill(list, skillId: string)
            for _, existing in ipairs(list) do
                if existing == skillId then
                    return
                end
            end
            table.insert(list, skillId)
        end

        profile.equippedWeaponId = ''
        profile.inventoryToolsStashed = false

        if #profile.unlockedSkills == 0 and #profile.skillLoadout == 0 then
            for _, starterSkillId in ipairs(STARTER_SKILL_IDS) do
                table.insert(profile.unlockedSkills, starterSkillId)
                table.insert(profile.skillLoadout, starterSkillId)
            end
        else
            for _, starterSkillId in ipairs(STARTER_SKILL_IDS) do
                ensureSkill(profile.unlockedSkills, starterSkillId)
                ensureSkill(profile.skillLoadout, starterSkillId)
            end
        end

        local potionEntry = getInventoryEntry(profile, 'minor_healing_potion')
        if not potionEntry then
            table.insert(profile.inventory, {
                itemId = 'minor_healing_potion',
                amount = 3,
            })
        elseif potionEntry.amount < 1 then
            potionEntry.amount = 1
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
        elseif styleEntry.amount < 1 then
            styleEntry.amount = 1
        end

        local dekuSkinEntry = getInventoryEntry(profile, 'deku_skin')
        if not dekuSkinEntry then
            table.insert(profile.inventory, {
                itemId = 'deku_skin',
                amount = 1,
            })
        elseif dekuSkinEntry.amount < 1 then
            dekuSkinEntry.amount = 1
        end

        local gojoWhiteSkinEntry = getInventoryEntry(profile, 'gojo_white_skin')
        if not gojoWhiteSkinEntry then
            table.insert(profile.inventory, {
                itemId = 'gojo_white_skin',
                amount = 1,
            })
        elseif gojoWhiteSkinEntry.amount < 1 then
            gojoWhiteSkinEntry.amount = 1
        end

        local luffySkinEntry = getInventoryEntry(profile, 'luffy_skin')
        if not luffySkinEntry then
            table.insert(profile.inventory, {
                itemId = 'luffy_skin',
                amount = 1,
            })
        elseif luffySkinEntry.amount < 1 then
            luffySkinEntry.amount = 1
        end

        local luffyGear5SkinEntry = getInventoryEntry(profile, 'luffy_gear_5_skin')
        if not luffyGear5SkinEntry then
            table.insert(profile.inventory, {
                itemId = 'luffy_gear_5_skin',
                amount = 1,
            })
        elseif luffyGear5SkinEntry.amount < 1 then
            luffyGear5SkinEntry.amount = 1
        end

        local chaosEdgeEntry = getInventoryEntry(profile, 'imported_chaos_edge')
        if not chaosEdgeEntry then
            table.insert(profile.inventory, {
                itemId = 'imported_chaos_edge',
                amount = 1,
            })
        elseif chaosEdgeEntry.amount < 1 then
            chaosEdgeEntry.amount = 1
        end

        local sukunaSkinEntry = getInventoryEntry(profile, 'sukuna_skin')
        if not sukunaSkinEntry then
            table.insert(profile.inventory, {
                itemId = 'sukuna_skin',
                amount = 1,
            })
        elseif sukunaSkinEntry.amount < 1 then
            sukunaSkinEntry.amount = 1
        end

        local dekuOneForAllSkinEntry = getInventoryEntry(profile, 'deku_one_for_all_skin')
        if not dekuOneForAllSkinEntry then
            table.insert(profile.inventory, {
                itemId = 'deku_one_for_all_skin',
                amount = 1,
            })
        elseif dekuOneForAllSkinEntry.amount < 1 then
            dekuOneForAllSkinEntry.amount = 1
        end

        local susanooSasukeSkinEntry = getInventoryEntry(profile, 'susanoo_sasuke_skin')
        if not susanooSasukeSkinEntry then
            table.insert(profile.inventory, {
                itemId = 'susanoo_sasuke_skin',
                amount = 1,
            })
        elseif susanooSasukeSkinEntry.amount < 1 then
            susanooSasukeSkinEntry.amount = 1
        end
    end)
end

function InventoryServiceV2.rebuildPlayerTools(player: Player)
    local profile = dependencies.PersistenceService.getProfile(player)
    if not profile then
        return
    end

    local function ensureSkill(list, skillId: string)
        for _, existing in ipairs(list) do
            if existing == skillId then
                return
            end
        end
        table.insert(list, skillId)
    end

    local backpack = player:FindFirstChildOfClass('Backpack') or player:WaitForChild('Backpack', 5)
    if not backpack then
        return
    end

    if #profile.skillLoadout == 0 then
        for _, starterSkillId in ipairs(STARTER_SKILL_IDS) do
            table.insert(profile.skillLoadout, starterSkillId)
        end
    end

    local normalizedSkillLoadout = {}
    local seenSkillId = {}
    for _, skillId in ipairs(profile.skillLoadout) do
        if SkillData[skillId] and not seenSkillId[skillId] then
            seenSkillId[skillId] = true
            table.insert(normalizedSkillLoadout, skillId)
        end
    end

    for _, starterSkillId in ipairs(STARTER_SKILL_IDS) do
        if SkillData[starterSkillId] and not seenSkillId[starterSkillId] then
            seenSkillId[starterSkillId] = true
            table.insert(normalizedSkillLoadout, starterSkillId)
        end
    end

    profile.skillLoadout = normalizedSkillLoadout

    for _, starterSkillId in ipairs(STARTER_SKILL_IDS) do
        ensureSkill(profile.unlockedSkills, starterSkillId)
    end

    destroyTools(backpack)
    if player.Character then
        destroyTools(player.Character)
    end

    for _, skillId in ipairs(normalizedSkillLoadout) do
        local castSkillId = skillId
        local skillDef = SkillData[castSkillId]
        if skillDef then
            local skillTool = ToolFactory.createSkillTool(castSkillId, skillDef, function()
                dependencies.SkillService.useSkill(player, castSkillId)
            end)
            skillTool.Parent = backpack
        end
    end

    for _, entry in ipairs(profile.inventory) do
        local entryItemId = entry.itemId
        local entryAmount = entry.amount
        local itemDef = ItemData[entryItemId]
        if itemDef and entryAmount > 0 then
            if not shouldMaterializeInventoryTool(itemDef) then
                continue
            end
            if itemDef.toolKind == 'consumable' then
                local consumableItemId = entryItemId
                local consumableTool = ToolFactory.createConsumableTool(consumableItemId, itemDef, entryAmount, function()
                    InventoryServiceV2.consumeItem(player, consumableItemId, 1)
                end)
                consumableTool.Parent = backpack
            elseif itemDef.toolKind == 'skin' then
                local skinTemplateId = itemDef.skinTemplateId
                local skinAssetId = itemDef.skinAssetId
                local skinTool = ToolFactory.createSkinTool(entryItemId, itemDef, function()
                    dependencies.CharacterSkinService.applySkin(player, skinTemplateId, skinAssetId)
                end)
                skinTool.Parent = backpack
            elseif itemDef.toolKind == 'imported_tool' then
                local importedTool = dependencies.ImportedAssetService.createToolClone(entryItemId)
                if importedTool then
                    importedTool.Parent = backpack
                end
            else
                local itemTool = ToolFactory.createInventoryItemTool(entryItemId, itemDef, entryAmount)
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

function InventoryServiceV2.toggleInventoryToolStash(player: Player)
    InventoryServiceV2.stashInventoryTools(player)
end

function InventoryServiceV2.stashInventoryTools(player: Player)
    local changed = false

    dependencies.PersistenceService.updateProfile(player, function(profile)
        if profile.inventoryToolsStashed == true then
            profile.inventoryToolsStashed = false
            changed = true
        end
    end)

    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass('Humanoid')
        if humanoid then
            humanoid:UnequipTools()
        end
    end

    if changed then
        InventoryServiceV2.rebuildPlayerTools(player)
    end

    dependencies.Runtime.SystemMessage:FireClient(
        player,
        'Moved equipped tools into your bag.'
    )
end

return InventoryServiceV2
