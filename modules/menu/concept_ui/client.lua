local resourceName = "concept_ui"
if GetResourceState(resourceName) ~= 'started' then return end
Menus = Menus or {}
local QBMenu = lib.require('@concept_bridge.lib.menu.client.qb')

function OpenMenu(id, data, useQBinput)
    if useQBinput then
        data = QBMenu.ToContext(id, data)
    end
    data.id = id
    exports.concept_ui:RegisterContext(data)
    exports.concept_ui:ShowContext(id)
    return data
end

GetMenuResourceName = function()
    return resourceName
end
