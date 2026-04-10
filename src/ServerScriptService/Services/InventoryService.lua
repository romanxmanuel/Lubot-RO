--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local CardDefs = require(ReplicatedStorage.Shared.DataDefs.Cards.CardDefs)
local EquipmentDefs = require(ReplicatedStorage.Shared.DataDefs.Items.EquipmentDefs)
local ItemDefs = require(ReplicatedStorage.Shared.DataDefs.Items.ItemDefs)
local TableUtil = require(ReplicatedStorage.Shared.Util.TableUtil)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryService = {}
local grantedItemCounter = 0

local function getProfile(player)
    return PlayerDataService.getOrCreateProfile(player)
end

local function assertPositiveAmount(amount: number)
    assert(amount > 0, 'Amount must be positive')
end

local function nextSortOrder(profile)
    profile.inventorySortCounter = math.max(math.floor(tonumber(profile.inventorySortCounter) or 0), 0) + 1
    return profile.inventorySortCounter
end

local function markInventoryObtained(profile, itemId: string)
    profile.inventoryOrder = profile.inventoryOrder or {}
    if profile.inventoryOrder[itemId] == nil then
        profile.inventoryOrder[itemId] = nextSortOrder(profile)
    end
end

local function clearInventoryObtained(profile, itemId: string)
    profile.inventoryOrder = profile.inventoryOrder or {}
    profile.inventoryOrder[itemId] = nil
end

local function markCardObtained(profile, cardId: string)
    profile.cardOrder = profile.cardOrder or {}
    if profile.cardOrder[cardId] == nil then
        profile.cardOrder[cardId] = nextSortOrder(profile)
    end
end

local function clearCardObtained(profile, cardId: string)
    profile.cardOrder = profile.cardOrder or {}
    profile.cardOrder[cardId] = nil
end

local function nextGrantedInstanceId(player, itemId: string)
    grantedItemCounter += 1
    return string.format('%d_%s_%d_%d', player.UserId, itemId, os.time(), grantedItemCounter)
end

local function createEquipmentInstance(player, itemId: string, dropData)
    local itemDef = ItemDefs[itemId]
    local equipmentDef = EquipmentDefs[itemId]
    local instanceId = nextGrantedInstanceId(player, itemId)
    return {
        instanceId = instanceId,
        itemId = itemId,
        itemType = itemDef.itemType,
        slot = itemDef.slot,
        enhancementTrack = equipmentDef and equipmentDef.enhancementTrack or nil,
        enhancementLevel = dropData and dropData.enhancementLevel or 0,
        rarity = (dropData and dropData.rarity) or itemDef.rarity,
        affixes = TableUtil.deepCopy((dropData and dropData.affixes) or {}),
        socketedCards = TableUtil.deepCopy((dropData and dropData.socketedCards) or {}),
        sourceMonsterId = dropData and dropData.sourceMonsterId or nil,
        sourceHint = dropData and dropData.sourceHint or nil,
        destroyed = false,
        obtainedAt = os.time(),
    }
end

function InventoryService.init() end
function InventoryService.start() end

function InventoryService.grantItem(player, itemId: string, amount: number)
    assertPositiveAmount(amount)
    local itemDef = ItemDefs[itemId]
    assert(itemDef, ('Unknown itemId: %s'):format(itemId))
    local ok, reason = InventoryService.grantResolvedDrop(player, {
        kind = 'item',
        id = itemId,
        quantity = amount,
        rarity = itemDef.rarity,
    })
    assert(ok, tostring(reason))
end

function InventoryService.grantResolvedDrop(player, drop)
    if type(drop) ~= 'table' then
        return false, 'InvalidDrop'
    end

    local profile = getProfile(player)
    local kind = drop.kind or 'item'
    local quantity = math.max(math.floor(tonumber(drop.quantity) or 1), 1)

    if kind == 'card' then
        local cardDef = CardDefs[drop.id]
        if not cardDef then
            return false, 'UnknownCard'
        end

        if (profile.cards[drop.id] or 0) <= 0 then
            markCardObtained(profile, drop.id)
        end
        profile.cards[drop.id] = (profile.cards[drop.id] or 0) + quantity
        return true, nil
    end

    local itemDef = ItemDefs[drop.id]
    if not itemDef then
        return false, 'UnknownItem'
    end

    if itemDef.itemType == 'Equipment' then
        for _ = 1, quantity do
            local instance = createEquipmentInstance(player, drop.id, drop)
            profile.itemInstances[instance.instanceId] = instance
        end
        return true, nil
    end

    if (profile.inventory[drop.id] or 0) <= 0 then
        markInventoryObtained(profile, drop.id)
    end
    profile.inventory[drop.id] = (profile.inventory[drop.id] or 0) + quantity
    return true, nil
