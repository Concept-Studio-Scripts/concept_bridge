Shells = Shells or {}
Shells.All = Shells.All or {}
Shells.ActivePlayers = Shells.ActivePlayers or {} -- Track players in shells

Shells.Interactable = Shells.Interactable or {}
Shells.BucketsInUse = Shells.BucketsInUse or {} -- Track buckets in use

local hooks, visits, transitioning, generations, bucketOwners = {}, {}, {}, {}, {}

local function callable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' then return false end
    if rawget(value, '__cfx_functionReference') ~= nil then return true end
    local meta = getmetatable(value)
    return type(meta) == 'table' and type(meta.__call) == 'function'
end

local function identifier(value)
    if type(value) == 'string' then return #value > 0 and #value <= 128 and not value:find('%c') end
    return type(value) == 'number' and value >= 0 and value <= 2147483647 and value % 1 == 0
end

local function playerSource(value)
    if type(value) ~= 'number' and type(value) ~= 'string' then return end
    value = tonumber(value)
    if value and value > 0 and value <= 65535 and value % 1 == 0 then return value end
end

local function clientData(value, seen)
    local kind = type(value)
    if callable(value) or (kind == 'table' and rawget(value, '__cfx_functionReference')) then return end
    if kind == 'string' or kind == 'boolean' or kind == 'vector2' or kind == 'vector3' or kind == 'vector4' or kind == 'quaternion' then return value end
    if kind == 'number' then
        if value == value and math.abs(value) < math.huge then return value end
        return
    end
    if kind ~= 'table' then return end
    seen = seen or {}
    if seen[value] then return end
    seen[value] = true
    local result = {}
    for key, item in pairs(value) do
        if type(key) == 'string' or type(key) == 'number' then result[key] = clientData(item, seen) end
    end
    seen[value] = nil
    return result
end

local function near(src, point)
    if type(point) ~= 'table' or not point.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local distance = point.distance or 2.0
    if type(distance) ~= 'number' or distance <= 0 or distance == math.huge then return false end
    if not coords then return false end
    local squared = 0
    for _, axis in ipairs({'x', 'y', 'z'}) do
        local a, b = coords[axis], point.coords[axis]
        if type(a) ~= 'number' or type(b) ~= 'number' or a ~= a or b ~= b or math.abs(a) == math.huge or math.abs(b) == math.huge then return false end
        squared = squared + (a - b) ^ 2
    end
    return squared <= distance ^ 2
end

local function notifyExit(src, shellId, hook)
    if not hook then return end
    local ok = pcall(hook, src, shellId)
    if not ok then print(('[concept_bridge] Shell %s onExit failed after cleanup.'):format(tostring(shellId))) end
end

local function locked(src, fn)
    if transitioning[src] then return false, 'transition_busy' end
    transitioning[src] = true
    local ok, success, reason = pcall(fn)
    transitioning[src] = nil
    if not ok then
        print('[concept_bridge] Shell transition failed.')
        return false, 'transition_failed'
    end
    return success, reason
end

local function allocateBucket()
    for bucket = 1000, 9999 do
        if not Shells.BucketsInUse[tostring(bucket)] then return bucket end
    end
    error('No shell routing buckets available')
end

function Shells.Interactable.New(_type, id, model, coords, rotation, entityType, distance, meta)
    assert(_type, "Shells.Interactable.Create: 'type' is required")
    assert(id, "Shells.Interactable.Create: 'name' is required")
    assert(coords, "Shells.Interactable.Create: 'coords' is required")
    return {
        type = _type,
        id = id,
        model = model,
        coords = coords,
        rotation = rotation or vector3(0.0, 0.0, 0.0),
        distance = distance or 2.0,
        entityType = entityType or "object", -- Default entity type
        meta = clientData(meta or {}),
    }
end

