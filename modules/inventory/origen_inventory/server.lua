---@diagnostic disable: duplicate-set-field
if GetResourceState('origen_inventory') == 'missing' then return end
if GetResourceState('ox_inventory') ~= 'missing' then return end

Inventory = Inventory or {}
Inventory.Stashes = Inventory.Stashes or {}

local origin = exports.origen_inventory
local items = lib.require('@concept_bridge.lib.inventory.shared.provider_items')

local function inventoryId(id, kind)
    if kind == 'trunk' or kind == 'glovebox' then return kind .. '_' .. id end
    return id -- Stashes retain the exact ID passed to registerStash.
end

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "origen_inventory"
end

---@description This will add an item, and return true or false based on success
---@param src number
---@param item string
---@param count number
---@param slot number (optional)
---@param metadata table (optional)
---@return boolean
Inventory.AddItem = function(src, item, count, slot, metadata)
    local canCarry = Inventory.CanCarryItem(src, item, count)
    if not canCarry then return false end
    local success = origin:addItem(src, item, count, slot, metadata)
    if not success then return false end
    TriggerClientEvent("concept_bridge:client:inventory:updateInventory", src, {action = "add", item = item, count = count, slot = slot, metadata = metadata})
    return success or false
end

---@description This will remove an item, and return true or false based on success
---@param src number
---@param item string
---@param count number
---@param slot number (optional)
---@param metadata table (optional)
---@return boolean
Inventory.RemoveItem = function(src, item, count, slot, metadata)
    if slot ~= nil or metadata ~= nil then
        local selected
        if slot ~= nil then
            selected = Inventory.GetItemBySlot(src, slot)
        else
            -- removeItem has no metadata parameter. Target one matching stack.
            for _, row in pairs(Inventory.GetPlayerInventory(src)) do
                if row.name == item and items.Matches(row.metadata, metadata) and row.count >= count then
                    selected = row
                    break
                end
            end
        end
        if not selected or selected.name ~= item or selected.count < count or
            not items.Matches(selected.metadata, metadata) then return false, 'item_not_found' end
        slot = selected.slot
    end
    local success = origin:removeItem(src, item, count, slot)
    if not success then return false end
    TriggerClientEvent("concept_bridge:client:inventory:updateInventory", src, {action = "remove", item = item, count = count, slot = slot, metadata = metadata})
    return success or false
end

---@description This will add items to a trunk, and return true or false based on success
---@param identifier string
---@param items table
---@return boolean
Inventory.AddTrunkItems = function(identifier, items)
    -- The docs establish player addItems, not trunk creation or bulk metadata.
    return false, 'unsupported_trunk_items'
end

---@description This will clear the specified inventory, will always return true unless a value isnt passed correctly.
---@param id string
---@param _type string unused with ox_inventory
---@return boolean
Inventory.ClearStash = function(id, _type)
    if type(id) ~= "string" then return false end
    return origin:clearInventory(inventoryId(id, _type))
end

---@description This will return a table with the item info, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    return items.Info(Inventory.Items()[item], item, Inventory.GetImagePath)
end

---@description This will return the entire items table from the inventory.
---@return table 
Inventory.Items = function()
    -- Also referenced in Origen's own origen_reports/custom integration docs.
    return origin:Items() or {}
end

---@description This will return the count of the item in the players inventory, if not found will return 0.
---@param src number
---@param item string
---@param metadata table (optional)
---@return number
Inventory.GetItemCount = function(src, item, metadata)
    if metadata ~= nil then
        return items.Count(Inventory.GetPlayerInventory(src), item, metadata)
    end
    return origin:getItemCount(src, item) or 0
end

---@description This will return the players inventory.
---@param src number
---@return table
Inventory.GetPlayerInventory = function(src)
    return items.List(origin:getItems(src))
end

---@description Returns the specified slot data as a table.
---@param src number
---@param slot number
---@return table {weight, name, metadata, slot, label, count}
Inventory.GetItemBySlot = function(src, slot)
    local numeric = tonumber(slot)
    if not numeric or numeric < 1 or numeric % 1 ~= 0 then return {} end
    return items.Row(origin:getSlot(src, numeric), numeric) or {}
end

---@description This will set the metadata of an item in the inventory.
---@param src number
---@param item string
---@param slot number
---@param metadata table
---@return nil
Inventory.SetMetadata = function(src, item, slot, metadata)
    local selected = Inventory.GetItemBySlot(src, slot)
    if selected.name ~= item then return false, 'item_not_found' end
    return origin:setMetadata(src, selected.slot, metadata)
end

---@description This will open the specified stash for the src passed.
---@param src number
---@param _type string "stash", "trunk", "glovebox"
---@param id string
---@return nil
Inventory.OpenStash = function(src, _type, id)
    _type = _type or "stash"
    return origin:OpenInventory(src, inventoryId(id, _type))
end

---@description This will register a stash
---@param id number|string
---@param label string
---@param slots number
---@param weight number
---@param owner string (optional)
---@param groups table (optional)
---@param coords table (optional)
---@return boolean
---@return string|number
Inventory.RegisterStash = function(id, label, slots, weight, owner, groups, coords)
    -- These access restrictions have no documented registerStash data fields.
    if owner or groups or coords then return false, 'unsupported_stash_restrictions' end
    if Inventory.Stashes[id] then return true, id end
    origin:registerStash(id, {label = label or id, slots = slots, maxweight = weight})
    Inventory.Stashes[id] = {id = id, label = label or id, slots = slots, weight = weight, owner = owner, groups = groups, coords = coords}
    return true, id
end

---@description This will return a boolean if the player has the item.
---@param src number
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(src, item, requiredCount)
    return Inventory.GetItemCount(src, item) >= (requiredCount or 1)
end

---@description This is to get if there is available space in the inventory, will return boolean.
---@param src number
---@param item string
---@param count number
---@return boolean
Inventory.CanCarryItem = function(src, item, count)
    return origin:canCarryItem(src, item, count)
end

---@description This will update the plate to the vehicle inside the inventory. (It will also update with jg-mechanic if using it)
---@param oldplate string
---@param newplate string
---@return boolean
Inventory.UpdatePlate = function(oldplate, newplate)
    local queries = {
        'UPDATE gloveboxitems SET plate = @newplate WHERE plate = @oldplate',
        'UPDATE trunkitems SET plate = @newplate WHERE plate = @oldplate',
    }
    local values = { newplate = newplate, oldplate = oldplate }
    MySQL.transaction.await(queries, values)
    if GetResourceState('jg-mechanic') == 'missing' then return true end
    return true, exports["jg-mechanic"]:vehiclePlateUpdated(oldplate, newplate)
end

---@description This will get the image path for an item, it is an alternate option to GetItemInfo. If a image isnt found will revert to concept_bridge logo (useful for menus)
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("origen_inventory", string.format("html/images/%s.png", item))
    local imagePath = file and string.format("nui://origen_inventory/html/images/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will open a players inventory, used for admin purposes and stuff.
---@param src number
---@param target number
Inventory.OpenPlayerInventory = function(src, target)
    assert(src, "OpenPlayerInventory: src is required")
    assert(target, "OpenPlayerInventory: target is required")
    return origin:OpenInventoryById(src, target)
end

return Inventory
