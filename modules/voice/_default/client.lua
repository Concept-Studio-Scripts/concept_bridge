---@diagnostic disable: duplicate-set-field
Voice = Voice or {}

---@description Returns the name of the active voice resource.
---@return string
Voice.GetResourceName = function()
    return 'default'
end

---@description Voice proximity snapshot. `index`/`mode` are nil when the provider
---does not report them; `distance` falls back to the native proximity.
---@return table { index: number|nil, mode: string|number|nil, distance: number|nil }
Voice.GetProximity = function()
    local distance = nil
    local ok, d = pcall(MumbleGetTalkerProximity)
    if ok and type(d) == 'number' and d > 0 then distance = d end
    return { index = nil, mode = nil, distance = distance }
end

local bound, activeResource, activeReader

---@description Wires a provider to the shared voice update events. Only the active
---provider notifies (checked at fire time).
---@param resourceName string
---@param getProximity fun(): table
Voice.BindUpdates = function(resourceName, getProximity)
    activeResource, activeReader = resourceName, getProximity
    if bound then return end
    bound = true
    AddEventHandler('pma-voice:setTalkingMode', function()
        if Voice.GetResourceName() ~= activeResource then return end
        TriggerEvent('concept_bridge:Client:OnVoiceUpdate', activeReader())
    end)

    CreateThread(function()
        local serverId = GetPlayerServerId(PlayerId())
        while serverId == 0 do
            Wait(250)
            serverId = GetPlayerServerId(PlayerId())
        end
        AddStateBagChangeHandler('proximity', ('player:%s'):format(serverId), function()
            if Voice.GetResourceName() ~= activeResource then return end
            TriggerEvent('concept_bridge:Client:OnVoiceUpdate', activeReader())
        end)
    end)
end

return Voice
