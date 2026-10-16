if GetResourceState('emergencydispatch') ~= 'started' then return end
Dispatch = Dispatch or {}
local DispatchRequests = lib.require('@concept_bridge.lib.security.server.dispatch')

Dispatch.SendAlert = function(data)
    local job = data.job or data.jobs[1] or 'police'
    local message = data.message or "An Alert Has Been Made"
    local coords = data.coords or vector3(0, 0, 0)

    TriggerEvent('emergencydispatch:emergencycall:new', job, message, coords, true)
end

RegisterNetEvent('concept_bridge:server:dispatch:sendAlert', function(data)
    local src = tonumber(source)
    if src and src > 0 then
        return DispatchRequests.Send(src, 'emergencydispatch', Dispatch.SendAlert, data)
    end
    if src == nil or src == 0 then return Dispatch.SendAlert(data) end
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'emergencydispatch'
end

return Dispatch