function Shells.New(data)
    local id = data.id or lib.string.random('................')
    local _type = data.type or "none"
    local model = data.model
    local size = data.size or vector3(10.0, 10.0, 10.0) -- Default size if not provided
    local coords = data.coords or vector3(0.0, 0.0, 0.0) -- Default coordinates if not provided
    local rotation = data.rotation or vector3(0.0, 0.0, 0.0) -- Default rotation if not provided
    local interior = data.interior or {}
    local exterior = data.exterior or {}
    if Shells.All[id] then
        for _, activeId in pairs(Shells.ActivePlayers) do
            if activeId == id then return nil, 'shell_in_use' end
        end
    end
    local bucket = data.bucket or (hooks[id] and hooks[id].bucket) or allocateBucket()
    if type(bucket) ~= 'number' or bucket <= 0 or bucket > 2147483647 or bucket % 1 ~= 0 then return nil, 'invalid_bucket' end
    if bucketOwners[tostring(bucket)] and bucketOwners[tostring(bucket)] ~= id then return nil, 'bucket_in_use' end
    if not identifier(id) then return nil, 'invalid_shell' end
    if data.onEnter ~= nil and not callable(data.onEnter) then return nil, 'invalid_hook' end
    if data.onExit ~= nil and not callable(data.onExit) then return nil, 'invalid_hook' end
    assert(id, "Shells.Create: 'id' is required")
    assert(model, "Shells.Create: 'shellModel' is required")
    assert(coords, "Shells.Create: 'coords' is required")

    local interiorInteractions = {}
    for k, v in pairs(interior or {}) do
        local interiorCoords = coords + (v.offset or vector3(0.0, 0.0, 0.0))
        local interaction = Shells.Interactable.New(
            v.type or "none",
            v.id or lib.string.random('................'),
            v.model,
            interiorCoords,
            v.rotation or vector3(0.0, 0.0, 0.0),
            v.entityType or "object", -- Default entity type for interior interactions
            v.distance or 2.0,
            v.meta
        )
        interiorInteractions[interaction.id] = interaction
    end

    local exteriorInteractions = {}
    for k, v in pairs(exterior or {}) do
        local interaction = Shells.Interactable.New(
            v.type or "none",
            v.id or lib.string.random('................'),
            v.model,
            v.coords,
            v.rotation or vector3(0.0, 0.0, 0.0),
            v.entityType or "object", -- Default entity type for exterior interactions
            v.distance or 2.0,
            v.meta
        )
        exteriorInteractions[interaction.id] = interaction
    end

    local shellData = {
        id = id,
        type = _type,
        entityType = "object", -- Default entity type for shells
        model = model,
        coords = coords,
        size = size or vector3(10.0, 10.0, 10.0), -- Default size if not provided
        rotation = rotation or vector3(0.0, 0.0, 0.0),
        interior = interiorInteractions,
        exterior = exteriorInteractions,
        bucket = bucket,
    }

    local previous = hooks[id]
    if previous and previous.bucket ~= bucket then
        bucketOwners[tostring(previous.bucket)], Shells.BucketsInUse[tostring(previous.bucket)] = nil, nil
    end
    hooks[id] = {onEnter = data.onEnter, onExit = data.onExit, bucket = bucket}
    bucketOwners[tostring(bucket)], Shells.BucketsInUse[tostring(bucket)] = id, true
    Shells.All[id] = shellData
    return shellData
end

function Shells.Create(data)
    local shell, reason = Shells.New(data)
    if not shell then return nil, reason end
    TriggerClientEvent('concept_bridge:client:CreateShell', -1, clientData(shell))
    return shell
end

function Shells.CreateBulk(shells)
    assert(shells, "Shells.CreateBulk: 'shells' is required")
    assert(type(shells) == "table", "Shells.CreateBulk: 'shells' must be a table")
    local toClient = {}
    local function publishCreated()
        if next(toClient) then
            TriggerClientEvent('concept_bridge:client:CreateShells', -1, toClient)
        end
    end
    for _, shellData in pairs(shells) do
        local ok, shell, reason = pcall(Shells.New, shellData)
        if not ok then
            publishCreated()
            error(shell, 0)
        end
        if not shell then
            publishCreated()
            return false, reason
        end
        toClient[shell.id] = clientData(shell)
    end
    TriggerClientEvent('concept_bridge:client:CreateShells', -1, toClient)
    return true
