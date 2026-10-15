---@diagnostic disable: duplicate-set-field
if GetResourceState('esx_skin') ~= 'started' then return end
Clothing = Clothing or {}

function Clothing.OpenMenu()
    TriggerEvent('esx_skin:openMenu', function() end, function() end, true)
end

---This will get the name of the in use resource.
---@return string
Clothing.GetResourceName = function()
    return 'esx_skin'
end