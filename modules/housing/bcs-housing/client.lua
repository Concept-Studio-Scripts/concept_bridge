if GetResourceState('bcs-housing') ~= 'started' then return end

Housing = Housing or {}

RegisterNetEvent('Housing:client:EnterHome', function(insideId)
    TriggerServerEvent('concept_bridge:Server:_OnPlayerInside', insideId)
end)

RegisterNetEvent("Housing:client:DeleteFurnitures", function()
    TriggerServerEvent('concept_bridge:Server:_OnPlayerInside', false)
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "bcs-housing"
end

return Housing