if GetResourceState('redutzu-mdt') ~= 'started' then return end
Dispatch = Dispatch or {}
local DispatchRequests = lib.require('@concept_bridge.lib.security.server.dispatch')

Dispatch.SendAlert = function(data)
    TriggerEvent('redutzu-mdt:server:addDispatchToMDT', {
        code = data.code,
        title = data.message,
        street = data.street,
        duration = data.time,
        coords = data.coords
    })
end

RegisterNetEvent('concept_bridge:server:dispatch:sendAlert', function(data)
    local src = tonumber(source)
    if src and src > 0 then
        return DispatchRequests.Send(src, 'redutzu-mdt', Dispatch.SendAlert, data)
    end
    if src == nil or src == 0 then return Dispatch.SendAlert(data) end
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'redutzu-mdt'
end

return Dispatch