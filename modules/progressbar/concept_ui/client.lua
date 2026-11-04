---@diagnostic disable: duplicate-set-field
local resourceName = "concept_ui"
if GetResourceState(resourceName) ~= 'started' then return end

ProgressBar = ProgressBar or {}

---Converts a QB progress bar options table to the ox_lib shape concept_ui takes.
---@param options table
---@return table
local function convertFromQB(options)
    if not options then return options end
    local props = {}
    for _, p in ipairs({ options.prop or {}, options.propTwo or {} }) do
        if p.model then
            props[#props + 1] = { model = p.model, bone = p.bone, pos = p.coords, rot = p.rotation }
        end
    end
    local disables = options.controlDisables or {}
    local animation = options.animation or {}
    return {
        duration = options.duration,
        label = options.label,
        useWhileDead = options.useWhileDead,
        canCancel = options.canCancel,
        disable = {
            move = disables.disableMovement,
            car = disables.disableCarMovement,
            combat = disables.disableCombat,
            mouse = disables.disableMouse,
        },
        anim = animation.animDict and {
            dict = animation.animDict,
            clip = animation.anim,
            flag = animation.flags or 49,
        } or (animation.task and { scenario = animation.task }) or nil,
        prop = props,
    }
end

---This function opens a progress bar.
---@param options table ox_lib shape; style = 'circle' shows the round one
---@param cb function|nil called with the result
---@param isQBInput boolean|nil options use the qb-progressbar shape
---@return boolean
function ProgressBar.Open(options, cb, isQBInput)
    if isQBInput then
        options = convertFromQB(options)
    end
    options = options or {}

    local success
    if options.style == 'circle' then
        success = exports.concept_ui:ProgressCircle(options)
    else
        success = exports.concept_ui:Progress(options)
    end

    if cb then cb(success) end
    return success
end

ProgressBar.GetResourceName = function()
    return resourceName
end

return ProgressBar