end

local function enter(src, shellId, entranceId, network)
    src = playerSource(src)
    if not src or not identifier(shellId) or not identifier(entranceId) then return false, 'invalid_request' end
    return locked(src, function()
        local key = tostring(src)
        local shell, policy = Shells.All[shellId], hooks[shellId]
        if not shell or not policy then return false, 'unknown_shell' end
        local playerName, generation = GetPlayerName(src), generations[src] or 0
        if not playerName then return false, 'player_unavailable' end
        if Shells.ActivePlayers[key] == shellId then return true end
        local entrance = shell.exterior[entranceId]
        local exitId = entrance and type(entrance.meta) == 'table' and entrance.meta.link
        local interior = identifier(exitId) and shell.interior[exitId]
        if not interior then return false, 'invalid_entrance' end
        local previous = visits[key]
        local currentBucket = GetPlayerRoutingBucket(src)
        if previous and currentBucket ~= previous.bucket then return false, 'bucket_changed' end
        if network and not near(src, entrance) then return false, 'out_of_range' end
        if policy.onEnter then
            local ok, allowed = pcall(policy.onEnter, src, shellId)
            if not ok or not allowed then return false, 'access_denied' end
        end
        if GetPlayerName(src) ~= playerName or (generations[src] or 0) ~= generation then return false, 'player_unavailable' end
        if Shells.All[shellId] ~= shell or hooks[shellId] ~= policy then return false, 'shell_changed' end
        if GetPlayerRoutingBucket(src) ~= currentBucket then return false, 'bucket_changed' end
        if network and not near(src, entrance) then return false, 'out_of_range' end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return false, 'player_unavailable' end
        local rootCoords = previous and previous.returnCoords or GetEntityCoords(ped)
        local priorShell = Shells.ActivePlayers[key]
        SetPlayerRoutingBucket(src, policy.bucket)
        visits[key] = {shellId = shellId, bucket = policy.bucket,
            previousBucket = previous and previous.previousBucket or currentBucket,
            returnCoords = rootCoords, entranceId = entranceId,
            switched = previous ~= nil, onExit = policy.onExit}
        Shells.ActivePlayers[key] = shellId
        TriggerClientEvent('concept_bridge:client:EnterShell', src, shellId, exitId, priorShell)
        if previous then notifyExit(src, previous.shellId, previous.onExit) end
        return true
    end)
end

local function leave(src, shellId, oldId, network)
    src = playerSource(src)
    if not src or not identifier(shellId) then return false, 'invalid_request' end
    return locked(src, function()
        local key = tostring(src)
        local visit = visits[key]
        if not visit or visit.shellId ~= shellId or Shells.ActivePlayers[key] ~= shellId then return false, 'not_inside' end
        local playerName, generation = GetPlayerName(src), generations[src] or 0
        local shell = Shells.All[shellId]
        local exitId, returnCoords
        if oldId ~= nil then
            if not identifier(oldId) then return false, 'invalid_exit' end
            local interior = shell and shell.interior[oldId]
            exitId = interior and type(interior.meta) == 'table' and interior.meta.link
            if not identifier(exitId) or not shell.exterior[exitId] then return false, 'invalid_exit' end
            if network and (not near(src, interior) or GetPlayerRoutingBucket(src) ~= visit.bucket) then return false, 'out_of_range' end
        else
            if network then return false, 'invalid_exit' end
            exitId = visit.entranceId
            if not shell or not shell.exterior[exitId] then returnCoords = visit.returnCoords end
        end
        if visit.switched then returnCoords = visit.returnCoords end
        local connected = GetPlayerName(src) ~= nil
        if connected then SetPlayerRoutingBucket(src, visit.previousBucket) end
        visits[key], Shells.ActivePlayers[key] = nil, nil
        notifyExit(src, shellId, visit.onExit)
        if connected and GetPlayerName(src) == playerName and (generations[src] or 0) == generation then
            TriggerClientEvent('concept_bridge:client:ExitShell', src, shellId, exitId, returnCoords)
        end
        return true
    end)
