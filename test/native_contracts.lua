local env = setmetatable({
    lib = {requestNamedPtfxAsset = function() end},
    AddEventHandler = function() end, exports = function() end,
    UseParticleFxAssetNextCall = function() end, SetParticleFxNonLoopedColour = function() end,
    StartParticleFxLoopedAtCoord = function() return 0 end,
    DoesParticleFxLoopedExist = function() return false end,
    Wait = function() end, CreateThread = function() end,
    StopParticleFxLooped = function(handle) assert(type(handle) == 'number', 'stop takes a numeric handle') end,
    RemoveParticleFx = function(handle) assert(type(handle) == 'number', 'remove takes a numeric handle') end,
    RemoveNamedPtfxAsset = function(dict) assert(dict == 'test_dictionary', 'unload the dictionary, not the effect or handle') end,
    StartParticleFxNonLoopedAtCoord = function(...)
        assert(select('#', ...) == 11, 'non-looped coordinate native has eleven arguments')
        return 42
    end,
    SetPedComponentVariation = function() end,
    SetPedPropIndex = function(_, _, _, _, attach) assert(attach == false, 'ped prop attach flag must be boolean') end,
}, {__index = _G})
local Particle = assert(loadfile('lib/particles/client/particles.lua', 't', env))()
local pos = {x = 0, y = 0, z = 0}
local token = Particle.Play('test_dictionary', 'test_effect', pos, pos, 1, pos, true, 100)
assert(token == '42', 'repeating particle identity remains a string')
Particle.Stop(token)
Particle.Play('test_dictionary', 'test_effect', pos, pos, 1, pos, false, 100)
env.StartParticleFxNonLoopedAtCoord = function() return 0 end
assert(Particle.Play('test_dictionary', 'test_effect', pos, pos, 1, pos, false, 100) == nil,
    'failed native creation releases its dictionary without passing zero to a removal native')
local Utility = assert(loadfile('lib/utility/client/utility.lua', 't', env))()
local skin = {clothing = {}, props = {}}
for i = 0, 13 do skin.clothing[i], skin.props[i] = {0, 0}, {0, 0} end
assert(Utility.SetEntitySkinData(1, skin), 'skin restoration succeeds with typed native flags')
print('native_contracts: particle fallback/stop and ped prop native contracts passed')

