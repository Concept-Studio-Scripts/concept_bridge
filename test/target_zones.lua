-- Run from bridge root: lua test/target_zones.lua [root/]
-- A stopping resource takes only its own target zones with it: every other resource's zones stay tracked and
-- removable (before, ox_target forgot them all on any stop and qb-target / sleepless_interact never cleaned up).
local root, assertions = arg[1] or './', 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local function adapter(provider)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local state = {removed = {}, removedNames = {}, coordsAdded = {}, stop = nil, invoking = 'flexhour', nextId = 0}
    local function add() state.nextId = state.nextId + 1 return state.nextId end
    local function remove(kind) return function(_, id) state.removed[#state.removed + 1] = kind .. ':' .. tostring(id) end end
    local api = {
        addBoxZone = add, addSphereZone = add, removeZone = remove('zone'),
        AddBoxZone = function() end, AddCircleZone = function() end, RemoveZone = remove('zone'),
        addCoords = function(_, coords, opts)
            state.coordsAdded[#state.coordsAdded + 1] = {coords = coords, options = opts}
            -- (sleepless_interact: the id comes from the position, so two zones on one spot share it)
            return ('%s,%s,%s'):format(coords.x, coords.y, coords.z)
        end,
        removeCoords = function(_, id, names)
            state.removed[#state.removed + 1] = 'coords:' .. tostring(id)
            state.removedNames[#state.removedNames + 1] = names
        end,
    }
    setmetatable(api, {__index = function() return function() end end})
    env.exports = setmetatable({}, {__index = function() return api end})
    env.GetResourceState = function() return 'started' end
    env.GetCurrentResourceName = function() return 'concept_bridge' end
    env.GetInvokingResource = function() return state.invoking end
    env.AddEventHandler = function(name, fn) if name == 'onResourceStop' then state.stop = fn end end
    env.RegisterNetEvent = function() end
    env.Target = {}
    env.vector3 = function(x, y, z) return {x = x, y = y, z = z} end
    local ids = 0
    env.lib = {string = {random = function() ids = ids + 1 return 'id' .. ids end}}
    env.GetGameTimer = function() return 0 end
    -- (the resolver loads the domain's _default module before an adapter)
    assert(loadfile(root .. 'modules/target/_default/client.lua', 't', env))()
    local chunk = assert(loadfile(root .. 'modules/target/' .. provider .. '/client.lua', 't', env))
    chunk()
    return env.Target, state
end

local options = {{name = 'fh_test', label = 'Test', onSelect = function() end}}
for _, provider in ipairs({'ox_target', 'qb-target', 'sleepless_interact'}) do
    local Target, state = adapter(provider)
    local center = {x = 1.0, y = 2.0, z = 3.0}
    state.invoking = 'flexhour'
    local mine = Target.AddSphereZone('fh_clerk', center, 1.5, options)
    state.invoking = 'other_script'
    Target.AddBoxZone('other_zone', center, {x = 1.0, y = 1.0, z = 1.0}, 0.0, options)
    expect(state.stop ~= nil, provider .. ': cleans up when a resource stops')

    state.stop('other_script')
    local removedOther = #state.removed
    expect(removedOther == 1, provider .. ': the stopping resource\'s own zone is removed')
    Target.RemoveZone('fh_clerk')
    expect(#state.removed == removedOther + 1,
        provider .. ': another resource stopping does not make flexhour\'s zone unremovable (ghost eye option)')
    Target.RemoveZone('fh_clerk')
    expect(#state.removed == removedOther + 1, provider .. ': a removed zone is not removed twice')

    -- the target system itself restarted: its zones are gone and their ids mean nothing any more
    state.invoking = 'flexhour'
    Target.AddSphereZone('fh_clerk', center, 1.5, options)
    local before = #state.removed
    state.stop(provider)
    Target.RemoveZone('fh_clerk')
    expect(#state.removed == before, provider .. ': after the target system stops, stale zone ids are never removed')

    -- the bridge itself stops: everything it put on the target system goes
    Target.AddSphereZone('a', center, 1.5, options)
    state.invoking = 'other_script'
    Target.AddSphereZone('b', center, 1.5, options)
    before = #state.removed
    state.stop('concept_bridge')
    expect(#state.removed == before + 2, provider .. ': when the bridge stops, all its zones are removed')
    expect(mine ~= nil, provider .. ': a zone is returned to its creator')
end

do
    local Target, state = adapter('sleepless_interact')
    state.invoking = 'flexhour'
    Target.AddBoxZone('box', {x = 0, y = 0, z = 0}, {x = 1, y = 1, z = 1}, 0.0, {{label = 'Box', onSelect = function() end}})
    Target.AddSphereZone('ball', {x = 0, y = 0, z = 0}, 1.0, {{label = 'Ball', onSelect = function() end}})
    local added = state.coordsAdded[1]
    expect(added and added.coords.x == 0 and added.coords.y == 0 and type(added.options) == 'table' and #added.options == 1,
        'sleepless_interact: a zone is added as addCoords(coords, options) (the coords and options go as two arguments)')
    expect(#state.coordsAdded == 2, 'sleepless_interact: sphere zones are coords points too (it has no sphere zones)')
    Target.RemoveZone('box')
    expect(state.removed[1] == 'coords:0,0,0' and state.removedNames[1] and state.removedNames[1][1] == 'box:1',
        'sleepless_interact: a zone removes only its own named options at a shared coords id')
    expect(#state.removed == 1, 'sleepless_interact: ... and the other zone on that spot stays')
    Target.RemoveZone('ball')
    expect(state.removedNames[2] and state.removedNames[2][1] == 'ball:1', 'sleepless_interact: ... until it is removed itself')
    -- two zones on one spot, given the same option name, and an unnamed table used twice
    local named = {{name = 'open', label = 'Open', onSelect = function() end}}
    local unnamed = {{label = 'Look', onSelect = function() end}}
    Target.AddBoxZone('left', {x = 5, y = 5, z = 5}, {x = 1, y = 1, z = 1}, 0.0, named)
    Target.AddBoxZone('right', {x = 5, y = 5, z = 5}, {x = 1, y = 1, z = 1}, 0.0, named)
    Target.AddBoxZone('again', {x = 6, y = 6, z = 6}, {x = 1, y = 1, z = 1}, 0.0, unnamed)
    expect(named[1].name == 'open' and unnamed[1].name == nil, 'sleepless_interact: the option tables passed in keep their own names')
    Target.RemoveZone('left')
    local names = state.removedNames[#state.removedNames]
    expect(names[1] == 'left:open' and #names == 1, 'sleepless_interact: a zone removes only its own options at a shared spot, even with a shared name')
end

for _, provider in ipairs({'ox_target', 'qb-target', 'sleepless_interact'}) do
    local Target = adapter(provider)
    local check = {{name = 'rob', label = 'Rob', onSelect = function() end, canInteract = function() return true end}}
    local function count()
        local n = 0
        for _ in pairs(Target.CanInteractIds and Target.CanInteractIds() or {}) do n = n + 1 end
        return n
    end
    local before = count()
    Target.AddLocalEntity(5001, check)
    Target.AddLocalEntity({5002, 5003}, check)
    Target.AddSphereZone('fh_zone', {x = 0, y = 0, z = 0}, 1.0, check)
    expect(count() == before + 3, provider .. ': each added target keeps its canInteract check')
    Target.RemoveLocalEntity(5001)
    expect(count() == before + 2, provider .. ': a removed entity frees its check')
    Target.RemoveLocalEntity(5002)
    expect(count() == before + 2, provider .. ': a check shared by two entities stays while one of them is left')
    Target.RemoveLocalEntity(5003)
    Target.RemoveZone('fh_zone')
    expect(count() == before, provider .. ': ... and goes with the last; a removed zone frees its check')
    Target.AddGlobalPlayer(check)
    Target.AddLocalEntity(5004, {{name = 'plain', label = 'Plain', onSelect = function() end}})
    Target.RemoveLocalEntity(5004)
    expect(count() == before + 1, provider .. ': a global option\'s check is never taken by the next entity')
end

-- the same option tables passed again (a shell spawned twice): each spawn wraps the caller's own check,
-- so freeing the first spawn's check leaves the second one working
for _, provider in ipairs({'ox_target', 'qb-target', 'sleepless_interact'}) do
    local Target = adapter(provider)
    local allowed = false
    local shared = {{name = 'enter', label = 'Enter', onSelect = function() end, canInteract = function() return allowed end}}
    local original = shared[1].canInteract
    local seen = {}
    local function capture(fixed) seen[#seen + 1] = fixed end
    local realFix = Target.FixOptions
    Target.FixOptions = function(options) local fixed = realFix(options) capture(fixed) return fixed end
    Target.AddLocalEntity(6001, shared)
    Target.AddLocalEntity(6002, shared)
    Target.FixOptions = realFix
    expect(shared[1].canInteract == original, provider .. ': the caller\'s option tables are not changed')
    Target.RemoveLocalEntity(6001)
    local second = seen[2] and (seen[2][1] or select(2, next(seen[2])))
    expect(second and second.canInteract(6002) == false, provider .. ': after the first spawn is removed the second still asks the caller')
    allowed = true
    expect(second.canInteract(6003) == true, provider .. ': ... and follows its answer')
end

print(('target_zones: %d assertions passed'):format(assertions))
