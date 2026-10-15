---@diagnostic disable: duplicate-set-field
if GetResourceState('fivem-appearance') ~= 'started' then return end
Clothing = Clothing or {}

function Clothing.OpenMenu()
    TriggerEvent('qb-clothing:client:openMenu')
end

---This will get the name of the in use resource.
---@return string
Clothing.GetResourceName = function()
    return 'fivem-appearance'
end
