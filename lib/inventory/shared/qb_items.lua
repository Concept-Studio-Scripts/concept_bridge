-- QB-shaped definitions for QB/PS inventories on either QBCore or Qbox.
-- Resolve on demand: Qbox's compatibility bridge may be disabled or restarted.
local Items = {}

function Items.List()
    local shared
    if GetResourceState('qbx_core') == 'started' then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and type(core) == 'table' then shared = core.Shared end
    else
        shared = Framework and Framework.Shared
    end
    if type(shared) ~= 'table' or type(shared.Items) ~= 'table' then
        return nil, 'item_registry_unavailable'
    end
    return shared.Items
end

function Items.Get(name)
    local definitions, reason = Items.List()
    if not definitions then return nil, reason end
    if type(name) ~= 'string' or type(definitions[name]) ~= 'table' then
        return nil, 'unknown_item'
    end
    return definitions[name]
end

function Items.Info(name, imagePath)
    local item = Items.Get(name)
    if not item then return {} end
    return {
        name = item.name or name,
        label = item.label or item.name or name,
        stack = not item.unique,
        weight = item.weight or 0,
        description = item.description or '',
        image = imagePath(item.image or item.name or name),
    }
end

return Items
