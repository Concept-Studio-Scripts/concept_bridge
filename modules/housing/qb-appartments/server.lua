if GetResourceState('qb-apartments') ~= 'started' then return end

Housing = Housing or {}

RegisterNetEvent('qb-apartments:server:SetInsideMeta', function(house, insideId, bool, isVisiting)
    local src = source
    if type(bool) ~= 'boolean' or (isVisiting ~= nil and type(isVisiting) ~= 'boolean') then return end
    if bool then
        if type(house) ~= 'string' or #house == 0 or #house > 128 then return end
        if type(insideId) ~= 'string' and type(insideId) ~= 'number' then return end
        if type(insideId) == 'string' and #insideId == 0 then return end
        if type(insideId) == 'number' and (insideId <= 0 or insideId > 2147483647 or insideId % 1 ~= 0) then return end
        insideId = house .. '-' .. tostring(insideId)
    else
        insideId = false
    end
    Housing.ObservePlayerInside(src, insideId, 'qb-apartments')
end)

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "qb-apartments"
end


return Housing