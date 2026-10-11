-- Update the selected slot without removing/re-adding any inventory contents.
local Metadata = {}



local function find(items, slot, name)
    if type(items) ~= 'table' then return end
    for key, entry in pairs(items) do
        if type(entry) == 'table' and tonumber(entry.slot or key) == slot and entry.name == name then
            return entry, key
        end
    end
end

---@return boolean success
---@return string? reason Failure leaves the item available for retry; no destructive fallback.
function Metadata.Set(src, name, slot, metadata)
    slot = tonumber(slot)
    if type(name) ~= 'string' or not slot or slot < 1 or slot % 1 ~= 0 or type(metadata) ~= 'table' then
        return false, 'invalid_metadata_request'
    end
    local player = Framework.GetPlayer(src)
    if not player then return false, 'player_unavailable' end
    local provider = Inventory and Inventory.GetResourceName and Inventory.GetResourceName()

    if provider == 'ox_inventory' then
        local ox = exports.ox_inventory
        local readOk, before = pcall(function() return ox:GetSlot(src, slot) end)
        if not readOk then return false, 'provider_error' end
        if not before or before.name ~= name then return false, 'item_not_found' end
        local count = before.count
        local ok = pcall(function() ox:SetMetadata(src, slot, lib.table.deepclone(metadata)) end)
        local afterOk, after = pcall(function() return ox:GetSlot(src, slot) end)
        if afterOk and after and after.name == name and after.count == count and lib.table.matches(after.metadata, metadata) then
            return true
        end
        if not ok or not afterOk then return false, 'provider_error' end
        return false, 'update_not_applied'
    end

    local before, key = find(player.PlayerData and player.PlayerData.items, slot, name)
    if not before then return false, 'item_not_found' end
    local updated = lib.table.deepclone(player.PlayerData.items)
    updated[key].info = lib.table.deepclone(metadata)
    -- Keep alternate-field providers and existing dual-field records consistent.
    if before.metadata ~= nil then updated[key].metadata = lib.table.deepclone(metadata) end
    local count = before.amount or before.count
    local ok, result
    if provider == 'qb-inventory' or provider == 'ps-inventory' then
        ok, result = pcall(function()
            return exports[provider]:SetInventory(src, updated, 'concept_bridge: metadata update')
        end)
    else
        local setter = player.Functions and player.Functions.SetInventory
        if not setter then return false, 'unsupported_metadata_update' end
        ok, result = pcall(setter, updated)
    end

    -- SetInventory commonly returns nil. Verify the authoritative player data
    -- instead of reporting success merely because the export did not throw.
    player = Framework.GetPlayer(src)
    local after = player and find(player.PlayerData and player.PlayerData.items, slot, name)
    if after and (after.amount or after.count) == count and lib.table.matches(after.info or after.metadata, metadata) then
        if not ok then
            print(('[concept_bridge] %s raised after applying metadata for player %s slot %s; update verified.'):format(provider or 'inventory', src, slot))
        end
        TriggerClientEvent('concept_bridge:client:inventory:updateInventory', src,
            { action = 'metadata', item = name, slot = slot, metadata = lib.table.deepclone(metadata) })
        return true
    end
    if not ok then return false, 'provider_error' end
    if result == false then return false, 'update_rejected' end
    return false, 'update_not_applied'
end

return Metadata
