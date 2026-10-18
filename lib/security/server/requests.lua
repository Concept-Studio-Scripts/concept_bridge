-- Domain request checks only. ox_lib owns callback registration and transport.
local Requests = {}
local sessions, revisions, slots = {}, {}, {}

function Requests.Integer(value, low, high)
    return type(value) == 'number' and value == value and value % 1 == 0
        and value >= low and value <= high
end

function Requests.Text(value, maximum, empty, multiline)
    if type(value) ~= 'string' or #value > maximum or (not empty and #value == 0) then return false end
    if multiline then value = value:gsub('[\n\r\t]', '') end
    return not value:find('%c')
end

local function get(fn, ...)
    if type(fn) ~= 'function' then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return value end
end

local function framework()
    return Framework or (Bridge and Bridge.Framework)
end

local function provider(domain)
    local module = _G[domain] or (Bridge and Bridge[domain])
    return module and get(module.GetResourceName)
end

local function character(src, name, required)
    local fw = framework()
    if name == 'default' then
        return GetPlayerIdentifierByType(src, 'license')
    end
    if required and (not fw or not get(fw.GetPlayer, src)) then return nil end
    local identifier = fw and get(fw.GetPlayerIdentifier, src)
    if required and (identifier == nil or identifier == false) then return nil end
    if identifier == nil then return false end
    return identifier
end

function Requests.Current(ctx)
    if (sessions[ctx.src] or 0) ~= ctx.session or not GetPlayerName(ctx.src)
        or (revisions.Framework or 0) ~= ctx.frameworkRevision
        or (revisions[ctx.domain] or 0) ~= ctx.revision
        or provider('Framework') ~= ctx.framework or provider(ctx.domain) ~= ctx.provider
        or (ctx.framework ~= 'default' and GetResourceState(ctx.framework) ~= 'started')
        or (ctx.provider ~= 'default' and GetResourceState(ctx.provider) ~= 'started') then return false end
    local identity = character(ctx.src, ctx.framework, ctx.required)
    -- Identity reads can yield too; recheck the captured epochs afterwards.
    return identity == ctx.character and identity ~= nil
        and (sessions[ctx.src] or 0) == ctx.session
        and (revisions.Framework or 0) == ctx.frameworkRevision
        and (revisions[ctx.domain] or 0) == ctx.revision
        and GetPlayerName(ctx.src) ~= nil
        and provider('Framework') == ctx.framework and provider(ctx.domain) == ctx.provider
        and (ctx.framework == 'default' or GetResourceState(ctx.framework) == 'started')
        and (ctx.provider == 'default' or GetResourceState(ctx.provider) == 'started')
end

function Requests.Finish(ctx)
    local domain = slots[ctx.key]
    if domain and domain[ctx.src] and domain[ctx.src].busy == ctx then domain[ctx.src].busy = nil end
end

function Requests.Capture(domain, src, expected, requireCharacter)
    src = tonumber(src)
    if not Requests.Integer(src, 1, 65535) or not GetPlayerName(src) then return nil, 'player_unavailable' end
    local ctx = {domain = domain, src = src, provider = expected,
        framework = provider('Framework'), session = sessions[src] or 0,
        revision = revisions[domain] or 0, frameworkRevision = revisions.Framework or 0,
        required = requireCharacter ~= false}
    ctx.character = character(src, ctx.framework, ctx.required)
    if not ctx.framework or ctx.character == nil or not Requests.Current(ctx) then
        return nil, 'player_unavailable'
    end
    return ctx
end

-- concurrent: read-only requests may overlap (cash and bank asked together); the burst still limits them.
function Requests.Begin(domain, src, expected, interval, requireCharacter, key, burst, concurrent)
    src = tonumber(src)
    if not Requests.Integer(src, 1, 65535) or not GetPlayerName(src) then return nil, 'player_unavailable' end
    key = key or domain
    slots[key] = slots[key] or {}
    local slot = slots[key][src] or {}
    slots[key][src] = slot
    local now = GetGameTimer()
    if slot.busy and not concurrent then return nil, 'request_busy' end
    if not slot.at or now < slot.at or now - slot.at >= interval then slot.at, slot.count = now, 0 end
    if slot.count >= (burst or 1) then return nil, 'rate_limited' end
    slot.count = slot.count + 1
    if concurrent then
        local ctx, reason = Requests.Capture(domain, src, expected, requireCharacter)
        if not ctx then return nil, reason end
        ctx.key = key
        return ctx
    end
    -- Reserve before identity reads, which may yield in custom adapters.
    local reservation = {}
    slot.busy = reservation
    local ctx, reason = Requests.Capture(domain, src, expected, requireCharacter)
    if slot.busy ~= reservation then return nil, 'request_expired' end
    slot.busy = ctx
    if not ctx then return nil, reason end
    ctx.key = key
    return ctx
end

function Requests.Execute(ctx, fn, ...)
    local result = table.pack(pcall(fn, ...))
    local current = Requests.Current(ctx)
    Requests.Finish(ctx)
    if not current then return false, 'request_expired' end
    if not result[1] then return false, 'provider_error' end
    return true, table.unpack(result, 2, result.n)
end

-- Client replies/payloads may contain data, never functions, references or cycles.
function Requests.Copy(value)
    local seen, nodes, bytes = {}, 0, 0
    local function copy(entry, depth)
        nodes = nodes + 1
        if nodes > 2048 or depth > 8 then error('payload_too_large') end
        local kind = type(entry)
        if kind == 'nil' or kind == 'boolean' then return entry end
        if kind == 'number' then
            if entry ~= entry or math.abs(entry) > 1e12 then error('invalid_number') end
            return entry
        end
        if kind == 'string' then
            bytes = bytes + #entry
            if #entry > 8192 or bytes > 65536 or entry:find('%z') then error('invalid_string') end
            return entry
        end
        if kind == 'vector2' or kind == 'vector3' or kind == 'vector4' then
            copy(entry.x, depth + 1) copy(entry.y, depth + 1)
            if kind ~= 'vector2' then copy(entry.z, depth + 1) end
            if kind == 'vector4' then copy(entry.w, depth + 1) end
            return entry
        end
        if kind ~= 'table' or getmetatable(entry) ~= nil or seen[entry] then error('invalid_table') end
        seen[entry] = true
        local result = {}
        for key, item in pairs(entry) do
            if not (Requests.Text(key, 128) or Requests.Integer(key, 1, 4096))
                or key == '__cfx_functionReference' then error('invalid_key') end
            result[key] = copy(item, depth + 1)
        end
        seen[entry] = nil
        return result
    end
    local ok, result = pcall(copy, value, 0)
    if ok then return result end
    return nil, 'invalid_payload'
end

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if not src then return end
    sessions[src] = (sessions[src] or 0) + 1
    for _, domain in pairs(slots) do domain[src] = nil end
end)
AddEventHandler('concept_bridge:Server:OnPlayerUnload', function(src)
    src = tonumber(src)
    if src then sessions[src] = (sessions[src] or 0) + 1 end
    -- Keep cooldowns: forwarded framework notifications must not reset abuse limits.
end)
AddEventHandler('Bridge:Refresh', function(domain, _, _, owner)
    if owner == 'concept_bridge' and type(domain) == 'string' then
        revisions[domain] = (revisions[domain] or 0) + 1
    end
end)

return Requests
