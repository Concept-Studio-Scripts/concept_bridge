-- Run from bridge root: lua test/shell_access.lua [root/]
local root, assertions = arg[1] or './', 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local vector = {}
vector.__index = vector
local function vec(x, y, z) return setmetatable({x=x, y=y, z=z}, vector) end
vector.__add = function(a,b) return vec(a.x+b.x, a.y+b.y, a.z+b.z) end
vector.__sub = function(a,b) return vec(a.x-b.x, a.y-b.y, a.z-b.z) end
vector.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
local function noFunctions(value, seen)
    if type(value) == 'function' then return false end
    if type(value) ~= 'table' then return true end
    if rawget(value,'__cfx_functionReference') then return false end
    seen = seen or {}
    if seen[value] then return true end
    seen[value] = true
    for _, item in pairs(value) do if not noFunctions(item, seen) then return false end end
    return true
end
local function fixture()
    local env = setmetatable({}, {__index=_G})
    env._G, env.vector3 = env, vec
    local state = {events={}, handlers={}, sets=0, players={
        [7]={name='seven', bucket=42, coords=vec(10,0,0)},
        [8]={name='eight', bucket=17, coords=vec(100,0,0)},
    }}
    env.lib = {string={random=function() return 'generated' end}}
    env.RegisterNetEvent = function(name, fn) state.handlers[name]=fn end
    env.AddEventHandler = env.RegisterNetEvent
    env.RegisterCommand = function() end
    env.GetCurrentResourceName = function() return 'concept_bridge' end
    env.GetPlayerName = function(src) return state.players[src] and state.players[src].name end
    env.GetPlayerPed = function(src) return state.players[src] and src or 0 end
    env.GetEntityCoords = function(ped) return state.players[ped].coords end
    env.GetPlayerRoutingBucket = function(src) return state.players[src].bucket end
    env.SetPlayerRoutingBucket = function(src, bucket) state.sets=state.sets+1; state.players[src].bucket=bucket end
    env.TriggerClientEvent = function(name, src, ...) state.events[#state.events+1]={name=name, src=src, args=table.pack(...)} end
    env.print = function() end
    local api = assert(loadfile(root .. 'lib/shells/server/shells.lua', 't', env))()
    local function request(action, src, ...)
        env.source=src
        return state.handlers['concept_bridge:server:' .. action .. 'Shell'](...)
    end
    return env, state, api, request
end
local function data(id, bucket, onEnter, onExit)
    return {id=id, model='test_shell', coords=vec(0,0,100), bucket=bucket, onEnter=onEnter, onExit=onExit,
        interior={{id='door', type='exit', offset=vec(0,0,1), distance=2, meta={link='front'}}},
        exterior={{id='front', type='entrance', coords=vec(10,0,0), distance=2, meta={link='door'}}}}
end
do
    local env, state, api, request = fixture()
    local exits=0
    local input = data('denied',9001,function() return false end,function() exits=exits+1 end)
    local shell=api.Create(input)
    expect(shell and shell.bucket==9001 and api.BucketsInUse['9001'], 'constructor retains configured bucket and reserves it')
    expect(shell.onEnter==nil and shell.onExit==nil and noFunctions(state.events[1]), 'hooks stay private and creation is serializable')
    local before=#state.events
    expect(request('Enter',7,'denied','front')==false and state.sets==0 and #state.events==before, 'original denial hook now rejects without bucket/client effects')
    input.onEnter=function() return true end
    expect(request('Enter',7,'denied','front')==false, 'caller replacing its input hook cannot replace private policy')
    expect(exits==0 and api.Inside(7)==false, 'denial creates no membership or exit notification')
end
do
    local env, state, api, request = fixture()
    local entries, exits=0,0
    local shell=api.Create(data('a',8000,function(src,id) entries=entries+1; return src==7 and id=='a' end,function() exits=exits+1 end))
    api.Create(data('b'))
    local bad=api.New(data('bad',8000))
    expect(bad==nil and api.Get('a')==shell, 'bucket collision does not replace existing shell')
    local before=#state.events
    for _, args in ipairs({{}, {'missing','front'}, {'a',{}}, {{},'front'}, {'a','missing'}}) do
        expect(request('Enter',7,table.unpack(args))==false, 'malformed/unknown entry returns failure')
    end
    expect(state.sets==0 and #state.events==before, 'invalid public inputs have no mutation')
    expect(request('Enter',8,'a','front',7)==false and state.players[7].bucket==42, 'victim payload cannot select another source')
    state.players[7].coords=vec(12,0,0)
    expect(request('Enter',7,'a','front')==true and state.players[7].bucket==8000, 'server proximity boundary and permission allow entry')
    expect(api.ActivePlayers['7']=='a' and api.Inside(7)==shell and entries==1, 'membership records actual sender')
    expect(state.events[#state.events].args[2]=='door', 'server resolves exterior-to-interior link')
    local before=#state.events
    expect(request('Enter',7,'a','front')==true and #state.events==before and entries==1, 'repeat entry does not overwrite original bucket or respawn')
    expect(api.New(data('a',9000))==nil and api.Get('a')==shell, 'active shell cannot be overwritten')
    expect(request('Exit',8,'a','door')==false and state.players[8].bucket==17, 'non-member cannot exit')
    expect(request('Exit',7,'b','door')==false and request('Exit',7,'a',{})==false, 'wrong shell and malformed exit rejected')
    expect(request('Exit',7,'a','door')==false and state.players[7].bucket==8000, 'remote exit outside interior range rejected')
    state.players[7].coords=shell.interior.door.coords
    expect(request('Exit',7,'a','door')==true and state.players[7].bucket==42, 'valid exit restores original nonzero bucket')
    expect(api.ActivePlayers['7']==nil and api.Inside(7)==false and exits==1, 'exit clears membership and notifies private hook once')
    expect(state.events[#state.events].args[2]=='front', 'server resolves interior-to-exterior link')
    expect(request('Exit',7,'a','door')==false and exits==1, 'repeat exit has no membership to mutate')
    local replacement=api.New(data('a',9000))
    expect(replacement.bucket==9000 and not api.BucketsInUse['8000'] and api.BucketsInUse['9000'], 'inactive replacement releases old bucket reservation')
end
do
    local env, state, api, request = fixture()
    local exitCalls=0
    local deny=setmetatable({__cfx_functionReference='private-enter'}, {__metatable='private',__call=function() return false end})
    local finish=setmetatable({__cfx_functionReference='private-exit'}, {__call=function() exitCalls=exitCalls+1 end})
    local input=data('a',8000,deny,finish)
    input.exterior[1].meta.reference=deny
    expect(api.Create(input)~=nil and noFunctions(state.events[#state.events]), 'FiveM callable-table hooks are accepted without serializing references')
    expect(request('Enter',7,'a','front')==false and state.players[7].bucket==42, 'cross-resource denial hook is called privately')
    input.onEnter=setmetatable({__cfx_functionReference='private-allow'}, {__call=function() return true end})
    api.New(input)
    expect(api.Enter(7,'a','front')==true and api.Exit(7,'a')==true and exitCalls==1, 'cross-resource entry and exit callbacks keep callable semantics')
end
do
    local env, state, api, request = fixture()
    local shell=api.New(data('a',8000))
    shell.bucket=12
    expect(api.Enter(7,'a','front')==true and state.players[7].bucket==8000, 'entry uses configured private bucket, not mutable snapshot')
    api.Exit(7,'a')
    local replacement=api.New(data('a',8001))
    expect(replacement.bucket==8001 and api.BucketsInUse['8000']==nil, 'replacement releases privately owned bucket even if public snapshot changed')
end
do
    local env, state, api, request = fixture()
    local exited={}
    api.Create(data('a',8000,nil,function(_,id) exited[#exited+1]=id end))
    api.Create(data('b',8001,nil,function(_,id) exited[#exited+1]=id end))
    state.players[7].coords=vec(500,0,0)
    expect(api.Enter(7,'a','front')==true, 'trusted server API retains remote teleport capability')
    state.players[7].coords=vec(0,0,101)
    expect(api.Enter(7,'b','front')==true and api.ActivePlayers['7']=='b' and exited[1]=='a', 'direct shell switch retains single membership and exits prior shell')
    expect(api.Exit(7,'b')==true and state.players[7].bucket==42 and exited[2]=='b', 'switch exit restores first bucket')
    expect(state.events[#state.events].args[3].x==500, 'switch exit returns to original world position, not previous interior')
    expect(api.Enter(7,'a','front')==true, 'shell usable after exit')
    state.handlers['concept_bridge:Server:OnPlayerUnload'](7)
    expect(state.players[7].bucket==42 and api.ActivePlayers['7']==nil, 'character unload restores bucket and removes membership')
    before=#state.events
    state.handlers['concept_bridge:Server:OnPlayerUnload'](7)
    expect(#state.events==before, 'repeated unload has no stale shell state')
    api.Enter(8,'b','front')
    env.source=8
    state.handlers.playerDropped()
    expect(api.ActivePlayers['8']==nil and state.players[8].bucket==8001, 'disconnect clears state without routing a dropped source')
    api.Enter(7,'a','front')
    state.handlers.onResourceStop('other_resource')
    expect(api.ActivePlayers['7']=='a', 'unrelated resource stop does not clean shells')
    state.handlers.onResourceStop('concept_bridge')
    expect(state.players[7].bucket==42 and api.ActivePlayers['7']==nil and next(api.BucketsInUse)==nil, 'bridge stop restores bucket and clears reservations')
end
do
    local env, state, api, request = fixture()
    local entered=0
    api.Create(data('a',8000,function() error('provider failure') end))
    expect(request('Enter',7,'a','front')==false and state.players[7].bucket==42, 'authorization hook exception fails closed')
    api.New(data('a',8000,function() coroutine.yield(); return true end))
    local pending=coroutine.create(function() return request('Enter',7,'a','front') end)
    expect(coroutine.resume(pending) and coroutine.status(pending)=='suspended', 'permission hook may yield')
    expect(request('Enter',7,'a','front')==false, 'overlapping requests cannot commit two transitions')
    state.players[7].coords=vec(100,0,0)
    local ok, accepted=coroutine.resume(pending)
    expect(ok and accepted==false and state.players[7].bucket==42, 'distance is rechecked after yielding authorization')
    state.players[7].coords=vec(10,0,0)
    pending=coroutine.create(function() return request('Enter',7,'a','front') end)
    expect(coroutine.resume(pending), 'second authorization begins')
    state.handlers['concept_bridge:Server:OnPlayerUnload'](7)
    ok, accepted=coroutine.resume(pending)
    expect(ok and accepted==false and api.ActivePlayers['7']==nil, 'unload cancels pending shell entry')
    api.New(data('a',8000,nil,function() error('exit failure') end))
    api.Enter(7,'a','front')
    expect(api.Exit(7,'a')==true and state.players[7].bucket==42 and api.ActivePlayers['7']==nil, 'exit hook error cannot strand bucket or membership')
end
do
    local env, state, api, request = fixture()
    local input=data('a',8000,function() return false end)
    input.exterior[1].meta.nested={secret=function() end, label='kept'}
    expect(api.CreateBulk({input,data('b',8001)})==true, 'bulk creation reports success')
    expect(noFunctions(state.events[#state.events]) and state.events[#state.events].args[1].a.exterior.front.meta.nested.label=='kept', 'bulk snapshot strips functions but retains client metadata')
    env.source=7
    state.handlers.onPlayerJoining(7)
    expect(noFunctions(state.events[#state.events]) and state.events[#state.events].src==7, 'join snapshot stays client-safe')
    api.AddObjects('a',{interior={{id='extra',type='none',coords=vec(0,0,100),meta={callback=function() end}}}})
    expect(noFunctions(state.events[#state.events]), 'object update cannot serialize callback functions')
    api.Get('a').exterior.front.meta.link='missing'
    expect(request('Enter',7,'a','front')==false, 'missing linked interior cannot authorize entry')
end

local function orderedBatch(...)
    local entries=table.pack(...)
    return setmetatable({}, {__pairs=function()
        local index=0
        return function()
            index=index+1
            if index<=entries.n then return index, entries[index] end
        end
    end})
end

do
    local env, state, api = fixture()
    local accepted, reason=api.CreateBulk(orderedBatch(data('created',8000,function() return true end),data('blocked',8000)))
    expect(accepted==false and reason=='bucket_in_use', 'bulk failure preserves the constructor reason')
    expect(api.Get('created') and not api.Get('blocked'), 'bulk failure keeps only successfully registered shells')
    local broadcast=state.events[#state.events]
    expect(broadcast and broadcast.name=='concept_bridge:client:CreateShells' and broadcast.src==-1 and
        broadcast.args[1].created and not broadcast.args[1].blocked and noFunctions(broadcast),
        'already connected clients receive successful shells before a later bulk failure')
    env.source=7
    state.handlers.onPlayerJoining(7)
    local joined=state.events[#state.events].args[1]
    expect(joined.created and not joined.blocked, 'late joiners receive the same shell definitions after a partial failure')
end

do
    local _, state, api = fixture()
    local accepted, reason=api.CreateBulk({data('invalid',-1)})
    expect(accepted==false and reason=='invalid_bucket' and #state.events==0 and next(api.All)==nil,
        'failure before any shell is created has no client broadcast or registration')
end

do
    local _, state, api = fixture()
    local invalid=data('invalid',8001)
    invalid.model=nil
    local ok, reason=pcall(api.CreateBulk,orderedBatch(data('created',8000),invalid))
    expect(not ok and tostring(reason):find('shellModel',1,true), 'bulk constructor errors retain their existing failure behavior')
    local broadcast=state.events[#state.events]
    expect(broadcast and broadcast.args[1].created and not broadcast.args[1].invalid and api.Get('created'),
        'constructor errors also publish earlier successful registrations before propagating')
end

-- Client coordinate cleanup for direct switches and resource stop uses root world
-- position. Native graphics/entities are doubled; actual client shell code runs.
do
    local env=setmetatable({}, {__index=_G})
    env._G, env.vector3=env, vec
    local handlers, coords, zones, registered={},vec(10,0,0),{},{}
    local entity={
        Register=function(value)
            local point={id=value.id,spawned=1}
            registered[value.id]=value
            if value.OnSpawn then value.OnSpawn(point) end
            return point
        end,
        Unregister=function(id)
            local value=registered[id]
            if value and value.OnRemove then value.OnRemove({id=id,spawned=1}) end
            registered[id]=nil
        end,
    }
    env.Target={AddBoxZone=function(id) zones[id]=true end,RemoveZone=function(id) zones[id]=nil end}
    env.lib={require=function(name)
        if name:find('client_entity',1,true) then return entity end
        return assert(loadfile(root .. 'lib/shells/client/config.lua','t',env))()
    end}
    env.RegisterNetEvent=function(name,fn) handlers[name]=fn end
    env.AddEventHandler=env.RegisterNetEvent
    env.GetCurrentResourceName=function() return 'concept_bridge' end
    env.PlayerPedId=function() return 7 end
    env.GetEntityCoords=function() return coords end
    env.SetEntityCoords=function(_,x,y,z) coords=vec(x,y,z) end
    env.DoScreenFadeOut,env.DoScreenFadeIn,env.Wait,env.FreezeEntityPosition=function() end,function() end,function() end,function() end
    env.print=function() end
    assert(loadfile(root .. 'lib/shells/client/shells.lua','t',env))()
    local function shell(id,height)
        return {id=id,model='test',coords=vec(0,0,height),exterior={front={id=id..'-front',type='entrance',coords=vec(10,0,0),rotation=vec(0,0,0),distance=2}},
            interior={door={id=id..'-door',type='exit',coords=vec(0,0,height),rotation=vec(0,0,0),distance=2}}}
    end
    env.Shells.New(shell('a',100)); env.Shells.New(shell('b',200))
    expect(zones['a-front'] and zones['b-front'], 'shell creation exposes both exterior entrances')
    env.Shells.Enter('a','door')
    expect(not zones['a-front'] and zones['a-door'], 'entry swaps the current shell entrance for its interior exit')
    env.Shells.Enter('b','door')
    expect(zones['a-front'] and not zones['a-door'] and not zones['b-front'] and zones['b-door'], 'direct switch restores the old exterior and clears only its interior points')
    expect(env.Shells.Inside()=='b' and coords.z==200, 'client direct switch renders destination')
    handlers.onResourceStop('concept_bridge')
    expect(coords.x==10 and coords.z==0, 'client resource stop returns to first world position')
    handlers['concept_bridge:client:ExitShell']('b','front',vec(12,0,0))
    expect(coords.x==12 and env.Shells.Inside()==false, 'server-supplied root return coordinates override nested exterior')
    expect(zones['a-front'] and zones['b-front'] and not zones['b-door'], 'final exit leaves both shell entrances available')
end
print(('shell_access: %d assertions passed'):format(assertions))