end

function InventoryService.equipItem(player, itemId: string, slotName: string)
    local profile = getProfile(player)

    for instanceId, itemInstance in pairs(profile.itemInstances) do
        if not itemInstance.destroyed and itemInstance.itemId == itemId and itemInstance.slot == slotName then
            profile.equipment[slotName] = instanceId
            return true
        end
    end

    return false
end

function InventoryService.unequipItemInstance(player, itemInstanceId: string): (boolean, string?)
    local profile = getProfile(player)
    local itemInstance = profile.itemInstances[itemInstanceId]
    if not itemInstance or itemInstance.destroyed then
        return false, 'UnknownEquipment'
    end

    local slotName = itemInstance.slot
    if type(slotName) ~= 'string' or slotName == '' then
        return false, 'NotEquipment'
    end

    if profile.equipment[slotName] ~= itemInstanceId then
        return false, 'NotEquipped'
    end

    profile.equipment[slotName] = nil
    return true, nil
end

function InventoryService.getEnhanceableItem(player, itemInstanceId: string)
    local profile = getProfile(player)
    return profile.itemInstances[itemInstanceId]
end

function InventoryService.socketCardIntoEquipment(player, itemInstanceId: string, cardId: string): (boolean, string?)
    local profile = getProfile(player)
    local itemInstance = profile.itemInstances[itemInstanceId]
    if not itemInstance or itemInstance.destroyed then
        return false, 'UnknownEquipment'
    end

    local cardDef = CardDefs[cardId]
    if not cardDef then
        return false, 'UnknownCard'
    end

    if (profile.cards[cardId] or 0) <= 0 then
        return false, 'CardNotOwned'
    end

    local itemDef = ItemDefs[itemInstance.itemId]
    local equipmentDef = EquipmentDefs[itemInstance.itemId]
    if not itemDef or itemDef.itemType ~= 'Equipment' or not equipmentDef then
        return false, 'NotEquipment'
    end

    local availableSlots = equipmentDef.cardSlots or 0
    if availableSlots <= 0 then
        return false, 'NoCardSlots'
    end

    itemInstance.socketedCards = itemInstance.socketedCards or {}
    if #itemInstance.socketedCards >= availableSlots then
        return false, 'CardSlotsFull'
    end

    local supportedSlots = cardDef.supportedSlots
    if type(supportedSlots) == 'table' and next(supportedSlots) ~= nil and not supportedSlots[itemInstance.slot or ''] then
        return false, 'UnsupportedEquipmentSlot'
    end

    profile.cards[cardId] = (profile.cards[cardId] or 0) - 1
    if (profile.cards[cardId] or 0) <= 0 then
        profile.cards[cardId] = nil
        clearCardObtained(profile, cardId)
    end

    table.insert(itemInstance.socketedCards, cardId)
    return true, nil
end

function InventoryService.getOwnedMaterials(player)
    local profile = getProfile(player)
    local materials = {}

    for itemId, amount in pairs(profile.inventory) do
        local itemDef = ItemDefs[itemId]
        if itemDef and itemDef.itemType == 'Material' then
            materials[itemId] = amount
        end
    end

    return materials
end

function InventoryService.getConsumableCount(player, itemId: string): number
    local profile = getProfile(player)
    return profile.inventory[itemId] or 0
end

function InventoryService.equipAmmoItem(player, itemId: string): (boolean, string?)
    local profile = getProfile(player)
    local itemDef = ItemDefs[itemId]
    if not itemDef then
        return false, 'UnknownItem'
    end
    if itemDef.itemType ~= 'Consumable' then
        return false, 'NotConsumable'
    end

    local hasAmmoTag = false
    for _, tag in ipairs(itemDef.tags or {}) do
        if tag == 'ammo' then
            hasAmmoTag = true
            break
        end
    end
    if not hasAmmoTag then
        return false, 'NotAmmo'
    end
    if (profile.inventory[itemId] or 0) <= 0 then
        return false, 'AmmoNotOwned'
    end

    profile.settings = profile.settings or {}
    profile.settings.equippedAmmoItemId = itemId
    return true, nil
end

