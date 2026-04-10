--!strict

local TableUtil = {}

function TableUtil.deepCopy<T>(value: T): T
    if type(value) ~= 'table' then
        return value
    end

    local copy = {}
    for key, child in value do
        (copy :: any)[key] = TableUtil.deepCopy(child)
    end

    return copy :: any
end

return TableUtil

