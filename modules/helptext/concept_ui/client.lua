---@diagnostic disable: duplicate-set-field
HelpText = HelpText or {}
local resourceName = "concept_ui"
if GetResourceState(resourceName) ~= 'started' then return end

---This will show a help text message at the screen position passed.
---"[E] Open" shows E as a key chip; positions follow ox_lib names (left-center, right-center, top-center, bottom-center).
---@param message string
---@param position string|nil
---@return nil
HelpText.ShowHelpText = function(message, position)
    return exports.concept_ui:ShowTextUI(message, { position = position })
end

---This will get the name of the in use resource.
---@return string
HelpText.GetResourceName = function()
    return resourceName
end

---This will hide the help text message on the screen
---@return nil
HelpText.HideHelpText = function()
    return exports.concept_ui:HideTextUI()
end

return HelpText
