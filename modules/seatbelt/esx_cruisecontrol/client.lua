---@diagnostic disable: duplicate-set-field
local resourceName = 'esx_cruisecontrol'
local configured = type(BridgeClientConfig) == 'table' and BridgeClientConfig.Seatbelt or 'auto'
if GetResourceState(resourceName) == 'missing' then return end
if configured ~= 'auto' and configured ~= resourceName then return end

Seatbelt = Seatbelt or {}

-- esx_cruisecontrol supports land vehicles (bikes/boats/aircraft excluded).
local ESX_ALLOWED = {
    [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true,
    [9] = true, [10] = true, [11] = true, [12] = true, [17] = true, [18] = true, [19] = true, [20] = true,
}

---@description Returns the name of the active seatbelt resource.
---@return string
Seatbelt.GetResourceName = function()
    return resourceName
end

---@description True when the vehicle class is in the ESX allowed set.
---@param vehicle number
---@return boolean
Seatbelt.HasSeatbelt = function(vehicle)
    if type(vehicle) ~= 'number' or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local ok, class = pcall(GetVehicleClass, vehicle)
    if not ok or type(class) ~= 'number' then return false end
    return ESX_ALLOWED[class] == true
end

---@description Current buckle state from the provider export.
---@return boolean|nil
Seatbelt.GetState = function()
    local ok, on = pcall(function()
        return exports[resourceName]:isSeatbeltOn()
    end)
    if ok and on ~= nil then return on == true end
    return nil
end

Seatbelt.BindUpdates(resourceName, Seatbelt.GetState)

return Seatbelt
