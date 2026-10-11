---@diagnostic disable: duplicate-set-field
if GetResourceState('tgiann-inventory') == 'missing' then return end

local tgiann = exports["tgiann-inventory"]
local items = lib.require('@concept_bridge.lib.inventory.shared.provider_items')

Inventory = Inventory or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "tgiann-inventory"
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    return items.Info(tgiann:Items(item), item, Inventory.GetImagePath)
end

Inventory.Items = function()
    return tgiann:Items() or {}
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    return tgiann:HasItem(item, requiredCount or 1)
end

---@description This will return their count of the item in the players inventory, if not found will return 0.
---@param item string
---@return number
Inventory.GetItemCount = function(item)
    local searchItem = tgiann:GetItemCount(item, nil, false)
    return searchItem or 0
end

---@description This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    local pngItem = Inventory.StripPNG(item)
    local webpItem = Inventory.StripWebp(item)
    local pngPath = LoadResourceFile("inventory_images", string.format("/images/%s.png", pngItem))
    local webpPath = LoadResourceFile("inventory_images", string.format("/images/%s.webp", webpItem))
    local imagePath = pngPath and string.format("nui://inventory_images/images/%s.png", pngItem) or webpPath and string.format("nui://inventory_images/images/%s.webp", webpItem)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will return the players inventory in the format of {name, label, count, slot, metadata}
---@return table
Inventory.GetPlayerInventory = function()
    return items.List(tgiann:GetPlayerItems())
end

return Inventory
