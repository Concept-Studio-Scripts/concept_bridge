local f = assert(io.open('lib/entities/client/client_entity.lua', 'rb'))
local body = assert(f:read('a'):match('function ClientEntity.UpdateRotation%(id, rotation%)(.-)\nend'))
f:close()
local entity = {spawned = 7, rotation = {x = 0, y = 0, z = 0}}
local applied
local env = setmetatable({
    ClientEntity = {All = {test = entity}},
    vector3 = function(x, y, z) assert(type(z) == 'number'); return {x=x, y=y, z=z} end,
    DoesEntityExist = function() return true end,
    SetEntityRotation = function(_, x, y, z) applied = {x=x, y=y, z=z} end,
}, {__index = _G})
local rotate = assert(load('return function(id, rotation)' .. body .. '\nend', 'rotation', 't', env))()
rotate('test', 'invalid')
assert(applied == nil and entity.rotation.z == 0, 'invalid headings preserve the existing rotation')
rotate('test', '90')
assert(applied.z == 90 and entity.rotation.z == 90, 'numeric string headings still work')
local euler = {x=10, y=20, z=30}
rotate('test', euler)
assert(applied.x == 10 and applied.z == 30 and entity.rotation == euler, 'Euler vectors remain supported')
print('entity_rotation: invalid/string/vector rotation contracts passed')

