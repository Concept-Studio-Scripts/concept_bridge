---@diagnostic disable: duplicate-set-field
Seatbelt = Seatbelt or {}

---@description Returns the name of the active seatbelt resource.
---@return string
Seatbelt.GetResourceName = function()
    return 'default'
end

---@description Conservative vehicle-capability fallback. Bikes/cycles/boats are
---excluded; aircraft can be excluded per provider. Mirrors the HUD tables.
---@param vehicle number
---@param allowAircraft boolean|nil
---@return boolean
Seatbelt.IsSeatbeltVehicle = function(vehicle, allowAircraft)
    if type(vehicle) ~= 'number' or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local okClass, class = pcall(GetVehicleClass, vehicle)
    if not okClass or type(class) ~= 'number' then return true end
    if class == 8 or class == 13 or class == 14 then return false end
    if allowAircraft ~= true and (class == 15 or class == 16) then return false end
    local okModel, model = pcall(GetEntityModel, vehicle)
    if okModel and type(model) == 'number' then
        local okBike, isBike = pcall(IsThisModelABike, model)
        if okBike and (isBike == true or isBike == 1) then return false end
    end
    return true
end

---@description True when the vehicle has a seatbelt (provider capability).
---@param vehicle number
---@return boolean
Seatbelt.HasSeatbelt = function(vehicle)
    return false
end

---@description Current buckle state: true/false, or nil when unknown/unavailable.
---@return boolean|nil
Seatbelt.GetState = function()
    return nil
end

---@description Broadcasts a buckle state change for consumers.
---@param state boolean|nil
Seatbelt.Notify = function(state)
    TriggerEvent('concept_bridge:Client:OnSeatbeltUpdate', state)
end

---@description Wires the shared raw listeners (toggle event + player statebags) to
---the active provider. Providers call this once at load; every handler checks the
---active provider at fire time, so only the selected one notifies.
---@param resourceName string
---@param getState fun(): boolean|nil
Seatbelt.BindUpdates = function(resourceName, getState)
    local function refresh()
        if Seatbelt.GetResourceName() ~= resourceName then return end
        Seatbelt.Notify(getState())
    end

    AddEventHandler('seatbelt:client:ToggleSeatbelt', function(state)
        if Seatbelt.GetResourceName() ~= resourceName then return end
        if type(state) == 'boolean' then
            Seatbelt.Notify(state)
        else
            refresh()
        end
    end)

    CreateThread(function()
        local serverId = GetPlayerServerId(PlayerId())
        while serverId == 0 do
            Wait(250)
            serverId = GetPlayerServerId(PlayerId())
        end
        local bag = ('player:%s'):format(serverId)
        AddStateBagChangeHandler('seatbelt', bag, refresh)
        AddStateBagChangeHandler('harness', bag, refresh)
    end)
end

return Seatbelt
