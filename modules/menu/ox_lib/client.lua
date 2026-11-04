local resourceName = "ox_lib"
if GetResourceState(resourceName) ~= 'started' then return end
Menus = Menus or {}
local QBMenu = lib.require('@concept_bridge.lib.menu.client.qb')


function OpenMenu(id, data, useQBinput)
    if useQBinput then
        data = QBMenu.ToContext(id, data)
    end
    lib.registerContext(data)
    lib.showContext(id)
    return data
end

GetMenuResourceName = function()
    return resourceName
end


-- RegisterCommand('menutest', function()
--     local test1 = function()
--         print("Test 1 executed")
--     end

--     Bridge.Menu.Open({
--         title = "test",
--         description = "test",
--         options = {
--             {
--                 title = "test",
--                 description = "test",
--                 icon = "fas fa-box-open",
--                 onSelect = test1
--             },           
--         }
--     })
-- end)