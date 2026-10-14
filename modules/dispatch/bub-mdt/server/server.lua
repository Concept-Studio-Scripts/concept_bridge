if GetResourceState('bub-mdt') ~= 'started' then return end
Dispatch = Dispatch or {}

---This will get the name of the in use resource.
---@return string
Dispatch.GetResourceName = function()
    return 'bub-mdt'
end

return Dispatch