--[[

    Get this inventory here https://onestudios.gg/

]]--

---@diagnostic disable: duplicate-set-field
if GetResourceState('one_inventory') == 'missing' then return end
local inv = exports['one_inventory']
Inventory = Inventory or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "one_inventory"
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    local itemData = inv:GetItemDefinition(item)
    if not itemData then return {} end
    return {
        name = itemData.name,
        label = itemData.label,
        stack = itemData.unique,
        weight = itemData.weight,
        description = itemData.description,
        image = Inventory.GetImagePath(itemData.image or itemData.name)
    }
end

---@description This will return the entire items table from the inventory.
---@return table 
Inventory.Items = function()
    return inv:GetAllItemDefinitions()
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    return inv:HasItem(item, requiredCount or 1)
end

---@description This will return their count of the item in the players inventory, if not found will return 0.
---@param item string
---@return number
Inventory.GetItemCount = function(item)
    return inv:GetItemCount(item, nil)
end

---@description This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("one_inventory", string.format("web/images/%s.png", item))
    local imagePath = file and string.format("nui://one_inventory/web/images/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will return the players inventory in the format of {name, label, count, slot, metadata}
---@return table
Inventory.GetPlayerInventory = function()
    return inv:GetInventoryItems()
end


return Inventory