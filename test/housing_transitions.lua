-- Run from bridge root: lua test/housing_transitions.lua [root/]
local root, assertions = arg[1] or './', 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local event = 'concept_bridge:Server:_OnPlayerInside'
local normalized = 'concept_bridge:Client:OnPlayerInside'
local function fixture(provider)
    local state = {network = {}, localEvents = {}, events = {}, reads = {}, stopped = {}, players = {
        [5] = {name = 'sender', identifier = 'char5', ped = 105, bucket = 42},
        [7] = {name = 'victim', identifier = 'char7', ped = 107, bucket = 77},
    }}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.RegisterNetEvent = function(name, fn) state.network[name] = fn end
    env.AddEventHandler = function(name, fn) state.localEvents[name] = fn end
    env.GetResourceState = function(name)
        return state.stopped[name] or ((name == provider or name == 'qb-core') and 'started' or 'missing')
    end
    env.GetPlayerName = function(src) return state.players[src] and state.players[src].name end
    env.GetPlayerPed = function(src)
        state.reads[#state.reads + 1] = src
        return state.players[src] and state.players[src].ped or 0
    end
    env.GetPlayerRoutingBucket = function(src)
        state.reads[#state.reads + 1] = src
        return state.players[src].bucket
    end
    env.GetEntityCoords = function(ped) return {x = ped, y = 2, z = 3} end
    env.TriggerEvent = function(name, ...) state.events[#state.events + 1] = {name = name, args = table.pack(...)} end
    env.TriggerClientEvent = function() error('Housing must not broadcast the server-local notification') end
    env.Framework = {
        GetResourceName = function() return 'qb-core' end,
        GetPlayer = function(src) return state.players[src] end,
        GetPlayerIdentifier = function(src) return state.players[src] and state.players[src].identifier end,
    }
    assert(loadfile(root .. 'modules/housing/_default/server.lua', 't', env))()
    if provider then
        local directory = provider == 'qb-apartments' and 'qb-appartments' or provider
        assert(loadfile(root .. 'modules/housing/' .. directory .. '/server.lua', 't', env))()
    end
    env.source = 5
    local function published(src, id)
        local value = state.events[#state.events]
        expect(value and value.name == normalized and value.args.n == 4, 'preserve server-local event and four arguments')
        expect(value.args[1] == src and value.args[2] == id, 'correct player and property/exit')
        expect(value.args[3] == state.players[src].bucket and value.args[4].x == state.players[src].ped, 'server bucket/coordinates')
    end
    local function rejected(fn, ...)
        local count = #state.events
        local ok = pcall(fn, ...)
        expect(ok and #state.events == count, 'reject without exception or notification')
    end
    return env, state, published, rejected
end

do
    local env, state, published, rejected = fixture('bcs-housing')
    expect(env.Housing.GetResourceName() == 'bcs-housing', 'BCS adapter selected')
    expect(env.Housing.ObservePlayerInside(5, 'home', 'bcs-housing') == true, 'valid provider observation')
    published(5, 'home')
    state.events, state.reads = {}, {}
    expect(state.network[event]('property-123') == true, 'original one-argument request succeeds')
    published(5, 'property-123')
    for _, src in ipairs(state.reads) do expect(src == 5, 'all native player lookups use sender') end
    rejected(state.network[event], 7, 'property-victim')
    rejected(env.Housing.ObservePlayerInside, 7, 'property-victim', 'bcs-housing')
    for _, value in ipairs({true, {}, '', string.rep('x', 129), 'bad\nname', 0, -1, 1.5, math.huge, 0/0}) do
        rejected(state.network[event], value)
    end
    expect(state.network[event](123) == true, 'positive numeric property ID is not a source')
    published(5, 123)
    expect(state.network[event](false) == true, 'false exit accepted')
    published(5, false)
    expect(state.network[event]() == true, 'nil exit normalized')
    published(5, false)
    for _, src in ipairs({0, -1, 65536, 1.5, 'bad'}) do
        env.source = src
        rejected(state.network[event], 'home')
    end
    env.source = 0
    rejected(state.network[event], 7, 'home')
    expect(state.localEvents['concept_bridge:Server:PublishPlayerInside'](7, 'trusted') == true, 'local producer has explicit player interface')
    published(7, 'trusted')
    expect(state.network['concept_bridge:Server:PublishPlayerInside'] == nil, 'trusted local event is not network registered')
    env.source = 5
    rejected(state.localEvents['concept_bridge:Server:PublishPlayerInside'], 7, 'spoofed')
    expect(env.Housing.PublishPlayerInside(7, 'server-export') == true, 'trusted server API can choose its player')
    published(7, 'server-export')
    rejected(env.Housing.PublishPlayerInside, 99, 'missing-player')
    state.stopped['bcs-housing'] = 'stopped'
    rejected(state.network[event], 'home')
    state.stopped['bcs-housing'] = nil
    state.stopped['qb-core'] = 'stopped'
    rejected(state.network[event], 'home')
    state.stopped['qb-core'] = nil
    env.Framework.GetPlayer = function() return nil end
    rejected(state.network[event], 'home')
end

-- Provider payloads retain their native arguments but always publish sender 5.
for _, provider in ipairs({'qb-houses', 'qb-apartments', 'esx_property', 'ps-housing'}) do
    local env, state, published, rejected = fixture(provider)
    expect(env.Housing.GetResourceName() == provider, 'correct provider resource name')
    rejected(state.network[event], 'BCS-path-is-not-for-this-provider')
    if provider == 'qb-houses' then
        local fn = state.network['qb-houses:server:SetInsideMeta']
        fn('house-12', true)
        published(5, 'house-12')
        fn('house-12', false)
        published(5, false)
        rejected(fn, 'house-12', 'false')
        rejected(fn, {}, true)
        rejected(fn, false, true)
        rejected(fn, nil, true)
    elseif provider == 'qb-apartments' then
        local fn = state.network['qb-apartments:server:SetInsideMeta']
        fn('tower', 12, true, true)
        published(5, 'tower-12')
        fn(nil, nil, false, false)
        published(5, false)
        for _, args in ipairs({{{}, 'id', true}, {'tower', {}, true}, {'', 1, true}, {'tower', '', true},
            {'tower', math.huge, true}, {'tower', 'id', 'true'}, {'tower', 'id', true, 'true'}}) do
            rejected(fn, table.unpack(args))
        end
        local client = setmetatable({GetResourceState = env.GetResourceState}, {__index = _G})
        assert(loadfile(root .. 'modules/housing/qb-appartments/client.lua', 't', client))()
        expect(client.Housing.GetResourceName() == 'qb-apartments', 'client uses real apartment resource name')
    else
        local enter = provider == 'esx_property' and 'esx_property:enter' or 'ps-housing:server:enterProperty'
        local leave = provider == 'esx_property' and 'esx_property:leave' or 'ps-housing:server:leaveProperty'
        state.network[enter]('property-12')
        published(5, 'property-12')
        state.network[leave]('property-12')
        published(5, false)
        rejected(state.network[enter], nil)
        rejected(state.network[enter], false)
        rejected(state.network[enter], {})
    end
    state.stopped[provider] = 'stopped'
    rejected(env.Housing.ObservePlayerInside, 5, 'home', provider)
end

do
    local env, state, published, rejected = fixture('bcs-housing')
    local client = setmetatable({}, {__index = _G})
    local handlers = {}
    client.GetResourceState = env.GetResourceState
    client.RegisterNetEvent = function(name, fn) handlers[name] = fn end
    client.TriggerServerEvent = function(name, ...) return state.network[name](...) end
    assert(loadfile(root .. 'modules/housing/bcs-housing/client.lua', 't', client))()
    handlers['Housing:client:EnterHome']('bcs-home')
    published(5, 'bcs-home')
    handlers['Housing:client:DeleteFurnitures']()
    published(5, false)
    local original = env.Framework.GetPlayerIdentifier
    local reads = 0
    env.Framework.GetPlayerIdentifier = function(src)
        reads = reads + 1
        if reads == 2 then state.players[src].identifier = 'replacement' end
        return original(src)
    end
    rejected(state.network[event], 'home')
end

-- Capture source before a provider read changes global source; reject unloads.
do
    local env, state, published, rejected = fixture('bcs-housing')
    env.Framework.GetPlayer = function(src)
        env.source = 7
        return state.players[src]
    end
    expect(state.network[event]('home') == true, 'global source changes cannot redirect notification')
    published(5, 'home')
    env.source = 5
    env.Framework.GetPlayer = function(src)
        state.localEvents['concept_bridge:Server:OnPlayerUnload'](src)
        return state.players[src]
    end
    rejected(state.network[event], 'home')
end

do
    local env, state, published = fixture('bcs-housing')
    local reads = 0
    env.Framework.GetPlayer = function(src)
        reads = reads + 1
        if reads == 1 then coroutine.yield() end
        return state.players[src]
    end
    local pending = coroutine.create(function() return state.network[event]('home') end)
    expect(coroutine.resume(pending) and coroutine.status(pending) == 'suspended', 'actual provider read yields')
    env.source = 7
    local ok, accepted = coroutine.resume(pending)
    expect(ok and accepted == true, 'yielded observation keeps captured sender')
    published(5, 'home')
    reads, env.source, state.events = 0, 5, {}
    pending = coroutine.create(function() return state.network[event]('home') end)
    expect(coroutine.resume(pending), 'second observation starts')
    state.localEvents.playerDropped()
    ok, accepted = coroutine.resume(pending)
    expect(ok and accepted == false and #state.events == 0, 'disconnect during provider yield cancels publication')
end

do
    local env, state, published, rejected = fixture(nil)
    env.source = 0
    env.Framework = {GetResourceName = function() return 'default' end}
    expect(env.Housing.PublishPlayerInside('7', false) == true, 'standalone trusted publishing remains usable')
    published(7, false)
    rejected(state.network[event], 'home')
    env.GetEntityCoords = function() return {x = math.huge, y = 0, z = 0} end
    rejected(env.Housing.PublishPlayerInside, 7, 'home')
end

print(('housing_transitions: %d assertions passed'):format(assertions))
