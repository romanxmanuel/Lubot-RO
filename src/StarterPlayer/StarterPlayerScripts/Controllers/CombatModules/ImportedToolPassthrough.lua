--!strict

local ImportedToolPassthrough = {}

function ImportedToolPassthrough:Attack(_context)
    return true
end

function ImportedToolPassthrough:Block(_context)
    return true
end

function ImportedToolPassthrough:Dash(_context)
    return true
end

function ImportedToolPassthrough:OnEquip(_context)
    return nil
end

function ImportedToolPassthrough:OnUnequip(_context)
    return nil
end

return ImportedToolPassthrough