end

function Shells.Enter(src, shellId, entranceId)
    return enter(src, shellId, entranceId, false)
end

function Shells.Exit(src, shellId, oldId)
    return leave(src, shellId, oldId, false)
end

local function cleanup(src, dropped, stopping)
    src = playerSource(src)
    if not src then return end
    generations[src] = (generations[src] or 0) + 1
    local key = tostring(src)
    local visit = visits[key]
    if not visit then Shells.ActivePlayers[key] = nil return end
    if not dropped and GetPlayerName(src) then
        SetPlayerRoutingBucket(src, visit.previousBucket)
        if not stopping then
            TriggerClientEvent('concept_bridge:client:ExitShell', src, visit.shellId, visit.entranceId, visit.returnCoords)
        end
    end
    visits[key], Shells.ActivePlayers[key] = nil, nil
    if not stopping then notifyExit(src, visit.shellId, visit.onExit) end
end

function Shells.Get(shellId)
    assert(shellId, "Shells.GetShellById: 'shellId' is required")
    return Shells.All[shellId]
end

function Shells.Inside(src)
    src = tonumber(src)
    assert(src, "Shells.IsInside: 'src' is required")

    local shellId = Shells.ActivePlayers[tostring(src)]
    if not shellId then
        return false
    end

    local shell = Shells.All[shellId]
    if not shell then
        return false
    end

    return shell
end

function Shells.AddObjects(shellId, objects)
    assert(shellId, "Shells.AddObjects: 'shellId' is required")
    assert(objects, "Shells.AddObjects: 'objects' is required")
    assert(type(objects) == "table", "Shells.AddObjects: 'objects' must be a table")

    local shell = Shells.All[shellId]
    assert(shell, "Shell not found: " .. tostring(shellId))

    local interiors = objects.interior or {}
    local exteriors = objects.exterior or {}
    for _, objData in pairs(interiors) do
        local obj = Shells.Interactable.New(
            objData.type,
            objData.id,
            objData.model,
            objData.coords,
            objData.rotation,
            objData.entityType,
            objData.distance,
            objData.meta
        )
        shell.interior[obj.id] = obj -- Update the shell's interior with the new object
    end
    for _, objData in pairs(exteriors) do
        local obj = Shells.Interactable.New(
            objData.type,
            objData.id,
            objData.model,
            objData.coords,
            objData.rotation,
            objData.entityType,
            objData.distance,
            objData.meta
        )
        shell.exterior[obj.id] = obj -- Update the shell's exterior with the new object
    end

    TriggerClientEvent('concept_bridge:client:AddObjectsToShell', -1, shellId, clientData(shell.interior), clientData(shell.exterior))
    return shell
end

function Shells.RemoveObjects(shellId, objectIds)
    assert(shellId, "Shells.RemoveObjects: 'shellId' is required")
    assert(objectIds, "Shells.RemoveObjects: 'objects' is required")
    if type(objectIds) ~= "table" then
        objectIds = {objectIds} -- Ensure it's a table
    end

    local shell = Shells.All[shellId]
    assert(shell, "Shell not found: " .. tostring(shellId))

    for _, objId in pairs(objectIds) do
        shell.interior[objId] = nil
        shell.exterior[objId] = nil
    end

    TriggerClientEvent('concept_bridge:client:RemoveObjectsFromShell', -1, shellId, objectIds)
    return shell
end

RegisterNetEvent('concept_bridge:server:EnterShell', function(shellId, entranceId)
    local src = source
    return enter(src, shellId, entranceId, true)
end)

RegisterNetEvent('concept_bridge:server:ExitShell', function(shellId, oldId)
    local src = source
    return leave(src, shellId, oldId, true)
end)

AddEventHandler('onPlayerJoining', function(playerId)
    local src = source
    TriggerClientEvent('concept_bridge:client:CreateShells', src, clientData(Shells.All))
end)

