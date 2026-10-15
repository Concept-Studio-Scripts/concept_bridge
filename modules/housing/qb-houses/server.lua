if GetResourceState('qb-houses') ~= 'started' then return end

Housing = Housing or {}

RegisterNetEvent('qb-houses:server:SetInsideMeta', function(insideId, bool)
    local src = source
    if type(bool) ~= 'boolean' or (bool and (insideId == nil or insideId == false)) then return end
    insideId = bool and insideId or false
    Housing.ObservePlayerInside(src, insideId, 'qb-houses')
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "qb-houses"
end

return Housing