function InventoryService.getEquippedAmmoItemId(player): string?
    local profile = getProfile(player)
    local settings = profile.settings or {}
    local itemId = tostring(settings.equippedAmmoItemId or '')
    if itemId == '' then
        return nil
    end
    return itemId
end

function InventoryService.consumeEquippedAmmo(player, amount: number): (boolean, string?)
    local profile = getProfile(player)
    local itemId = InventoryService.getEquippedAmmoItemId(player)
    if not itemId then
        return false, 'OutOfArrows'
    end

    local current = tonumber(profile.inventory[itemId]) or 0
    if current < amount then
        profile.settings.equippedAmmoItemId = ''
        return false, 'OutOfArrows'
    end

    InventoryService.consumeConsumable(player, itemId, amount)
    if (tonumber(profile.inventory[itemId]) or 0) <= 0 then
        profile.settings.equippedAmmoItemId = ''
    end
    return true, nil
end

function InventoryService.getZeny(player): number
    local profile = getProfile(player)
    return profile.zeny
end

function InventoryService.consumeMaterials(player, materials)
    local profile = getProfile(player)

    for itemId, amount in pairs(materials) do
        local current = profile.inventory[itemId] or 0
        assert(current >= amount, ('Not enough material: %s'):format(itemId))
        local newAmount = current - amount
        if newAmount <= 0 then
            profile.inventory[itemId] = nil
            clearInventoryObtained(profile, itemId)
        else
            profile.inventory[itemId] = newAmount
        end
    end
end

function InventoryService.consumeConsumable(player, itemId: string, amount: number)
    local profile = getProfile(player)
    local current = profile.inventory[itemId] or 0
    assert(current >= amount, ('Not enough consumables: %s'):format(itemId))
    local newAmount = current - amount
    if newAmount <= 0 then
        profile.inventory[itemId] = nil
        clearInventoryObtained(profile, itemId)
    else
        profile.inventory[itemId] = newAmount
    end
end

function InventoryService.spendZeny(player, amount: number)
    local profile = getProfile(player)
    assert(profile.zeny >= amount, 'Not enough zeny')
    profile.zeny -= amount
end

function InventoryService.addZeny(player, amount: number)
    local profile = getProfile(player)
    profile.zeny += math.max(math.floor(amount), 0)
end

function InventoryService.getInventoryAmount(player, itemId: string): number
    local profile = getProfile(player)
    return profile.inventory[itemId] or 0
end

function InventoryService.removeInventoryAmount(player, itemId: string, amount: number): boolean
    local profile = getProfile(player)
    local current = profile.inventory[itemId] or 0
    local delta = math.max(math.floor(amount), 0)
    if delta <= 0 or current < delta then
        return false
    end

    local newAmount = current - delta
    if newAmount <= 0 then
        profile.inventory[itemId] = nil
        clearInventoryObtained(profile, itemId)
    else
        profile.inventory[itemId] = newAmount
    end

    return true
end

function InventoryService.setEnhancementLevel(player, itemInstanceId: string, newLevel: number)
    local itemInstance = InventoryService.getEnhanceableItem(player, itemInstanceId)
    assert(itemInstance, 'Unknown enhanceable item')
    itemInstance.enhancementLevel = newLevel
end

function InventoryService.destroyEnhanceableItem(player, itemInstanceId: string)
    local profile = getProfile(player)
    local itemInstance = profile.itemInstances[itemInstanceId]
    if not itemInstance then
        return
    end

    itemInstance.destroyed = true

    if itemInstance.slot and profile.equipment[itemInstance.slot] == itemInstanceId then
        profile.equipment[itemInstance.slot] = nil
    end
end

function InventoryService.getEquippedInstanceId(player, slotName: string)
    local profile = getProfile(player)
    return profile.equipment[slotName]
end

function InventoryService.getAllItemInstances(player)
    local profile = getProfile(player)
    return profile.itemInstances
end

function InventoryService.getCurrentWeight(player): number
    local profile = getProfile(player)
    local totalWeight = 0

    for itemId, amount in pairs(profile.inventory) do
        local itemDef = ItemDefs[itemId]
        if itemDef and itemDef.weight then
            totalWeight += itemDef.weight * amount
        end
    end

    for _, itemInstance in pairs(profile.itemInstances) do
        if not itemInstance.destroyed then
            local itemDef = ItemDefs[itemInstance.itemId]
            if itemDef and itemDef.weight then
                totalWeight += itemDef.weight
            end
        end
    end

    return totalWeight
end

return InventoryService
