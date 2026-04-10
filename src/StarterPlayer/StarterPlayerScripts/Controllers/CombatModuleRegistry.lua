--!strict

local CombatModuleRegistry = {}

CombatModuleRegistry.DEFAULT_MODULE = 'DefaultMMOCombat'
CombatModuleRegistry.IMPORTED_TOOL_MODULE = 'ImportedToolPassthrough'

CombatModuleRegistry.ItemToModule = {
    imported_chaos_edge = CombatModuleRegistry.IMPORTED_TOOL_MODULE,
    ['10288487412'] = CombatModuleRegistry.IMPORTED_TOOL_MODULE,
}

local function readItemId(tool: Tool): string?
    local itemId = tool:GetAttribute('ItemId')
    if itemId ~= nil then
        return tostring(itemId)
    end

    local inventoryItemId = tool:GetAttribute('InventoryItemId')
    if inventoryItemId ~= nil then
        return tostring(inventoryItemId)
    end

    return nil
end

function CombatModuleRegistry.resolveModuleName(tool: Tool?): string
    if not tool then
        return CombatModuleRegistry.DEFAULT_MODULE
    end

    local importedAssetId = tool:GetAttribute('ImportedAssetId')
    if importedAssetId ~= nil then
        local importedKey = tostring(importedAssetId)
        return CombatModuleRegistry.ItemToModule[importedKey] or CombatModuleRegistry.IMPORTED_TOOL_MODULE
    end

    local itemId = readItemId(tool)
    if itemId then
        return CombatModuleRegistry.ItemToModule[itemId] or CombatModuleRegistry.DEFAULT_MODULE
    end

    return CombatModuleRegistry.DEFAULT_MODULE
end

return CombatModuleRegistry
