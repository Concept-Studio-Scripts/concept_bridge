---@diagnostic disable: duplicate-set-field
if GetResourceState('jpr-inventory') == 'missing' then return end

local jpr = exports['jpr-inventory']
local registeredShops = {}

Inventory = Inventory or {}
Inventory.Stashes = Inventory.Stashes or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "jpr-inventory"
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
    local success = exports['jpr-inventory']:AddItem(src, item, count, slot, metadata, 'concept_bridge Item added')
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
    local success = exports['jpr-inventory']:RemoveItem(src, item, count, slot, 'concept_bridge Item removed')
    if not success then return false end
    TriggerClientEvent("concept_bridge:client:inventory:updateInventory", src, {action = "remove", item = item, count = count, slot = slot, metadata = metadata})
    return success or false
end

---@description This will return a table with the item info, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    local itemTable = nil
    if Framework and Framework.GetItemInfo then
        local ok, info = pcall(Framework.GetItemInfo, item)
        if ok and type(info) == 'table' then itemTable = info end
    end
    if (not itemTable or not (itemTable.name or itemTable.label)) and Framework and Framework.Shared and Framework.Shared.Items then
        itemTable = Framework.Shared.Items[item]
    end
    if type(itemTable) ~= 'table' then return {} end
    return {
        name = itemTable.name or item,
        label = itemTable.label or item,
        stack = itemTable.unique ~= true and itemTable.stack ~= false,
        weight = itemTable.weight,
        description = itemTable.description,
        image = Inventory.GetImagePath(itemTable.image or item),
    }
end

---@description This will return the entire items table from the inventory.
---@return table
Inventory.Items = function()
    if Framework and Framework.Shared and Framework.Shared.Items then
        return Framework.Shared.Items
    end
    if Framework and Framework.ItemList then
        local ok, list = pcall(Framework.ItemList)
        if ok and type(list) == 'table' then
            return list.Items or list
        end
    end
    return {}
end

---@description This will return the count of the item in the players inventory.
---@param src number
---@param item string
---@param metadata table (optional)
---@return number
Inventory.GetItemCount = function(src, item, metadata)
    if metadata then
        local total = 0
        for _, v in pairs(Inventory.GetPlayerInventory(src) or {}) do
            if v.name == item and v.metadata == metadata then
                total = total + (v.count or v.amount or 0)
            end
        end
        return total
    end
    if jpr.GetItemCount then
        local ok, n = pcall(function() return jpr:GetItemCount(src, item) end)
        if ok and type(n) == 'number' then return n end
    end
    if Framework and Framework.GetItemCount then
        local ok, n = pcall(Framework.GetItemCount, src, item, metadata)
        if ok and type(n) == 'number' then return n end
    end
    local total = 0
    for _, v in pairs(Inventory.GetPlayerInventory(src) or {}) do
        if v.name == item then
            total = total + (v.count or v.amount or 0)
        end
    end
    return total
end

---@description This wil return the players inventory.
---@param src number
---@return table
Inventory.GetPlayerInventory = function(src)
    if Framework and Framework.GetPlayerInventory then
        local ok, inv = pcall(Framework.GetPlayerInventory, src)
        if ok and type(inv) == 'table' then return inv end
    end
    if jpr.GetInventory then
        local ok, inv = pcall(function() return jpr:GetInventory(src) end)
        if ok and type(inv) == 'table' then return inv end
    end
    return {}
end

---@description Space check — prefer jpr export when present.
Inventory.CanCarryItem = function(src, item, count)
    if jpr.CanAddItem then
        local ok, result = pcall(function() return jpr:CanAddItem(src, item, count) end)
        if ok and result ~= nil then return result and true or false end
    end
    return true
end

---@description Returns the specified slot data as a table.
---@param src number
---@param slot number
---@return table {weight, name, metadata, slot, label, count}
Inventory.GetItemBySlot = function(src, slot)
    local slotData = jpr:GetItemBySlot(src, slot)
    if not slotData then return {} end
    return {
        name = slotData.name,
        label = slotData.label,
        weight = slotData.weight,
        slot = slot,
        count = slotData.amount,
        metadata = slotData.info,
        stack = slotData.unique,
        description = slotData.description
    }
end

---@description This will open the specified stash for the src passed.
---@param src number
---@param _type string "stash", "trunk", "glovebox"
---@param id string
---@return nil
Inventory.OpenStash = function(src, _type, id)
    _type = _type or "stash"
    local tbl = Inventory.Stashes[id] or {weight = 1000000, slots = 50}
    TriggerClientEvent('concept_bridge:client:jpr-inventory:openStash', src, id, { weight = tbl.weight, slots = tbl.slots })
end

---@description This will return a boolean if the player has the item.
---@param src number
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(src, item, requiredCount)
    return jpr:HasItem(src, item, requiredCount or 1)
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
    local file = LoadResourceFile("jpr-inventory", string.format("html/images/%s.png", item))
    local imagePath = file and string.format("nui://jpr-inventory/html/images/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will open the specified shop for the src passed.
---@param src number
---@param shopTitle string
Inventory.OpenShop = function(src, shopTitle)
    jpr:OpenShop(src, shopTitle)
end

---@description This will register a shop, if it already exists it will return true.
---@param shopTitle string
---@param inventory table
---@param shopCoords table
---@param shopGroups table
Inventory.RegisterShop = function(shopTitle, inventory, shopCoords, shopGroups)
    if not shopTitle or not inventory or not shopCoords then return end
    if registeredShops[shopTitle] then return true end

    local repackItems = {}
    local repackedShopItems = {name = shopTitle, label = shopTitle, coords = shopCoords, items = repackItems, slots = #inventory, }
    for k, v in pairs(inventory) do
        table.insert(repackItems, { name = v.name, price = v.price or 1000, amount = v.count or v.amount or 1, slot = k })
    end

    jpr:CreateShop(repackedShopItems)
    registeredShops[shopTitle] = true
    return true
end

---@description This will open a players inventory, used for admin purposes and stuff.
---@param src number
---@param target number
Inventory.OpenPlayerInventory = function(src, target)
    assert(src, "OpenPlayerInventory: src is required")
    assert(target, "OpenPlayerInventory: target is required")
    local identifier = Framework.GetPlayerIdentifier(target)
    if not identifier then return false end
    exports['jpr-inventory']:OpenInventory(src, identifier)
end

return Inventory