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
-- Every library file lib/init.lua loads must RETURN its table: ox_lib's require hands back `true` for a file that
-- returns nothing, and the bridge then tried to register `true` as a module and did not start.
do
    local f = assert(io.open('lib/init.lua', 'rb'))
    local init = f:read('a')
    f:close()
    local seen = 0
    for path in init:gmatch("lib%.require%('@concept_bridge%.([%w_%.]+)'%)") do
        seen = seen + 1
        local file = path:gsub('%.', '/') .. '.lua'
        local h = assert(io.open(file, 'rb'), file .. ' exists')
        local last
        -- (the last line that is neither empty nor a comment is a return of something)
        for line in (h:read('a') .. string.char(10)):gmatch('(.-)\r?' .. string.char(10)) do
            local code = line:gsub('%-%-.*$', ''):gsub('%s+$', '')
            if code ~= '' then last = code end
        end
        h:close()
        expect(last ~= nil and last:match('^return%s+[%w_]+$') ~= nil, file .. ' returns its module table (last statement: ' .. tostring(last) .. ')')
    end
    expect(seen >= 12, 'lib/init.lua names its libraries (' .. seen .. ')')
    -- and a module that is not a table is refused, not iterated
    local env = setmetatable({}, { __index = _G })
    local printed = 0
    env.BridgeSharedConfig = { DebugLevel = 0 }
    env.exports = function() end
    env.TriggerEvent = function() end
    env.print = function() printed = printed + 1 end
    env.IsDuplicityVersion = function() return true end
    env.cLib = { Broken = true, Fine = { a = function() end } }
    env.Framework, env.Inventory = {}, {}
    local ok, err = pcall(assert(loadfile('init.lua', 't', env)))
    expect(ok, 'the bridge starts with a library that returned nothing: ' .. tostring(err))
    expect(env.Bridge.Broken == nil and env.Bridge.Fine ~= nil and printed >= 1, 'the broken one is named and skipped, the others are registered')
end
print(('runtime_identity: %d assertions passed'):format(assertions))
