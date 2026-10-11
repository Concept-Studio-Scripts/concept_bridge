-- Run from bridge root: lua test/runtime_identity.lua
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
for _, server in ipairs({true, false}) do
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local paths, exported = {}, {}
    env.IsDuplicityVersion = function() return server end
    env.BridgeSharedConfig = {Lang = 'auto', DebugLevel = 0}
    env.lib = {locale = function(key) expect(key == nil, 'auto locale uses ox_lib selection') end,
        require = function(path) paths[#paths + 1] = path return {} end}
    env.exports = function(name, value) exported[name] = value end
    env.TriggerEvent = function() end
    assert(loadfile('lib/init.lua', 't', env))()
    for _, path in ipairs(paths) do
        expect(path:find('@concept_bridge.', 1, true) == 1, 'module source is explicitly the bridge')
    end
    expect(env.cLib.Entity and env.cLib.Math and env.cLib.LA, 'bridge extensions retained')
    env.Framework, env.Inventory = {marker = true}, {marker = true}
    assert(loadfile('init.lua', 't', env))()
    expect(exported.Bridge() == env.Bridge, 'Bridge getter retained')
    expect(exported.Framework().marker and exported.Inventory().marker, 'provider getters retained')
    for _, name in ipairs({'Require', 'Callback', 'RegisterCallback', 'TriggerCallback',
        'RegisterRebound', 'Ids', 'Tables', 'Table', 'Prints', 'Point', 'Raycast',
        'Vehicles', 'Scaleform', 'Language', 'Zones', 'SQL'}) do
        expect(exported[name] == nil and env.cLib[name] == nil, 'dependency utility is not exported: ' .. name)
    end
end
print(('runtime_identity: %d assertions passed'):format(assertions))
