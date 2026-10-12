-- Run from bridge root: lua test/consumer_contracts.lua
-- What consumer resources lean on: "is this player down" and "save this player's inventory now".
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local Down = assert(loadfile('lib/framework/shared/player_down.lua'))()
expect(Down.FromQbMetadata({ isdead = true }) == true, 'dead is down')
expect(Down.FromQbMetadata({ isdead = false, inlaststand = true }) == true, 'last stand is down')
expect(Down.FromQbMetadata({ isdead = false, inlaststand = false }) == false, 'neither is not down')
expect(Down.FromQbMetadata({}) == false and Down.FromQbMetadata(nil) == false, 'no metadata is not down')
expect(Down.FromQbMetadata({ inlaststand = 'yes' }) == false, 'only a real true counts')
expect(Down.FromFlag(true) == true and Down.FromFlag(1) == true, 'a dead flag is down')
expect(Down.FromFlag(false) == false and Down.FromFlag(nil) == false and Down.FromFlag(0) == false, 'no flag is not down')

-- every framework module offers it on both sides, next to GetIsPlayerDead
local function source(path)
    local f = assert(io.open(path, 'rb'))
    local s = f:read('a')
    f:close()
    return s
end
for _, fw in ipairs({ 'es_extended', 'ox_core', 'qb-core', 'qbx_core' }) do
    for _, side in ipairs({ 'server', 'client' }) do
        local s = source(('modules/framework/%s/%s.lua'):format(fw, side))
        expect(s:find('Framework.GetIsPlayerDown = function', 1, true) ~= nil, fw .. ' ' .. side .. ' has GetIsPlayerDown')
        expect(s:find('Framework.GetIsPlayerDead = function', 1, true) ~= nil, fw .. ' ' .. side .. ' keeps GetIsPlayerDead')
        expect(s:find('lib.framework.shared.player_down', 1, true) ~= nil, fw .. ' ' .. side .. ' uses the shared rule')
    end
end

-- the Qbox and QBCore server modules really answer "down" for last stand
for _, fw in ipairs({ 'qb-core', 'qbx_core' }) do
    local s = source(('modules/framework/%s/server.lua'):format(fw))
    local body = s:match('Framework%.GetIsPlayerDown = function%(src%)(.-)\nend')
    expect(body ~= nil, fw .. ': the function can be read')
    local env = { Framework = { GetPlayer = function(src)
        if src == 1 then return { PlayerData = { metadata = { isdead = false, inlaststand = true } } } end
        if src == 2 then return { PlayerData = { metadata = { isdead = false, inlaststand = false } } } end
        return nil
    end }, lib = { require = function() return Down end } }
    local fn = assert(load('return function(src)' .. body .. '\nend', fw, 't', env))()
    expect(fn(1) == true, fw .. ': a player in last stand is down')
    expect(fn(2) == false, fw .. ': a player on their feet is not')
    expect(fn(3) == false, fw .. ': nobody there is not down')
end

-- a forced save of one player's inventory
local saved, fail = {}, false
exports = setmetatable({}, { __index = function(_, name)
    return { SaveInventory = function(_, src) if fail then error('database away') end saved[#saved + 1] = name .. ':' .. src end }
end })
local Save = assert(loadfile('lib/inventory/server/save_player.lua'))()
expect(Save.Player('qb-inventory', 7) == true and saved[1] == 'qb-inventory:7', 'qb-inventory saves that player')
expect(Save.Player('ps-inventory', 8) == true and saved[2] == 'ps-inventory:8', 'ps-inventory saves that player')
expect(Save.Player('jpr-inventory', 9) == true and saved[3] == 'jpr-inventory:9', 'jpr-inventory saves that player')
local ok, why = Save.Player('ox_inventory', 7)
expect(ok == false and why == 'unsupported' and #saved == 3, 'ox_inventory: unsupported, said so, nothing called')
ok, why = Save.Player('qb-inventory', 0)
expect(ok == false and why == 'invalid_player', 'no player: refused')
ok, why = Save.Player('qb-inventory', 'x')
expect(ok == false and why == 'invalid_player', 'not a server id: refused')
fail = true
ok, why = Save.Player('qb-inventory', 7)
expect(ok == false and why == 'provider_error', 'the provider threw: false with the reason, no error out')
expect(source('modules/inventory/_default/server.lua'):find('Inventory.SavePlayerInventory = function', 1, true) ~= nil,
    'the inventory module offers SavePlayerInventory')

print(('consumer_contracts: %d assertions passed'):format(assertions))
