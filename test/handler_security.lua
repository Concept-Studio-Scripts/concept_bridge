-- Actual server adapters and domain guards; no game/server state is touched.
-- Run from the bridge root: lua test/handler_security.lua.
local assertions = 0
local function expect(value, message) assertions = assertions + 1 assert(value, message) end

local function fixture(domain, provider)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local state = {now = 1000, handlers = {}, callbacks = {}, network = {}, effects = {}, resources = {},
        characters = {[7] = 'victim', [8] = 'actor', [9] = 'officer'}, connected = {[7] = true, [8] = true, [9] = true},
        framework = 'qb-core', reads = 0, roster = {7, 7, 9}}
    state.resources['qb-core'], state.resources[provider] = 'started', 'started'
    env.GetGameTimer = function() return state.now end
    env.GetPlayerName = function(src) return state.connected[src] and ('player:' .. src) or nil end
    env.GetPlayerIdentifierByType = function(src) return 'license:' .. src end
    env.GetResourceState = function(name) return name == 'default' and 'missing' or state.resources[name] or 'missing' end
    env.GetCurrentResourceName = function() return 'concept_bridge' end
    env.GetInvokingResource = function() return 'consumer' end
    env.GetPlayerPed = function(src) return src * 10 end
    env.GetPlayers = function() return {} end
    env.AddEventHandler = function(name, fn)
        local handle = {name = name, fn = fn}
        state.handlers[#state.handlers + 1] = handle
        return handle
    end
    env.RegisterNetEvent = function(name, fn)
        state.network[name] = true
        if fn then return env.AddEventHandler(name, fn) end
    end
    env.RegisterCommand, env.CreateThread = function() end, function() end
    local function pause(phase)
        if state.pause == phase then state.pause = nil coroutine.yield(phase) end
    end
    env.Framework = {
        GetResourceName = function() return state.framework end,
        GetPlayer = function(src) return state.characters[src] and {} or nil end,
        GetPlayerIdentifier = function(src)
            state.identifierReads = (state.identifierReads or 0) + 1
            if state.identifierReads == state.pauseIdentifierAt then coroutine.yield('identity') end
            return state.characters[src]
        end,
        GetPlayersByJob = function() pause('roster') return state.roster end,
    }
    if domain ~= 'Framework' then env[domain] = {GetResourceName = function() return provider end} end
    env.GlobalState, env.Bridge = {}, {Framework = env.Framework}
    env.lib = {callback = {register = function(name, fn) state.callbacks[name] = fn end}}
    local loaded = {}
    local function loadModule(path)
        local file = assert(io.open(path, 'r'))
        local source = file:read('a') file:close()
        source = source:gsub('`[^`]+`', '123')
        return assert(load(source, '@' .. path, 't', env))()
    end
    env.lib.require = function(name)
        local path = name:gsub('^@[^.]+%.', ''):gsub('%.', '/') .. '.lua'
        if not loaded[path] then loaded[path] = loadModule(path) end
        return loaded[path]
    end
    local function effect(kind, actor, data)
        state.effects[#state.effects + 1] = {kind = kind, actor = actor, data = data}
        return true
    end
    local function phone(src)
        pause('phone')
        return 'phone:' .. src
    end
    env.exports = {
        okokPhone = {
            getEmailAddressFromSource = function(_, src) pause('phone') return 'owner' .. src .. '@example.com' end,
            sendEmail = function(_, data) return effect('email', data.sender, data) end,
        },
        ['qb-phone'] = {sendNewMailToOffline = function(_, identifier, data) return effect('email', identifier, data) end},
        yseries = {GetPhoneNumberBySourceId = function(_, src) return phone(src) end,
            SendMail = function(_, data, _, number) effect('email', number, data) return 1, true end},
        ['lb-phone'] = {GetEquippedPhoneNumber = function(_, src) return phone(src) end,
            GetEmailAddress = function(_, number) return number .. '@example.com' end,
            SendMail = function(_, data) return effect('email', data.to, data) end},
        ['lb-tablet'] = {AddDispatch = function(_, data) return effect('dispatch', nil, data) end},
        piotreq_gpt = {SendAlert = function(_, src, data) return effect('dispatch', src, data) end},
        ['qb-core'] = {GetCoreObject = function() return {Functions = {}} end},
        es_extended = {getSharedObject = function() return {} end},
        ox_inventory = {registerUsableItem = function(_, _, callback) state.usable = callback end},
    }
    env.require = function() return {GetPlayer = env.Framework.GetPlayer} end
    env.TriggerClientEvent = function(name, target, data) return effect(name, target, data) end
    env.TriggerEvent = function(name, ...)
        local args = table.pack(...)
        if name == 'redutzu-mdt:server:addDispatchToMDT' or name == 'emergencydispatch:emergencycall:new' then
            effect('dispatch', nil, args[1])
        end
        for _, handle in ipairs({table.unpack(state.handlers)}) do
            if handle.name == name then handle.fn(table.unpack(args, 1, args.n)) end
        end
    end
    local function fire(name, sender, ...)
        env.source = sender
        local result
        for _, handle in ipairs({table.unpack(state.handlers)}) do
            if handle.name == name then result = table.pack(handle.fn(...)) end
        end
        return result and table.unpack(result, 1, result.n)
    end
    return env, state, loadModule, fire
end

local function emailFixture(provider)
    local env, state, loadModule, fire = fixture('Phone', provider)
    loadModule('modules/phone/' .. provider .. '/server.lua')
    local function request(data, extra)
        if provider == 'okokPhone' then
            if extra then return state.callbacks['concept_bridge:Callback:okokPhone:sendEmail'](8, data.email, data.title, data.message, extra) end
            return state.callbacks['concept_bridge:Callback:okokPhone:sendEmail'](8, data.email, data.title, data.message)
        end
        return fire('concept_bridge:Server:genericEmail', 8, data)
    end
    return env, state, request, fire
end
local email = {email = 'recipient@example.com', title = 'Subject', message = 'Body\nsecond line', src = 7}
local own = {okokPhone = 'owner8@example.com', ['qb-phone'] = 'actor', yseries = 'phone:8', ['lb-phone'] = 'phone:8@example.com'}
for _, provider in ipairs({'okokPhone', 'qb-phone', 'yseries', 'lb-phone'}) do
    local env, state, request, fire = emailFixture(provider)
    expect(request(email) == true and #state.effects == 1 and state.effects[1].actor == own[provider],
        provider .. ' legitimate network email keeps the real sender/recipient and cannot choose victim source')
    expect(request(email) == false and #state.effects == 1, provider .. ' repeated network email is rate limited')
    expect(env.Phone.SendEmail(7, email.email, email.title, email.message, true) == true and #state.effects == 2,
        provider .. ' trusted server export remains callable without network limits')
    state.now = state.now + 5000
    expect(request({email = {}, title = 'x', message = 'x'}) == false and #state.effects == 2,
        provider .. ' malformed email causes no provider effects')
    expect(request({email = email.email, title = string.rep('x', 257), message = 'x'}) == false,
        provider .. ' oversized title is rejected')
    expect(request({email = email.email, title = 'x', message = 'x\0x'}) == false,
        provider .. ' control/binary input is rejected')
    fire('playerDropped', 8)
    state.characters[8] = nil
    expect(request(email) == false and #state.effects == 2, provider .. ' unloaded players cannot send')
end

for _, provider in ipairs({'qb-phone', 'yseries', 'lb-phone'}) do
    local env, state, request = emailFixture(provider)
    if provider == 'qb-phone' then state.pauseIdentifierAt = 3 else state.pause = 'phone' end
    local pending = coroutine.create(function() request(email) end)
    expect(coroutine.resume(pending) and coroutine.status(pending) == 'suspended', provider .. ' provider lookup can yield')
    state.characters[8] = 'new-character'
    expect(coroutine.resume(pending) and #state.effects == 0, provider .. ' lookup cannot send after a character change')
end

do
    local env, state, request, fire = emailFixture('okokPhone')
    state.pause = 'phone'
    local pending = coroutine.create(function() request(email) end)
    assert(coroutine.resume(pending))
    env.source = 7
    expect(coroutine.resume(pending) and #state.effects == 1 and state.effects[1].actor == own.okokPhone,
        'a changed event source global does not change the captured email actor')
    state.now = state.now + 5000
    env.exports.okokPhone.getEmailAddressFromSource = function() error('provider failed') end
    expect(request(email) == false and #state.effects == 1, 'lookup errors have no send effect and do not escape')
    fire('concept_bridge:Server:OnPlayerUnload', 0, 8)
    expect(request(email) == false, 'forwarded unload cannot refill the email quota')
    state.now = 0
    env.exports.okokPhone.getEmailAddressFromSource = function() return 'owner8@example.com' end
    expect(request(email) == true, 'native clock wrap does not wedge the request limit')
end

for _, change in ipairs({'character', 'drop', 'provider', 'refresh'}) do
    local env, state, request, fire = emailFixture('okokPhone')
    state.pause = 'phone'
    local pending = coroutine.create(function() request(email) end)
    expect(coroutine.resume(pending) and coroutine.status(pending) == 'suspended', 'email lookup can yield')
    env.source = 7
    if change == 'character' then state.characters[8] = 'new-character'
    elseif change == 'drop' then fire('playerDropped', 8)
    elseif change == 'provider' then state.resources.okokPhone = 'stopped'
    else env.TriggerEvent('Bridge:Refresh', 'Phone', {}, 2, 'concept_bridge') end
    expect(coroutine.resume(pending) and #state.effects == 0, 'email ' .. change .. ' during lookup cannot send as the successor')
end

do
    local _, state, request = emailFixture('okokPhone')
    expect(request(email, 7) == false and #state.effects == 0, 'email callback rejects injected extra target arguments')
end

local alert = {message = 'An alert', code = '10-80', coords = {x = 10, y = 20, z = 30},
    jobs = {'police', 'police'}, time = 100000, blipData = {sprite = 161, color = 1, scale = 0.8}}
local tablet = {priority = 'high', code = '10-80', title = 'Title', description = 'Description',
    location = {label = 'Street', coords = {x = 10, y = 20}}, time = 300, job = 'police'}
local function dispatchFixture(provider)
    local env, state, loadModule, fire = fixture('Dispatch', provider)
    loadModule('settings/serverConfig.lua')
    local path = provider == 'default' and '_default' or provider
    loadModule('modules/dispatch/' .. path .. '/server/server.lua')
    local name = provider == 'default' and 'concept_bridge:Server:DispatchAlert'
        or provider == 'piotreq_gpt' and 'concept_bridge:Server:piotreq_gpt' or 'concept_bridge:server:dispatch:sendAlert'
    return env, state, fire, name, provider == 'lb-tablet' and tablet or alert
end
do
    local env, state, fire, event, data = dispatchFixture('default')
    env.BridgeServerConfig.CanSendDispatch = function() error('must not run for server-local dispatch') end
    fire(event, 0, data)
    expect(#state.effects == 2, 'trusted server-local fallback dispatch preserves the relay contract')
    state.effects = {}
    env.BridgeServerConfig.CanSendDispatch = function() return true end
    state.pause = 'roster'
    local pending = coroutine.create(function() fire(event, 8, data) end)
    assert(coroutine.resume(pending))
    state.characters[8] = 'next'
    expect(coroutine.resume(pending) and #state.effects == 0, 'fallback fanout rechecks the actor after a yielding roster read')
end

for _, provider in ipairs({'default', 'lb-tablet', 'redutzu-mdt', 'emergencydispatch', 'piotreq_gpt'}) do
    local env, state, fire, event, data = dispatchFixture(provider)
    expect(fire(event, 8, data) == false and #state.effects == 0, provider .. ' client dispatch is denied by default')
    expect(env.BridgeServerConfig.CanSendDispatch == nil, provider .. ' no general player permission policy is installed')
    env.BridgeServerConfig.CanSendDispatch = function(src, selected, checked)
        state.approval = {src = src, provider = selected, code = checked.code}
        local incident = state.incident
        return incident ~= nil and incident.src == src and incident.provider == selected and incident.code == checked.code
    end
    state.now = state.now + 5000
    expect(fire(event, 8, data) == false and #state.effects == 0, provider .. ' gameplay policy rejects a report without a server incident')
    state.incident = {src = 8, provider = provider, code = data.code}
    state.now = state.now + 5000
    fire(event, 8, data)
    expect(state.approval.src == 8 and state.approval.provider == provider and state.approval.code == data.code,
        provider .. ' gameplay policy receives the actual caller, provider and validated report')
    local count = #state.effects
    expect(count == (provider == 'default' and 2 or 1), provider .. ' authorized alert preserves provider flow and deduplicates recipients')
    expect(fire(event, 8, data) == false and #state.effects == count, provider .. ' dispatch spam has no effects')
    state.now = state.now + 5000
    expect(fire(event, 8, {message = 'x', coords = {x = 0/0, y = 1, z = 1}}) == false and #state.effects == count,
        provider .. ' invalid coordinates do not reach providers')
    if provider == 'piotreq_gpt' then env.Dispatch.SendAlert(7, alert) else env.Dispatch.SendAlert(data) end
    expect(#state.effects > count, provider .. ' trusted server dispatch remains available')
end

for _, change in ipairs({'character', 'stop', 'refresh', 'error'}) do
    local env, state, fire, event, data = dispatchFixture('lb-tablet')
    env.BridgeServerConfig.CanSendDispatch = function(src, provider, checked)
        expect(src == 8 and provider == 'lb-tablet' and checked.description == tablet.description,
            'hook receives validated existing dispatch payload')
        if change == 'error' then error('policy failed') end
        coroutine.yield('authorize')
        return true
    end
    local pending = coroutine.create(function() fire(event, 8, data) end)
    expect(coroutine.resume(pending), 'authorization errors do not escape the network handler')
    if change ~= 'error' then
        if change == 'character' then state.characters[8] = 'next'
        elseif change == 'stop' then state.resources['lb-tablet'] = 'stopped'
        else env.TriggerEvent('Bridge:Refresh', 'Dispatch', {}, 2, 'concept_bridge') end
        expect(coroutine.resume(pending), 'yielding authorization completes safely')
    end
    expect(#state.effects == 0, change .. ' during dispatch authorization fails closed')
end

do
    local env, state, loadModule, fire = fixture('Dispatch', 'lb-tablet')
    loadModule('settings/serverConfig.lua')
    loadModule('modules/dispatch/_default/server/server.lua')
    loadModule('modules/dispatch/lb-tablet/server/server.lua')
    env.BridgeServerConfig.CanSendDispatch = function() return true end
    expect(fire('concept_bridge:Server:DispatchAlert', 8, alert) == false and #state.effects == 0,
        'default relay cannot bypass the selected dispatch provider')
    fire('concept_bridge:Server:DispatchAlert', 0, alert)
    expect(#state.effects == 2 and state.effects[1].kind == 'concept_bridge:Client:DispatchAlert',
        'trusted server-local fallback relay retains its behavior with another active provider')
end

for _, provider in ipairs({'qb-clothing', 'illenium-appearance', 'fivem-appearance', 'esx_skin'}) do
    local env, state, loadModule, fire = fixture('Clothing', provider)
    loadModule('modules/clothing/' .. provider .. '/server.lua')
    env.Clothing.GetAppearance = function(src)
        state.reads, state.readSource = state.reads + 1, src
        if state.pause then state.pause = nil coroutine.yield('appearance') end
        return {model = 123, components = {{component_id = 1, drawable = 2, texture = 0}}}
    end
    local callback = state.callbacks['concept_bridge:cb:GetAppearance']
    expect(callback(8).model == 123 and state.readSource == 8, provider .. ' appearance callback reads only its caller')
    expect(callback(8, 7) == nil and state.reads == 1, provider .. ' target injection is rejected before a read')
    state.pause = true
    local pending = coroutine.create(function() expect(callback(8) == nil, provider .. ' stale appearance reply is discarded') end)
    assert(coroutine.resume(pending))
    state.characters[8] = 'next'
    expect(coroutine.resume(pending), provider .. ' character swap during database read is safe')
    state.now = state.now + 1000
    env.Clothing.GetAppearance = function() return {nested = {__cfx_functionReference = 'unsafe'}} end
    expect(callback(8) == nil, provider .. ' appearance replies cannot forward callable references')
end

do
    local env, state, loadModule, fire = fixture('Clothing', 'default')
    loadModule('modules/clothing/_default/server.lua')
    local answer = {model = 123, components = {}}
    env.lib.callback.await = function(name, target, ...)
        expect(name == 'concept_bridge:cb:GetAppearance' and target == 8 and select('#', ...) == 0,
            'trusted appearance read preserves ox_lib target and arguments')
        return answer
    end
    local result = env.Clothing.GetAppearance(8)
    expect(result.model == 123 and result ~= answer, 'client appearance response is copied as bounded data')
    answer.cycle = answer
    expect(env.Clothing.GetAppearance(8) == nil, 'cyclic client appearance is rejected')
    answer = {payload = string.rep('x', 8193)}
    expect(env.Clothing.GetAppearance(8) == nil, 'oversized appearance is rejected')
    answer = {bad = math.huge}
    expect(env.Clothing.GetAppearance(8) == nil, 'non-finite appearance data is rejected')
end

for _, provider in ipairs({'ox_core', 'es_extended'}) do
    local env, state, loadModule, fire = fixture('Framework', provider)
    state.framework, state.resources[provider] = provider, 'started'
    local getPlayer, getIdentifier = env.Framework.GetPlayer, env.Framework.GetPlayerIdentifier
    local api = loadModule('modules/framework/' .. provider .. '/server.lua')
    env.Framework, env.Bridge.Framework = api, api
    api.GetPlayer, api.GetPlayerIdentifier = getPlayer, getIdentifier
    api.GetFrameworkJobs = function() state.reads = state.reads + 1 return {police = {label = 'Police'}} end
    local registry = state.callbacks['concept_bridge:Callback:GetFrameworkJobs']
    expect(registry(8).police.label == 'Police', provider .. ' public registry retains its return shape')
    expect(next(registry(8, 7)) == nil and state.reads == 1, provider .. ' registry rejects unexpected payloads')
    state.characters[8] = nil
    expect(registry(8).police ~= nil, provider .. ' public definitions remain available before character selection')
    state.characters[8] = 'actor'
    if provider == 'ox_core' then
        local actors = {}
        api.GetAccountBalance = function(src, account)
            state.reads = state.reads + 1
            actors[#actors + 1] = src
            if state.pause then state.pause = nil coroutine.yield('balance') end
            return account == 'bank' and 200 or 100
        end
        local balance = state.callbacks['concept_bridge:Callback:GetAccountBalance']
        expect(balance(8, 'cash') == 100 and balance(8, 'money') == 100 and balance(8, 'bank') == 200,
            'normal consumer cash/money/bank burst remains supported')
        expect(actors[1] == 8 and balance(8, 'bank', 7) == nil, 'account target is source-bound and cannot be injected')
        expect(balance(8, {}) == nil, 'invalid account cannot reach the provider')
        state.now, state.pause = state.now + 1000, true
        local pending = coroutine.create(function() expect(balance(8, 'bank') == nil, 'old-character account result is discarded') end)
        assert(coroutine.resume(pending))
        fire('playerDropped', 8)
        env.source, state.characters[8] = 7, 'new-character'
        expect(coroutine.resume(pending), 'source reuse cannot inherit an account response')
        local calls = state.reads
        for _ = 1, 12 do balance(8, 'bank') end
        expect(state.reads - calls == 8, 'bank read abuse is bounded while allowing ordinary read bursts')
        local uses = 0
        api.RegisterUsableItem('pda', function(src, item)
            uses = uses + 1
            expect(src == 8 and item.name == 'pda', 'trusted fallback item callback retains source/item shape')
        end)
        expect(not state.network['ox_core:useItem:pda'], 'inventory-less OX item use is not network-registered')
        fire('ox_core:useItem:pda', 8, 7, {name = 'pda'})
        expect(uses == 0, 'client cannot invoke fallback usable-item callback for any player')
        fire('ox_core:useItem:pda', 0, 8, {name = 'pda'})
        expect(uses == 1, 'trusted server fallback invokes the item once')
        state.resources.ox_inventory = 'started'
        api.RegisterUsableItem('pda', function(src) expect(src == 8, 'native inventory registration retains callback arguments') end)
        expect(type(state.usable) == 'function', 'native OX inventory usable items remain dependency-owned')
        state.usable(8, {name = 'pda', slot = 2})
    else
        api.ItemList = function() return {Items = {water = {name = 'water'}}} end
        expect(state.callbacks['concept_bridge:Callback:GetFrameworkItems'](8).Items.water.name == 'water',
            'ESX item definitions have an independent request budget from jobs')
    end
end

do
    local _, state, request = emailFixture('okokPhone')
    expect(request({email = email.email, title = '', message = ''}) == true and #state.effects == 1,
        'bounded empty subject/body strings retain the existing email contract')
    local dispatchEnv, dispatchState, fire, event = dispatchFixture('lb-tablet')
    dispatchEnv.BridgeServerConfig.CanSendDispatch = function() return true end
    local data = {priority = 'high', code = '10-80', title = 'Title', description = '',
        location = {label = '', coords = {x = 10, y = 20}}, time = 300}
    fire(event, 8, data)
    expect(#dispatchState.effects == 1, 'an unavailable street label or empty description does not break valid tablet alerts')
end

-- Evaluate the real manifest DSL; check client packfile visibility independently
-- of whether the server configuration is still loaded by the server.
do
    local client, server = {}, {}
    local groups = {files = client, file = client, client_scripts = client, client_script = client,
        shared_scripts = client, shared_script = client, server_scripts = server, server_script = server}
    local manifest = setmetatable({}, {__index = function(_, key)
        return function(entries)
            local target = groups[key]
            if not target then return end
            if type(entries) == 'string' then entries = {entries} end
            for _, path in ipairs(entries) do target[#target + 1] = path end
        end
    end})
    assert(loadfile('fxmanifest.lua', 't', manifest))()
    local function included(patterns, path)
        for _, pattern in ipairs(patterns) do
            pattern = pattern:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1')
                :gsub('%*%*', '\1'):gsub('%*', '[^/]*'):gsub('\1', '.*')
            if path:match('^' .. pattern .. '$') then return true end
        end
        return false
    end
    expect(included(server, 'settings/serverConfig.lua') and not included(client, 'settings/serverConfig.lua'),
        'server authorization/logging config is loaded server-side but excluded from client downloads')
    expect(included(client, 'settings/clientConfig.lua') and included(client, 'settings/sharedConfig.lua'),
        'client/shared configuration remains available to clients')
end

print(('handler_security: %d assertions passed'):format(assertions))
