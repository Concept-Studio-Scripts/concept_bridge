-- Bridge integration contracts, not ox_lib transport reimplementation tests.
-- Run from the repository root: lua test/ox_lib_contracts.lua
local assertions = 0
local function expect(value, message)
    assertions = assertions + 1
    assert(value, message)
end
local function environment(provider)
    local env = setmetatable({}, {__index = _G})
    env._G = env
    local state = {events = {}, callbacks = {}, points = {}, removed = 0, reindexed = 0}
    env.GetResourceState = function(name) return name == provider and 'started' or 'missing' end
    env.GetCurrentResourceName = function() return 'concept_bridge' end
    env.GetInvokingResource = function() return 'consumer' end
    env.RegisterNetEvent = function(name, handler) state.events[name] = handler end
    env.AddEventHandler = env.RegisterNetEvent
    env.CreateThread, env.Wait, env.TriggerEvent = function() end, function() end, function() end
    env.lib = {callback = {register = function(name, handler) state.callbacks[name] = handler end}}
    return env, state
end
local function loadModule(path, env)
    local file = assert(io.open(path, 'r'))
    local source = file:read('a')
    file:close()
    -- These adapters use FiveM literals/optional access. Translate only the
    -- isolated expressions needed by this stock-Lua fixture.
    source = source:gsub('`[^`]+`', '123')
    source = source:gsub('Bridge.Entity.Get%(targetEntity%)%?%.spawned', '(Bridge.Entity.Get(targetEntity) or {}).spawned')
    return assert(load(source, '@' .. path, 't', env))()
end

-- End-to-end bridge caller -> ox_lib dependency -> registered provider handler.
do
    local server, state = environment('okokPhone')
    local sent
    server.exports = {okokPhone = {
        getEmailAddressFromSource = function(_, src) expect(src == 12, 'email sender is callback source') return 'sender@example.com' end,
        sendEmail = function(_, data) sent = data return true end,
    }}
    loadModule('modules/phone/okokPhone/server.lua', server)
    local client = environment('okokPhone')
    client.lib.callback.await = function(name, delay, ...)
        local args = table.pack(...)
        expect(delay == false and args.n == 3, 'cooldown false does not enter email payload')
        return state.callbacks[name](12, ...)
    end
    local phone = loadModule('modules/phone/okokPhone/client.lua', client)
    expect(phone.SendEmail('recipient@example.com', 'Subject', 'Body'), 'email result forwarded')
    expect(sent.sender == 'sender@example.com' and sent.recipients[1] == 'recipient@example.com', 'email addresses preserved')
    expect(sent.subject == 'Subject' and sent.body == 'Body', 'email subject/body preserved')
end

do
    local env = environment('es_extended')
    env.exports = {es_extended = {getSharedObject = function() return {} end}}
    env.lib.callback.await = function(name, delay, ...)
        expect(delay == false and select('#', ...) == 0, 'framework requests have no stray false payload')
        return name:find('Items', 1, true) and {Items = {water = {name = 'water'}}} or {police = {label = 'Police'}}
    end
    local framework = loadModule('modules/framework/es_extended/client.lua', env)
    expect(framework.ItemList().Items.water.name == 'water', 'ESX items reply consumed')
    expect(framework.GetFrameworkJobs().police.label == 'Police', 'ESX jobs reply consumed')
end

do
    local env = environment('default')
    env.lib.callback.await = function(name, target, ...)
        expect(name == 'concept_bridge:cb:GetAppearance' and target == 12 and select('#', ...) == 0, 'appearance has explicit client target')
        return {model = 123}
    end
    local clothing = loadModule('modules/clothing/_default/server.lua', env)
    expect(clothing.GetAppearance(12).model == 123, 'appearance reply forwarded')
end

