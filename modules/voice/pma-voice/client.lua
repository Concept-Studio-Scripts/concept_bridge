---@diagnostic disable: duplicate-set-field
local resourceName = 'pma-voice'
local configured = type(BridgeClientConfig) == 'table' and BridgeClientConfig.Voice or 'auto'
if GetResourceState(resourceName) == 'missing' then return end
if configured ~= 'auto' and configured ~= resourceName then return end

Voice = Voice or {}

local DefaultProximity = Voice.GetProximity

---@description Returns the name of the active voice resource.
---@return string
Voice.GetResourceName = function()
    return resourceName
end

---@description pma-voice proximity from the replicated player statebag. Falls back
---to the native proximity when pma-voice has not published state yet.
---@return table { index: number|nil, mode: string|number|nil, distance: number|nil }
Voice.GetProximity = function()
    local state = LocalPlayer and LocalPlayer.state
    local prox = state and state.proximity
    if type(prox) ~= 'table' then
        return DefaultProximity()
    end
    return {
        index = type(prox.index) == 'number' and prox.index or nil,
        mode = (type(prox.mode) == 'string' or type(prox.mode) == 'number') and prox.mode or nil,
        distance = type(prox.distance) == 'number' and prox.distance or nil,
    }
end

Voice.BindUpdates(resourceName, Voice.GetProximity)

return Voice
