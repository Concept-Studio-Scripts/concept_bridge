-- Only normalizes item rows; provider export names and envelopes stay in adapters.
local Items = {}

function Items.Stack(item)
    if type(item.stack) == 'boolean' then return item.stack end
    if type(item.stack) == 'number' then return item.stack == -1 or item.stack > 1 end
    if type(item.unique) == 'boolean' then return not item.unique end
    return false
end

function Items.Info(item, name, image)
    if type(item) ~= 'table' or next(item) == nil then return {} end
    return {
        name = item.name or name,
        label = item.label or item.name or name,
        stack = Items.Stack(item),
        weight = tonumber(item.weight) or 0,
        description = item.description or '',
        image = image(item.image or item.name or name),
    }
end

function Items.Row(item, slot, id)
    if type(item) ~= 'table' or type(item.name) ~= 'string' then return nil end
    local close = item.close
    if close == nil then close = item.shouldClose end
    if close == nil then close = item.useable end
    return {
        name = item.name, label = item.label or item.name,
        count = tonumber(item.amount or item.count) or 0,
        metadata = item.info or item.metadata or {},
        slot = tonumber(item.slot) or slot, id = id,
        weight = tonumber(item.weight) or 0, description = item.description or '',
        stack = Items.Stack(item), close = close,
    }
end

function Items.List(rows, coreIds)
    local result = {}
    if type(rows) ~= 'table' then return result end
    for key, item in pairs(rows) do
        local id
        if coreIds then
            id = type(key) == 'string' and not tonumber(key) and key or
                (type(item) == 'table' and item.id or nil)
        end
        local row = Items.Row(item, tonumber(key) or key, id)
        if row then result[#result + 1] = row end
    end
    return result
end

-- Bridge metadata queries match the supplied fields, including nested fields.
function Items.Matches(actual, filter)
    if filter == nil then return true end
    if type(filter) ~= 'table' then return actual == filter end
    if type(actual) ~= 'table' then return false end
    for key, value in pairs(filter) do
        if not Items.Matches(actual[key], value) then return false end
    end
    return true
end

function Items.Count(rows, name, metadata)
    local count = 0
    for _, row in pairs(rows) do
        if row.name == name and Items.Matches(row.metadata, metadata) then
            count = count + row.count
        end
    end
    return count
end

return Items
