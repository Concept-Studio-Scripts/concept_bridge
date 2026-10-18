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
    local state = {removed = {}, stop = nil, invoking = 'flexhour', nextId = 0}
    local function add() state.nextId = state.nextId + 1 return state.nextId end
    local function remove(kind) return function(_, id) state.removed[#state.removed + 1] = kind .. ':' .. tostring(id) end end
    local api = {
        addBoxZone = add, addSphereZone = add, removeZone = remove('zone'),
        AddBoxZone = function() end, AddCircleZone = function() end, RemoveZone = remove('zone'),
        addCoords = add, removeCoords = remove('coords'),
    }
    setmetatable(api, {__index = function() return function() end end})
    env.exports = setmetatable({}, {__index = function() return api end})
    env.GetResourceState = function() return 'started' end
    env.GetCurrentResourceName = function() return 'concept_bridge' end
    env.GetInvokingResource = function() return state.invoking end
    env.AddEventHandler = function(name, fn) if name == 'onResourceStop' then state.stop = fn end end
    env.RegisterNetEvent = function() end
    env.Target = {}
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
    Target.AddBoxZone('box', {x = 0, y = 0, z = 0}, {x = 1, y = 1, z = 1}, 0.0, options)
    Target.AddSphereZone('ball', {x = 0, y = 0, z = 0}, 1.0, options)
    Target.RemoveZone('box')
    Target.RemoveZone('ball')
    expect(state.removed[1]:match('^coords:') and state.removed[2]:match('^zone:'),
        'sleepless_interact: a box (coords point) and a sphere zone are each removed the way they were added')
end

print(('target_zones: %d assertions passed'):format(assertions))
