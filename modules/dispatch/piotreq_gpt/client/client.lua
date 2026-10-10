---@diagnostic disable: duplicate-set-field
if GetResourceState('piotreq_gpt') == 'missing' then return end
Dispatch = Dispatch or {}

Dispatch.SendAlert = function(data)
    if not data then return end
    TriggerServerEvent('concept_bridge:Server:piotreq_gpt', data)
end

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'piotreq_gpt'
end

return Dispatch