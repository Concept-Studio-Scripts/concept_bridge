---@diagnostic disable: duplicate-set-field
if GetResourceState('ps-inventory') == 'missing' then return end
local ps = exports['ps-inventory']
local QbItems = lib.require('@concept_bridge.lib.inventory.shared.qb_items')

Inventory = Inventory or {}

---Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    return QbItems.Info(item, Inventory.GetImagePath)
end

---This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "ps-inventory"
end

---This will return the entire items table from the inventory.
---@return table 
Inventory.Items = function()
    return QbItems.List() or {}
end

---Will return boolean if the player has the item.
---@param item string
---@return boolean
Inventory.HasItem = function(item)
    return ps:HasItem(item)
end

---This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("ps-inventory", string.format("html/images/%s.png", item))
    local imagePath = file and string.format("nui://ps-inventory/html/images/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

RegisterNetEvent('concept_bridge:client:ps-inventory:openStash', function(id, data)
    if source ~= 65535 then return end
    TriggerEvent('ps-inventory:client:SetCurrentStash', id)
    TriggerServerEvent('ps-inventory:server:OpenInventory', 'stash', id, { maxweight = data.weight, slots = data.slots })
end)

return Inventory
