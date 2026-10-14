---@diagnostic disable: duplicate-set-field
if GetResourceState('core_inventory') ~= 'started' then return end

Inventory = Inventory or {}
Inventory.Stashes = Inventory.Stashes or {}
local core = exports.core_inventory
local items = lib.require('@concept_bridge.lib.inventory.shared.provider_items')

local function content(src)
    local inventory = core:getInventory(src)
    return type(inventory) == 'table' and inventory.content or nil
end

local function resolveSlot(src, slot)
    if slot == nil then return nil end
    local rows = content(src)
    if type(rows) ~= 'table' then return nil end
    local numeric = tonumber(slot)
    if numeric then
        if numeric < 1 or numeric % 1 ~= 0 then return nil end
        local item = core:getItemBySlot(src, numeric)
        if type(item) ~= 'table' or not item.name then return nil end
        -- Exact removal requires the content key, never a grid slot index.
        for id, row in pairs(rows) do
            if type(row) == 'table' and row.name == item.name and
                (tonumber(row.slot) == numeric or (item.id ~= nil and id == item.id)) then
                return items.Row(row, numeric, id)
            end
        end
        -- Numeric metadata/read calls remain possible without a documented ID map.
        return items.Row(item, numeric)
    end
    return items.Row(rows[slot], slot, slot)
end

---This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "core_inventory"
end

---This will return a table with the item info, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    return items.Info(Inventory.Items()[item], item, Inventory.GetImagePath)
end

---This will add an item, and return true or false based on success
---@param src number
---@param item string
---@param count number
---@param slot number
---@param metadata table
---@return boolean
Inventory.AddItem = function(src, item, count, slot, metadata)
    -- https://docs.c8re.store/core-inventory/exports#server-exports-%E2%80%94-items
    local success = core:addItem(src, item, count, metadata)
    if not success then return false end
    TriggerClientEvent("concept_bridge:client:inventory:updateInventory", src, {action = "add", item = item, count = count, slot = slot, metadata = metadata})
    return success or false
end

---This will remove an item, and return true or false based on success
---@param src number
---@param item string
---@param count number
---@param slot number
---@param metadata table
---@return boolean
Inventory.RemoveItem = function(src, item, count, slot, metadata)
    local selected
    if slot ~= nil then
        selected = resolveSlot(src, slot)
    end
    if not slot and metadata then
        for _, row in pairs(Inventory.GetPlayerInventory(src)) do
            if row.name == item and items.Matches(row.metadata, metadata) and row.count >= count then
                selected = row
                break
            end
        end
    end
    local success
    if slot ~= nil or metadata ~= nil then
        if not selected or selected.name ~= item or selected.count < count or not items.Matches(selected.metadata, metadata) then
            return false, 'item_not_found'
        end
        if type(selected.id) ~= 'string' then return false, 'item_id_unavailable' end
        success = core:removeItemExact(src, selected.id, count)
        slot = selected.slot
    else
        success = core:removeItem(src, item, count)
    end
    if not success then return false end
    TriggerClientEvent("concept_bridge:client:inventory:updateInventory", src, {action = "remove", item = item, count = count, slot = slot, metadata = metadata})
    return success
end

---This will return the count of the item in the players inventory, if not found will return 0.
---if metadata is passed it will find the matching items count.
---@param src number
---@param item string
---@param metadata table
---@return number
Inventory.GetItemCount = function(src, item, metadata)
    if metadata then
        return items.Count(Inventory.GetPlayerInventory(src), item, metadata)
    end
    local count = core:getItemCount(src, item)
    return count or 0
end

---This wil return the players inventory.
---@param src number
---@return table
Inventory.GetPlayerInventory = function(src)
    return items.List(content(src), true)
end

---Returns the specified slot data as a table.
---format {weight, name, metadata, slot, label, count}
---@param src number
---@param slot number
---@return table
Inventory.GetItemBySlot = function(src, slot)
    return resolveSlot(src, slot) or {}
end

