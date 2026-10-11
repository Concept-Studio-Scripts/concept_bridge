---@diagnostic disable: duplicate-set-field
Shops = Shops or {}

local registeredShops, busy, lastRequest, generations = {}, {}, {}, {}
local MAX_TOTAL, MAX_AMOUNT, COOLDOWN = 2147483647, 100, 500
local JOURNAL_PREFIX = 'concept_bridge:shop_checkout:'

local function number(value)
    if type(value) ~= 'number' and type(value) ~= 'string' then return nil end
    value = tonumber(value)
    if value and value == value and math.abs(value) < math.huge then return value end
end

local function integer(value, minimum, maximum)
    value = number(value)
    if value and value % 1 == 0 and value >= minimum and value <= maximum then return value end
end

local function name(value)
    return type(value) == 'string' and #value > 0 and #value <= 128 and not value:find('%c')
end

local function call(fn, ...)
    if type(fn) ~= 'function' then return false end
    return pcall(fn, ...)
end

local function get(fn, ...)
    local ok, result = call(fn, ...)
    if ok then return result end
end

local function point(value)
    local kind = type(value)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return nil end
    local x, y, z = number(value.x), number(value.y), number(value.z)
    if x and y and z then return {x = x, y = y, z = z} end
end

local function locations(value)
    local single = point(value)
    if single then return {single} end
    if type(value) ~= 'table' then return nil end
    local result = {}
    for key, coords in pairs(value) do
        if not integer(key, 1, 64) then return nil end
        local location = point(coords)
        if not location then return nil end
        result[#result + 1] = location
    end
    if #result > 0 then return result end
end

local function groups(value)
    if value == nil then return {} end -- No groups means an unrestricted shop.
    if type(value) ~= 'table' then return nil end
    local result = {}
    for key, grade in pairs(value) do
        if integer(key, 1, 128) and name(grade) then
            result[grade] = 0
        elseif name(key) and integer(grade, 0, 10000) then
            result[key] = tonumber(grade)
        else
            return nil
        end
    end
    return result
end

local function context(src)
    if not GetPlayerName(src) then return nil end
    local player = get(Framework.GetPlayer, src)
    local identifier = get(Framework.GetPlayerIdentifier, src)
    local framework = get(Framework.GetResourceName)
    local inventory = get(Inventory.GetResourceName)
    if not player or not name(identifier) or not name(framework) or not name(inventory) then return nil end
    return {src = src, identifier = identifier, framework = framework, inventory = inventory,
        generation = generations[src] or 0, key = JOURNAL_PREFIX .. framework .. ':' .. identifier}
end

local function samePlayer(ctx)
    return (generations[ctx.src] or 0) == ctx.generation and GetPlayerName(ctx.src) ~= nil
        and get(Framework.GetResourceName) == ctx.framework
        and get(Inventory.GetResourceName) == ctx.inventory
        and (ctx.framework == 'default' or GetResourceState(ctx.framework) == 'started')
        and (ctx.inventory == 'default' or GetResourceState(ctx.inventory) == 'started')
        and get(Framework.GetPlayerIdentifier, ctx.src) == ctx.identifier
        and get(Framework.GetPlayer, ctx.src) ~= nil
end

local function access(ctx, shop)
    if not samePlayer(ctx) then return false, 'player_unavailable' end
    local job = get(Framework.GetPlayerJobData, ctx.src)
    local allowed = next(shop.groups) == nil
    if type(job) == 'table' then
        local minimum = shop.groups[job.jobName]
        local grade = number(job.gradeRank)
        allowed = allowed or (minimum ~= nil and grade ~= nil and grade >= minimum)
    end
    if not allowed and (ctx.framework == 'qb-core' or ctx.framework == 'qbx_core') then
        local player = get(Framework.GetPlayer, ctx.src)
        local gang = player and type(player.PlayerData) == 'table' and player.PlayerData.gang
        if type(gang) == 'table' and type(gang.grade) == 'table' then
            local minimum, grade = shop.groups[gang.name], number(gang.grade.level)
            allowed = minimum ~= nil and grade ~= nil and grade >= minimum
        end
    end
    -- ox_core exposes all authoritative group memberships, not just the active job.
    if not allowed and ctx.framework == 'ox_core' then
        local player = get(Framework.GetPlayer, ctx.src)
        local memberships = player and get(player.getGroups)
        if type(memberships) == 'table' then
            for group, minimum in pairs(shop.groups) do
                local grade = number(memberships[group])
                if grade and grade >= minimum then allowed = true break end
            end
        end
    end
    if not allowed then return false, 'group_denied' end
    local ped = GetPlayerPed(ctx.src)
    if not ped or ped == 0 then return false, 'player_unavailable' end
    local coords = point(GetEntityCoords(ped))
    if not coords or GetPlayerRoutingBucket(ctx.src) ~= shop.bucket then return false, 'out_of_range' end
    for _, location in ipairs(shop.locations) do
        local dx, dy, dz = coords.x - location.x, coords.y - location.y, coords.z - location.z
        if dx * dx + dy * dy + dz * dz <= shop.distance * shop.distance then
            if samePlayer(ctx) then return true end
            return false, 'player_unavailable'
        end
    end
    return false, 'out_of_range'
end

local function notify(src, key, kind, ...)
    local ok, message = call(locale, key, ...)
    if ok then call(Notify.SendNotify, src, message, kind, 5000) end
end

local function save(ctx, record, phase)
    record.phase = phase
    local ok, encoded = call(json.encode, record)
    if not ok then return false end
    local written = call(SetResourceKvp, ctx.key, encoded)
    return written and get(GetResourceKvpString, ctx.key) == encoded
end

local function read(ctx)
    local ok, encoded = call(GetResourceKvpString, ctx.key)
    if not ok then return false, 'journal_unavailable' end
    if encoded == nil then return nil end
    local decoded, record = call(json.decode, encoded)
    if not decoded or type(record) ~= 'table' or record.identifier ~= ctx.identifier
        or record.framework ~= ctx.framework or type(record.total) ~= 'number' or not number(record.total) or record.total < 0
        or record.total > MAX_TOTAL or (record.account ~= 'money' and record.account ~= 'bank') then
        return false, 'recovery_required'
    end
    return record
end

local function finish(ctx, record)
    -- A terminal record is safe even if deleting the KVP fails.
    if save(ctx, record, 'complete') then call(DeleteResourceKvp, ctx.key) return true end
    return false
end

local function review(ctx, record)
    save(ctx, record, 'review_required')
    print(('[concept_bridge] Shop checkout requires reconciliation for source %s; journal retained.'):format(ctx.src))
    return false, 'recovery_required'
end

local function equal(left, right)
    return number(left) ~= nil and math.abs(left - right) < 0.0001
end

local function refund(ctx, record)
    if not save(ctx, record, 'refund_pending') then return false, 'recovery_required' end
    if record.total == 0 then return finish(ctx, record) end
    if not samePlayer(ctx) then save(ctx, record, 'refund_pending') return false, 'refund_pending' end
    local before = number(get(Framework.GetAccountBalance, ctx.src, record.account))
    if not before or before < 0 or before + record.total == before then return false, 'refund_pending' end
    if not samePlayer(ctx) or not save(ctx, record, 'refunding') then return false, 'refund_pending' end
    local credited, result = call(Framework.AddAccountBalance, ctx.src, record.account, record.total)
    if not samePlayer(ctx) then return review(ctx, record) end
    local after = number(get(Framework.GetAccountBalance, ctx.src, record.account))
    if after and after > before and equal(after, before + record.total) then return finish(ctx, record) end
    if credited and result ~= true and after == before then
        save(ctx, record, 'refund_pending') return false, 'refund_pending'
    end
    return review(ctx, record) -- Never retry an unconfirmed credit and risk a duplicate refund.
end

local function recover(ctx)
    local record, reason = read(ctx)
    if record == false then return false, reason end
    if not record or record.phase == 'complete' then return true end
    if record.phase ~= 'refund_pending' then return false, 'recovery_required' end
    return refund(ctx, record)
end

--- Register fallback shop stock for this resource session. nil count is unlimited.
--- options.distance defaults to 3 metres; options.bucket defaults to 0.
Shops.CreateShop = function(shopName, shopInventory, shopCoords, shopGroups, options)
    if not name(shopName) or type(shopInventory) ~= 'table' then return false, 'invalid_shop' end
    if options == nil then options = {} end
    if type(options) ~= 'table' then return false, 'invalid_shop' end
    local distance = options.distance == nil and 3 or number(options.distance)
    local bucket = integer(options.bucket == nil and 0 or options.bucket, 0, 2147483647)
    local coords, permitted = locations(shopCoords), groups(shopGroups)
    if not distance or distance <= 0 or distance > 20 or not bucket or not coords or not permitted then
        return false, 'invalid_shop'
    end
    local rows, index = {}, {}
    for _, entry in pairs(shopInventory) do
        if type(entry) ~= 'table' or not name(entry.name) or index[entry.name] then return false, 'invalid_item' end
        local price = number(entry.price)
        local count = entry.count ~= nil and integer(entry.count, 0, MAX_TOTAL) or nil
        if not price or price < 0 or price > MAX_TOTAL or (entry.count ~= nil and not count) then return false, 'invalid_item' end
        local row = {name = entry.name, price = price, count = count}
        rows[#rows + 1], index[row.name] = row, row
    end
    if #rows == 0 then return false, 'invalid_shop' end
    if registeredShops[shopName] then return true end -- Re-registration never replenishes live stock.
    registeredShops[shopName] = {name = shopName, inventory = rows, items = index,
        locations = coords, groups = permitted, distance = distance, bucket = bucket}
    return true
end

Shops.OpenShop = function(src, shopName)
    src = integer(src, 1, 65535)
    if not src or not name(shopName) then return false, 'invalid_request' end
    local shop = registeredShops[shopName]
    local ctx = context(src)
    if not shop or not ctx then return false, 'shop_unavailable' end
    local allowed, reason = access(ctx, shop)
    if not allowed then return false, reason end
    TriggerClientEvent('concept_bridge:Client:openShop', src, 'shop', shopName,
        {name = shopName, inventory = lib.table.deepclone(shop.inventory)})
    return true
end

local function checkout(ctx, shopName, item, amount, account, tx)
    if not recover(ctx) then return false, 'recovery_required' end
    local shop = registeredShops[shopName]
    if not shop then return false, 'unknown_shop' end
    local allowed, reason = access(ctx, shop)
    if not allowed then return false, reason end
    local entry = shop.items[item]
    if not entry then return false, 'unknown_item' end
    if entry.count ~= nil and entry.count < amount then
        notify(ctx.src, 'Shops.NotEnoughStock', 'error') return false, 'insufficient_stock'
    end
    local total = entry.price * amount
    if not number(total) or total > MAX_TOTAL then return false, 'invalid_total' end
    local info = get(Inventory.GetItemInfo, item)
    if type(info) ~= 'table' or info.name ~= item then return false, 'unknown_item' end
    local beforeItems = integer(get(Inventory.GetItemCount, ctx.src, item), 0, MAX_TOTAL)
    if not beforeItems or beforeItems + amount > MAX_TOTAL then return false, 'inventory_unavailable' end
    -- Resolve after any yielding reads: another player may have consumed stock.
    allowed, reason = access(ctx, shop)
    if not allowed then return false, reason end
    if entry.count ~= nil and entry.count < amount then return false, 'insufficient_stock' end
    tx.entry, tx.amount = entry, amount
    if entry.count ~= nil then entry.count = entry.count - amount end
    local balance = number(get(Framework.GetAccountBalance, ctx.src, account))
    if not balance or balance < total then
        notify(ctx.src, 'Shops.NotEnoughMoney', 'error') return false, 'insufficient_money'
    end
    if get(Inventory.CanCarryItem, ctx.src, item, amount) ~= true then return false, 'inventory_full' end
    allowed, reason = access(ctx, shop)
    if not allowed then return false, reason end
    balance = number(get(Framework.GetAccountBalance, ctx.src, account))
    if not balance or balance < total or (total > 0 and balance - total == balance) or not samePlayer(ctx) then return false, 'payment_unavailable' end
    allowed, reason = access(ctx, shop)
    if not allowed then return false, reason end
    local record = {identifier = ctx.identifier, framework = ctx.framework, inventory = ctx.inventory, account = account,
        total = total, shop = shopName, item = item, amount = amount, beforeItems = beforeItems, beforeBalance = balance}
    tx.record = record
    if not save(ctx, record, 'charging') then return false, 'journal_unavailable' end
    if total > 0 then
        local charged, result = call(Framework.RemoveAccountBalance, ctx.src, account, total)
        if not samePlayer(ctx) then tx.keepStock = true return review(ctx, record) end
        local after = number(get(Framework.GetAccountBalance, ctx.src, account))
        if not charged or result ~= true or not after or after >= balance or not equal(after, balance - total) then
            if charged and result ~= true and after == balance then finish(ctx, record) return false, 'payment_failed' end
            tx.keepStock = true return review(ctx, record)
        end
    end
    if not save(ctx, record, 'charged') then refund(ctx, record) return false, 'journal_unavailable' end
    allowed, reason = access(ctx, shop)
    if not allowed then refund(ctx, record) return false, reason end
    beforeItems = integer(get(Inventory.GetItemCount, ctx.src, item), 0, MAX_TOTAL)
    if not beforeItems or beforeItems + amount > MAX_TOTAL or not samePlayer(ctx) then refund(ctx, record) return false, 'inventory_unavailable' end
    allowed, reason = access(ctx, shop)
    if not allowed then refund(ctx, record) return false, reason end
    record.beforeItems = beforeItems
    if not save(ctx, record, 'delivering') then refund(ctx, record) return false, 'journal_unavailable' end
    local added, result = call(Inventory.AddItem, ctx.src, item, amount)
    if not samePlayer(ctx) then tx.keepStock = true return review(ctx, record) end
    local afterItems = integer(get(Inventory.GetItemCount, ctx.src, item), 0, MAX_TOTAL)
    if afterItems == beforeItems + amount then
        tx.keepStock = true
        if not finish(ctx, record) then review(ctx, record) end
        notify(ctx.src, 'Shops.PurchasedItem', 'success', amount, type(info.label) == 'string' and info.label or item)
        return true
    end
    -- Only undo an observed partial addition; unknown mutations need reconciliation.
    if afterItems and afterItems > beforeItems and afterItems < beforeItems + amount then
        local removed, success = call(Inventory.RemoveItem, ctx.src, item, afterItems - beforeItems)
        if removed and success == true and samePlayer(ctx) then
            afterItems = integer(get(Inventory.GetItemCount, ctx.src, item), 0, MAX_TOTAL)
        else afterItems = nil end
    elseif afterItems == beforeItems and (not added or result == true) then
        tx.keepStock = true return review(ctx, record)
    end
    if afterItems ~= beforeItems then tx.keepStock = true return review(ctx, record) end
    if not save(ctx, record, 'refund_pending') then return false, 'recovery_required' end
    local refunded = refund(ctx, record)
    notify(ctx.src, 'Shops.PurchaseFailed', 'error')
    return false, refunded and 'delivery_failed' or 'refund_pending'
end

local function locked(src, fn)
    if busy[src] then return false, 'checkout_busy' end
    busy[src] = true
    local tx = {}
    local ok, success, reason = pcall(fn, tx)
    if not ok and tx.record and tx.record.phase ~= 'complete' then tx.keepStock = true end
    if tx.entry and tx.entry.count ~= nil and not tx.keepStock then tx.entry.count = tx.entry.count + tx.amount end
    busy[src] = nil
    if not ok then
        -- Provider calls are protected individually; unexpected failures are never success.
        if tx.record then print('[concept_bridge] Shop checkout interrupted; recovery journal retained.') end
        return false, 'checkout_failed'
    end
    return success, reason
end

Shops.CompleteCheckout = function(src, shopName, item, amount, account)
    src = integer(src, 1, 65535)
    if not src then return false, 'invalid_request' end
    local now = GetGameTimer()
    if lastRequest[src] and now >= lastRequest[src] and now - lastRequest[src] < COOLDOWN then return false, 'rate_limited' end
    lastRequest[src] = now
    amount = integer(amount, 1, MAX_AMOUNT)
    if not name(shopName) or not name(item) or not amount or (account ~= 'money' and account ~= 'bank') then return false, 'invalid_request' end
    return locked(src, function(tx)
        local ctx = context(src)
        if not ctx then return false, 'player_unavailable' end
        return checkout(ctx, shopName, item, amount, account, tx)
    end)
end

--- Server-only recovery API; no network event can choose another refund recipient.
Shops.RetryCheckoutRefund = function(src)
    src = integer(src, 1, 65535)
    if not src then return false, 'invalid_request' end
    return locked(src, function()
        local ctx = context(src)
        if not ctx then return false, 'player_unavailable' end
        return recover(ctx)
    end)
end

Shops.GetPendingCheckout = function(src)
    src = integer(src, 1, 65535)
    local ctx = src and context(src)
    if not ctx then return nil end
    local record, reason = read(ctx)
    if record == false then return nil, reason end
    if type(record) == 'table' and record.phase ~= 'complete' then return lib.table.deepclone(record) end
end

RegisterNetEvent('concept_bridge:Server:completeCheckout', function(shopName, item, amount, account)
    local src = source
    Shops.CompleteCheckout(src, shopName, item, amount, account)
end)

local function invalidate(src)
    src = tonumber(src)
    if not src then return end
    generations[src] = (generations[src] or 0) + 1
    lastRequest[src] = nil
end
AddEventHandler('playerDropped', function() invalidate(source) end)
AddEventHandler('concept_bridge:Server:OnPlayerUnload', invalidate)

return Shops
