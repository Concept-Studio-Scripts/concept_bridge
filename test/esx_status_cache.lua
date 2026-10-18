-- Run from bridge root: lua test/esx_status_cache.lua [checkout/]
-- Actual ESX client adapter; provider/native doubles and explicit callback timing.
local root = arg[1] or './'
local checks = 0
local function expect(value, message) checks = checks + 1 assert(value, message) end
local function fixture()
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local state = { loaded = true, running = true, value = 10, pending = {}, hints = {}, events = {} }
    local handlers = {}
    env.GetResourceState = function(name)
        if name == 'es_extended' or (name == 'esx_status' and state.running) then return 'started' end
        return 'stopped'
    end
    local esx = {
        IsPlayerLoaded = function() return state.loaded end,
        GetPlayerData = function()
            return { variables = { status = { { name = 'hunger', percent = state.value } } } }
        end,
    }
    env.exports = { es_extended = { getSharedObject = function() return esx end } }
    local clock = 0
    env.GetGameTimer = function() clock = clock + 2000 return clock end   -- (each read a moment later: no cached copy is reused)
    env.AddEventHandler = function(name, fn) handlers[name] = fn end
    env.RegisterNetEvent = env.AddEventHandler
    env.Wait = function() end
    env.TriggerEvent = function(name, ...)
        if name == 'esx_status:getStatus' then
            local status, cb = ...
            if state.defer then state.pending[#state.pending + 1] = cb
            elseif not state.noStatus then
                cb({ getPercent = function()
                    if state.duringRead then state.duringRead() end
                    return state.value
                end })
            end
        elseif name == 'concept_bridge:Client:OnNeedsUpdate' then
            state.hints[#state.hints + 1] = ...
        else state.events[#state.events + 1] = name end
    end
    local api = assert(loadfile(root .. 'modules/framework/es_extended/client.lua', 't', env))()
    local function fire(name, ...)
        local fn = handlers[name]
        if fn then fn(...) end
    end
    return api, state, fire
end

do
    local api, state, fire = fixture()
    fire('esx_status:onTick', { { name = 'hunger', percent = 90 }, { name = 'thirst', percent = 40 } })
    expect(api.GetHunger() == 90 and api.GetThirst() == 40, 'live remaining percentages, not depletion')
    expect(state.hints[1].hunger == 90 and state.hints[1].thirst == 40, 'normalized needs hint retained')
    state.loaded = false
    fire('esx:onPlayerLogout')
    fire('esx_status:onTick', { { name = 'hunger', percent = 99 } })
    expect(api.GetHunger() == 0 and #state.hints == 1, 'logout rejects old cache and late ticks')
    state.loaded, state.value = true, 20
    fire('esx:playerLoaded', {})
    expect(api.GetHunger() == 20, 'new character reads fresh status without waiting for a tick')
    expect(state.events[1] == 'concept_bridge:Client:OnPlayerUnload'
        and state.events[2] == 'concept_bridge:Client:OnPlayerLoaded', 'framework forwarding retained')
end

-- Player-loaded alone must clear data too, including fast character switches.
do
    local api, state, fire = fixture()
    fire('esx_status:onTick', { { name = 'hunger', percent = 90 } })
    state.value = 30
    fire('esx:playerLoaded', {})
    expect(api.GetHunger() == 30, 'load starts a new cache generation')
end

for _, boundary in ipairs({ 'logout', 'load', 'stop', 'start', 'status_loaded' }) do
    local api, state, fire = fixture()
    state.defer = true
    expect(api.GetHunger() == 10, 'pending provider read falls back to current character data')
    local oldCallback = assert(state.pending[1])
    if boundary == 'logout' then
        state.loaded = false
        fire('esx:onPlayerLogout')
        state.loaded = true
        fire('esx:playerLoaded', {})
    elseif boundary == 'load' then fire('esx:playerLoaded', {})
    elseif boundary == 'status_loaded' then fire('esx_status:loaded')
    else
        state.running = boundary == 'start'
        fire(boundary == 'stop' and 'onClientResourceStop' or 'onClientResourceStart', 'esx_status')
    end
    oldCallback({ getPercent = function() return 95 end })
    state.defer, state.value = false, 25
    expect(api.GetHunger() == 25, boundary .. ': late callback cannot restore retired cache')
end

do
    local api, state, fire = fixture()
    state.defer = true
    api.GetHunger()
    state.pending[1]({ val = 450000 })
    expect(api.GetHunger() == 45, 'current deferred callback caches the existing val fallback')
    fire('esx_status:loaded')
    state.defer = false
    expect(api.GetHunger() == 10, 'status reload clears previous cache')
end

do
    local api, state, fire = fixture()
    fire('esx_status:onTick', { { name = 'hunger', percent = 90 } })
    state.running = false
    fire('onClientResourceStop', 'esx_status')
    fire('esx_status:onTick', { { name = 'hunger', percent = 99 } })
    expect(api.GetHunger() == 10 and #state.hints == 1, 'stopped provider clears cache and ignores late tick')
    state.running, state.value = true, 35
    fire('onClientResourceStart', 'esx_status')
    expect(api.GetHunger() == 35, 'restarted provider refreshes from current status')
    fire('esx_status:onTick', { { name = 'hunger', percent = 65 } })
    fire('onClientResourceStop', 'unrelated_resource')
    expect(api.GetHunger() == 65, 'unrelated resource lifecycle does not clear status')
end

do
    local api, state, fire = fixture()
    state.duringRead = function()
        state.loaded = false
        fire('esx:onPlayerLogout')
    end
    expect(api.GetHunger() == 0, 'logout during status read cannot commit or fall back to old character')
    state.loaded, state.duringRead, state.value = true, nil, 15
    fire('esx:playerLoaded', {})
    expect(api.GetHunger() == 15, 'fresh read after interrupted callback is usable')
end

do
    local api, state, fire = fixture()
    state.running, state.noStatus = false, true
    expect(api.GetHunger() == 10, 'missing provider retains current-character data fallback')
    state.loaded = false
    fire('esx:onPlayerLogout')
    expect(api.GetHunger() == 0, 'missing provider cannot expose logged-out character fallback')
end

print(('esx_status_cache: %d assertions passed'):format(checks))
