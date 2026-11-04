---@diagnostic disable: duplicate-set-field
local resourceName = "concept_ui"
if GetResourceState(resourceName) ~= 'started' then return end

Input = {}

---concept_ui takes ox_lib's inputDialog rows and returns its values, so QB input data is converted the same way.
function Input.Open(title, data, isQBFormat, submitText)
    if not isQBFormat then
        return exports.concept_ui:InputDialog(title, data)
    end
    local inputs = data.inputs
    local returnData = exports.concept_ui:InputDialog(title, QBToOxInput(inputs))
    if not returnData then return end
    local convertedData = {}
    for i, v in pairs(inputs) do
        if returnData[i] ~= nil then convertedData[v.name] = returnData[i] end
    end
    return convertedData
end

function Input.GetResourceName()
    return resourceName
end

return Input
