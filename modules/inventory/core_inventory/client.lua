---@diagnostic disable: duplicate-set-field
if GetResourceState('core_inventory') == 'missing' then return end
local core = exports.core_inventory
local items = lib.require('@concept_bridge.lib.inventory.shared.provider_items')

Inventory = Inventory or {}

---This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "core_inventory"
end

--- Return the item info in oxs format, {name, label, stack, weight, description, image}
--- https://docs.c8re.store/core-inventory/exports#client-exports-%E2%80%94-inventory-ui
--- @param item string
--- @return table
Inventory.GetItemInfo = function(item)
    local itemList = Inventory.Items()
    return itemList[item] or {}
end

---This will return the entire items table from the inventory in the ox format.
---@return table 
Inventory.Items = function()
    local allItems = core:getItemsList()
    if not allItems then return {} end
    local dataRepack = {}
    for itemName, itemData in pairs(allItems) do
        if type(itemData) == 'table' then
            dataRepack[itemName] = items.Info(itemData, itemName, Inventory.GetImagePath)
        end
    end
    return dataRepack
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    return Inventory.GetItemCount(item) >= (requiredCount or 1)
end

Inventory.GetItemCount = function(item)
    return core:getItemCount(item) or 0
end

---This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("core_inventory", string.format("html/img/%s.png", item))
    local imagePath = file and string.format("nui://core_inventory/html/img/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---This will return the players inventory in the format of {name, label, count, slot, metadata}
---@return table
Inventory.GetPlayerInventory = function()
    return items.List(core:getPlayerItems(), true)
end

return Inventory
