-- Run from bridge root: lua test/framework_client_state.lua [root/]
-- Client getters on the character select screen (no character loaded yet) return nil or an empty
-- value instead of erroring, and ox_core's isLoggedIn / GetIsPlayerLoaded follow the character.
local root, assertions = arg[1] or './', 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local function load(path, setup)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.handlers = {}
    env.GetResourceState = function() return 'started' end
    env.RegisterNetEvent = function(name, fn) env.handlers[name] = fn end
    env.AddEventHandler = env.RegisterNetEvent
    env.TriggerEvent = function() end
    env.Wait = function() end
    env.LocalPlayer = {state = {}}
    env.cache = {playerId = 1}
    env.Framework = {}
    setup(env)
    assert(loadfile(root .. path, 't', env))()
    return env
end

local function getters(name, env, data)
    local F = env.Framework
    local ok, err = pcall(function()
        expect(F.GetPlayerIdentifier() == nil, name .. ': no identifier before a character is loaded')
        local first, last = F.GetPlayerName()
        expect(first == nil and last == nil, name .. ': no name before load')
        expect(F.GetPlayerDob() == nil, name .. ': no date of birth before load')
        expect(F.GetPlayerMetaData('hunger') == nil, name .. ': no metadata before load')
        expect(F.GetPlayerJobData() == nil and F.GetPlayerJob() == nil, name .. ': no job before load')
        expect(F.GetAccountBalance('cash') == 0, name .. ': a balance of 0 before load')
        expect(type(F.GetPlayerInventory()) == 'table', name .. ': an empty inventory before load')
        expect(F.GetIsPlayerDead() == false, name .. ': not dead before load')
    end)
    expect(ok, name .. ': getters before load do not error' .. (ok and '' or (' - ' .. tostring(err))))
    -- loaded: the same getters read the character
    for k, v in pairs({citizenid = 'ABC123', charinfo = {firstname = 'Ann', lastname = 'Bee', birthdate = '1990-01-01'},
        metadata = {hunger = 80, isdead = false}, job = {name = 'police', label = 'Police', grade = {name = 'Officer', level = 1}},
        money = {cash = 50, bank = 900}, items = {}}) do data[k] = v end
    expect(F.GetPlayerIdentifier() == 'ABC123' and select(2, F.GetPlayerName()) == 'Bee', name .. ': loaded character is read')
    expect(F.GetPlayerDob() == '1990-01-01', name .. ': date of birth is read from PlayerData')
    expect(F.GetPlayerJobData().jobName == 'police' and F.GetAccountBalance('money') == 50, name .. ': job and cash are read')
end

do
    local data = {}
    local env = load('modules/framework/qb-core/client.lua', function(env)
        local core = {Shared = {Items = {}, Jobs = {}}, Functions = {GetPlayerData = function() return data end}}
        env.exports = setmetatable({}, {__index = function() return {GetCoreObject = function() return core end} end})
    end)
    getters('qb-core', env, data)
end

do
    local data = {}
    local env = load('modules/framework/qbx_core/client.lua', function(env)
        env.exports = setmetatable({}, {__index = function() return {GetPlayerData = function() return data end} end})
    end)
    getters('qbx_core', env, data)
end

do
    local player = {}
    local env = load('modules/framework/ox_core/client.lua', function(env)
        env.require = function() return {GetPlayer = function() return player end} end
        env.exports = setmetatable({}, {__index = function() return setmetatable({}, {__index = function() return function() end end}) end})
    end)
    local F = env.Framework
    expect(env.LocalPlayer.state.isLoggedIn == false, 'ox_core: not logged in on the character select screen')
    expect(F.GetIsPlayerLoaded() == false, 'ox_core: no character loaded while ox has an empty player object')
    player.charId = 4
    env.handlers['ox:playerLoaded'](1, false)
    expect(env.LocalPlayer.state.isLoggedIn == true and F.GetIsPlayerLoaded() == true, 'ox_core: logged in once a character loads')
    env.handlers['ox:startCharacterSelect']()
    expect(env.LocalPlayer.state.isLoggedIn == false, 'ox_core: back to character select is logged out')
    player.charId = nil
    env.handlers['ox:playerLogout']()
    expect(env.LocalPlayer.state.isLoggedIn == false and F.GetIsPlayerLoaded() == false, 'ox_core: logged out after logout')
end

print(('framework_client_state: %d assertions passed'):format(assertions))
