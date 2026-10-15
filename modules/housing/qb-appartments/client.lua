if GetResourceState('qb-apartments') ~= 'started' then return end

Housing = Housing or {}

---This will get the name of the in use resource.
---@return string
Housing.GetResourceName = function()
    return "qb-apartments"
end

return Housing