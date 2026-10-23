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

-- Execute the timer callback: a successful restart must keep the stable token,
-- then a failed restart must end the timer and release its tracked dictionary.
for _, useLoopedNative in ipairs({true, false}) do
    for _, failure in ipairs({{value = 0}, {value = false}, {}}) do
        local thread
        local starts, waits, releases = 0, 0, 0
        local function startEffect()
            starts = starts + 1
            if starts <= 2 then return 40 + starts end
            return failure.value
        end
        local recurringEnv = setmetatable({
            CreateThread = function(callback) thread = callback end,
            StartParticleFxLoopedAtCoord = useLoopedNative and startEffect or function() return 0 end,
            DoesParticleFxLoopedExist = function(handle) return handle ~= 0 end,
            StartParticleFxNonLoopedAtCoord = startEffect,
            RemoveNamedPtfxAsset = function(dict)
                assert(dict == 'test_dictionary', 'failed restarts release the dictionary')
                releases = releases + 1
            end,
        }, {__index = env})
        recurringEnv.Wait = function(delay)
            if delay ~= 100 then return end
            waits = waits + 1
            assert(waits <= 2, 'failed restarts must not keep retrying')
            if waits == 2 then
                assert(recurringEnv.Particles['41'] == 42, 'restarts preserve the original token')
            end
        end
        local recurringParticle = assert(loadfile('lib/particles/client/particles.lua', 't', recurringEnv))()
        local recurringToken = recurringParticle.Play('test_dictionary', 'test_effect', pos, pos, 1, pos, true, 100)
        assert(recurringToken == '41' and thread, 'repeating effects schedule their timer')
        thread()
        assert(starts == 3 and waits == 2, 'timer stops immediately after a failed restart')
        assert(recurringEnv.Particles[recurringToken] == nil, 'failed restarts clear the tracked token')
        assert(releases == 1, 'failed restarts release the dictionary exactly once')
        recurringParticle.Stop(recurringToken)
        assert(releases == 1, 'stopping a failed effect does not unload its dictionary again')
    end
end

local Utility = assert(loadfile('lib/utility/client/utility.lua', 't', env))()
local skin = {clothing = {}, props = {}}
for i = 0, 13 do skin.clothing[i], skin.props[i] = {0, 0}, {0, 0} end
assert(Utility.SetEntitySkinData(1, skin), 'skin restoration succeeds with typed native flags')
print('native_contracts: particle fallback/restart/stop and ped prop native contracts passed')
