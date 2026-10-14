-- Run from bridge root: lua test/provider_selection.lua.
-- Actual resolver and adapter source, with native/provider doubles only.
local assertions = 0
local function expect(value, message) assertions = assertions + 1 assert(value, message) end
local catalog = assert(loadfile('lib/providers/shared/catalog.lua'))()
local function definition(name)
    for _, item in ipairs(catalog) do if item.name == name then return item end end
    error('unknown domain: ' .. name)
end
local function fixture(definitions, side, actual, initial, runtimeLoader)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local state = {resources = initial or {}, handlers = {}, callbacks = {}, registrations = {},
        emitted = {}, bags = {}, errors = {}, version = '2.0.0', files = {}, failures = {}, threads = {}, exported = {}}
    env.BridgeSharedConfig = {Providers = {}, DebugLevel = 0, Notify = 'auto', HelpText = 'auto', Skills = 'auto'}
    env.BridgeClientConfig = {Seatbelt = 'auto', Voice = 'auto', InputSystem = 'auto', MenuSystem = 'auto', ProgressBarSystem = 'auto'}
    env.GlobalState, env.LocalPlayer = {}, {state = {isLoggedIn = true, proximity = {distance = 3}}}
    env.GetCurrentResourceName = function() return 'concept_bridge' end
    env.GetResourceState = function(name) return state.resources[name] or 'missing' end
    env.GetResourceMetadata = function() return state.version end
    env.GetPlayerServerId, env.PlayerId = function() return 7 end, function() return 0 end
    env.IsDuplicityVersion = function() return side == 'server' end
    env.CreateThread = function(fn) state.threads[#state.threads + 1] = fn end
    env.Wait, env.SetTimeout, env.RegisterCommand = function() end, function() end, function() end
    env.AddEventHandler = function(name, fn)
        local handle = {name = name, fn = fn}
        state.handlers[#state.handlers + 1] = handle
        return handle
    end
    env.RegisterNetEvent = function() end
    env.RemoveEventHandler = function(handle) handle.removed = true end
    env.AddStateBagChangeHandler = function(key, bag, fn)
        local handle = {key = key, bag = bag, fn = fn}
        state.bags[#state.bags + 1] = handle
        return handle
    end
    env.RemoveStateBagChangeHandler = function(handle) handle.removed = true end
    env.TriggerEvent = function(name, ...)
        state.emitted[#state.emitted + 1] = {name = name, args = table.pack(...)}
    end
    env.TriggerClientEvent = function() end
    env.print = function(message) state.errors[#state.errors + 1] = message end
    env.locale = function(key) return key end
    env.lib = {callback = {register = function(name, fn)
        state.registrations[name] = (state.registrations[name] or 0) + 1
        state.callbacks[name] = fn
    end}}
    local loaded = {}
    env.lib.require = function(name)
        local path = name:gsub('^@[^.]+%.', ''):gsub('%.', '/') .. '.lua'
        if not loaded[path] then loaded[path] = assert(loadfile(path, 't', env))() end
        return loaded[path]
    end
    local items = {water = {name = 'water', label = 'Water', weight = 10, unique = false}}
    env.Framework = {Shared = {Items = items}, ItemList = function() return {Items = items} end}
    local core = {Shared = {Items = items, Jobs = {}}, Functions = {}, Commands = {}}
    env.exports = setmetatable({
        ['qb-core'] = {GetCoreObject = function() return core end},
        es_extended = {getSharedObject = function() return {} end},
        qbx_core = {}, ox_inventory = {Items = function(_, name) return name and items[name] or items end},
        ['qs-inventory'] = {GetItemList = function() return items end},
        ['qb-inventory'] = {},
        concept_seatbelt = {IsBuckled = function() return true end},
    }, {__call = function(_, name, fn) state.exported[name] = fn end})
    env.require = function() return {} end
    for _, item in ipairs(definitions) do
        for fileSide, path in pairs(item.defaults) do
            state.files[path] = {domain = item.name, resource = 'default'}
        end
        for _, candidate in ipairs(item.candidates) do
            for _, fileSide in ipairs({'client','server'}) do
                if candidate[fileSide] then state.files[candidate[fileSide]] = {domain = item.name, resource = candidate.resource} end
            end
        end
    end
    env.LoadResourceFile = function(resource, path)
        if resource ~= 'concept_bridge' then return nil end
        if state.pause == path then state.pause = nil coroutine.yield() end
        if actual then
            local file = assert(io.open(path, 'r'))
            local source = file:read('a') file:close()
            -- Only FiveM hash literals are translated for stock Lua fixtures.
            source = source:gsub('`[^`]+`', '123')
            source = source:gsub('([%w_]+%.[%w_]+)%?%.([%w_]+)', '(%1 and %1.%2)')
            source = source:gsub('menu%[id%]%?%.options%?%[selected%]%?%.params',
                '(menu[id] and menu[id].options and menu[id].options[selected] and menu[id].options[selected].params)')
            return source
        end
        local file = assert(state.files[path], path)
        local name, provider = file.domain, file.resource
        local body = ('%s = %s or {}\n%s.GetResourceName = function() return %q end\n'):format(name,name,name,provider)
        body = body .. ('%s.Read = function() return %q end\n'):format(name,provider)
        if provider ~= 'default' then
            body = body .. ('%s[%q] = function() return %q end\n'):format(name, 'Only_' .. provider, provider)
            body = body .. ('AddEventHandler(%q, function() TriggerEvent("fixture:seen", %q) end)\n'):format('fixture:' .. name,provider)
        end
        body = body .. ('lib.callback.register(%q, function() return %q end)\n'):format('fixture:' .. name,provider)
        if state.failures[path] == 'runtime' then body = body .. 'error("provider initialization failed")\n' end
        if state.failures[path] == 'malformed' then return body .. 'return true\n' end
        return body .. 'return ' .. name
    end
    local resolver
    if runtimeLoader then
        assert(loadfile('modules/providers/' .. side .. '.lua', 't', env))()
        resolver = env.ProviderResolver
    else
        resolver = assert(loadfile('lib/providers/shared/resolver.lua', 't', env))().New(definitions, side)
    end
    local function fire(name, ...)
        local handlers = {table.unpack(state.handlers)}
        for _, handle in ipairs(handlers) do if not handle.removed and handle.name == name then handle.fn(...) end end
    end
    local function lifecycle(provider, running)
        state.resources[provider] = running and 'started' or 'stopped'
        fire(side == 'server' and (running and 'onResourceStart' or 'onResourceStop')
            or (running and 'onClientResourceStart' or 'onClientResourceStop'), provider)
    end
    return env, state, resolver, lifecycle, fire
end

-- Every migrated family and runtime side uses the same start/stop/precedence
-- contracts. Synthetic bodies isolate selection from third-party APIs.
for _, item in ipairs(catalog) do
    for _, side in ipairs({'client','server'}) do
        if item.defaults[side] then
            local env, state, api, lifecycle, fire = fixture({item}, side)
            local candidates = {}
            for _, candidate in ipairs(item.candidates) do if candidate[side] then candidates[#candidates + 1] = candidate end end
            local first = candidates[1]
            if first then
                local read = env[item.name].Read
                for _, unready in ipairs({'stopped','starting','uninitialized'}) do
                    state.resources[first.resource] = unready
                    api.Refresh()
                    expect(env[item.name].GetResourceName() == 'default', item.name .. ' ' .. side .. ' rejects ' .. unready)
                end
                lifecycle(first.resource, true)
                local old = env[item.name]['Only_' .. first.resource]
                expect(env[item.name].GetResourceName() == first.resource, item.name .. ' ' .. side .. ' admits a late provider')
                if candidates[2] then
                    lifecycle(candidates[2].resource, true)
                    local selected = api.GetStatus()[item.name].resource
                    api.Refresh()
                    expect(api.GetStatus()[item.name].resource == selected and #api.GetStatus()[item.name].active == 2,
                        item.name .. ' conflict selection is deterministic and observable')
                    expect(read() == selected and read == env[item.name].Read,
                        item.name .. ' cached shared method dispatches to the selected adapter')
                    lifecycle(candidates[2].resource, false)
                end
                lifecycle(first.resource, false)
                local before = #state.emitted
                fire('fixture:' .. item.name)
                expect(env[item.name].GetResourceName() == 'default' and env[item.name]['Only_' .. first.resource] == nil
                    and old() == nil and #state.emitted == before, item.name .. ' stop clears capabilities and old listeners')
                lifecycle(first.resource, true)
                local before = #state.emitted
                fire('fixture:' .. item.name)
                expect(#state.emitted == before + 1 and state.registrations['fixture:' .. item.name] == 1
                    and state.callbacks['fixture:' .. item.name]() == first.resource,
                    item.name .. ' restart has one listener and one ox_lib callback registration')
                expect(old() == first.resource and old == env[item.name]['Only_' .. first.resource],
                    item.name .. ' cached callable export recovers after restart without consumer changes')
                env.BridgeSharedConfig.Providers[item.name] = 'none'
                api.Refresh()
                expect(env[item.name].GetResourceName() == 'default', item.name .. ' explicit none uses the default')
                env.BridgeSharedConfig.Providers[item.name] = first.resource
                api.Refresh()
                expect(env[item.name].GetResourceName() == first.resource, item.name .. ' explicit running provider is honored')
                lifecycle(first.resource, false)
                expect(env[item.name].GetResourceName() == 'default',
                    item.name .. ' explicit selection cannot activate a stopped resource')
            end
        end
    end
end

for _, example in ipairs({
    {'Inventory', {ox_inventory = 'started', origen_inventory = 'started', ['qb-inventory'] = 'started'}, 'ox_inventory'},
    {'Inventory', {['qb-inventory'] = 'started', ['codem-inventory'] = 'started'}, 'codem-inventory'},
    {'Framework', {['qb-core'] = 'started', qbx_core = 'started'}, 'qbx_core'},
    {'Target', {['qb-target'] = 'started', ox_target = 'started', sleepless_interact = 'started'}, 'ox_target'},
}) do
    for _, side in ipairs({'client','server'}) do
        local item = definition(example[1])
        if item.defaults[side] then
            local env = fixture({item}, side, false, example[2])
            expect(env[item.name].GetResourceName() == example[3],
                example[1] .. ' ' .. side .. ' preserves compatibility overrides and resolves exclusion cycles')
        end
    end
end

for _, side in ipairs({'client','server'}) do
    local env, state, api, lifecycle = fixture({definition('Inventory')}, side, true,
        {ox_inventory = 'started', ['qs-inventory'] = 'stopped'})
    expect(env.Inventory.GetResourceName() == 'ox_inventory', side .. ' actual OX wins over installed stopped QS')
    expect(env.Inventory.GetItemInfo('water').label == 'Water', side .. ' actual OX item read remains normalized')
    lifecycle('qs-inventory', true)
    expect(env.Inventory.GetResourceName() == 'qs-inventory' and env.Inventory.GetItemInfo('water').name == 'water',
        side .. ' actual QS takes its established precedence when started')
    lifecycle('qs-inventory', false)
    expect(env.Inventory.GetResourceName() == 'ox_inventory', side .. ' actual OX recovers after QS stops')
end

do
    local env, state, api, lifecycle = fixture({definition('Inventory')}, 'server', true,
        {['qb-inventory'] = 'started'})
    expect(env.Inventory.Version == true and type(env.Inventory.Old) == 'table', 'late QB load initializes its current version')
    local oldCapacity = env.Inventory.Old.CanCarryItem
    lifecycle('qs-inventory', true)
    expect(env.Inventory.Version == nil and env.Inventory.Old == nil, 'QS does not inherit QB-specific state')
    expect(oldCapacity() == nil, 'cached QB legacy methods cannot execute after switching to QS')
    state.version = '1.0.0'
    lifecycle('qs-inventory', false)
    expect(env.Inventory.Version == false, 'returning to QB re-reads provider version')
end

for _, provider in ipairs({'qb-core','qbx_core','es_extended','ox_core'}) do
    for _, side in ipairs({'client','server'}) do
        local env, state, api, lifecycle = fixture({definition('Framework')}, side, true, {[provider] = 'started'})
        expect(env.Framework.GetResourceName() == provider and type(env.Framework.GetIsPlayerDown) == 'function',
            provider .. ' ' .. side .. ' loads its actual adapter through the resolver')
        lifecycle(provider, false)
        expect(env.Framework.GetResourceName() == 'default' and env.Framework.GetIsPlayerDown == nil,
            provider .. ' ' .. side .. ' restores standalone capabilities after stop')
    end
end

do
    local item = definition('Fuel')
    local env, state, api, lifecycle, fire = fixture({item}, 'client')
    local first = item.candidates[1]
    state.failures[first.client] = 'runtime'
    lifecycle(first.resource, true)
    expect(env.Fuel.GetResourceName() == 'default' and api.GetStatus().Fuel.error ~= nil,
        'unready initialization fails closed with diagnostic evidence')
    local before = #state.emitted
    fire('fixture:Fuel')
    expect(#state.emitted == before, 'failed initialization removes staged listeners')
    state.failures[first.client] = 'malformed'
    api.Refresh()
    expect(env.Fuel.GetResourceName() == 'default', 'malformed adapter results cannot be selected')
    state.failures[first.client] = nil
    api.Refresh()
    expect(env.Fuel.GetResourceName() == first.resource, 'explicit retry recovers a now-ready provider')
end

do
    local item = definition('Fuel')
    local env, state, api, lifecycle = fixture({item}, 'client')
    local first = item.candidates[1]
    state.pause = first.client
    local pending = coroutine.create(function() lifecycle(first.resource, true) end)
    expect(coroutine.resume(pending) and coroutine.status(pending) == 'suspended', 'provider initialization can yield')
    lifecycle(first.resource, false)
    expect(coroutine.resume(pending) and env.Fuel.GetResourceName() == 'default',
        'a stop during initialization cannot publish a stale provider generation')
end

do
    local env, state, api, lifecycle = fixture({definition('Menu')}, 'client', true, {['qb-menu'] = 'started'})
    local opened
    env.exports['qb-menu'] = {openMenu = function(_, data) opened = data end}
    local data = {id = 'menu', {header = 'Title'}}
    expect(env.Menu.Open(data, true) == 'menu' and opened == data,
        'actual menu default API can call its selected provider helper')
    lifecycle('qb-menu', false)
    expect(env.OpenMenu == nil and env.GetMenuResourceName == nil, 'menu stop removes stale provider helper globals')
    local opened, reason = env.Menu.Open(data, true)
    expect(opened == nil and reason == 'provider_unavailable', 'default menu degrades explicitly after its provider stops')
end

for _, side in ipairs({'client','server'}) do
    local env, state, api, lifecycle = fixture(catalog, side, true, {ox_lib = 'started'}, true)
    env.ProviderResolver, env.cLib = api, {}
    assert(loadfile('init.lua', 't', env))()
    expect(state.exported.Inventory() == env.Inventory and env.Bridge.Inventory == env.Inventory,
        side .. ' actual startup exports the live managed table')
    for name, status in pairs(api.GetStatus()) do
        expect(status.error == nil and type(env[name].GetResourceName) == 'function',
            side .. ' actual ' .. name .. ' default/hard-dependency startup remains available')
    end
    local exported = state.exported.Inventory()
    lifecycle('qs-inventory', true)
    expect(state.exported.Inventory() == exported and env.Bridge.Inventory == exported
        and exported.GetResourceName() == 'qs-inventory', side .. ' existing exports see provider replacement')
end

for _, family in ipairs({'Seatbelt','Voice'}) do
    local item = definition(family)
    local provider = family == 'Seatbelt' and 'concept_seatbelt' or 'pma-voice'
    local env, state, api, lifecycle, fire = fixture({item}, 'client', true, {[provider] = 'started'})
    env.BridgeClientConfig[family] = 'none'
    env.BridgeSharedConfig.Providers[family] = provider
    api.Refresh()
    expect(family == 'Seatbelt' and env.Seatbelt.GetState() == true
        or family == 'Voice' and env.Voice.GetProximity().distance == 3,
        family .. ' explicit domain override takes precedence over its older selector')
    for _, thread in ipairs(state.threads) do thread() end
    local bags, threads = #state.bags, #state.threads
    lifecycle(provider, false)
    lifecycle(provider, true)
    expect(#state.bags == bags and #state.threads == threads, family .. ' actual restart reuses permanent statebag listeners')
    local before = #state.emitted
    fire(family == 'Seatbelt' and 'seatbelt:client:ToggleSeatbelt' or 'pma-voice:setTalkingMode', true)
    expect(#state.emitted == before + 1, family .. ' actual restart emits only one update')
end

do
    local item = definition('Fuel')
    local env, state, api, lifecycle = fixture({item}, 'client')
    local first = item.candidates[1]
    state.pause = first.client
    local pending = coroutine.create(function() lifecycle(first.resource, true) end)
    assert(coroutine.resume(pending))
    state.resources[first.resource] = 'stopped'
    expect(coroutine.resume(pending) and env.Fuel.GetResourceName() == 'default',
        'live resource readiness is rechecked after yielding even before the stop event is delivered')
end

-- Catalog paths stay case-sensitive on Linux and every adapter is covered.
for _, item in ipairs(catalog) do
    for _, candidate in ipairs(item.candidates) do
        for _, side in ipairs({'client','server'}) do
            if candidate[side] then
                local file = assert(io.open(candidate[side], 'r'))
                file:close()
            end
        end
    end
end
print(('provider_selection: %d assertions passed'):format(assertions))
