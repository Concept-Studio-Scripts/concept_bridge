---@diagnostic disable: duplicate-set-field
local resourceName = 'qbx_seatbelt'
local configured = type(BridgeClientConfig) == 'table' and BridgeClientConfig.Seatbelt or 'auto'
if GetResourceState(resourceName) == 'missing' then return end
if configured ~= 'auto' and configured ~= resourceName then return end

Seatbelt = Seatbelt or {}

---@description Returns the name of the active seatbelt resource.
---@return string
Seatbelt.GetResourceName = function()
    return resourceName
end

---@description True when the vehicle has a seatbelt (provider capability export,
---falling back to the class heuristic).
---@param vehicle number
---@return boolean
Seatbelt.HasSeatbelt = function(vehicle)
    local okExp, result = pcall(function()
        if exports[resourceName].VehicleHasSeatbelt then
            return exports[resourceName]:VehicleHasSeatbelt(vehicle)
        end
        if exports[resourceName].DoesVehicleHaveSeatbelt then
            return exports[resourceName]:DoesVehicleHaveSeatbelt(vehicle)
        end
        return nil
    end)
    if okExp and result ~= nil then return result == true end
    return Seatbelt.IsSeatbeltVehicle(vehicle, false)
end

---@description Current buckle state from the player statebag, then the provider
---export; nil when the provider has not reported yet.
---@return boolean|nil
Seatbelt.GetState = function()
    local state = LocalPlayer and LocalPlayer.state
    if state then
        if state.harness == true then return true end
        if state.seatbelt ~= nil then return state.seatbelt == true end
    end
    local ok, harness = pcall(function()
        return exports[resourceName]:HasHarness()
    end)
    if ok and harness == true then return true end
    return nil
end

Seatbelt.BindUpdates(resourceName, Seatbelt.GetState)

return Seatbelt
