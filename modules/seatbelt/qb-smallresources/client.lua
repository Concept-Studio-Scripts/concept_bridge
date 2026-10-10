---@diagnostic disable: duplicate-set-field
local resourceName = 'qb-smallresources'
local configured = type(BridgeClientConfig) == 'table' and BridgeClientConfig.Seatbelt or 'auto'
if GetResourceState(resourceName) == 'missing' then return end
if configured ~= 'auto' and configured ~= resourceName then return end

Seatbelt = Seatbelt or {}

---@description Returns the name of the active seatbelt resource.
---@return string
Seatbelt.GetResourceName = function()
    return resourceName
end

---@description True when the vehicle has a seatbelt (qb-smallresources has no
---capability export, so the class heuristic is authoritative).
---@param vehicle number
---@return boolean
Seatbelt.HasSeatbelt = function(vehicle)
    return Seatbelt.IsSeatbeltVehicle(vehicle, false)
end

---@description Current buckle state from the player statebag or the provider export.
---@return boolean|nil
Seatbelt.GetState = function()
    local state = LocalPlayer and LocalPlayer.state
    if state and state.seatbelt ~= nil then return state.seatbelt == true end
    local ok, on = pcall(function()
        return exports[resourceName]:HasSeatbeltOn()
    end)
    if ok and on ~= nil then return on == true end
    local okH, harness = pcall(function()
        return exports[resourceName]:HasHarness()
    end)
    if okH and harness ~= nil then return harness == true end
    return nil
end

Seatbelt.BindUpdates(resourceName, Seatbelt.GetState)

return Seatbelt
