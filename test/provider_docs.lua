-- Run from bridge root: lua test/provider_docs.lua [checkout/]
-- Provider API references: https://conceptstudio.store/docs/concept-bridge#inventory-provider-details
local root = arg[1] or './'
local assertions = 0
local function expect(condition, message)
    assertions = assertions + 1
    assert(condition, message)
end

local function fixture(provider, side)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    assert(loadfile(root .. 'test/support/ox_lib.lua'))()(env)
    local state = {notices = {}, calls = {}, result = true, loaded = true}
    state.definitions = {
        water = {name = 'water', label = 'Water', weight = 10, description = 'Drink', unique = false},
        bread = {name = 'bread', label = 'Bread', weight = 20, unique = true},
        -- Core's OX items file can omit name, and uses boolean stack.
        unnamed = {label = 'Named by key', stack = false},
    }
    state.rows = {
        [5] = {name = 'water', label = 'Water', amount = 10, slot = 5,
            weight = 10, info = {quality = 80, nested = {token = 1}, extra = true}, unique = false, close = false, useable = true},
        [8] = {name = 'water', count = 3, slot = 8, metadata = {quality = 20}},
        [9] = {name = 'bread', amount = 1, slot = 9, info = {}},
    }
    state.content = {['water-alpha'] = state.rows[5], ['water-beta'] = state.rows[8], ['bread-gamma'] = state.rows[9]}
    local function call(name, args)
        state.calls[#state.calls + 1] = {name = name, args = args}
    end
    local native = {}
    local function method(name, arity, implementation)
        native[name] = function(_, ...)
            local args = table.pack(...)
            expect(args.n == arity, provider .. ':' .. name .. ' argument count')
            call(name, args)
            return implementation(table.unpack(args, 1, args.n))
        end
    end
    local helper = assert(loadfile(root .. 'lib/inventory/shared/provider_items.lua'))()
    local function total(name, metadata, strict)
        local count = 0
        for _, row in pairs(helper.List(state.rows)) do
            if row.name == name and helper.Matches(row.metadata, metadata) and
                (not strict or metadata == nil or helper.Matches(metadata, row.metadata)) then
                count = count + row.count
            end
        end
        return count
    end
    local function definition(name)
        if name ~= nil then return state.definitions[name] or {} end
        return state.definitions
    end
    local function slot(src, index)
        expect(src == 1 and type(index) == 'number', 'numeric server slot contract')
        return state.loaded and state.rows[index] or nil
    end
    local function add(src, item, count)
        expect(src == 1 and item == 'water' and count == 2, 'add source/name/count')
        return state.result
    end
    local function remove(src, item, count)
        expect(src == 1 and item == 'water' and count == 2, 'remove source/name/count')
        return state.result
    end
    if provider == 'origen_inventory' then
        if side == 'client' then
            method('getPlayerItems', 0, function() return state.loaded and state.rows or nil end)
        else
            method('Items', 0, function() return state.definitions end)
            method('getItems', 1, function(src) expect(src == 1, 'Origen getItems source') return state.loaded and state.rows or nil end)
            method('getItemCount', 2, function(src, name) expect(src == 1, 'Origen count source') return total(name) end)
            method('getSlot', 2, slot)
            method('canCarryItem', 3, function() return state.result end)
            method('addItem', 5, function(src, name, count, index, metadata)
                expect(index == 5 and metadata.quality == 90, 'Origen slot precedes info')
                return add(src, name, count)
            end)
            method('removeItem', 4, function(src, name, count, index)
                expect(index == nil or index == 5 or index == 8, 'Origen remove slot, no metadata argument')
                return remove(src, name, count)
            end)
            method('setMetadata', 3, function(src, index, metadata)
                expect(src == 1 and index == 5 and metadata.quality == 90, 'Origen metadata numeric slot')
                return state.result
            end)
            method('registerStash', 2, function(id, data)
                expect(id == 'locker' and data.label == 'Locker' and data.slots == 20 and data.maxweight == 1000, 'Origen stash data table')
            end)
            method('OpenInventory', 2, function(src, id) expect(src == 1 and id == 'locker', 'Origen opens registered ID') end)
            method('OpenInventoryById', 2, function(src, target) expect(src == 1 and target == 2, 'Origen opens target ID') end)
            method('clearInventory', 1, function(id) expect(id == 'locker', 'Origen clears registered ID') return state.result end)
        end
    elseif provider == 'core_inventory' then
        method('getItemsList', 0, function() return state.definitions end)
        if side == 'client' then
            method('getPlayerItems', 0, function() return state.loaded and state.content or nil end)
            method('getItemCount', 1, function(name) return total(name) end)
        else
            method('getInventory', 1, function(src)
                expect(src == 1, 'Core inventory source')
                return state.loaded and {content = state.content, label = 'Pockets', slots = 20} or nil
            end)
            method('getItemCount', 2, function(src, name) expect(src == 1, 'Core count source') return total(name) end)
            method('getItemBySlot', 2, slot)
            method('addItem', 4, function(src, name, count, metadata)
                expect(metadata.quality == 90, 'Core add metadata argument')
                return add(src, name, count)
            end)
            method('removeItem', 3, remove)
            method('removeItemExact', 3, function(src, id, count)
                expect(src == 1 and (id == 'water-alpha' or id == 'water-beta') and count == 2, 'Core removes opaque content key')
                return state.result
            end)
            method('setMetadata', 3, function(src, index, metadata)
                expect(src == 1 and index == 5 and metadata.quality == 90, 'Core setter receives numeric slot')
                -- Official contract returns void.
            end)
            method('canCarry', 3, function() return state.result end)
            method('openInventory', 6, function(src, id, kind, label, restrictions, open)
                expect(src == 1 and id == 'locker' and kind == 'stash' and label == 'Locker' and restrictions == nil and open == true, 'Core opening contract')
            end)
            method('openOtherPlayerInventory', 2, function(src, target) expect(src == 1 and target == 2, 'Core opens target player') end)
        end
    else
        method('Items', 1, definition)
        -- Items() enumeration and Items(name) both have documented optional args.
        native.Items = function(_, ...)
            local args = table.pack(...)
            expect(args.n <= 1, 'Tgiann Items optional name only')
            call('Items', args)
            return definition(args[1])
        end
        method('GetPlayerItems', side == 'server' and 1 or 0, function(src)
            if side == 'server' then expect(src == 1, 'Tgiann items source') end
            return state.loaded and state.rows or nil
        end)
        if side == 'client' then
            method('GetItemCount', 3, function(name, metadata, strict)
                expect(metadata == nil and strict == false, 'Tgiann client count contract') return total(name)
            end)
            method('HasItem', 2, function(name, count) return total(name) >= count end)
        else
            method('GetItemCount', 3, function(src, name, metadata)
                expect(src == 1, 'Tgiann total count source') return total(name, metadata, true)
            end)
            method('GetItemBySlot', 2, function(src, index) return slot(src, index) or {amount = 0} end)
            method('CanCarryItem', 3, function() return state.result end)
            method('HasItem', 3, function(src, name, count) return total(name) >= count end)
            method('AddItem', 6, function(src, name, count, index, metadata, clothing)
                expect(index == 5 and metadata.quality == 90 and clothing == false, 'Tgiann QB add argument order') return add(src, name, count)
            end)
            method('RemoveItem', 5, function(src, name, count, index, metadata)
                expect(index == 5 and metadata.quality == 80, 'Tgiann removal slot/info order') return remove(src, name, count)
            end)
            method('UpdateItemMetadata', 4, function(src, name, index, metadata)
                expect(src == 1 and name == 'water' and index == 5 and metadata.quality == 90, 'Tgiann metadata name/numeric slot contract')
            end)
        end
    end
    setmetatable(native, {__index = function(_, name) error('Undocumented/unexpected export: ' .. provider .. ':' .. name) end})
    env.exports = {[provider] = native}
    env.GetResourceState = function(name) return name == provider and 'started' or 'missing' end
    env.LoadResourceFile = function(resource)
        expect(resource == provider or resource == 'inventory_images', 'image resource spelling') return nil
    end
    env.TriggerClientEvent = function(name, src, data)
        state.notices[#state.notices + 1] = {name = name, src = src, data = data}
    end
    env.Inventory = {
        StripPNG = function(name) return name:gsub('%.png$', '') end,
        StripWebp = function(name) return name:gsub('%.webp$', '') end,
        -- Origen client retains the bridge's existing framework registry fallback.
        Items = function()
            if state.registryMissing then error('framework registry unavailable') end
            return state.definitions
        end,
    }
    local cache = {}
    env.lib = env.lib or {callback = {register = function() end}}
    env.lib.require = function(module)
        local path = module:gsub('^@[^.]+%.', ''):gsub('%.', '/') .. '.lua'
        if not cache[path] then cache[path] = assert(loadfile(root .. path, 't', env))() end
        return cache[path]
    end
    local api = assert(loadfile(root .. 'modules/inventory/' .. provider .. '/' .. side .. '.lua', 't', env))()
    return api, state
end

for _, provider in ipairs({'origen_inventory', 'core_inventory', 'tgiann-inventory'}) do
    for _, side in ipairs({'client', 'server'}) do
        local api, state = fixture(provider, side)
        local function count(name, metadata)
            if side == 'client' then return api.GetItemCount(name) end
            return api.GetItemCount(1, name, metadata)
        end
        local function has(name, required)
            if side == 'client' then return api.HasItem(name, required) end
            return api.HasItem(1, name, required)
        end
        local function list()
            if side == 'client' then return api.GetPlayerInventory() end
            return api.GetPlayerInventory(1)
        end
        local info = api.GetItemInfo('water')
        expect(info.name == 'water' and info.label == 'Water' and info.weight == 10 and info.description == 'Drink', 'complete item definition')
        expect(info.stack == true and api.GetItemInfo('bread').stack == false, 'QB uniqueness normalized correctly')
        expect(next(api.GetItemInfo('absent')) == nil, 'unknown definition')
        expect(api.Items().water ~= nil, 'item enumeration')
        state.definitions.water.label = 'Updated water'
        expect(api.GetItemInfo('water').label == 'Updated water', 'definition changes remain visible')
        state.definitions.water.label = 'Water'
        if provider == 'origen_inventory' and side == 'client' then
            state.registryMissing = true
            expect(next(api.Items()) == nil and next(api.GetItemInfo('water')) == nil, 'missing Origen framework registry fails safely')
            state.registryMissing = false
        end
        if provider == 'core_inventory' then
            expect(api.GetItemInfo('unnamed').name == 'unnamed' and api.GetItemInfo('unnamed').stack == false, 'OX-format definition keyed by name')
        end
        expect(count('water') == 13 and count('absent') == 0, 'total count spans both stacks')
        expect(has('water', 13) and not has('water', 14) and not has('absent'), 'HasItem threshold and default one')
        local rows = list()
        expect(#rows == 3, 'each physical stack normalized once')
        local slots = {}
        for _, row in pairs(rows) do slots[row.slot] = row end
        expect(slots[5].count == 10 and slots[5].metadata.nested.token == 1 and slots[5].label == 'Water' and slots[5].close == false, 'amount/info row and false close preserved')
        expect(slots[8].count == 3 and slots[8].metadata.quality == 20, 'count/metadata alternate row preserved')
        if provider == 'core_inventory' then expect(slots[5].id == 'water-alpha', 'opaque ID separate from numeric slot') end
        state.loaded = false
        expect(#list() == 0, 'unloaded player inventory returns empty')
        state.loaded = true
        if side == 'server' then
            local filter = provider == 'tgiann-inventory' and state.rows[5].info or {quality = 80}
            expect(count('water', filter) == 10 and count('water', {quality = 99}) == 0, 'metadata count scans all matching stacks')
            if provider == 'tgiann-inventory' then
                expect(count('water', {quality = 80}) == 0, 'Tgiann retains native strict metadata default')
                expect(api.SetMetadata(1, 'water', '5', {quality = 90}) == nil, 'Tgiann metadata setter return preserved')
                expect(api.SetMetadata(1, 'bread', 5, {quality = 90}) == false, 'Tgiann metadata identity guarded')
            end
            local selected = api.GetItemBySlot(1, '5')
            expect(selected.name == 'water' and selected.count == 10, 'numeric slot lookup')
            expect(next(api.GetItemBySlot(1, 77)) == nil, 'missing slot including Tgiann amount-zero sentinel')
            expect(next(api.GetItemBySlot(1, 0)) == nil and next(api.GetItemBySlot(1, 5.5)) == nil, 'invalid numeric slots rejected')
            expect(api.AddItem(1, 'water', 2, 5, {quality = 90}) == true, 'documented add succeeds')
            local notices = #state.notices
            state.result = false
            expect(api.AddItem(1, 'water', 2, 5, {quality = 90}) == false and #state.notices == notices, 'rejected add emits no success event')
            expect(api.RemoveItem(1, 'water', 2, 5, {quality = 80}) == false and #state.notices == notices, 'rejected removal emits no success event')
            state.result = true
            expect(api.RemoveItem(1, 'water', 2, 5, {quality = 80}) == true, 'targeted removal succeeds')
            if provider ~= 'tgiann-inventory' then
                expect(api.RemoveItem(1, 'water', 2) == true, 'untargeted removal uses documented export')
                expect(api.RemoveItem(1, 'water', 2, nil, {quality = 20}) == true, 'metadata-only removal selects matching stack')
                expect(api.RemoveItem(1, 'water', 12, nil, {}) == false, 'filtered removal never partly consumes several stacks')
                expect(api.RemoveItem(1, 'water', 12, 5) == false, 'targeted removal cannot exceed selected stack')
                expect(api.RemoveItem(1, 'bread', 2, 5) == false, 'wrong item in targeted slot rejected')
                local calls = #state.calls
                expect(api.RemoveItem(1, 'water', 2, 5, {quality = 99}) == false, 'mismatching metadata rejected')
                local last = state.calls[#state.calls]
                expect(#state.calls >= calls and last.name ~= 'removeItem' and last.name ~= 'removeItemExact', 'no mutation for wrong target')
                expect(api.SetMetadata(1, 'bread', 5, {quality = 90}) == false, 'metadata item identity checked')
                local result = api.SetMetadata(1, 'water', '5', {quality = 90})
                expect(provider == 'core_inventory' and result == nil or provider == 'origen_inventory' and result == true, 'setter documented return retained')
                expect(api.RegisterStash('locker', 'Locker', 20, 1000) == true, 'stash registration')
                expect(api.RegisterStash('private', 'Private', 20, 1000, 'owner') == false, 'unsupported stash restriction is explicit')
                api.OpenStash(1, 'stash', 'locker')
                api.OpenPlayerInventory(1, 2)
                expect(api.CanCarryItem(1, 'water', 2) == true, 'native capacity query')
                state.result = false
                expect(api.CanCarryItem(1, 'water', 2) == false, 'capacity rejection propagated')
                state.result = true
            end
            if provider == 'origen_inventory' then
                expect(api.ClearStash('locker', 'stash') == true and api.Stashes.locker ~= nil, 'clear retains stash registration')
                expect(api.AddTrunkItems('ABC', {{item = 'water', count = 2}}) == false, 'undocumented bulk trunk operation fails explicitly')
            elseif provider == 'core_inventory' then
                expect(api.GetItemBySlot(1, 'water-alpha').slot == 5, 'legacy opaque ID lookup supported')
                expect(api.RemoveItem(1, 'water', 2, 'water-alpha') == true, 'legacy opaque ID removal supported')
                expect(api.SetMetadata(1, 'water', 'water-alpha', {quality = 90}) == nil, 'opaque ID mapped to numeric metadata slot')
                -- If provider rows omit the ID/slot mapping, do not guess it.
                state.content = {['water-alpha'] = {name = 'water', amount = 10, info = {quality = 80}}}
                local ok, reason = api.RemoveItem(1, 'water', 2, 5)
                expect(ok == false and reason == 'item_id_unavailable', 'missing unique ID mapping blocks exact removal')
                ok, reason = api.SetMetadata(1, 'water', 'water-alpha', {quality = 90})
                expect(ok == false and reason == 'slot_unavailable', 'missing numeric slot mapping blocks metadata update')
                expect(api.SetMetadata(1, 'water', 5, {quality = 90}) == nil, 'native numeric slot still supports metadata')
            end
        end
    end
end

local helper = assert(loadfile(root .. 'lib/inventory/shared/provider_items.lua'))()
expect(helper.Stack({stack = -1}) and helper.Stack({stack = 5}) and not helper.Stack({stack = 1}), 'numeric stack limits normalized')
expect(helper.Matches({nested = {a = 1, b = 2}}, {nested = {a = 1}}), 'nested subset metadata comparison')
expect(not helper.Matches({nested = {a = 1}}, {nested = {a = 2}}), 'nested metadata mismatch')
local indexed = helper.List({[5] = {name = 'water', amount = 2, slot = 5, id = 'water-alpha'}}, true)
expect(indexed[1].id == 'water-alpha' and indexed[1].slot == 5, 'Core client array preserves explicit unique ID')
print(('Provider documentation regressions: %d assertions passed'):format(assertions))
