Housing = Housing or {}

local function integer(value, maximum)
    if type(value) ~= 'number' and type(value) ~= 'string' then return nil end
    value = tonumber(value)
    if value and value > 0 and value <= maximum and value % 1 == 0 then return value end
end

local function property(value)
    if value == nil or value == false then return true, false end
    if type(value) == 'string' then
        return #value > 0 and #value <= 128 and not value:find('%c'), value
    end
    if type(value) == 'number' and integer(value, 2147483647) then return true, value end
    return false
end

local function get(fn, ...)
    if type(fn) ~= 'function' then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local generations = {}
local function publish(src, insideId, provider)
    src = integer(src, 65535)
    local valid, normalized = property(insideId)
    if not src or not valid then return false, 'invalid_request' end
    local generation = generations[src] or 0
    if provider and (Housing.GetResourceName() ~= provider or GetResourceState(provider) ~= 'started') then
        return false, 'provider_unavailable'
    end
    local playerName = GetPlayerName(src)
    if not playerName then return false, 'player_unavailable' end
    local framework = get(Framework.GetResourceName)
    if not framework then return false, 'player_unavailable' end
    local identifier
    if framework ~= 'default' then
        if GetResourceState(framework) ~= 'started' or not get(Framework.GetPlayer, src) then
            return false, 'player_unavailable'
        end
        identifier = get(Framework.GetPlayerIdentifier, src)
        if identifier == nil or identifier == false then return false, 'player_unavailable' end
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'player_unavailable' end
    local bucket, coords = GetPlayerRoutingBucket(src), GetEntityCoords(ped)
    local kind = type(coords)
    if kind ~= 'vector3' and kind ~= 'vector4' and kind ~= 'table' then return false, 'player_unavailable' end
    for _, axis in ipairs({'x', 'y', 'z'}) do
        local value = coords[axis]
        if type(value) ~= 'number' or value ~= value or math.abs(value) == math.huge then return false, 'player_unavailable' end
    end
    if type(bucket) ~= 'number' or bucket < 0 or bucket > 2147483647 or bucket % 1 ~= 0 then return false, 'player_unavailable' end
    if framework ~= 'default' and (get(Framework.GetPlayerIdentifier, src) ~= identifier
        or not get(Framework.GetPlayer, src) or GetResourceState(framework) ~= 'started') then
        return false, 'player_unavailable'
    end
    if (generations[src] or 0) ~= generation or GetPlayerName(src) ~= playerName
        or GetPlayerPed(src) ~= ped or get(Framework.GetResourceName) ~= framework then
        return false, 'player_unavailable'
    end
    if provider and (Housing.GetResourceName() ~= provider or GetResourceState(provider) ~= 'started') then
        return false, 'provider_unavailable'
    end
    -- Historical name: this is a server-local notification, never a client broadcast.
    -- Reported property data is not authorization to enter, mutate or access a stash.
    TriggerEvent('concept_bridge:Client:OnPlayerInside', src, normalized, bucket, coords)
    return true
end

--- Trusted server code may explicitly publish another player's notification.
Housing.PublishPlayerInside = function(src, insideId)
    return publish(src, insideId)
end

--- Provider observations bind network traffic to its sender and active adapter.
Housing.ObservePlayerInside = function(src, insideId, provider)
    local sender = tonumber(source)
    if sender and sender > 0 and integer(src, 65535) ~= sender then return false, 'invalid_source' end
    if type(provider) ~= 'string' or provider == 'default' then return false, 'provider_unavailable' end
    return publish(src, insideId, provider)
end

-- The BCS client sends only property data. Never accept (playerId, propertyId).
RegisterNetEvent('concept_bridge:Server:_OnPlayerInside', function(...)
    local src = source
    local insideId = ...
    if select('#', ...) > 1 or not integer(src, 65535) then return false, 'invalid_request' end
    return Housing.ObservePlayerInside(src, insideId, 'bcs-housing')
end)

-- AddEventHandler alone does not expose this interface to network traffic.
AddEventHandler('concept_bridge:Server:PublishPlayerInside', function(src, insideId)
    if tonumber(source) and tonumber(source) > 0 then return false, 'invalid_source' end
    return Housing.PublishPlayerInside(src, insideId)
end)

local function invalidate(src)
    src = integer(src, 65535)
    if src then generations[src] = (generations[src] or 0) + 1 end
end
AddEventHandler('playerDropped', function() invalidate(source) end)
AddEventHandler('concept_bridge:Server:OnPlayerUnload', invalidate)

Housing.GetResourceName = function()
    return 'default'
end

return Housing
