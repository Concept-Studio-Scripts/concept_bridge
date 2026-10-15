-- Run from bridge root: lua test/audit_regressions.lua [checkout/]
-- Current-branch tests, separate from the historical comparative review fixture.
local root = arg[1] or './'
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local function environment(resource)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    assert(loadfile(root .. 'test/support/ox_lib.lua'))()(env)
    local state = {handlers = {}, events = {}}
    env.GetResourceMetadata = function() return '1.0.0' end
    env.GetResourceState = function(name) return name == resource and 'started' or 'missing' end
    env.RegisterNetEvent = function(name, handler) if handler then state.handlers[name] = handler end end
    env.AddEventHandler = env.RegisterNetEvent
    env.RegisterCommand, env.CreateThread = function() end, function() end
    env.TriggerClientEvent = function() end
    env.TriggerEvent = function(name, ...) state.events[#state.events + 1] = {name = name, args = table.pack(...)} end
    env.LoadResourceFile = function() return nil end
    env.lib.callback = {register = function() end}
    env.exports = {}
    return env, state
end
local function load(path, env) return assert(loadfile(root .. path, 't', env))() end

for _, provider in ipairs({'qb-core', 'qbx_core', 'es_extended', 'ox_core'}) do
    local env, state = environment(provider)
    local core = {Shared = {}, Functions = {}, Commands = {}}
    core.Functions.CreateUseableItem = function(_, callback) state.usable = callback end
    env.exports['qb-core'] = {GetCoreObject = function() return core end}
    env.exports.qbx_core = {CreateUseableItem = function(_, _, callback) state.usable = callback end}
    env.exports.es_extended = {getSharedObject = function() return {
        RegisterUsableItem = function(_, callback) state.usable = callback end,
    } end}
    env.require = function() return {GetPlayer = function() return nil end} end
    local api = load('modules/framework/' .. provider .. '/server.lua', env)
    api.GetPlayerJobData = function() return {jobName = 'unemployed'} end
    api.AddJobCount = function(src, job)
        state.events[#state.events + 1] = {name = 'fixture:jobCount', args = {src, job}}
    end
    local names = provider == 'es_extended' and {'esx:playerLoaded', 'esx:playerLogout', 'esx:setJob'} or
        provider == 'ox_core' and {'ox:playerLoaded', 'ox:playerLogout', 'ox:setGroup'} or
        {'QBCore:Server:OnPlayerLoaded', 'QBCore:Server:OnPlayerUnload', 'QBCore:Server:OnJobUpdate'}
    for index, name in ipairs(names) do
        expect(type(state.handlers[name]) == 'function', 'framework event registered: ' .. name)
        for _, case in ipairs({{source = 8, want = 8}, {source = '8', want = 8}, {source = 0, want = 7}, {want = 7}}) do
            env.source = case.source
            state.events = {}
            if index == 3 and provider == 'ox_core' then
                state.handlers[name](7, 'police', 2)
            elseif index == 3 then
                state.handlers[name](7, {name = 'police'}, {name = 'unemployed'})
            else
                state.handlers[name](7)
            end
            expect(#state.events > 0, 'framework lifecycle still emits normalized event')
            for _, event in ipairs(state.events) do
                expect(event.args[1] == case.want, 'network sender overrides victim ID; local server caller keeps explicit ID')
            end
        end
    end
    if provider ~= 'ox_core' then
        local received, source
        api.RegisterUsableItem('water', function(src, item) source, received = src, item end)
        state.usable(8, 'water')
        expect(source == 8 and received.name == 'water' and type(received.metadata) == 'table', 'string usable-item callback')
        state.usable(8, {name = 'water', amount = 3, slot = 5, info = {quality = 80}})
        expect(received.amount == 3 and received.slot == 5 and received.metadata.quality == 80, 'table usable-item callback preserves stack and metadata')
        state.usable(8, 'water', {name = 'water', count = 4, id = 6, metadata = {quality = 90}})
        expect(received.count == 4 and received.slot == 6 and received.metadata.quality == 90, 'explicit third callback argument takes precedence')
    end
end

-- Provider identifiers are intentionally different: QB uses labels; OX/Sleepless names.
for _, provider in ipairs({'ox_target', 'qb-target', 'sleepless_interact'}) do
    local env = environment(provider)
    local entries, calls = {}, 0
    local qb = provider == 'qb-target'
    local key = function(option) return qb and option.label or option.name end
    local native = {}
    native[qb and 'AddGlobalPlayer' or 'addGlobalPlayer'] = function(_, data)
        for _, option in pairs(qb and data.options or data) do entries[key(option)] = option end
    end
    native[qb and 'RemoveGlobalPlayer' or 'removeGlobalPlayer'] = function(_, identifiers)
        calls = calls + 1
        if identifiers == nil then entries = {} return end
        for _, id in pairs(type(identifiers) == 'table' and identifiers or {identifiers}) do entries[id] = nil end
    end
    env.exports[provider] = native
    local api = load('modules/target/' .. provider .. '/client.lua', env) or env.Target
    api.AddGlobalPlayer({{name = 'inspect', label = 'Inspect player'}, {name = 'search', label = 'Search player'}, {name = 'other', label = 'Other'}})
    local inspect, search, other = qb and 'Inspect player' or 'inspect', qb and 'Search player' or 'search', qb and 'Other' or 'other'
    expect(entries[inspect] and entries[search] and entries[other], 'target options added with native identifier convention')
    api.RemoveGlobalPlayer()
    expect(calls == 0 and entries[inspect] and entries[other], 'nil removal never clears all targets')
    api.RemoveGlobalPlayer(inspect)
    expect(entries[inspect] == nil and entries[search] and entries[other], 'single removal retains unrelated options')
    api.RemoveGlobalPlayer({search})
    expect(entries[search] == nil and entries[other], 'list removal retains unrelated options')
    api.RemoveGlobalPlayer({})
    api.RemoveGlobalPlayer('unknown')
    api.RemoveGlobalPlayer(inspect)
    expect(entries[other] ~= nil, 'empty/unknown/repeated removal harmless')
end

do
    local env = environment('qb-inventory')
    local definitions = {water = {name = 'water', weight = 10, unique = false}, bread = {name = 'bread', weight = 20, unique = true}}
    local state = {rows = {{name = 'water', count = 10, slot = 5}}, config = {MaxWeight = 120, MaxSlots = 30}}
    env.Framework = {Shared = {Items = definitions}, GetPlayerInventory = function() return state.rows end}
    env.exports['qb-inventory'] = {}
    local cache = {}
    env.lib = env.lib or {callback = {register = function() end}}
    env.lib.require = function(module)
        local path = module:gsub('^@[^.]+%.', ''):gsub('%.', '/') .. '.lua'
        if path == 'config.lua' then return state.config end
        if not cache[path] then cache[path] = load(path, env) end
        return cache[path]
    end
    env.Inventory = {StripPNG = function(name) return name:gsub('%.png$', '') end}
    local api = load('modules/inventory/qb-inventory/server.lua', env)
    expect(api.Old.CanCarryItem(1, 'water', 1), '100 current weight plus 10 requested fits 120')
    expect(api.Old.CanCarryItem(1, 'water', 2), 'exact weight capacity permitted')
    expect(not api.Old.CanCarryItem(1, 'water', 3), 'over-weight rejected')
    state.config.MaxSlots = 1
    expect(api.Old.CanCarryItem(1, 'water', 1), 'existing stack needs no free slot')
    expect(not api.Old.CanCarryItem(1, 'bread', 1), 'new unique item needs a free slot')
    state.rows = {[5] = {name = 'water', count = 1, slot = 5}}
    state.config.MaxSlots = 2
    expect(api.Old.CanCarryItem(1, 'bread', 1), 'sparse occupied slots counted accurately')
    expect(not api.Old.CanCarryItem(1, 'bread', 2), 'each unique item consumes a slot')
    expect(not api.Old.CanCarryItem(1, 'unknown', 1), 'unknown definition cannot claim capacity')
    expect(not api.Old.CanCarryItem(1, 'water', 0) and not api.Old.CanCarryItem(1, 'water', -1) and not api.Old.CanCarryItem(1, 'water', 1.5), 'invalid requested amounts rejected')
    state.rows = nil
    expect(not api.Old.CanCarryItem(1, 'water', 1), 'unavailable player inventory rejects capacity query')
end
print(('PASS: %d audit regression assertions'):format(assertions))
