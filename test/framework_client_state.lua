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

-- PlayerData through the core's export is copied on every call: the bridge keeps a loaded character's
-- data and follows the framework's own update events.
for _, provider in ipairs({'qb-core', 'qbx_core'}) do
    local reads, data = 0, {}
    local function fetch() reads = reads + 1 return data end
    local env = load('modules/framework/' .. provider .. '/client.lua', function(env)
        if provider == 'qb-core' then
            local core = {Shared = {Items = {}, Jobs = {}}, Functions = {GetPlayerData = fetch}}
            env.exports = setmetatable({}, {__index = function() return {GetCoreObject = function() return core end} end})
        else
            env.exports = setmetatable({}, {__index = function() return {GetPlayerData = fetch} end})
        end
    end)
    local F = env.Framework
    F.GetPlayerData()
    F.GetPlayerData()
    expect(reads == 2, provider .. ': before a character is loaded every read asks the core')
    data = {citizenid = 'A1', job = {name = 'unemployed'}, money = {cash = 1}}
    F.GetPlayerData()
    local before = reads
    for _ = 1, 10 do F.GetPlayerIdentifier() end
    expect(reads == before, provider .. ': a loaded character is read from the cache')
    env.handlers['QBCore:Player:SetPlayerData']({citizenid = 'A1', job = {name = 'police'}, money = {cash = 5}})
    expect(F.GetPlayerJobData().jobName == 'police' and F.GetAccountBalance('cash') == 5 and reads == before,
        provider .. ': SetPlayerData updates the cache')
    env.handlers['QBCore:Client:OnJobUpdate']({name = 'ambulance', label = 'EMS', grade = {name = 'a', level = 1}})
    expect(F.GetPlayerJobData().jobName == 'ambulance', provider .. ': a job update reaches the cache')
    if provider == 'qb-core' then
        -- (qb-core 1.3: Player:UpdateClient sends one key at a time, 'all' for the whole data)
        env.handlers['QBCore:Client:OnPlayerUpdated']('money', {cash = 40, bank = 0})
        env.handlers['QBCore:Client:OnPlayerUpdated']('metadata', {hunger = 12, isdead = true})
        expect(F.GetAccountBalance('cash') == 40 and F.GetPlayerMetaData('hunger') == 12 and F.GetIsPlayerDead() == true,
            provider .. ': per-key updates (money, metadata) reach the cache')
        env.handlers['QBCore:Client:OnPlayerUpdated']('all', {citizenid = 'A1', job = {name = 'mechanic'}, money = {cash = 7}})
        expect(F.GetAccountBalance('cash') == 7 and F.GetPlayerJobData().jobName == 'mechanic' and reads == before,
            provider .. ': an all update replaces the cache')
    end
    env.handlers['QBCore:Client:OnPlayerUnload']()
    data = {}
    expect(F.GetPlayerIdentifier() == nil and reads > before, provider .. ': after unload the core is asked again')
end

do
    local reads, now, data = 0, 0, {job = {name = 'unemployed'}, accounts = {{name = 'bank', money = 10}}}
    local env = load('modules/framework/es_extended/client.lua', function(env)
        local esx = {GetPlayerData = function() reads = reads + 1 return data end, IsPlayerLoaded = function() return true end}
        env.exports = setmetatable({}, {__index = function() return {getSharedObject = function() return esx end} end})
        env.GetGameTimer = function() return now end
    end)
    local F = env.Framework
    F.GetPlayerData()
    F.GetPlayerData()
    expect(reads == 1, 'es_extended: a copy is reused within a second')
    env.handlers['esx:setPlayerData']('job', {name = 'police'})
    expect(F.GetPlayerData().job.name == 'police' and reads == 1, 'es_extended: esx:setPlayerData updates the copy')
    env.handlers['esx:setAccountMoney']({name = 'bank', money = 99})
    expect(F.GetPlayerData().accounts[1].money == 99, 'es_extended: an account update reaches the copy')
    now = 1500
    F.GetPlayerData()
    expect(reads == 2, 'es_extended: after a second the data is read again')
    env.handlers['esx:onPlayerLogout']()
    F.GetPlayerData()
    expect(reads == 3, 'es_extended: after logout the data is read again')
end

-- Signed balances pass through the real client adapters, including cash aliases.
for _, provider in ipairs({'qb-core', 'qbx_core', 'es_extended'}) do
    local data = {citizenid = 'SIGNED', money = {}, accounts = {}}
    local env = load('modules/framework/' .. provider .. '/client.lua', function(env)
        local core = {Shared = {Items = {}, Jobs = {}}, Functions = {GetPlayerData = function() return data end}}
        local esx = {GetPlayerData = function() return data end, IsPlayerLoaded = function() return true end}
        env.exports = setmetatable({}, {__index = function() return {
            GetCoreObject = function() return core end,
            GetPlayerData = function() return data end,
            getSharedObject = function() return esx end,
        } end})
        env.GetGameTimer = function() return 0 end
    end)
    for _, value in ipairs({-1250, 0, 500}) do
        data.money = {cash = value, bank = value, black_money = value}
        data.accounts = {{name = 'money', money = value}, {name = 'bank', money = value}, {name = 'black_money', money = value}}
        for _, account in ipairs({'cash', 'money', 'bank', 'black_money'}) do
            expect(env.Framework.GetAccountBalance(account) == value,
                provider .. ': signed client ' .. account .. ' balance ' .. value)
        end
    end
end

do
    local data, now = nil, 0
    local env = load('modules/framework/es_extended/client.lua', function(env)
        env.GetGameTimer = function() return now end
        env.exports = {es_extended = {getSharedObject = function() return {
            GetPlayerData = function() return data end,
            IsPlayerLoaded = function() return data and data.identifier ~= nil end,
        } end}}
    end)
    local F = env.Framework
    for _, empty in ipairs({false, {}, 'not loaded'}) do
        data, now = empty or nil, now + 1001
        expect(F.GetPlayerIdentifier() == nil and F.GetPlayerDob() == nil, 'ESX identity is unavailable before character load')
        expect(F.GetPlayerMetaData('hunger') == nil, 'ESX missing metadata does not throw')
        expect(F.GetPlayerJobData() == nil and F.GetPlayerJob() == nil, 'ESX missing job does not throw')
        expect(F.GetIsPlayerDead() == false and F.GetAccountBalance('cash') == 0, 'ESX unloaded defaults remain safe')
    end
    data, now = {identifier = 'esx:A', metadata = {hunger = 42}, job = {name = 'police', label = 'Police', grade = 2}}, now + 1001
    expect(F.GetPlayerMetaData('hunger') == 42 and F.GetPlayerJob() == 'police', 'ESX loaded values remain available')
    env.handlers['esx:onPlayerLogout']()
    data = nil
    expect(F.GetPlayerJobData() == nil and F.GetPlayerIdentifier() == nil, 'ESX logout discards the old character')
end

print(('framework_client_state: %d assertions passed'):format(assertions))