for _, provider in ipairs({'qb-clothing', 'illenium-appearance', 'fivem-appearance', 'esx_skin'}) do
    local env, state = environment(provider)
    env.exports = {['qb-core'] = {GetCoreObject = function() return {} end}}
    env.lib.require = function(path) error('unexpected clothing import: ' .. path) end
    loadModule('modules/clothing/' .. provider .. '/server.lua', env)
    expect(type(state.callbacks['concept_bridge:cb:GetAppearance']) == 'function', provider .. ' registers with ox_lib without bridge callback globals')
end

local vector_mt = {__add = function(a, b) return setmetatable({x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}, getmetatable(a)) end}
local function vec3(x, y, z) return setmetatable({x = x, y = y, z = z}, vector_mt) end
local function worldEnvironment()
    local env, state = environment('default')
    env.vec3, env.vector3 = vec3, vec3
    env.lib.string = {random = function() return 'generated-id' end}
    env.lib.points = {new = function(data)
        data.id = #state.points + 1
        data.remove = function(self) self.removed = true state.removed = state.removed + 1 end
        state.points[#state.points + 1] = data
        return data
    end}
    env.lib.grid = {removeEntry = function() state.reindexed = state.reindexed + 1 end, addEntry = function() end}
    return env, state
end

do
    local env, state = worldEnvironment()
    env.Utility = {}
    env.lib.requestModel = function(model) expect(model == 'model', 'entity streams through ox_lib') return 123 end
    env.GetEntityCoords = function() return vec3(0, 0, 0) end
    env.DoesEntityExist = function(entity) return entity == 88 end
    env.CreateObject = function() return 88 end
    env.FreezeEntityPosition, env.SetEntityRotation, env.SetModelAsNoLongerNeeded = function() end, function() end, function() end
    env.SetEntityAsMissionEntity, env.DeleteEntity, env.SetEntityCoords = function() end, function() end, function() end
    local api = loadModule('lib/entities/client/client_entity.lua', env)
    local definition = {id = 'consumer-entity', coords = vec3(1, 2, 3), model = 'model', entityType = 'object'}
    expect(api.Create(definition) == definition and api.Get('consumer-entity') == definition, 'public entity data and ID retained')
    expect(state.points[1].id == 1 and definition.id == 'consumer-entity', 'ox point ID cannot overwrite entity ID')
    state.points[1]:onEnter()
    expect(api.GetEntity('consumer-entity') == 88, 'proximity entry spawns entity')
    local coords = vec3(4, 5, 6)
    api.SetKey('consumer-entity', 'coords', coords)
    expect(state.reindexed == 1 and state.points[1].coords == coords, 'network coordinate update reindexes ox grid')
    state.points[1]:onExit()
    expect(definition.spawned == nil, 'proximity exit despawns entity')
    api.Destroy('consumer-entity')
    expect(state.removed == 1 and api.Get('consumer-entity') == nil, 'destroy removes ox point and entity record')
    api.Create({id = 'cleanup', coords = coords})
    state.events.onResourceStop('consumer')
    expect(state.removed == 2 and api.Get('cleanup') == nil, 'consumer stop removes owned points')
end

do
    local env, state = worldEnvironment()
    local drawn = 0
    env.lib.marker = {new = function(data)
        expect(data.width == 2 and data.height == 4 and data.coords.x == 2, 'replicated marker fields mapped to ox_lib')
        return {draw = function() drawn = drawn + 1 end}
    end}
    env.exports = function() end
    local api = loadModule('lib/markers/client/markers.lua', env)
    local data = {id = 'marker', position = vec3(1, 2, 3), offset = vec3(1, 0, 0), size = vec3(2, 2, 4), drawDistance = 25}
    expect(api.Create(data) == 'marker' and state.points[1].distance == 25, 'replicated marker uses ox point proximity')
    state.points[1]:nearby()
    expect(drawn == 1, 'ox point drives marker rendering')
    api.Create(data)
    expect(state.points[1].removed and state.removed == 1, 'replacing marker removes previous point')
    state.events.onResourceStop('concept_bridge')
    expect(state.removed == 2 and not api.Remove('marker'), 'resource stop removes remaining markers')
end

print(('ox_lib_contracts: %d assertions passed'):format(assertions))
