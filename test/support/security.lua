-- Load actual domain helpers into dependency-double environments.
return function(env, root)
    root = root or './'
    env.GetGameTimer = env.GetGameTimer or function() return 1000 end
    env.GetPlayerName = env.GetPlayerName or function(src) return src and ('player:' .. src) end
    env.GetPlayerIdentifierByType = env.GetPlayerIdentifierByType or function(src) return 'license:' .. src end
    env.Framework = env.Framework or {GetResourceName = function() return 'default' end}
    local previous, loaded = env.lib.require, {}
    env.lib.require = function(name)
        if name:find('^@concept_bridge%.lib%.security%.server%.') then
            local path = name:gsub('^@[^.]+%.', ''):gsub('%.', '/') .. '.lua'
            if not loaded[name] then loaded[name] = assert(loadfile(root .. path, 't', env))() end
            return loaded[name]
        end
        if previous then return previous(name) end
        error('unexpected dependency: ' .. name)
    end
end
