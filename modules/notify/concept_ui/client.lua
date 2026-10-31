---@diagnostic disable: duplicate-set-field
Notify = Notify or {}
local resourceName = "concept_ui"
if GetResourceState(resourceName) ~= 'started' then return end

Notify.GetResourceName = function()
    return resourceName
end

---This will send a notify message of the type and time passed
---@param message string
---@param _type string
---@param time number
---@return nil
Notify.SendNotify = function(message, _type, time)
    return exports.concept_ui:Notify({ description = message, type = _type, duration = time or 3000 })
end

---This will send a notify message with a title. concept_ui shows the message alone when there is no title.
---@param title string|nil
---@param message string
---@param _type string
---@param time number
---@param props table|nil optional: icon, iconColor, position, id
---@return nil
Notify.SendNotification = function(title, message, _type, time, props)
    props = type(props) == 'table' and props or {}
    return exports.concept_ui:Notify({
        title = title,
        description = message,
        type = _type or "success",
        duration = time or 3000,
        icon = props.icon,
        iconColor = props.iconColor,
        position = props.position,
        id = props.id,
    })
end

return Notify
