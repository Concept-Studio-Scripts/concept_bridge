-- Actual loader/export/callback transport identity under bridge and imported use.
-- Run from the repository root: lua test/runtime_identity.lua
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local function environment(resource, server)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.GetCurrentResourceName = function() return resource end
    env.IsDuplicityVersion = function() return server end
    env.GetInvokingResource = function() return 'custom_provider' end
    env.exports = function() end
    env.RegisterNetEvent, env.CreateThread, env.AddEventHandler, env.TriggerEvent = function() end, function() end, function() end, function() end
    return env
end

for _, context in ipairs({'concept_bridge', 'consumer_resource'}) do
    for _, server in ipairs({true, false}) do
        local env = environment(context, server)
        local loads, exported = {}, {}
        env.exports = function(name, fn) exported[name] = fn end
        env.LoadResourceFile = function(resource, path)
            loads[#loads + 1] = {resource = resource, path = path}
            return 'return {}'
        end
        assert(loadfile('lib/init.lua', 't', env))()
        expect(#loads > 10, 'actual loader initialized client/server helpers')
        for _, entry in ipairs(loads) do
            expect(entry.resource == 'concept_bridge', 'imported loader resolves the bridge, not the importing resource')
        end
        expect(exported.cLib == env.cLib, 'cLib export retains the initialized API')
        local before = #loads
        local first = env.Require('fixture.lua')
        expect(env.Require('fixture.lua') == first and #loads == before + 1, 'canonical module cache is reused')
        env.Require('fixture.lua', 'custom_resource')
        expect(loads[#loads].resource == 'custom_resource', 'explicit external loader source retained')
        env.Require('fixture.lua', true)
        expect(loads[#loads].resource == 'custom_provider', 'invoking-resource lookup retained')
        env.LoadResourceFile = function() return nil end
        local ok, error = pcall(env.Require, 'missing.lua')
        expect(not ok and tostring(error):find('concept_bridge:missing.lua', 1, true), 'missing modules identify canonical source')
    end
end

for _, server in ipairs({true, false}) do
    local env = environment('concept_bridge', server)
    local events = {}
    env.RegisterNetEvent = function(name) events[name] = true end
    local callback = assert(loadfile('lib/callback/shared/callback.lua', 't', env))()
    expect(type(callback.Register) == 'function' and type(callback.Trigger) == 'function', 'callback API retained')
    local expected = server and {'CS:Callback', 'SCR:Callback'} or {'SC:Callback', 'CSR:Callback'}
    for _, name in ipairs(expected) do
        expect(events['concept_bridge:' .. name], 'transport registered on canonical resource namespace')
    end
    for name in pairs(events) do expect(not name:find('community_bridge', 1, true), 'no legacy transport registration') end
end

for _, server in ipairs({true, false}) do
    local env = environment('concept_bridge', server)
    local exported = {}
    env.exports = function(name, fn) exported[name] = fn end
    env.cLib, env.Framework, env.Inventory = {}, {marker = true}, {marker = true}
    env.BridgeSharedConfig = {DebugLevel = 0}
    assert(loadfile('init.lua', 't', env))()
    expect(exported.Bridge() == env.Bridge, 'canonical resource exports full Bridge API')
    expect(exported.Framework() == env.Bridge.Framework and exported.Framework().marker, 'Framework module shape preserved')
    expect(exported.Inventory() == env.Bridge.Inventory and exported.Inventory().marker, 'Inventory module shape preserved')
end
print(('runtime_identity: %d assertions passed'):format(assertions))
