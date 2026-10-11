-- Run from bridge root: lua test/shop_transactions.lua
-- Exercises the actual fallback shop, including yielding provider operations.
local sourceFile = arg[1] or 'modules/shops/_default/server.lua'
local supportFile = arg[2] or 'test/support/ox_lib.lua'
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local function fixture()
    local env = setmetatable({}, {__index = _G})
    env._G = env
    assert(loadfile(supportFile))()(env)
    local clone = env.lib.table.deepclone
    local state = {time = 0, events = {}, journal = {}, encoded = {}, serial = 0,
        money = {[1] = 10000, [2] = 10000}, items = {[1] = 0, [2] = 0}, notices = {},
        players = {[1] = {identifier = 'char1'}, [2] = {identifier = 'char2'}},
        positions = {[1] = {x = 0, y = 0, z = 0}, [2] = {x = 0, y = 0, z = 0}},
        buckets = {}, job = {jobName = 'police', gradeRank = 3}, calls = {charge = 0, add = 0, refund = 0}}
    env.GetGameTimer = function() return state.time end
    env.GetResourceState = function() return state.stopped and 'stopped' or 'started' end
    env.GetPlayerName = function(src) return state.players[src] and 'Player' end
    env.GetPlayerPed = function(src) return state.players[src] and src or 0 end
    env.GetEntityCoords = function(ped) return state.positions[ped] end
    env.GetPlayerRoutingBucket = function(src) return state.buckets[src] or 0 end
    env.RegisterNetEvent = function(name, fn) state.events[name] = fn end
    env.AddEventHandler = env.RegisterNetEvent
    env.TriggerClientEvent = function(_, src, _, _, payload) state.open = {src = src, payload = payload} end
    env.locale = function(key) return key end
    env.Notify = {SendNotify = function(_, key, kind) state.notices[#state.notices + 1] = {key = key, kind = kind} end}
    env.print = function() state.logged = true end
    env.json = {encode = function(row)
        state.serial = state.serial + 1
        local token = tostring(state.serial)
        state.encoded[token] = clone(row)
        return token
    end, decode = function(token) return clone(state.encoded[token]) end}
    env.GetResourceKvpString = function(key) return state.journal[key] end
    env.SetResourceKvp = function(key, data)
        if state.journalFails then error('journal unavailable') end
        if state.journalSilentFails then return end
        state.journal[key] = data
    end
    env.DeleteResourceKvp = function(key)
        if state.deleteFails then error('delete unavailable') end
        state.journal[key] = nil
    end
    local function hook(kind, src)
        if state.hook then state.hook(kind, src) end
    end
    env.Framework = {
        GetResourceName = function() return state.framework or 'qb-core' end,
        GetPlayer = function(src) return state.players[src] end,
        GetPlayerIdentifier = function(src) return state.players[src] and state.players[src].identifier end,
        GetPlayerJobData = function() return state.job end,
        GetAccountBalance = function(src) hook('balance', src) return state.money[src] end,
        RemoveAccountBalance = function(src, _, amount)
            state.calls.charge = state.calls.charge + 1
            hook('charge', src)
            if state.chargeFails then return false end
            state.money[src] = state.money[src] - amount
            if state.chargeThrows then error('charged before error') end
            return true
        end,
        AddAccountBalance = function(src, _, amount)
            state.calls.refund = state.calls.refund + 1
            hook('refund', src)
            if state.refundFails then return false end
            state.money[src] = state.money[src] + amount
            if state.refundThrows then error('credited before error') end
            return true
        end,
    }
    env.Inventory = {
        GetResourceName = function() return 'test_inventory' end,
        GetItemInfo = function(item) return state.unknown and {} or {name = item, label = 'Item'} end,
        GetItemCount = function(src) hook('count', src) if state.countUnknown then return nil end return state.items[src] end,
        CanCarryItem = function(src) hook('capacity', src) return not state.full end,
        AddItem = function(src, _, amount)
            state.calls.add = state.calls.add + 1
            hook('add', src)
            if state.addFails then return false end
            state.items[src] = state.items[src] + (state.partial or amount)
            if state.addThrows then error('added before error') end
            return true
        end,
        RemoveItem = function(src, _, amount)
            if state.rollbackFails then return false end
            state.items[src] = state.items[src] - amount
            return true
        end,
    }
    local function reload() return assert(loadfile(sourceFile, 't', env))() end
    local api = reload()
    local function create(stock, groups, options, price, coords)
        return api.CreateShop('shop', {{name = 'item', price = price or 10, count = stock}}, coords or {x = 0, y = 0, z = 0}, groups, options)
    end
    local function buy(src, amount, account, shop, item)
        state.time = state.time + 1000
        return api.CompleteCheckout(src or 1, shop or 'shop', item or 'item', amount or 1, account or 'bank')
    end
    return api, state, env, create, buy, reload
end

-- Public API validation and registration copies prevent accidental access/stock changes.
do
    local api, state, env = fixture()
    expect(not api.CreateShop(nil, {}, {}), 'invalid shop registration')
    expect(not api.CreateShop('bad', {{name = 'item', price = 10}}, {x = 0}), 'incomplete coordinates rejected')
    expect(not api.CreateShop('bad', {{name = 'item', price = 10}}, {{x = 0, y = 0, z = 0}, {x = 0}}), 'invalid secondary location rejected')
    for _, price in ipairs({-1, math.huge, 0/0, {}, 2147483648}) do
        expect(not api.CreateShop('bad', {{name = 'item', price = price}}, {x = 0, y = 0, z = 0}), 'invalid configured price')
    end
    expect(not api.CreateShop('bad', {{name = 'item', price = 10, count = -1}}, {x = 0, y = 0, z = 0}), 'negative stock is not unlimited')
    expect(not api.CreateShop('bad', {{name = 'item', price = 10}}, {x = 0, y = 0, z = 0}, {police = false}), 'malformed group requirement')
    expect(not api.OpenShop(1, 'missing'), 'unknown shop cannot open')
    expect(not api.OpenShop({}, 'missing'), 'invalid source cannot open')
    local entries, coords, permitted = {{name = 'item', price = 10, count = 1}}, {x = 0, y = 0, z = 0}, {police = 3}
    expect(api.CreateShop('shop', entries, coords, permitted), 'valid shop registers')
    entries[1].price, entries[1].count, coords.x, permitted.police = 0, 100, 100, 0
    expect(api.OpenShop(1, 'shop'), 'registration owns coordinate and group copies')
    expect(state.open.payload.inventory[1].price == 10 and state.open.payload.inventory[1].count == 1, 'registration owns price and stock copies')
    state.open.payload.inventory[1].count = 100
    expect(api.OpenShop(1, 'shop') and state.open.payload.inventory[1].count == 1, 'menu snapshot cannot mutate live stock')
    env.source = 1
    state.events['concept_bridge:Server:completeCheckout']('shop', 'item', '1', 'bank', 2)
    expect(state.items[1] == 1 and state.items[2] == 0 and state.money[1] == 9990, 'network event uses sender and numeric string quantity')
    expect(#state.notices == 1 and state.notices[1].kind == 'success', 'successful purchase notifies once')
    expect(api.OpenShop(1, 'shop') and state.open.payload.inventory[1].count == 0, 'finite stock consumed')
    expect(api.CreateShop('shop', entries, {x = 0, y = 0, z = 0}) and not api.CompleteCheckout(2, 'shop', 'item', 1, 'bank'), 're-registering never restocks')
end

-- Reproduce each original F03 authorization/quantity flaw with zero mutations.
for _, mode in ipairs({'distance', 'group', 'grade', 'bucket', 'unloaded', 'stopped', 'stock', 'fraction'}) do
    local api, state, _, create, buy = fixture()
    create(1, {police = 3})
    if mode == 'distance' then state.positions[1].x = 4 end
    if mode == 'group' then state.job.jobName = 'unemployed' end
    if mode == 'grade' then state.job.gradeRank = 2 end
    if mode == 'bucket' then state.buckets[1] = 42 end
    if mode == 'unloaded' then state.players[1] = nil end
    if mode == 'stopped' then state.stopped = true end
    expect(not buy(1, mode == 'stock' and 100 or mode == 'fraction' and 0.5 or 1), mode .. ' checkout rejected')
    expect(state.calls.charge == 0 and state.calls.add == 0, mode .. ' rejection has no effects')
    if mode ~= 'stock' and mode ~= 'fraction' then expect(not api.OpenShop(1, 'shop'), mode .. ' opening rejected too') end
end
do
    local api, state, _, create, buy = fixture()
    create(nil)
    for _, amount in ipairs({0, -1, 0.5, 101, math.huge, -math.huge, 0/0, {}, true, 'NaN', '1e309'}) do
        expect(not buy(1, amount), 'invalid bounded integer quantity rejected')
    end
    expect(not buy(1, 1, {}) and not buy(1, 1, 'cash') and not buy(1, 1, 'bank', {}), 'invalid account/identifier types rejected')
    expect(not buy(1, 1, 'bank', 'missing') and not buy(1, 1, 'bank', 'shop', 'missing'), 'unknown shop/item rejected')
    expect(state.calls.charge == 0 and state.calls.add == 0, 'malformed requests never mutate')
    expect(buy(1, 100) and buy(1, 100) and state.items[1] == 200, 'unlimited stock permits repeated bounded purchases')
    local ok, reason = api.CompleteCheckout(1, 'shop', 'item', 1, 'bank')
    expect(not ok and reason == 'rate_limited', 'server cooldown applies to direct API too')
end
do
    local api, state, _, create, buy = fixture()
    create(1, nil, {bucket = 42, distance = 5}, 0, {{x = 10, y = 0, z = 0}, {x = 20, y = 0, z = 0}})
    state.buckets[1], state.positions[1].x, state.money[1] = 42, 15, 0
    expect(buy() and state.items[1] == 1 and state.money[1] == 0 and state.calls.charge == 0, 'free item, boundary distance, configured bucket and multiple locations')
end
do
    local _, state, _, create, buy = fixture()
    create(100, nil, nil, 2147483647)
    expect(not buy(1, 2) and state.calls.charge == 0, 'bounded transaction total')
end
do
    local _, state, _, create, buy = fixture()
    create(1, {police = 3})
    state.framework, state.job = 'ox_core', {}
    state.players[1].getGroups = function() return {police = 3} end
    expect(buy() and state.items[1] == 1, 'authoritative secondary OX membership accepted')
end
do
    local _, state, _, create, buy = fixture()
    create(1, {'gang'})
    state.job, state.players[1].PlayerData = {}, {gang = {name = 'gang', grade = {level = 0}}}
    expect(buy(), 'named group list and authoritative QB gang accepted')
end

-- Failure handling follows observed provider effects, not just return flags.
for _, failure in ipairs({'full', 'chargeFails', 'addFails', 'journalFails', 'journalSilentFails', 'unknown', 'countUnknown'}) do
    local api, state, _, create, buy = fixture()
    create(1)
    state[failure] = true
    expect(not buy() and state.items[1] == 0 and state.money[1] == 10000, failure .. ' preserves money/items')
    state[failure] = nil
    expect(buy() and state.items[1] == 1, failure .. ' restores stock and releases lock')
end
do
    local _, state, _, create, buy = fixture()
    create(1)
    state.addThrows = true
    expect(buy() and state.money[1] == 9990 and state.items[1] == 1, 'confirmed full delivery commits exactly once despite post-add exception')
end
do
    local api, state, _, create, buy = fixture()
    create(1)
    state.chargeThrows = true
    expect(not buy() and state.money[1] == 9990 and state.items[1] == 0, 'debit exception is not treated as a safe receipt')
    expect(api.GetPendingCheckout(1).phase == 'review_required' and state.calls.refund == 0, 'ambiguous debit retained rather than blindly credited')
end
do
    local _, state, _, create, buy = fixture()
    create(3)
    state.partial = 1
    expect(not buy(1, 3) and state.money[1] == 10000 and state.items[1] == 0, 'partial delivery rolls back goods and payment')
    state.partial = nil
    expect(buy(1, 3) and state.items[1] == 3, 'partial delivery restores reserved stock')
end
do
    local api, state, _, create, buy = fixture()
    create(3)
    state.partial, state.rollbackFails = 1, true
    expect(not buy(1, 3) and state.money[1] == 9970 and state.items[1] == 1, 'failed inventory rollback does not blindly refund goods')
    expect(api.GetPendingCheckout(1).phase == 'review_required' and not api.RetryCheckoutRefund(1), 'ambiguous effects block automatic replay')
    expect(not buy(2, 1), 'uncertain delivery holds finite stock')
end
do
    local api, state, _, create, buy, reload = fixture()
    create(1)
    state.addFails, state.refundFails = true, true
    expect(not buy() and state.money[1] == 9990 and state.items[1] == 0, 'failed refund is not reported as success')
    expect(api.GetPendingCheckout(1).phase == 'refund_pending', 'refund obligation retained')
    local fresh = reload()
    expect(fresh.GetPendingCheckout(1).phase == 'refund_pending', 'refund survives resource reload')
    state.players[2].identifier = 'char1'
    state.money[2], state.refundFails, state.refundThrows = 9990, nil, true
    expect(fresh.RetryCheckoutRefund(2) and state.money[2] == 10000, 'same character on new source receives confirmed refund despite provider error')
    expect(fresh.RetryCheckoutRefund(2) and state.money[2] == 10000, 'completed refund cannot repeat')
end
do
    local api, state, _, create, buy = fixture()
    create(1)
    state.deleteFails = true
    expect(buy() and not api.GetPendingCheckout(1), 'terminal journal remains safe if deletion fails')
end
do
    local api, state, env, create, buy = fixture()
    create(1)
    state.journal['concept_bridge:shop_checkout:qb-core:char1'] = env.json.encode({
        identifier = 'char1', framework = 'qb-core', account = 'bank', total = '10', phase = 'refund_pending'})
    local pending, reason = api.GetPendingCheckout(1)
    expect(not pending and reason == 'recovery_required', 'malformed persisted record fails closed without throwing')
    expect(not buy() and state.calls.charge == 0 and state.calls.refund == 0, 'corrupt ledger cannot authorize credit or checkout')
end
do
    local api, state, _, create, buy = fixture()
    create(1)
    state.hook = function(kind)
        if kind == 'count' and state.calls.charge > 0 then state.positions[1].x = 20 end
    end
    expect(not buy() and state.items[1] == 0 and state.money[1] == 10000, 'moving after charge but before delivery refunds without items')
    state.hook, state.positions[1].x = nil, 0
    expect(buy(), 'authorization failure after charge restores stock')
end
do
    local api, state, env, create, buy = fixture()
    create(1)
    state.hook = function(kind)
        if kind == 'charge' then
            state.players[1].identifier = 'replacement'
            env.source = 1
            state.events.playerDropped()
        end
    end
    expect(not buy() and state.calls.add == 0 and state.calls.refund == 0, 'source reuse during debit never delivers or credits replacement')
    state.players[2].identifier = 'char1'
    expect(api.GetPendingCheckout(2).phase == 'review_required', 'interrupted debit retained under original character identity')
end

-- Real coroutine interleaving: reserve before a yielding balance lookup.
do
    local api, state, _, create, buy = fixture()
    create(1)
    local yielded = false
    state.hook = function(kind, src)
        if kind == 'balance' and src == 1 and not yielded then yielded = true coroutine.yield() end
    end
    local first = coroutine.create(function() expect(buy(1), 'first reserved transaction succeeds') end)
    expect(coroutine.resume(first) and coroutine.status(first) == 'suspended', 'provider can yield inside protected checkout')
    expect(not buy(2) and state.money[2] == 10000, 'concurrent customer cannot oversell reserved stock')
    expect(not buy(1), 'same-player overlapping checkout cannot charge twice')
    expect(coroutine.resume(first) and coroutine.status(first) == 'dead', 'reserved transaction completes')
    expect(state.items[1] == 1 and state.calls.charge == 1, 'only one charge and delivery')
end
for _, transition in ipairs({'move', 'logout', 'reuse'}) do
    local _, state, env, create, buy = fixture()
    create(1, {police = 3})
    state.hook = function(kind)
        if kind ~= 'capacity' then return end
        if transition == 'move' then state.positions[1].x = 20
        elseif transition == 'logout' then state.players[1] = nil env.source = 1 state.events.playerDropped()
        else state.players[1].identifier = 'new-character' end
    end
    expect(not buy() and state.calls.charge == 0 and state.calls.add == 0, transition .. ' during provider yield invalidates authorization')
end
do
    local api, state, _, create, buy = fixture()
    create(1)
    state.hook = function(kind) if kind == 'add' then state.countUnknown = true end end
    expect(not buy() and state.money[1] == 9990 and state.items[1] == 1, 'unreadable post-delivery state is not blindly refunded')
    state.countUnknown = nil
    expect(api.GetPendingCheckout(1).phase == 'review_required', 'unconfirmed delivery recorded for reconciliation')
end

print(('shop_transactions: %d assertions passed'):format(assertions))
