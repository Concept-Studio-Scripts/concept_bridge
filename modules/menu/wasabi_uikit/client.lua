local resourceName = "wasabi_uikit"
if GetResourceState(resourceName) ~= 'started' then return end
Menus = Menus or {}
local QBMenu = lib.require('@concept_bridge.lib.menu.client.qb')

function OpenMenu(id, data, useQBinput)
    if useQBinput then
        data = QBMenu.ToContext(id, data)
    end
    exports.wasabi_uikit:RegisterContextMenu(data)
    exports.wasabi_uikit:OpenContextMenu(id)
    return data
end

GetMenuResourceName = function()
    return resourceName
end