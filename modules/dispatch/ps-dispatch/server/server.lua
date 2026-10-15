if GetResourceState('ps-dispatch') ~= 'started' then return end
Dispatch = Dispatch or {}

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'ps-dispatch'
end

return Dispatch