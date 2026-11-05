local resourceName = "lation_ui"
if GetResourceState(resourceName) ~= 'started' then return end
Menus = Menus or {}
local QBMenu = lib.require('@concept_bridge.lib.menu.client.qb')

local function runCheckForImageIcon(icon)
    local iconStr = tostring(icon):lower()
    if iconStr:match("^https?://") or iconStr:match("^nui://") or iconStr:match("^file://") then
        return true
    end

    local extensions = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg", ".webp", ".ico"}
    for _, ext in pairs(extensions) do
        if iconStr:match(ext .. "$") then
            return true
        end
    end

    return false
end

local function OxToLationMenu(data)
    local repack = {
        id = data.id,
        title = data.title or "",
        canClose = data.canClose ~= false,
        options = {}
    }
    -- Handle icon colors: remove for image icons, convert strings to hex for others
    for k, v in pairs(data.options) do
        if v.iconColor then
            if v.icon and runCheckForImageIcon(v.icon) then
                v.iconColor = nil
            end
        end
        table.insert(repack.options, v)
    end

    return repack
end

function OpenMenu(id, data, useQBinput)
    if useQBinput then
        data = QBMenu.ToContext(id, data)
    else
        data = OxToLationMenu(data)
    end
    exports.lation_ui:registerMenu(data)
    exports.lation_ui:showMenu(id)
    return data
end

function GetMenuResourceName()
    return resourceName
end