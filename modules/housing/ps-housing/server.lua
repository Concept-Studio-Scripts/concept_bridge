if GetResourceState('ps-housing') ~= 'started' then return end

Housing = Housing or {}

RegisterNetEvent('ps-housing:server:enterProperty', function(insideId)
    local src = source
    if insideId == nil or insideId == false then return end
    Housing.ObservePlayerInside(src, insideId, 'ps-housing')
end)

RegisterNetEvent('ps-housing:server:leaveProperty', function()
    local src = source
    Housing.ObservePlayerInside(src, false, 'ps-housing')
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "ps-housing"
end

return Housing