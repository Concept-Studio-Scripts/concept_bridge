Dispatch = Dispatch or {}
local DispatchRequests = lib.require('@concept_bridge.lib.security.server.dispatch')

-- Trusted server callers retain direct dispatch; network calls are authorized below.
local function sendAlert(data, request)
    local delivered = {}
    for _, name in pairs(data.jobs or {'police'}) do
        local players = Framework.GetPlayersByJob(name)
        if request and not DispatchRequests.Current(request) then return false end
        for _, target in pairs(players or {}) do
            target = tonumber(target)
            if target and target > 0 and GetPlayerName(target) and not delivered[target] then
                TriggerClientEvent('concept_bridge:Client:DispatchAlert', target, data)
                delivered[target] = true
            end
        end
    end
    return true
end

Dispatch.SendAlert = sendAlert

RegisterNetEvent('concept_bridge:Server:DispatchAlert', function(data)
    local src = tonumber(source)
    if src and src > 0 then
        return DispatchRequests.Send(src, 'default', sendAlert, data)
    end
    if src == nil or src == 0 then return sendAlert(data) end
end)

Dispatch.GetResourceName = function() return 'default' end
return Dispatch
