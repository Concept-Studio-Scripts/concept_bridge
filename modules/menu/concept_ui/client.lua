local resourceName = "concept_ui"
if GetResourceState(resourceName) ~= 'started' then return end
Menus = Menus or {}

---Converts a qb-menu list to the ox_lib context shape concept_ui takes.
---@param id string The menu ID.
---@param menu table The QB menu data.
---@return table
local function QBToContext(id, menu)
    local context = { id = id, title = "", canClose = true, options = {} }
    for _, v in ipairs(menu) do
        if v.isMenuHeader then
            if context.title == "" then context.title = v.header end
        else
            local params = v.params or {}
            context.options[#context.options + 1] = {
                title = v.header,
                description = v.txt,
                icon = v.icon,
                disabled = v.disabled,
                args = params.args,
                onSelect = v.action or function(args)
                    if not params.event then return end
                    if params.isServer then
                        return TriggerServerEvent(params.event, args)
                    end
                    return TriggerEvent(params.event, args)
                end,
            }
        end
    end
    return context
end

function OpenMenu(id, data, useQBinput)
    if useQBinput then
        data = QBToContext(id, data)
    end
    data.id = id
    exports.concept_ui:RegisterContext(data)
    exports.concept_ui:ShowContext(id)
    return data
end

GetMenuResourceName = function()
    return resourceName
end