function Shells.GetInteractable(shellId, id)
    assert(shellId, "Shells.GetInteractable: 'shellId' is required")
    assert(id, "Shells.GetInteractable: 'id' is required")

    local shell = Shells.All[shellId]
    if not shell then
        return nil, "Shell not found: " .. tostring(shellId)
    end

    local interactable = shell.interior[id] or shell.exterior[id]
    if not interactable then
        return nil, "Interactable not found: " .. tostring(id)
    end

    return interactable
end

function Shells.GetClosestInteractable(shellId, coords, exterior)
    assert(shellId, "Shells.GetClosestInteriorInteractable: 'shellId' is required")
    assert(coords, "Shells.GetClosestInteriorInteractable: 'coords' is required")

    local shell = Shells.All[shellId]
    if not shell then
        return nil, "Shell not found: " .. tostring(shellId)
    end

    local closest = nil
    local closestDistance = math.huge
    if exterior then
        for _, interactable in pairs(shell.exterior) do
            local distance = #(coords - interactable.coords)
            if distance < closestDistance then
                closestDistance = distance
                closest = interactable
            end
        end
        return closest, closestDistance
    end

    for _, interactable in pairs(shell.interior) do
        local distance = #(coords - interactable.coords)
        if distance < closestDistance then
            closestDistance = distance
            closest = interactable
        end
    end
    return closest, closestDistance
end

local testShell = nil
RegisterCommand('shells:create', function(source, args, rawCommand)
    local coords = GetEntityCoords(GetPlayerPed(source))
    if testShell then
        Shells.Exit(source, testShell.id, 'exit1') -- Exit previous shell if it exists
    end
    testShell = Shells.Create({
        id = lib.string.random('................'),
        type = "shell",
        model = "shell_garagem",
        coords = coords + vector3(0.0, 0.0, 100.0), -- Adjusted to place shell slightly below player
        rotation = vector3(0.0, 0.0, 0.0),
        size = vector3(10.0, 10.0, 10.0),
        interior = {
            {
                id = 'exit1',
                type = 'exit',
                coords = coords + vector3(0.0, 0.0, 1.0),
                rotation = vector3(0.0, 0.0, 0.0),
                distance = 2.0,
                meta = {
                    link = 'entrance1',
                }
            }
        },
        exterior = {
            {
                id = 'entrance1',
                type = 'entrance',
                -- entityType = "object",
                -- model = "xm_int_lev_sub_chair_02",
                coords = coords - vector3(0.0, 0.0, 0.5),
                rotation = vector3(0.0, 0.0, 0.0),
                distance = 2.0,
                meta = {
                    link = 'exit1',
                }
            }
        },
    })
end, true)

RegisterCommand('shells:addobject', function(source, args, rawCommand)
    if not testShell then
        print("No shell created. Use /shells:create first.")
        return
    end
    local model = args[1]
    if not model then
        print("Usage: /shells:addobject <shellId> <model>")
        return
    end

    local shellId = testShell.id
    local coords = GetEntityCoords(GetPlayerPed(source))
    local objectData = {
        type = "none",
        entityType = "ped",
        id = lib.string.random('................'),
        model = model,
        coords = coords - vector3(0.0, 0.0, 0.5), -- Adjusted to place object slightly above player
        rotation = vector3(0.0, 0.0, 0.0),
        distance = 2.0,
        meta = {}
    }
    Shells.AddObjects(shellId, {interior = {objectData}})
end, true)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(visits) do cleanup(src, false, true) end
    for bucket in pairs(Shells.BucketsInUse) do Shells.BucketsInUse[bucket] = nil end
    for bucket in pairs(bucketOwners) do bucketOwners[bucket] = nil end
    for id in pairs(hooks) do hooks[id] = nil end
end)

AddEventHandler('concept_bridge:Server:OnPlayerUnload', function(src)
    cleanup(src, false, false)
end)

AddEventHandler('playerDropped', function()
    cleanup(source, true, false)
end)

return Shells
