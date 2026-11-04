-- Provider selection owns adapter lifetimes; ox_lib still owns callback transport.
local Resolver = {}
local environmentKeys = {lib = true, CreateThread = true, RegisterNetEvent = true,
    AddEventHandler = true, RegisterCommand = true, SetTimeout = true,
    AddStateBagChangeHandler = true}

local function copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[key] = copy(item, seen) end
    return setmetatable(result, getmetatable(value))
end

function Resolver.New(catalog, side)
    local states, stopped, callbackSlots = {}, {}, {}
    local resource = GetCurrentResourceName()
    -- [name] = running, for the guard on every public call: asked of the game once, then kept by the resource
    -- start / stop events below. Selecting a provider still asks the game itself (it can stop mid-load).
    local running = {}

    local function started(name)
        return not stopped[name] and GetResourceState(name) == 'started'
    end

    local function knownStarted(name)
        if stopped[name] then return false end
        local known = running[name]
        if known == nil then
            known = GetResourceState(name) == 'started'
            running[name] = known
        end
        return known
    end

    local function guard(scope, fn)
        return function(...)
            if not scope.active or (scope.resource and not knownStarted(scope.resource)) then
                return nil, 'provider_unavailable'
            end
            return fn(...)
        end
    end

    local function close(scope)
        if not scope then return end
        scope.active = false
        for _, handle in ipairs(scope.events) do RemoveEventHandler(handle) end
        for _, handle in ipairs(scope.bags) do RemoveStateBagChangeHandler(handle) end
        scope.events, scope.bags = {}, {}
    end

    local function bindCallbacks(state)
        local wanted = {}
        for name, fn in pairs(state.baseScope.callbacks) do
            wanted[name] = guard(state.baseScope, fn)
        end
        if state.scope then
            for name, fn in pairs(state.scope.callbacks) do wanted[name] = guard(state.scope, fn) end
        end
        for name, slot in pairs(callbackSlots) do
            if slot.owner == state.definition.name then slot.fn = wanted[name] end
        end
        for name, fn in pairs(wanted) do
            local slot = callbackSlots[name]
            if not slot then
                slot = {owner = state.definition.name}
                callbackSlots[name] = slot
                lib.callback.register(name, function(...)
                    if slot.fn then return slot.fn(...) end
                    return nil, 'provider_unavailable'
                end)
            end
            slot.fn = fn
        end
    end

    local function environment(state, module, scope, base)
        local env = {[state.definition.name] = module}
        setmetatable(env, {__index = base and _G or state.baseEnv})
        env.AddEventHandler = function(name, fn)
            local handle = AddEventHandler(name, guard(scope, fn))
            scope.events[#scope.events + 1] = handle
            return handle
        end
        env.RegisterNetEvent = function(name, fn)
            RegisterNetEvent(name)
            if fn then return env.AddEventHandler(name, fn) end
        end
        env.AddStateBagChangeHandler = function(key, bag, fn)
            local handle = AddStateBagChangeHandler(key, bag, guard(scope, fn))
            scope.bags[#scope.bags + 1] = handle
            return handle
        end
        env.SetTimeout = function(delay, fn) return SetTimeout(delay, guard(scope, fn)) end
        env.RegisterCommand = function(name, fn, restricted)
            return RegisterCommand(name, guard(scope, fn), restricted)
        end
        -- Retained provider threads are only the default inventory/seatbelt/voice
        -- listeners. Defaults live once; provider adapters do not create loops.
        env.CreateThread = function(fn) return CreateThread(guard(scope, fn)) end
        local callback = setmetatable({register = function(name, fn)
            scope.callbacks[name] = fn
            if scope.active and state.ready then bindCallbacks(state) end
        end}, {
            __index = lib.callback,
            __call = function(_, ...) return lib.callback(...) end,
        })
        env.lib = setmetatable({callback = callback}, {__index = lib})
        return env
    end

    local function loadAdapter(path, env)
        local source = LoadResourceFile(resource, path)
        if type(source) ~= 'string' or source == '' then error('missing adapter: ' .. path) end
        local chunk, err = load(source, '@' .. resource .. '/' .. path, 't', env)
        if not chunk then error(err) end
        local result = chunk()
        if result ~= nil and type(result) ~= 'table' then error('adapter did not return a module table: ' .. path) end
    end

    local function configured(definition)
        local overrides = BridgeSharedConfig.Providers
        if type(overrides) == 'table' and overrides[definition.name] ~= nil then
            return overrides[definition.name]
        end
        local config = definition.config and _G[definition.config]
        return config and config[definition.key] or 'auto'
    end

    local function selectProvider(definition)
        local preference, active, activeSet = configured(definition), {}, {}
        local supported = {}
        for _, candidate in ipairs(definition.candidates) do
            if candidate[side] then supported[candidate.resource] = true end
        end
        local function externalBlocker(candidate)
            for _, other in ipairs(candidate.blocks or {}) do
                -- Some compatibility resources have no adapter on this side.
                -- A configured choice must not bypass those running blockers.
                if not supported[other] and started(other) then return true end
            end
            return false
        end
        for _, candidate in ipairs(definition.candidates) do
            if candidate[side] and started(candidate.resource) and not externalBlocker(candidate) then
                active[#active + 1] = candidate
                activeSet[candidate.resource] = #active
            end
        end
        if preference ~= 'auto' then
            for _, candidate in ipairs(active) do
                if candidate.resource == preference then return candidate, active end
            end
            return nil, active
        end
        for index, candidate in ipairs(active) do
            local blocked = false
            for _, other in ipairs(candidate.blocks or {}) do
                local otherIndex = activeSet[other]
                if otherIndex then
                    local mutual = false
                    for _, exclusion in ipairs(active[otherIndex].blocks or {}) do
                        if exclusion == candidate.resource then mutual = true break end
                    end
                    if not mutual or otherIndex < index then blocked = true break end
                end
            end
            if not blocked then return candidate, active end
        end
        -- Old OX/Origen guards excluded each other. A fixed order resolves that
        -- cycle rather than dropping both running providers.
        return active[1], active
    end

    local function publish(state, module, scope, selected)
        close(state.scope)
        state.scope = scope
        if scope then scope.active = true end
        state.generation = state.generation + 1
        state.implementation = module
        state.selected = selected and selected.resource or 'default'
        -- Older menu adapters supply global helpers used by their default API.
        -- Publish those helpers with the same lifetime as the selected adapter.
        for key, original in pairs(state.helpers) do
            state.baseEnv[key], _G[key] = original.base, original.global
        end
        if scope then
            for key, value in pairs(scope.env) do
                if key ~= state.definition.name and not environmentKeys[key] and type(value) == 'function' then
                    if not state.helpers[key] then
                        state.helpers[key] = {base = rawget(state.baseEnv, key), global = _G[key]}
                    end
                    local fn = guard(scope, value)
                    state.baseEnv[key], _G[key] = fn, fn
                end
            end
        end
        local function publicFunction(key, field)
            local id = field and (key .. '.' .. field) or key
            if state.functions[id] then return state.functions[id] end
            local reference
            reference = function(...)
                local currentScope = state.scope or state.baseScope
                if not currentScope.active or (currentScope.resource and not knownStarted(currentScope.resource)) then
                    return nil, 'provider_unavailable'
                end
                local exposed, implementation = state.public[key], state.implementation[key]
                if field then
                    exposed = type(exposed) == 'table' and exposed[field] or nil
                    implementation = type(implementation) == 'table' and implementation[field] or nil
                end
                local fn = exposed
                if fn == reference then fn = implementation end
                local meta = type(fn) == 'table' and getmetatable(fn)
                if type(fn) ~= 'function' and not (type(fn) == 'table' and
                    (rawget(fn, '__cfx_functionReference') or (type(meta) == 'table' and meta.__call))) then
                    return nil, 'provider_unavailable'
                end
                return fn(...)
            end
            state.functions[id] = reference
            return reference
        end
        for key in pairs(state.public) do state.public[key] = nil end
        for key, value in pairs(module) do
            if type(value) == 'function' then
                state.public[key] = publicFunction(key)
            elseif (key == 'Commands' or key == 'Old') and type(value) == 'table' then
                local commands = {}
                for name, fn in pairs(value) do
                    commands[name] = type(fn) == 'function' and publicFunction(key, name) or fn
                end
                state.public[key] = commands
            else
                state.public[key] = value
            end
        end
        state.public.GetResourceName = function() return state.selected end
        bindCallbacks(state)
        TriggerEvent('Bridge:Refresh', state.definition.name, state.public, state.generation, resource)
    end

    local function refresh(state, force)
        state.revision = state.revision + 1
        state.force = state.force or force
        if state.loading then state.pending = true return end
        state.loading = true
        repeat
            state.pending = false
            local revision, forced = state.revision, state.force
            state.force = false
            local selected, active = selectProvider(state.definition)
            state.active = {}
            for _, candidate in ipairs(active) do state.active[#state.active + 1] = candidate.resource end
            local name = selected and selected.resource or 'default'
            if forced or state.selected ~= name then
                local module, scope = copy(state.base), nil
                state.error = nil
                if selected then
                    scope = {active = false, resource = selected.resource, events = {}, bags = {}, callbacks = {}}
                    local env = environment(state, module, scope, false)
                    scope.env = env
                    local ok, err = pcall(loadAdapter, selected[side], env)
                    if ok and type(env[state.definition.name]) == 'table' and started(selected.resource) then
                        module = env[state.definition.name]
                        module.GetResourceName = function() return selected.resource end
                    else
                        close(scope)
                        scope, selected, module = nil, nil, copy(state.base)
                        state.error = tostring(err or 'adapter is no longer ready or did not produce a table')
                        print(('^1[concept_bridge] %s provider %s unavailable: %s^0'):format(state.definition.name, name, state.error))
                    end
                end
                if state.revision == revision then
                    publish(state, module, scope, selected)
                else
                    close(scope)
                end
            end
        until not state.pending
        state.loading = false
    end

    for _, definition in ipairs(catalog) do
        if definition.defaults[side] then
            local public = {}
            _G[definition.name] = public
            local state = {definition = definition, public = public, generation = 0, revision = 0, helpers = {}, functions = {}}
            states[#states + 1] = state
            state.baseScope = {active = true, events = {}, bags = {}, callbacks = {}}
            state.baseEnv = environment(state, public, state.baseScope, true)
            loadAdapter(definition.defaults[side], state.baseEnv)
            local baseModule = state.baseEnv[definition.name]
            if baseModule ~= public then
                for key, value in pairs(baseModule) do public[key] = value end
                state.baseEnv[definition.name] = public
            end
            local private = {lib = true, CreateThread = true, RegisterNetEvent = true,
                AddEventHandler = true, RegisterCommand = true, SetTimeout = true,
                AddStateBagChangeHandler = true, [definition.name] = true}
            for key, value in pairs(state.baseEnv) do
                if not private[key] then _G[key] = value end
            end
            state.base = copy(state.baseEnv[definition.name])
            state.ready = true
            refresh(state, true)
        end
    end

    local api = {}
    function api.GetStatus()
        local result = {}
        for _, state in ipairs(states) do
            result[state.definition.name] = {
                resource = state.selected, generation = state.generation,
                active = copy(state.active), error = state.error,
            }
        end
        return result
    end
    function api.Refresh()
        for _, state in ipairs(states) do refresh(state, true) end
    end
    function api.Owns(name)
        for _, state in ipairs(states) do if state.definition.name == name then return true end end
        return false
    end

    local function changed(name, stopping)
        if name == resource then return end
        stopped[name] = stopping or nil
        running[name] = not stopping
        local frameworkChanged = false
        for _, state in ipairs(states) do
            local relevant = false
            for _, candidate in ipairs(state.definition.candidates) do
                if candidate.resource == name then relevant = true break end
                for _, blocker in ipairs(candidate.blocks or {}) do
                    if blocker == name then relevant = true break end
                end
                if relevant then break end
            end
            if relevant or (frameworkChanged and state.definition.name == 'Inventory') then
                local generation = state.generation
                refresh(state, state.selected == name or (frameworkChanged and state.definition.name == 'Inventory'))
                if state.definition.name == 'Framework' and generation ~= state.generation then frameworkChanged = true end
            end
        end
    end
    AddEventHandler(side == 'server' and 'onResourceStart' or 'onClientResourceStart', function(name) changed(name, false) end)
    AddEventHandler(side == 'server' and 'onResourceStop' or 'onClientResourceStop', function(name)
        if name == resource then
            for _, state in ipairs(states) do close(state.scope) close(state.baseScope) end
        else
            changed(name, true)
        end
    end)
    return api
end

return Resolver
