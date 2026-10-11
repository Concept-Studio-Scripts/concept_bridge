-- Run from the bridge root: lua test/inventory_regressions.lua
-- Optional argument: path to a bridge checkout, including trailing slash.
-- Isolated fixtures exercise actual adapters; no FiveM/game state is touched.
local root = arg[1] or './'
local assertions = 0
local function expect(condition, message)
    assertions = assertions + 1
    assert(condition, message)
end

local function fixture(framework, provider)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    assert(loadfile(root .. 'test/support/ox_lib.lua'))()(env)
    local state = { bridge = true, mutations = 0, notices = {}, setters = 0 }
    state.definitions = {
        water = { name = 'water', label = 'Water', weight = 10, image = 'water.png', unique = false },
        bread = { name = 'bread', label = 'Bread', weight = 20, unique = true },
    }
    state.player = { PlayerData = { items = {
        [5] = { name = 'water', amount = 10, slot = 5, info = { old = true, nested = { token = 1 } } },
        [8] = { name = 'water', amount = 3, slot = 8, info = { other = true } },
        [9] = { name = 'bread', amount = 1, slot = 9, info = { quality = 80 } },
    } }, Functions = {} }
    local core = { Shared = { Items = state.definitions }, Functions = {
        GetPlayer = function() return state.player end,
    }, Commands = {} }
    env.GetResourceState = function(name)
        return (name == framework or name == provider) and 'started' or 'missing'
    end
    env.RegisterNetEvent, env.AddEventHandler, env.RegisterCommand = function() end, function() end, function() end
    env.CreateThread = function() end
    env.TriggerEvent = function() end
    env.TriggerClientEvent = function(name, src, data)
        state.notices[#state.notices + 1] = { name = name, src = src, data = data }
    end
    env.LoadResourceFile = function() return nil end
    env.print = function() end
    env.exports = {
        ['qb-core'] = { GetCoreObject = function()
            if not state.bridge then error('QB compatibility bridge unavailable') end
            return core
        end },
        qbx_core = { GetPlayer = function() return state.player end },
    }
    env.exports[provider] = {
        AddItem = function() state.mutations = state.mutations + 1 return true end,
        RemoveItem = function() state.mutations = state.mutations + 1 return true end,
        SetInventory = function(_, _, items)
            state.setters = state.setters + 1
            state.player.PlayerData.items = items -- provider's nil success return
        end,
    }
    state.player.Functions.AddItem = function() state.mutations = state.mutations + 1 error('must not re-add') end
    state.player.Functions.RemoveItem = function() state.mutations = state.mutations + 1 error('must not remove') end
    local loaded = {}
    env.lib = env.lib or {callback = {register = function() end}}
    env.lib.require = function(module)
        local path = module:gsub('^@[^.]+%.', ''):gsub('%.', '/') .. '.lua'
        if not path:find('lib/inventory/', 1, true) then return {} end
        if loaded[path] == nil then loaded[path] = assert(loadfile(root .. path, 't', env))() end
        return loaded[path]
    end
    env.Inventory = { GetResourceName = function() return provider end,
        StripPNG = function(name) return name:gsub('%.png$', '') end }
    local function load(path) return assert(loadfile(root .. path, 't', env))() end
    local api = load('modules/framework/' .. framework .. '/server.lua')
    return env, state, api, load
end

for _, framework in ipairs({ 'qb-core', 'qbx_core' }) do
    for _, provider in ipairs({ 'qb-inventory', 'ps-inventory' }) do
        for _, side in ipairs({ 'server', 'client' }) do
            local env, state, _, load = fixture(framework, provider)
            local api = load('modules/inventory/' .. provider .. '/' .. side .. '.lua')
            local info = api.GetItemInfo('water')
            expect(info.name == 'water' and info.label == 'Water' and info.weight == 10, 'valid normalized definition')
            expect(info.stack == true and api.GetItemInfo('bread').stack == false, 'QB uniqueness normalized to stackability')
            expect(api.Items().water == state.definitions.water, 'item enumeration uses provider definitions')
            expect(next(api.GetItemInfo('missing')) == nil, 'unknown item read is empty')
            state.definitions.water.label = 'Updated water'
            expect(api.GetItemInfo('water').label == 'Updated water', 'definition updates remain visible')
            if side == 'server' then
                expect(api.AddItem(1, 'water', 1) == true, 'successful add')
                expect(api.RemoveItem(1, 'water', 1) == true, 'successful removal')
                expect(state.mutations == 2, 'one native mutation per call')
                local boxes = 0
                for _, notice in ipairs(state.notices) do
                    if notice.name:find('ItemBox', 1, true) then
                        boxes = boxes + 1
                        expect(notice.data == state.definitions.water, 'ItemBox receives complete definition')
                    end
                end
                expect(boxes == 2, 'one ItemBox per successful mutation')
                local ok, reason = api.AddItem(1, 'missing', 1)
                expect(ok == false and reason == 'unknown_item' and state.mutations == 2, 'unknown definition blocks mutation')
                env.exports[provider].AddItem = function() return false end
                local notices = #state.notices
                expect(api.AddItem(1, 'water', 1) == false and #state.notices == notices, 'failed mutation emits no notice')
            end
            if framework == 'qbx_core' then
                state.bridge = false
                expect(next(api.Items()) == nil and next(api.GetItemInfo('water')) == nil, 'disabled bridge reads are safe')
                if side == 'server' then
                    local ok, reason = api.RemoveItem(1, 'water', 1)
                    expect(ok == false and reason == 'item_registry_unavailable' and state.mutations == 2, 'missing registry blocks mutation')
                end
                state.bridge = true
                expect(api.GetItemInfo('water').name == 'water', 'compatibility registry recovers without cached failure')
            end
        end

        local env, state, api = fixture(framework, provider)
        local original = state.player.PlayerData.items
        original[5].metadata = { alternate = true }
        local requested = { fresh = true, nested = { token = 2 } }
        expect(api.SetMetadata(1, 'water', '5', requested) == true, 'slot update accepts a numeric string')
        local updated = state.player.PlayerData.items
        expect(updated[5].amount == 10 and updated[5].slot == 5 and state.mutations == 0, 'stack count and identity preserved without remove/add')
        expect(updated[8].amount == 3 and updated[8].info.other and updated[9].info.quality == 80, 'same-name and unrelated slots unchanged')
        expect(updated[5].info.fresh and updated[5].metadata.fresh and updated[5].info.old == nil, 'metadata replaced and both fields kept consistent')
        expect(original[5].info.old and original[5].metadata.alternate, 'original snapshot is not mutated')
        requested.nested.token = 99
        expect(updated[5].info.nested.token == 2, 'request metadata does not alias live inventory')
        expect(state.notices[#state.notices].data.action == 'metadata', 'successful update emits normalized change')
        local setters = state.setters
        local ok, reason = api.SetMetadata(1, 'bread', 5, {})
        expect(ok == false and reason == 'item_not_found' and state.setters == setters, 'wrong-name slot cannot update another item')
        expect(api.SetMetadata(1, 'water', 5.5, {}) == false and api.SetMetadata(1, 'water', 5, nil) == false, 'invalid input cannot mutate')
        for _, failure in ipairs({ 'error', 'mutate_error', 'reject', 'noop' }) do
            env.exports[provider].SetInventory = function(_, _, items)
                if failure == 'error' then error('backend unavailable') end
                if failure == 'mutate_error' then
                    items[8].amount = 0
                    items[9].info.quality = 0
                    error('backend changed only its input before failing')
                end
                if failure == 'reject' then return false end
            end
            local before = state.player.PlayerData.items
            local success, failureReason = api.SetMetadata(1, 'water', 5, { attempted = failure })
            expect(success == false and failureReason ~= nil, 'provider failure is explicit: ' .. failure)
            expect(state.player.PlayerData.items == before and before[5].amount == 10 and before[8].amount == 3 and before[9].info.quality == 80 and state.mutations == 0, 'provider failure preserves original inventory: ' .. failure)
        end
        env.exports[provider].SetInventory = function(_, _, items)
            state.player.PlayerData.items = items
            error('logging failed after update')
        end
        expect(api.SetMetadata(1, 'water', 5, { final = true }) == true, 'post-apply error reports verified committed state')
        env.exports[provider].SetInventory = function(_, _, items)
            items[5].info = { left = { token = 1 }, right = { token = 1 } }
            state.player.PlayerData.items = items
        end
        local shared = { token = 1 }
        expect(api.SetMetadata(1, 'water', 5, { left = shared, right = shared }) == true, 'provider serialization may remove reference aliases without changing values')
        state.player = nil
        local success, failureReason = api.SetMetadata(1, 'water', 5, {})
        expect(success == false and failureReason == 'player_unavailable', 'disconnected player cannot mutate')
    end
end

do
    local env, state, api = fixture('qb-core', 'default')
    local success, reason = api.SetMetadata(1, 'water', 5, {})
    expect(success == false and reason == 'unsupported_metadata_update' and state.mutations == 0, 'unsupported providers never use destructive fallback')
    state.player.Functions.SetInventory = function(items) state.player.PlayerData.items = items end
    expect(api.SetMetadata(1, 'water', 5, { legacy = true }) == true, 'legacy injected SetInventory is supported')
end

do
    local env, state, api = fixture('qbx_core', 'ox_inventory')
    local slot = { name = 'water', slot = 5, count = 10, metadata = { old = true } }
    env.exports.ox_inventory = {
        GetSlot = function() return slot end,
        SetMetadata = function(_, _, _, metadata) slot.metadata = metadata end,
    }
    expect(api.SetMetadata(1, 'water', 5, { ox = true }) == true and slot.count == 10, 'Qbox native OX metadata path')
    expect(api.SetMetadata(1, 'bread', 5, {}) == false and slot.name == 'water', 'OX path checks item identity')
    env.exports.ox_inventory.SetMetadata = function() error('ox unavailable') end
    expect(api.SetMetadata(1, 'water', 5, {}) == false and slot.metadata.ox, 'OX error keeps existing item')
    env.exports.ox_inventory.SetMetadata = function(_, _, _, metadata)
        slot.metadata = metadata
        error('OX raised after commit')
    end
    expect(api.SetMetadata(1, 'water', 5, { committed = true }) == true and slot.count == 10, 'OX post-apply error reports verified state')
end

print(('PASS: %d inventory regression assertions'):format(assertions))
