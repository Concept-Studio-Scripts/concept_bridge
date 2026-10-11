-- Minimal dependency doubles; assertions live in bridge contract tests.
return function(env)
    local lib = env.lib or {}
    lib.callback = lib.callback or {register = function() end}
    lib.table = {}
    local function clone(value)
        if type(value) ~= 'table' then return value end
        local result = {}
        for key, entry in pairs(value) do result[key] = clone(entry) end
        return result
    end
    local function matches(left, right)
        if type(left) ~= 'table' or type(right) ~= 'table' then return left == right end
        for key, value in pairs(left) do if not matches(value, right[key]) then return false end end
        for key in pairs(right) do if left[key] == nil then return false end end
        return true
    end
    lib.table.deepclone, lib.table.matches = clone, matches
    lib.math = {clamp = function(value, lower, upper) return math.max(lower, math.min(value, upper)) end}
    env.lib = lib
    return lib
end
