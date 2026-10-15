if GetResourceState('lb-tablet') ~= 'started' then return end
Dispatch = Dispatch or {}

RegisterNetEvent("concept_bridge:server:dispatch:sendAlert", function(data)
    exports["lb-tablet"]:AddDispatch(data) -- this has a return value but we dont really have a use for it atm.
end)

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'lb-tablet'
end

return Dispatch