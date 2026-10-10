---@diagnostic disable: duplicate-set-field
local resourceName = 'concept_seatbelt'
local configured = type(BridgeClientConfig) == 'table' and BridgeClientConfig.Seatbelt or 'auto'
if GetResourceState(resourceName) == 'missing' then return end
if configured ~= 'auto' and configured ~= resourceName then return end

Seatbelt = Seatbelt or {}

---@description Returns the name of the active seatbelt resource.
---@return string
Seatbelt.GetResourceName = function()
    return resourceName
end

---@description True when the vehicle has a seatbelt (aircraft excluded).
---@param vehicle number
---@return boolean
Seatbelt.HasSeatbelt = function(vehicle)
    return Seatbelt.IsSeatbeltVehicle(vehicle, false)
end

---@description Current buckle state from the provider export.
---@return boolean|nil
Seatbelt.GetState = function()
    local ok, on = pcall(function()
        return exports[resourceName]:IsBuckled()
    end)
    if ok and on ~= nil then return on == true end
    return nil
end

Seatbelt.BindUpdates(resourceName, Seatbelt.GetState)

return Seatbelt
