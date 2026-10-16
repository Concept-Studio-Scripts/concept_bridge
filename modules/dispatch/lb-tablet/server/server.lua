if GetResourceState('lb-tablet') ~= 'started' then return end
Dispatch = Dispatch or {}
local DispatchRequests = lib.require('@concept_bridge.lib.security.server.dispatch')

Dispatch.SendAlert = function(data)
    exports["lb-tablet"]:AddDispatch(data) -- this has a return value but we dont really have a use for it atm.
end

RegisterNetEvent('concept_bridge:server:dispatch:sendAlert', function(data)
    local src = tonumber(source)
    if src and src > 0 then
        return DispatchRequests.Send(src, 'lb-tablet', Dispatch.SendAlert, data)
    end
    if src == nil or src == 0 then return Dispatch.SendAlert(data) end
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'lb-tablet'
end

return Dispatch