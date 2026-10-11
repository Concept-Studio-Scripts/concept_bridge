if GetResourceState('esx_property') == 'missing' then return end

Housing = Housing or {}

RegisterNetEvent('esx_property:enter', function(insideId)
    local src = source
    if insideId == nil or insideId == false then return end
    Housing.ObservePlayerInside(src, insideId, 'esx_property')
end)

RegisterNetEvent('esx_property:leave', function()
    local src = source
    Housing.ObservePlayerInside(src, false, 'esx_property')
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "esx_property"
end

return Housing