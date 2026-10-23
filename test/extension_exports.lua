-- Exercise the callable export boundary used by the CFX scheduler.
local cases = {
    {'lib/init.lua', 'cLib'},
    {'lib/logs/server/logs.lua', 'Logs'},
    {'lib/markers/client/markers.lua', 'Marker'},
    {'lib/markers/server/server.lua', 'Marker'},
    {'lib/utility/client/utility.lua', 'Utility'},
    {'lib/utility/shared/la.lua', 'LA'},
    {'lib/utility/shared/math.lua', 'Math'},
}
for _, case in ipairs(cases) do
    local registered = {}
    local env = setmetatable({
        lib = {locale = function() end, require = function() return {} end},
        BridgeSharedConfig = {},
        IsDuplicityVersion = function() return false end,
        RegisterNetEvent = function() end,
        AddEventHandler = function() end,
        GlobalState = {},
        exports = function(name, callback) registered[name] = callback end,
    }, {__index = _G})
    env._G = env
    local module = assert(loadfile(case[1], 't', env))()
    local ok, value = pcall(registered[case[2]])
    assert(ok and value == module, case[1] .. ': a consumer can call the export to retrieve the module table')
end
print(('extension_exports: %d export contracts passed'):format(#cases))
