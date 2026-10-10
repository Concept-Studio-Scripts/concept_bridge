---@diagnostic disable: duplicate-set-field
HelpText = HelpText or {}

---This will show a help text message at the screen position passed
---@param message string
---@param _position string
---@return nil
HelpText.ShowHelpText = function(message, _position)
    if type(Framework) == 'table' and type(Framework.ShowHelpText) == 'function' then
        return Framework.ShowHelpText(message, _position)
    end
    if exports.ox_lib then
        return exports.ox_lib:showTextUI(message, { position = _position or 'top-center' })
    end
end

---This will get the name of the in use resource.
---@return string
HelpText.GetResourceName = function()
    return "default"
end

---This will hide the help text message on the screen
---@return nil
HelpText.HideHelpText = function()
    if type(Framework) == 'table' and type(Framework.HideHelpText) == 'function' then
        return Framework.HideHelpText()
    end
    if exports.ox_lib then
        return exports.ox_lib:hideTextUI()
    end
end

RegisterNetEvent('concept_bridge:Client:ShowHelpText', function(message, position)
    HelpText.ShowHelpText(message, position)
end)

RegisterNetEvent('concept_bridge:Client:HideHelpText', function()
    HelpText.HideHelpText()
end)

return HelpText