---This will set the metadata of an item in the inventory.
---@param src number
---@param item string
---@param slot number
---@param metadata table
---@return nil
Inventory.SetMetadata = function(src, item, slot, metadata)
    local selected = resolveSlot(src, slot)
    if not selected or selected.name ~= item then return false, 'item_not_found' end
    local numeric = tonumber(selected.slot)
    if not numeric or numeric < 1 or numeric % 1 ~= 0 then return false, 'slot_unavailable' end
    -- The documented setter returns void. Preserve that result; do not invent success.
    return core:setMetadata(src, numeric, metadata)
end

---This will open the specified stash for the src passed.
---@param src number
---@param _type string
---@param id number||string
---@return nil
Inventory.OpenStash = function(src, _type, id)
    _type = _type or "stash"
    local stash = Inventory.Stashes[id] or {}
    return core:openInventory(src, id, _type, stash.label, nil, true)
end

---This will register a stash
---@param id number|string
---@param label string
---@param slots number
---@param weight number
---@param owner string
---@param groups table
---@param coords table
---@return boolean
---@return string|number
Inventory.RegisterStash = function(id, label, slots, weight, owner, groups, coords)
    if owner or groups or coords then return false, 'unsupported_stash_restrictions' end
    if Inventory.Stashes[id] then return true, id end
    if not slots then slots = 30 end
    Inventory.Stashes[id] = {
        id = id,
        label = label,
        slots = slots,
        weight = weight,
        owner = owner,
        groups = groups,
        coords = coords
    }
    return true, id
end

---@description This will return a boolean if the player has the item.
---@param src number
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(src, item, requiredCount)
    local count = Inventory.GetItemCount(src, item, nil)
    return count >= (requiredCount or 1)
end

---This is to get if there is available space in the inventory, will return boolean.
---@param src number
---@param item string
---@param count number
---@return boolean
Inventory.CanCarryItem = function(src, item, count)
    return core:canCarry(src, item, count)
end

---This will add items to a trunk, and return true or false based on success
---If a trunk with the identifier does not exist, it will create one with default values.
---@param identifier string
---@param items table
---@return boolean
Inventory.AddTrunkItems = function(identifier, items)
    if type(items) ~= "table" then return false end
    return false, print("AddItemsToTrunk is not implemented in core_inventory, because of this we dont have a way to add items to a trunk.")
end

---This will update the plate to the vehicle inside the inventory. (It will also update with jg-mechanic if using it)
---@param oldplate string
---@param newplate string
---@return boolean
Inventory.UpdatePlate = function(oldplate, newplate)
    -- have no clue if this will work but fingers crossed
    local queries = {
        'UPDATE coreinventories SET name = @newplate WHERE name = @oldplate',
        'UPDATE coreinventories SET name = @newplate WHERE name = @glovebox_oldplate',
        'UPDATE coreinventories SET name = @newplate WHERE name = @trunk_oldplate',
    }
    local values = {
        newplate = newplate,
        oldplate = oldplate,
        glovebox_oldplate = 'glovebox-' .. oldplate,
        trunk_oldplate = 'trunk-' .. oldplate
    }
    MySQL.transaction.await(queries, values)
    if GetResourceState('jg-mechanic') == 'missing' then return true end
    return true, exports["jg-mechanic"]:vehiclePlateUpdated(oldplate, newplate)
end

---This will get the image path for an item, it is an alternate option to GetItemInfo. If a image isnt found will revert to concept_bridge logo (useful for menus)
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("core_inventory", string.format("html/img/%s.png", item))
    local imagePath = file and string.format("nui://core_inventory/html/img/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---This will return the entire items table from the inventory.
---@return table 
Inventory.Items = function()
    return core:getItemsList() or {}
end

Inventory.OpenPlayerInventory = function(src, target)
    assert(src, "OpenPlayerInventory: src is required")
    assert(target, "OpenPlayerInventory: target is required")
    return core:openOtherPlayerInventory(src, target)
end

return Inventory
