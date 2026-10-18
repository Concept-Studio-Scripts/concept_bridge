-- Run from bridge root: lua test/target_caninteract.lua [root/]
-- canInteract results are reused for a second per option AND per target entity: looking from one
-- player to another within that second shows the second player's own options.
local root, assertions = arg[1] or './', 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local env = setmetatable({}, {__index = _G})
env._G = env
local now, ids = 0, 0
env.GetGameTimer = function() return now end
env.lib = {string = {random = function() ids = ids + 1 return 'id' .. ids end}}
env.AddEventHandler = function() end
env.RegisterNetEvent = function() end
env.SetTimeout = function() error('canInteract must not start a timer per check') end
env.Target = {}
assert(loadfile(root .. 'modules/target/_default/client.lua', 't', env))()
local Target = env.Target

local calls, handsUp = 0, {[101] = true, [202] = false}
local id = Target.CreateCanInteract(function(entity)
    calls = calls + 1
    return handsUp[entity]
end)

expect(Target.CanInteract(id, 101) == true, 'the first player can be robbed')
expect(Target.CanInteract(id, 202) == false, 'looking at a second player within the second asks about that player')
expect(Target.CanInteract(id, 101) == true and calls == 2, 'a result is reused for the same target within a second')
now = 1000
handsUp[101] = false
expect(Target.CanInteract(id, 101) == false and calls == 3, 'after a second the option is asked again')
expect(Target.CanInteract(id, {entity = 202}) == false, 'a target passed inside a table is keyed by its entity')
expect(Target.CanInteract('unknown', 101) == true, 'an option without a check is always shown')

-- old results are dropped as new targets come in (a crowd does not grow the cache for ever)
for entity = 1, 50 do Target.CanInteract(id, entity) end
now = 5000
Target.CanInteract(id, 999)
local kept = 0
for _ in pairs(Target.GetCanInteract(id).results) do kept = kept + 1 end
expect(kept == 1, 'stale results are dropped when a new target is checked')

print(('target_caninteract: %d assertions passed'):format(assertions))
