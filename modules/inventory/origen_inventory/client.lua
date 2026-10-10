---@diagnostic disable: duplicate-set-field
if GetResourceState('origen_inventory') == 'missing' then return end
if GetResourceState('ox_inventory') ~= 'missing' then return end
Inventory = Inventory or {}
local origin = exports.origen_inventory
local items = Require('lib/inventory/shared/provider_items.lua')
local frameworkItems = Inventory.Items

-- No client definition registry export is established by Origen's export page.
-- Retain the bridge's framework registry without inventing a native API.
Inventory.Items = function()
    if type(frameworkItems) ~= 'function' then return {} end
    local ok, registry = pcall(frameworkItems)
    return ok and type(registry) == 'table' and registry or {}
end

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "origen_inventory"
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    return items.Info(Inventory.Items()[item], item, Inventory.GetImagePath)
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    local count = Inventory.GetItemCount(item)
    return count >= (requiredCount or 1)
end

---@description This will return their count of the item in the players inventory, if not found will return 0.
---@param item string
---@return number
Inventory.GetItemCount = function(item)
    -- Origen's documented client search opens a UI; it is not a count query.
    return items.Count(Inventory.GetPlayerInventory(), item)
end

---@description This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("origen_inventory", string.format("html/images/%s.png", item))
    local imagePath = file and string.format("nui://origen_inventory/html/images/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

---@description This will return the players inventory in the format of {name, label, count, slot, metadata}
---@return table
Inventory.GetPlayerInventory = function()
    return items.List(origin:getPlayerItems())
end

return Inventory
