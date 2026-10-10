---@diagnostic disable: duplicate-set-field
if GetResourceState('qb-inventory') == 'missing' then return end
if GetResourceState('codem-inventory') ~= 'missing' then return end
if GetResourceState('origen_inventory') ~= 'missing' then return end
local qb = exports['qb-inventory']
local QbItems = Require('lib/inventory/shared/qb_items.lua')

Inventory = Inventory or {}

---@description This will get the name of the in use resource.
---@return string
Inventory.GetResourceName = function()
    return "qb-inventory"
end

---@description Return the item info in oxs format, {name, label, stack, weight, description, image}
---@param item string
---@return table
Inventory.GetItemInfo = function(item)
    return QbItems.Info(item, Inventory.GetImagePath)
end

---@description This will return the entire items table from the inventory.
---@return table 
Inventory.Items = function()
    return QbItems.List() or {}
end

---@description Will return boolean if the player has the item.
---@param item string
---@param requiredCount number (optional)
---@return boolean
Inventory.HasItem = function(item, requiredCount)
    return qb:HasItem(item, requiredCount or 1)
end

---@description This will get the image path for this item, if not found will return placeholder.
---@param item string
---@return string
Inventory.GetImagePath = function(item)
    item = Inventory.StripPNG(item)
    local file = LoadResourceFile("qb-inventory", string.format("html/images/%s.png", item))
    local imagePath = file and string.format("nui://qb-inventory/html/images/%s.png", item)
    return imagePath or "https://avatars.githubusercontent.com/u/47620135"
end

RegisterNetEvent('concept_bridge:client:qb-inventory:openStash', function(id, data)
    if source ~= 65535 then return end
    TriggerEvent("inventory:client:SetCurrentStash", id)
    TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, { maxweight = data.weight, slots = data.slots })
end)

-- Normalized inventory-change broadcast for bridge consumers.
RegisterNetEvent('QBCore:Client:OnPlayerUpdated', function(key)
    if key == 'items' then
        TriggerEvent('concept_bridge:Client:OnInventoryUpdate')
    end
end)

return Inventory
