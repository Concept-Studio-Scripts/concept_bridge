---@diagnostic disable: duplicate-set-field
if GetResourceState('emergencydispatch') ~= 'started' then return end
Dispatch = Dispatch or {}

---This will send an alert to currently supported dispatch systems.
---@param data table The data to send to the dispatch system.
---@return nil
Dispatch.SendAlert = function(data)
    local ped = PlayerPedId()

    local job = data.job or data.jobs[1] or 'police'
    local message = data.message or "An Alert Has Been Made"
    local coords = data.coords or GetEntityCoords(ped)

    TriggerServerEvent('concept_bridge:server:dispatch:sendAlert', {job = job, message = message, coords = coords})
end

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'emergencydispatch'
end

return Dispatch