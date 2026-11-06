local QBMenu = {}

---Runs a qb-menu option's params the way qb-menu does.
---@param params table The option's params.
function QBMenu.Dispatch(params)
    local event, args = params.event, params.args
    if not event then return end
    if params.isServer then return TriggerServerEvent(event, args) end
    if params.isCommand then return ExecuteCommand(event) end
    if params.isQBCommand then return TriggerServerEvent('QBCore:CallCommand', event, args) end
    if params.isAction then return event(args) end
    return TriggerEvent(event, args)
end

---Converts a qb-menu list to the ox_lib context shape.
---@param id string The menu ID.
---@param menu table The QB menu data.
---@return table
function QBMenu.ToContext(id, menu)
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
                onSelect = v.action or function() QBMenu.Dispatch(params) end,
            }
        end
    end
    return context
end

return QBMenu
